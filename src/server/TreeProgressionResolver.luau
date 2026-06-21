local TreeProgressionResolver = {}

function TreeProgressionResolver.create(deps)
	local function attemptUnlock(player, plotId)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		local plotRecord = deps.getAssignedPlot(player, plotId)

		if not plotRecord then
			return deps.buildFailure(deps.failureReasons.NotOwned)
		end

		local plotState = deps.getTreePlot(player, plotId)
		local allPlots = deps.getTreePlots(player) or {}
		local tree = deps.getTreeByPlotId(plotId)
		local gold = deps.getGold(player) or 0

		if not plotState or not tree then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		if plotState.Unlocked then
			return deps.buildFailure(deps.failureReasons.AlreadyUnlocked)
		end

		if not deps.isPlotUnlockable(allPlots, plotId) then
			return deps.buildFailure(deps.failureReasons.NotUnlockable)
		end

		if gold < tree.UnlockCost then
			return deps.buildFailure(deps.failureReasons.InsufficientGold)
		end

		local levelData = deps.getLevelData(tree.Id, 1)

		if not levelData then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		deps.setGold(player, gold - tree.UnlockCost)
		deps.setTreePlot(player, plotId, {
			PlotId = plotId,
			TreeId = tree.Id,
			Unlocked = true,
			Level = 1,
			State = deps.growingState,
			GrowingUntil = deps.getServerNow() + levelData.GrowTime,
		})

		deps.playUnlockButtonSuccessTween(player, plotId)
		deps.materializePlot(player, plotId)

		local nextTree = deps.getTreeByOrder(tree.PlotOrder + 1)
		local changedPlots = { plotId }

		if nextTree then
			deps.updatePromptForPlot(player, nextTree.PlotId)
			table.insert(changedPlots, nextTree.PlotId)
		end

		deps.refreshUnlockButtons(player)
		deps.pushStateUpdate(player, changedPlots)
		return deps.buildSuccess(deps.buildStatePayload(player, changedPlots).state)
	end

	local function attemptUpgrade(player, plotId)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		if not deps.getAssignedPlot(player, plotId) then
			return deps.buildFailure(deps.failureReasons.NotOwned)
		end

		local plotState = deps.getTreePlot(player, plotId)
		local tree = deps.getTreeByPlotId(plotId)
		local gold = deps.getGold(player) or 0

		if not plotState or not tree or not plotState.Unlocked then
			return deps.buildFailure(deps.failureReasons.PlotNotFound)
		end

		local nextLevel = deps.getUpgradeLevel(tree.Id, plotState.Level)

		if not nextLevel then
			return deps.buildFailure(deps.failureReasons.AlreadyMaxed)
		end

		local upgradeCost = deps.getUpgradeCost(tree.Id, plotState.Level)

		if not upgradeCost then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		if gold < upgradeCost then
			return deps.buildFailure(deps.failureReasons.InsufficientGold)
		end

		local nextLevelData = deps.getLevelData(tree.Id, nextLevel)

		if not nextLevelData then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		deps.setGold(player, gold - upgradeCost)

		local updatedPlotState = {
			PlotId = plotState.PlotId,
			TreeId = plotState.TreeId,
			Unlocked = true,
			Level = nextLevel,
			State = plotState.State,
			GrowingUntil = plotState.GrowingUntil,
		}

		if plotState.State == deps.growingState then
			updatedPlotState.GrowingUntil = deps.getServerNow() + nextLevelData.GrowTime
		end

		deps.setTreePlot(player, plotId, updatedPlotState)
		deps.materializePlot(player, plotId)
		deps.refreshUnlockButtons(player)
		deps.pushStateUpdate(player, { plotId })

		return deps.buildSuccess(deps.buildStatePayload(player, { plotId }).state)
	end

	return {
		attemptUnlock = attemptUnlock,
		attemptUpgrade = attemptUpgrade,
	}
end

return TreeProgressionResolver
