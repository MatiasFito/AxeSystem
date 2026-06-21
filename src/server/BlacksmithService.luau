local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local blacksmithZoneUtils = require(sharedFolder:WaitForChild("BlacksmithZoneUtils") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local blacksmithUpgradeResolverModule = require(script.Parent:WaitForChild("BlacksmithUpgradeResolver") :: ModuleScript)

local BlacksmithService = {}

local started = false
local playerData = nil
local axeService = nil
local blacksmithUpgradeResolver = nil

local function buildAxeSnapshot(tier, includeCost)
	if not tier then
		return nil
	end

	local snapshot = {
		id = tier.Id,
		name = tier.Name,
		description = tier.Description,
		power = tier.Power,
		goldMultiplier = tier.GoldMultiplier,
		imageId = tier.ImageId,
	}

	if includeCost then
		snapshot.cost = tier.Cost
	end

	return snapshot
end

local function buildStatePayload(player)
	if not playerData.isLoaded(player) then
		return serviceResult.failure(
			blacksmithConstants.FailureReason.DataNotLoaded,
			blacksmithConstants.getFailureMessage
		)
	end

	local currentTierId = playerData.getAxeTierId(player)
	local currentTier = axeConfig.getTier(currentTierId)

	if not currentTier then
		return serviceResult.failure(
			blacksmithConstants.FailureReason.ConfigError,
			blacksmithConstants.getFailureMessage
		)
	end

	local nextTier = axeConfig.getNextTier(currentTierId)
	local gold = playerData.getGold(player) or 0

	return serviceResult.success({
		gold = gold,
		currentTierId = currentTierId,
		currentAxe = buildAxeSnapshot(currentTier, false),
		nextTierId = nextTier and nextTier.Id or nil,
		nextAxe = buildAxeSnapshot(nextTier, true),
		canUpgrade = nextTier ~= nil and gold >= nextTier.Cost,
		isMaxTier = nextTier == nil,
	})
end

local function handleGetState(player)
	if not blacksmithZoneUtils.getBlacksmithPart() then
		return serviceResult.failure(
			blacksmithConstants.FailureReason.ShopUnavailable,
			blacksmithConstants.getFailureMessage
		)
	end

	return buildStatePayload(player)
end

local function handleUpgrade(player, requestedTierId)
	return blacksmithUpgradeResolver.handleUpgrade(player, requestedTierId)
end
function BlacksmithService.start(playerDataModule, axeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	axeService = axeServiceModule
	blacksmithUpgradeResolver = blacksmithUpgradeResolverModule.create({
		failureReasons = blacksmithConstants.FailureReason,
		buildStatePayload = buildStatePayload,
		isShopAvailable = function()
			return blacksmithZoneUtils.getBlacksmithPart() ~= nil
		end,
		isCharacterInZone = blacksmithZoneUtils.isCharacterInZone,
		buildFailure = function(reason, state)
			return serviceResult.failure(reason, blacksmithConstants.getFailureMessage, state)
		end,
		buildSuccess = serviceResult.success,
		canGrantTier = axeService.canGrantTier,
		grantAxe = axeService.grantAxe,
		setGold = playerData.setGold,
		setAxeTierId = playerData.setAxeTierId,
		warnGrantFailure = function(player, requestedTierId, grantResult)
			warn(
				string.format(
					"Failed to grant upgraded axe '%s' to %s: %s",
					requestedTierId,
					player.Name,
					tostring(grantResult)
				)
			)
		end,
	})

	local blacksmithFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = blacksmithConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = blacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local remotes = remoteRegistry.getOrCreateNamedChildren(blacksmithFolder, {
		{
			Name = blacksmithConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
		{
			Name = blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})
	local getStateRemote = remotes[blacksmithConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	local requestUpgradeRemote = remotes[blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteFunction

	getStateRemote.OnServerInvoke = handleGetState
	requestUpgradeRemote.OnServerInvoke = handleUpgrade
end

return BlacksmithService
