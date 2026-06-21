local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local blacksmithZoneUtils = require(sharedFolder:WaitForChild("BlacksmithZoneUtils") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local blacksmithStateBuilderModule = require(script.Parent:WaitForChild("BlacksmithStateBuilder") :: ModuleScript)
local blacksmithUpgradeResolverModule = require(script.Parent:WaitForChild("BlacksmithUpgradeResolver") :: ModuleScript)

local BlacksmithService = {}

local started = false
local playerData = nil
local axeService = nil
local blacksmithStateBuilder = nil
local blacksmithUpgradeResolver = nil

local function buildStatePayload(player)
	return blacksmithStateBuilder.buildStatePayload(player)
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
	blacksmithStateBuilder = blacksmithStateBuilderModule.create({
		failureReasons = blacksmithConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAxeTierId = playerData.getAxeTierId,
		getTier = axeConfig.getTier,
		getNextTier = axeConfig.getNextTier,
		getGold = playerData.getGold,
		buildFailure = function(reason)
			return serviceResult.failure(reason, blacksmithConstants.getFailureMessage)
		end,
		buildSuccess = serviceResult.success,
	})
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
