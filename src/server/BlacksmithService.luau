local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local blacksmithZoneUtils = require(sharedFolder:WaitForChild("BlacksmithZoneUtils") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local axeDamageResolverModule = require(script.Parent:WaitForChild("AxeDamageResolver") :: ModuleScript)
local blacksmithRemoteHandlersModule = require(script.Parent:WaitForChild("BlacksmithRemoteHandlers") :: ModuleScript)
local blacksmithRemoteRegistry = require(script.Parent:WaitForChild("BlacksmithRemoteRegistry") :: ModuleScript)
local blacksmithStateBuilderModule = require(script.Parent:WaitForChild("BlacksmithStateBuilder") :: ModuleScript)
local blacksmithUpgradeResolverModule = require(script.Parent:WaitForChild("BlacksmithUpgradeResolver") :: ModuleScript)

local BlacksmithService = {}

local started = false

function BlacksmithService.start(playerDataModule, axeServiceModule, gamePassServiceModule, wishingTreeServiceModule)
	if started then
		return
	end

	started = true

	local function getBlacksmithPartForPlayer(_player)
		return blacksmithZoneUtils.getBlacksmithPart()
	end

	local axeDamageResolver = axeDamageResolverModule.create({
		getAmberUpgradeLevel = playerDataModule.getAmberUpgradeLevel,
		getGamePassDamageMultiplier = function(player)
			if gamePassServiceModule and gamePassServiceModule.getDamageMultiplier then
				return gamePassServiceModule.getDamageMultiplier(player)
			end

			return 1
		end,
		getBlessingDamageMultiplier = function(player)
			if wishingTreeServiceModule and wishingTreeServiceModule.getAxePowerMultiplier then
				return wishingTreeServiceModule.getAxePowerMultiplier(player)
			end

			return 1
		end,
	})

	local blacksmithStateBuilder = blacksmithStateBuilderModule.create({
		failureReasons = blacksmithConstants.FailureReason,
		isPlayerLoaded = playerDataModule.isLoaded,
		getAxeTierId = playerDataModule.getAxeTierId,
		getTier = axeConfig.getTier,
		getNextTier = axeConfig.getNextTier,
		getGold = playerDataModule.getGold,
		resolveFinalDamageForTier = axeDamageResolver.resolveFinalDamageForTier,
		buildFailure = function(reason)
			return serviceResult.failure(reason, blacksmithConstants.getFailureMessage)
		end,
		buildSuccess = serviceResult.success,
	})
	local blacksmithUpgradeResolver = blacksmithUpgradeResolverModule.create({
		failureReasons = blacksmithConstants.FailureReason,
		buildStatePayload = blacksmithStateBuilder.buildStatePayload,
		getBlacksmithPart = getBlacksmithPartForPlayer,
		isCharacterInZone = blacksmithZoneUtils.isCharacterInZone,
		buildFailure = function(reason, state)
			return serviceResult.failure(reason, blacksmithConstants.getFailureMessage, state)
		end,
		buildSuccess = serviceResult.success,
		canGrantTier = axeServiceModule.canGrantTier,
		grantAxe = axeServiceModule.grantAxe,
		setGold = playerDataModule.setGold,
		setAxeTierId = playerDataModule.setAxeTierId,
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
	local blacksmithRemoteHandlers = blacksmithRemoteHandlersModule.create({
		isShopAvailable = function(player)
			return getBlacksmithPartForPlayer(player) ~= nil
		end,
		buildShopUnavailableFailure = function()
			return serviceResult.failure(
				blacksmithConstants.FailureReason.ShopUnavailable,
				blacksmithConstants.getFailureMessage
			)
		end,
		buildStatePayload = blacksmithStateBuilder.buildStatePayload,
		handleUpgrade = blacksmithUpgradeResolver.handleUpgrade,
	})
	local blacksmithRemotes = blacksmithRemoteRegistry.getOrCreateRemotes()

	blacksmithRemoteHandlersModule.bind({
		GetStateRemote = blacksmithRemotes.GetStateRemote,
		RequestUpgradeRemote = blacksmithRemotes.RequestUpgradeRemote,
	}, blacksmithRemoteHandlers)
end

return BlacksmithService
