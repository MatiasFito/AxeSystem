local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local amberShopConstants = require(sharedFolder:WaitForChild("AmberShopConstants") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local amberShopPurchaseResolverModule = require(script.Parent:WaitForChild("AmberShopPurchaseResolver") :: ModuleScript)
local amberShopRemoteHandlers = require(script.Parent:WaitForChild("AmberShopRemoteHandlers") :: ModuleScript)
local amberShopRemoteRegistry = require(script.Parent:WaitForChild("AmberShopRemoteRegistry") :: ModuleScript)
local amberShopStateBuilder = require(script.Parent:WaitForChild("AmberShopStateBuilder") :: ModuleScript)
local walkSpeedController = require(script.Parent:WaitForChild("WalkSpeedController") :: ModuleScript)

local AmberShopService = {}

local started = false
local playerData = nil
local purchaseResolver = nil

local function buildState(player)
	return amberShopStateBuilder.buildState(playerData, player)
end

function AmberShopService.getState(player)
	if not playerData or not playerData.isLoaded(player) then
		return serviceResult.failure(
			amberShopConstants.FailureReason.DataNotLoaded,
			amberShopConstants.getFailureMessage
		)
	end

	return serviceResult.success(buildState(player))
end

function AmberShopService.buyUpgrade(player, upgradeName)
	if not purchaseResolver then
		return serviceResult.failure(amberShopConstants.FailureReason.ConfigError, amberShopConstants.getFailureMessage)
	end

	return purchaseResolver.handlePurchase(player, upgradeName)
end

function AmberShopService.start(playerDataModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	purchaseResolver = amberShopPurchaseResolverModule.create({
		failureReasons = amberShopConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAmber = playerData.getAmber,
		getAmberUpgradeLevel = playerData.getAmberUpgradeLevel,
		setAmber = playerData.setAmber,
		setAmberUpgradeLevel = playerData.setAmberUpgradeLevel,
		savePlayer = playerData.savePlayer,
		getUpgradeStats = rebirthConfig.getUpgradeStats,
		buildState = function(player)
			return buildState(player)
		end,
		buildFailure = function(reason, state)
			return serviceResult.failure(reason, amberShopConstants.getFailureMessage, state)
		end,
		buildSuccess = serviceResult.success,
		applyPurchasedUpgrade = function(player, upgradeName)
			if upgradeName == "WalkSpeed" then
				walkSpeedController.applyToCurrentCharacter(playerData, player)
			end
		end,
	})

	local remotes = amberShopRemoteRegistry.getOrCreateRemotes()
	local handlers = amberShopRemoteHandlers.create({
		getState = AmberShopService.getState,
		buyUpgrade = AmberShopService.buyUpgrade,
	})

	amberShopRemoteHandlers.bind(remotes, handlers)
end

return AmberShopService
