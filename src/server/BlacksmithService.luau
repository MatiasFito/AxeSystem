local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local blacksmithZoneUtils = require(sharedFolder:WaitForChild("BlacksmithZoneUtils") :: ModuleScript)

local BlacksmithService = {}

local started = false
local playerData = nil
local axeService = nil

local function getOrCreateChild(parent, name, className)
	local child = parent:FindFirstChild(name)

	if child and child.ClassName == className then
		return child
	end

	if child then
		child:Destroy()
	end

	child = Instance.new(className)
	child.Name = name
	child.Parent = parent

	return child
end

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

local function buildFailure(reason, state)
	local payload = {
		success = false,
		reason = reason,
		message = blacksmithConstants.getFailureMessage(reason),
	}

	if state then
		payload.state = state
	end

	return payload
end

local function buildStatePayload(player)
	if not playerData.isLoaded(player) then
		return buildFailure(blacksmithConstants.FailureReason.DataNotLoaded)
	end

	local currentTierId = playerData.getAxeTierId(player)
	local currentTier = axeConfig.getTier(currentTierId)

	if not currentTier then
		return buildFailure(blacksmithConstants.FailureReason.ConfigError)
	end

	local nextTier = axeConfig.getNextTier(currentTierId)
	local gold = playerData.getGold(player) or 0

	return {
		success = true,
		state = {
			gold = gold,
			currentTierId = currentTierId,
			currentAxe = buildAxeSnapshot(currentTier, false),
			nextTierId = nextTier and nextTier.Id or nil,
			nextAxe = buildAxeSnapshot(nextTier, true),
			canUpgrade = nextTier ~= nil and gold >= nextTier.Cost,
			isMaxTier = nextTier == nil,
		},
	}
end

local function handleGetState(player)
	if not blacksmithZoneUtils.getBlacksmithPart() then
		return buildFailure(blacksmithConstants.FailureReason.ShopUnavailable)
	end

	return buildStatePayload(player)
end

local function handleUpgrade(player, requestedTierId)
	local statePayload = buildStatePayload(player)

	if not statePayload.success then
		return statePayload
	end

	local state = statePayload.state

	if not blacksmithZoneUtils.getBlacksmithPart() then
		return buildFailure(blacksmithConstants.FailureReason.ShopUnavailable, state)
	end

	if not blacksmithZoneUtils.isCharacterInZone(player.Character) then
		return buildFailure(blacksmithConstants.FailureReason.NotInRange, state)
	end

	if state.isMaxTier then
		return buildFailure(blacksmithConstants.FailureReason.AlreadyMaxed, state)
	end

	if typeof(requestedTierId) ~= "string" or requestedTierId ~= state.nextTierId then
		return buildFailure(blacksmithConstants.FailureReason.InvalidTier, state)
	end

	local nextAxe = state.nextAxe

	if not nextAxe then
		return buildFailure(blacksmithConstants.FailureReason.ConfigError, state)
	end

	if state.gold < nextAxe.cost then
		return buildFailure(blacksmithConstants.FailureReason.InsufficientGold, state)
	end

	local canGrantTier = axeService.canGrantTier(requestedTierId)

	if not canGrantTier then
		return buildFailure(blacksmithConstants.FailureReason.ConfigError, state)
	end

	local grantSuccess, grantResult = axeService.grantAxe(player, requestedTierId, true)

	if not grantSuccess then
		warn(
			string.format(
				"Failed to grant upgraded axe '%s' to %s: %s",
				requestedTierId,
				player.Name,
				tostring(grantResult)
			)
		)
		return buildFailure(blacksmithConstants.FailureReason.ConfigError, state)
	end

	playerData.setGold(player, state.gold - nextAxe.cost)
	playerData.setAxeTierId(player, requestedTierId)

	local refreshedStatePayload = buildStatePayload(player)

	if not refreshedStatePayload.success then
		return refreshedStatePayload
	end

	return {
		success = true,
		state = refreshedStatePayload.state,
		purchase = {
			previousTierId = state.currentTierId,
			newTierId = requestedTierId,
			costPaid = nextAxe.cost,
			goldAfter = refreshedStatePayload.state.gold,
		},
	}
end
function BlacksmithService.start(playerDataModule, axeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	axeService = axeServiceModule

	local remotesFolder = getOrCreateChild(ReplicatedStorage, blacksmithConstants.REMOTE_FOLDER_NAME, "Folder")
	local blacksmithFolder =
		getOrCreateChild(remotesFolder, blacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME, "Folder")
	local getStateRemote =
		getOrCreateChild(blacksmithFolder, blacksmithConstants.GET_STATE_REMOTE_NAME, "RemoteFunction")
	local requestUpgradeRemote =
		getOrCreateChild(blacksmithFolder, blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME, "RemoteFunction")

	getStateRemote.OnServerInvoke = handleGetState
	requestUpgradeRemote.OnServerInvoke = handleUpgrade
end

return BlacksmithService
