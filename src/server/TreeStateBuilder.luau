local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local lumberjackConfig = require(sharedFolder:WaitForChild("LumberjackConfig") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)

local TreeStateBuilder = {}

function TreeStateBuilder.isPlotUnlockable(treePlots, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not tree then
		return false
	end

	if tree.PlotOrder == 1 then
		return true
	end

	local previousTree = treeConfig.getTreeByOrder(tree.PlotOrder - 1)

	if not previousTree then
		return false
	end

	local previousPlotState = treePlots[previousTree.PlotId]
	return previousPlotState ~= nil and previousPlotState.Unlocked == true
end

function TreeStateBuilder.buildPlotSnapshot(playerData, player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not plotState or not tree then
		return nil
	end

	local levelData = nil
	local isMaxLevel = false
	local canUpgrade = false
	local upgradeCost = nil
	local hasLumberjack = plotState.HasLumberjack == true
	local lumberjackLevel = hasLumberjack and math.max(1, plotState.LumberjackLevel or 0) or 0
	local lumberjackHireCost = lumberjackConfig.getHireCostByPlotId(plotId)
	local lumberjackUpgradeCost = hasLumberjack and lumberjackConfig.getUpgradeCostByPlotId(plotId, lumberjackLevel)
		or nil
	local canHireLumberjack = plotState.Unlocked and not hasLumberjack
	local canUpgradeLumberjack = plotState.Unlocked and hasLumberjack

	if plotState.Unlocked and plotState.Level > 0 then
		levelData = treeConfig.getLevelData(tree.Id, plotState.Level)
		isMaxLevel = plotState.Level >= tree.MaxLevel
		upgradeCost = treeConfig.getUpgradeCost(tree.Id, plotState.Level)
		canUpgrade = upgradeCost ~= nil
	end

	return {
		plotId = plotId,
		plotOrder = tree.PlotOrder,
		treeId = tree.Id,
		treeName = tree.Name,
		unlocked = plotState.Unlocked,
		level = plotState.Level,
		state = plotState.State,
		isUnlockable = not plotState.Unlocked
			and TreeStateBuilder.isPlotUnlockable(playerData.getTreePlots(player) or {}, plotId),
		unlockCost = tree.UnlockCost,
		canUpgrade = canUpgrade,
		upgradeCost = upgradeCost,
		isMaxLevel = isMaxLevel,
		hasLumberjack = hasLumberjack,
		lumberjackLevel = lumberjackLevel,
		canHireLumberjack = canHireLumberjack,
		lumberjackHireCost = lumberjackHireCost,
		canUpgradeLumberjack = canUpgradeLumberjack,
		lumberjackUpgradeCost = lumberjackUpgradeCost,
		lumberjackGoldBonusPercent = lumberjackConfig.getGoldBonusPercent(lumberjackLevel),
		showLumberjackUpgradePad = canUpgradeLumberjack,
		stats = levelData and {
			health = levelData.Health,
			growTime = levelData.GrowTime,
			reward = levelData.Reward,
		} or nil,
		growingUntil = plotState.GrowingUntil,
	}
end

function TreeStateBuilder.buildStatePayload(playerData, treePlotService, getServerNow, player, changedPlotIds)
	if not playerData.isLoaded(player) then
		return serviceResult.failure(treeConstants.FailureReason.DataNotLoaded, treeConstants.getFailureMessage)
	end

	local plotSnapshots = {}
	local plotSetId = treePlotService.getAssignedPlotSetId(player)
	local plotIds = changedPlotIds

	if not plotIds then
		plotIds = {}

		for _, treeId in treeConfig.Order do
			table.insert(plotIds, treeConfig.ById[treeId].PlotId)
		end
	end

	for _, plotId in plotIds do
		local snapshot = TreeStateBuilder.buildPlotSnapshot(playerData, player, plotId)

		if snapshot then
			table.insert(plotSnapshots, snapshot)
		end
	end

	table.sort(plotSnapshots, function(left, right)
		return left.plotOrder < right.plotOrder
	end)

	return serviceResult.success({
		serverTime = getServerNow(),
		plotSetId = plotSetId,
		plots = plotSnapshots,
	})
end

return TreeStateBuilder
