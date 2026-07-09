local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local blacksmithZoneUtils = require(sharedFolder:WaitForChild("BlacksmithZoneUtils") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local blacksmithRemoteHandlersModule = require(script.Parent:WaitForChild("BlacksmithRemoteHandlers") :: ModuleScript)
local blacksmithRemoteRegistry = require(script.Parent:WaitForChild("BlacksmithRemoteRegistry") :: ModuleScript)
local blacksmithSectionMaterializerModule =
	require(script.Parent:WaitForChild("BlacksmithSectionMaterializer") :: ModuleScript)
local blacksmithStateBuilderModule = require(script.Parent:WaitForChild("BlacksmithStateBuilder") :: ModuleScript)
local blacksmithUpgradeResolverModule = require(script.Parent:WaitForChild("BlacksmithUpgradeResolver") :: ModuleScript)

local BlacksmithService = {}

local started = false

function BlacksmithService.start(playerDataModule, axeServiceModule, treePlotServiceModule)
	if started then
		return
	end

	started = true
	local blacksmithSectionMaterializer = blacksmithSectionMaterializerModule.create({
		getPlotSets = treePlotServiceModule.getPlotSets,
	})
	blacksmithSectionMaterializer.materializeAll()

	local function getBlacksmithPartForPlayer(player)
		local plotSetId = treePlotServiceModule.getAssignedPlotSetId(player)

		if typeof(plotSetId) ~= "string" or plotSetId == "" then
			return nil
		end

		return blacksmithZoneUtils.getBlacksmithPartForPlotSet(plotSetId)
	end

	local blacksmithStateBuilder = blacksmithStateBuilderModule.create({
		failureReasons = blacksmithConstants.FailureReason,
		isPlayerLoaded = playerDataModule.isLoaded,
		getAssignedPlotSetId = treePlotServiceModule.getAssignedPlotSetId,
		getAxeTierId = playerDataModule.getAxeTierId,
		getTier = axeConfig.getTier,
		getNextTier = axeConfig.getNextTier,
		getGold = playerDataModule.getGold,
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
