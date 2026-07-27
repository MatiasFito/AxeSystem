local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local damageHubConstants = require(sharedFolder:WaitForChild("DamageHubConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local axeDamageResolverModule = require(script.Parent:WaitForChild("AxeDamageResolver") :: ModuleScript)
local damageHubRemoteHandlers = require(script.Parent:WaitForChild("DamageHubRemoteHandlers") :: ModuleScript)
local damageHubRemoteRegistry = require(script.Parent:WaitForChild("DamageHubRemoteRegistry") :: ModuleScript)
local damageHubStateBuilderModule = require(script.Parent:WaitForChild("DamageHubStateBuilder") :: ModuleScript)

local DamageHubService = {}

local started = false
local playerData = nil
local gamePassService = nil
local wishingTreeService = nil
local stateBuilder = nil

local function buildFailure(reason)
	return serviceResult.failure(reason, damageHubConstants.getFailureMessage)
end

function DamageHubService.getState(player)
	if not playerData or not playerData.isLoaded(player) then
		return buildFailure(damageHubConstants.FailureReason.DataNotLoaded)
	end

	if gamePassService and gamePassService.refreshOwnership then
		gamePassService.refreshOwnership(player)
	end

	if not stateBuilder then
		return buildFailure(damageHubConstants.FailureReason.ConfigError)
	end

	return stateBuilder.buildStatePayload(player)
end

function DamageHubService.start(playerDataModule, gamePassServiceModule, wishingTreeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	gamePassService = gamePassServiceModule
	wishingTreeService = wishingTreeServiceModule

	local axeDamageResolver = axeDamageResolverModule.create({
		getAmberUpgradeLevel = playerData.getAmberUpgradeLevel,
		getGamePassDamageMultiplier = function(player)
			if gamePassService and gamePassService.getDamageMultiplier then
				return gamePassService.getDamageMultiplier(player)
			end

			return 1
		end,
		getBlessingDamageMultiplier = function(player)
			if wishingTreeService and wishingTreeService.getAxePowerMultiplier then
				return wishingTreeService.getAxePowerMultiplier(player)
			end

			return 1
		end,
	})

	stateBuilder = damageHubStateBuilderModule.create({
		failureReasons = damageHubConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAxeTierId = playerData.getAxeTierId,
		getAmberUpgradeLevel = playerData.getAmberUpgradeLevel,
		getOwnership = function(player)
			if gamePassService and gamePassService.getOwnership then
				return gamePassService.getOwnership(player)
			end

			return {}
		end,
		getTier = axeConfig.getTier,
		resolveFinalDamageForTier = axeDamageResolver.resolveFinalDamageForTier,
		buildFailure = buildFailure,
		buildSuccess = serviceResult.success,
	})

	local remotes = damageHubRemoteRegistry.getOrCreateRemotes()
	local handlers = damageHubRemoteHandlers.create({
		getState = DamageHubService.getState,
	})

	damageHubRemoteHandlers.bind(remotes, handlers)
	return remotes
end

return DamageHubService
