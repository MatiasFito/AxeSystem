local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local lumberjackConfig = require(sharedFolder:WaitForChild("LumberjackConfig") :: ModuleScript)
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)

local TreeStateBuilder = {}

local function getCostReductionLevel(playerData, player)
	if not playerData.getAmberUpgradeLevel then
		return 0
	end

	return playerData.getAmberUpgradeLevel(player, "CostReduction") or 0
end

local function getDiscountedCost(playerData, player, baseCost)
	if typeof(baseCost) ~= "number" then
		return nil
	end

	return rebirthConfig.getReducedCost(baseCost, getCostReductionLevel(playerData, player))
end

function TreeStateBuilder.isPlotUnlockable(treePlots, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not tree then
		return false
	end

	if tree.UnlockMode == "Affordable" then
		return true
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
	local supportsLumberjack = tree.SupportsLumberjack ~= false
	local hasLumberjack = supportsLumberjack and plotState.HasLumberjack == true
	local lumberjackLevel = hasLumberjack and math.max(1, plotState.LumberjackLevel or 0) or 0
	local lumberjackIsMaxLevel = hasLumberjack and lumberjackLevel >= lumberjackConstants.MAX_LEVEL
	local unlockCost = getDiscountedCost(playerData, player, tree.UnlockCost)
	local lumberjackHireCost = supportsLumberjack
			and getDiscountedCost(playerData, player, lumberjackConfig.getHireCostByPlotId(plotId))
		or nil
	local lumberjackUpgradeCost = hasLumberjack
			and getDiscountedCost(playerData, player, lumberjackConfig.getUpgradeCostByPlotId(plotId, lumberjackLevel))
		or nil
	local lumberjackAxeName = nil
	local canHireLumberjack = supportsLumberjack and plotState.Unlocked and not hasLumberjack
	local canUpgradeLumberjack = supportsLumberjack
		and plotState.Unlocked
		and hasLumberjack
		and not lumberjackIsMaxLevel

	if hasLumberjack and playerData.getAxeTierId then
		local tier = axeConfig.getTier(playerData.getAxeTierId(player)) or axeConfig.getDefaultTier()
		lumberjackAxeName = tier and tier.Name or nil
	end

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
		unlockCost = unlockCost,
		canUpgrade = canUpgrade,
		upgradeCost = upgradeCost,
		isMaxLevel = isMaxLevel,
		hasLumberjack = hasLumberjack,
		lumberjackLevel = lumberjackLevel,
		canHireLumberjack = canHireLumberjack,
		lumberjackHireCost = lumberjackHireCost,
		lumberjackIsMaxLevel = lumberjackIsMaxLevel,
		canUpgradeLumberjack = canUpgradeLumberjack,
		lumberjackUpgradeCost = lumberjackUpgradeCost,
		lumberjackAxeName = lumberjackAxeName,
		lumberjackGoldBonusPercent = lumberjackConfig.getGoldBonusPercent(lumberjackLevel),
		showLumberjackUpgradePad = supportsLumberjack and plotState.Unlocked and hasLumberjack,
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
