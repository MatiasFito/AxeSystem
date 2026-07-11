local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)

local LumberjackProgressionResolver = {}

local function clonePlotState(plotState)
	local hasLumberjack = plotState.HasLumberjack == true
	local lumberjackLevel = hasLumberjack and math.max(1, plotState.LumberjackLevel or 0) or 0

	return {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = plotState.Unlocked,
		Level = plotState.Level,
		State = plotState.State,
		GrowingUntil = plotState.GrowingUntil,
		HasLumberjack = hasLumberjack,
		LumberjackLevel = lumberjackLevel,
	}
end

function LumberjackProgressionResolver.create(deps)
	local function attemptHire(player, plotId)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		if not deps.getAssignedPlot(player, plotId) then
			return deps.buildFailure(deps.failureReasons.NotOwned)
		end

		local plotState = deps.getTreePlot(player, plotId)
		local gold = deps.getGold(player) or 0
		local hireCost = deps.getHireCost(player, plotId)

		if not plotState or not plotState.Unlocked then
			return deps.buildFailure(deps.failureReasons.PlotNotFound)
		end

		if plotState.HasLumberjack == true then
			return deps.buildFailure(deps.failureReasons.AlreadyHired)
		end

		if typeof(hireCost) ~= "number" then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		if gold < hireCost then
			return deps.buildFailure(deps.failureReasons.InsufficientGold)
		end

		local updatedPlotState = clonePlotState(plotState)
		updatedPlotState.HasLumberjack = true
		updatedPlotState.LumberjackLevel = 1

		deps.setGold(player, gold - hireCost)
		deps.setTreePlot(player, plotId, updatedPlotState)
		deps.playHireSuccessTween(player, plotId)
		deps.refreshPlot(player, plotId)
		deps.pushStateUpdate(player, { plotId })

		return deps.buildSuccess(true)
	end

	local function attemptUpgrade(player, plotId)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		if not deps.getAssignedPlot(player, plotId) then
			return deps.buildFailure(deps.failureReasons.NotOwned)
		end

		local plotState = deps.getTreePlot(player, plotId)
		local gold = deps.getGold(player) or 0

		if not plotState or not plotState.Unlocked then
			return deps.buildFailure(deps.failureReasons.PlotNotFound)
		end

		if plotState.HasLumberjack ~= true then
			return deps.buildFailure(deps.failureReasons.NotHired)
		end

		local currentLevel = math.max(1, plotState.LumberjackLevel or 0)

		if currentLevel >= lumberjackConstants.MAX_LEVEL then
			return deps.buildFailure(deps.failureReasons.AlreadyMaxed)
		end

		local upgradeCost = deps.getUpgradeCost(player, plotId, currentLevel)

		if typeof(upgradeCost) ~= "number" then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		if gold < upgradeCost then
			return deps.buildFailure(deps.failureReasons.InsufficientGold)
		end

		local updatedPlotState = clonePlotState(plotState)
		updatedPlotState.LumberjackLevel = currentLevel + 1

		deps.setGold(player, gold - upgradeCost)
		deps.setTreePlot(player, plotId, updatedPlotState)
		deps.refreshPlot(player, plotId)
		deps.pushStateUpdate(player, { plotId })

		return deps.buildSuccess(true)
	end

	return {
		attemptHire = attemptHire,
		attemptUpgrade = attemptUpgrade,
	}
end

return LumberjackProgressionResolver
