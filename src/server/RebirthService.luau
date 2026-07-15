local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local rebirthConstants = require(sharedFolder:WaitForChild("RebirthConstants") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local rebirthRemoteHandlers = require(script.Parent:WaitForChild("RebirthRemoteHandlers") :: ModuleScript)
local rebirthRemoteRegistry = require(script.Parent:WaitForChild("RebirthRemoteRegistry") :: ModuleScript)

local RebirthService = {}

local started = false
local playerData = nil
local treePlotRuntimeService = nil
local treeService = nil
local lumberjackService = nil

local function getMaxUnlockedPlotOrder(treePlots)
	local maxUnlockedPlotOrder = 0

	if typeof(treePlots) ~= "table" then
		return maxUnlockedPlotOrder
	end

	for plotId, plotState in treePlots do
		if plotState.Unlocked == true then
			local tree = treeConfig.getTreeByPlotId(plotId)

			if tree and tree.PlotOrder > maxUnlockedPlotOrder then
				maxUnlockedPlotOrder = tree.PlotOrder
			end
		end
	end

	return maxUnlockedPlotOrder
end

local function refreshRuntimeState(player)
	if treePlotRuntimeService and not treePlotRuntimeService.onPlayerDataReset(player) then
		warn(string.format("RebirthService failed to refresh tree state for %s", player.Name))
	end

	if lumberjackService and not lumberjackService.onPlayerDataReset(player) then
		warn(string.format("RebirthService failed to refresh lumberjack state for %s", player.Name))
	end

	if treeService and treeService.pushStateUpdate then
		treeService.pushStateUpdate(player)
	end
end

function RebirthService.getState(player)
	if not playerData or not playerData.isLoaded(player) then
		return serviceResult.failure(rebirthConstants.FailureReason.DataNotLoaded, rebirthConstants.getFailureMessage)
	end

	return serviceResult.success({
		amber = playerData.getAmber(player) or 0,
		amberGainLevel = playerData.getAmberUpgradeLevel(player, "AmberGain") or 0,
		rebirths = playerData.getRebirths(player) or 0,
		minimumPlotOrder = rebirthConfig.MINIMUM_PLOT_ORDER,
	})
end

function RebirthService.requestRebirth(player)
	if not playerData or not playerData.isLoaded(player) then
		return serviceResult.failure(rebirthConstants.FailureReason.DataNotLoaded, rebirthConstants.getFailureMessage)
	end

	local treePlots = playerData.getTreePlots(player)
	local maxUnlockedPlotOrder = getMaxUnlockedPlotOrder(treePlots)

	if maxUnlockedPlotOrder < rebirthConfig.MINIMUM_PLOT_ORDER then
		return serviceResult.failure(
			rebirthConstants.FailureReason.InsufficientProgress,
			rebirthConstants.getFailureMessage,
			{
				maxUnlockedPlotOrder = maxUnlockedPlotOrder,
				minimumPlotOrder = rebirthConfig.MINIMUM_PLOT_ORDER,
				estimatedAmber = 0,
			}
		)
	end

	local amberGainLevel = playerData.getAmberUpgradeLevel(player, "AmberGain") or 0
	local awardedAmber = rebirthConfig.calculateAmberReward(maxUnlockedPlotOrder, amberGainLevel)
	local rebirthSuccess, updatedState = playerData.applyRebirth(player, awardedAmber)

	if not rebirthSuccess or not updatedState then
		return serviceResult.failure(rebirthConstants.FailureReason.SaveFailed, rebirthConstants.getFailureMessage)
	end

	refreshRuntimeState(player)

	return serviceResult.success({
		awardedAmber = awardedAmber,
		amber = updatedState.Amber,
		rebirths = updatedState.Rebirths,
		maxUnlockedPlotOrder = maxUnlockedPlotOrder,
		minimumPlotOrder = rebirthConfig.MINIMUM_PLOT_ORDER,
	})
end

function RebirthService.start(
	playerDataModule,
	treePlotRuntimeServiceModule,
	treeServiceModule,
	lumberjackServiceModule
)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotRuntimeService = treePlotRuntimeServiceModule
	treeService = treeServiceModule
	lumberjackService = lumberjackServiceModule

	local remotes = rebirthRemoteRegistry.getOrCreateRemotes()
	local handlers = rebirthRemoteHandlers.create({
		getState = RebirthService.getState,
		requestRebirth = RebirthService.requestRebirth,
	})

	rebirthRemoteHandlers.bind(remotes, handlers)
end

return RebirthService
