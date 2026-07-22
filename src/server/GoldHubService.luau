local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local goldHubConstants = require(sharedFolder:WaitForChild("GoldHubConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local goldHubRemoteHandlers = require(script.Parent:WaitForChild("GoldHubRemoteHandlers") :: ModuleScript)
local goldHubRemoteRegistry = require(script.Parent:WaitForChild("GoldHubRemoteRegistry") :: ModuleScript)
local goldHubStateBuilderModule = require(script.Parent:WaitForChild("GoldHubStateBuilder") :: ModuleScript)

local GoldHubService = {}

local started = false
local playerData = nil
local sessionTimeService = nil
local gamePassService = nil
local stateBuilder = nil

local function buildFailure(reason)
	return serviceResult.failure(reason, goldHubConstants.getFailureMessage)
end

function GoldHubService.getState(player)
	if not playerData or not playerData.isLoaded(player) then
		return buildFailure(goldHubConstants.FailureReason.DataNotLoaded)
	end

	if gamePassService and gamePassService.refreshOwnership then
		gamePassService.refreshOwnership(player)
	end

	if not stateBuilder then
		return buildFailure(goldHubConstants.FailureReason.ConfigError)
	end

	return stateBuilder.buildStatePayload(player)
end

function GoldHubService.start(playerDataModule, sessionTimeServiceModule, gamePassServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	sessionTimeService = sessionTimeServiceModule
	gamePassService = gamePassServiceModule
	stateBuilder = goldHubStateBuilderModule.create({
		failureReasons = goldHubConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAxeTierId = playerData.getAxeTierId,
		getAmberUpgradeLevel = playerData.getAmberUpgradeLevel,
		getSessionSeconds = function(player)
			if sessionTimeService and sessionTimeService.getSessionSeconds then
				return sessionTimeService.getSessionSeconds(player)
			end

			return 0
		end,
		getOwnership = function(player)
			if gamePassService and gamePassService.getOwnership then
				return gamePassService.getOwnership(player)
			end

			return {}
		end,
		buildFailure = buildFailure,
		buildSuccess = serviceResult.success,
	})

	local remotes = goldHubRemoteRegistry.getOrCreateRemotes()
	local handlers = goldHubRemoteHandlers.create({
		getState = GoldHubService.getState,
	})

	goldHubRemoteHandlers.bind(remotes, handlers)
	return remotes
end

return GoldHubService
