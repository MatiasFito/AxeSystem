local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)

local LumberjackConfig = {}

local function getUpgradeBaseCost(tree)
	if not tree then
		return nil
	end

	if tree.UnlockCost == 0 then
		return lumberjackConstants.DEFAULT_HIRE_COST
	end

	return tree.UnlockCost * 5
end

function LumberjackConfig.getHireCostByPlotId(plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)
	return getUpgradeBaseCost(tree)
end

function LumberjackConfig.getUpgradeCostByPlotId(plotId, currentLevel)
	local baseCost = LumberjackConfig.getHireCostByPlotId(plotId)

	if typeof(baseCost) ~= "number" or typeof(currentLevel) ~= "number" then
		return nil
	end

	local nextLevel = math.max(1, math.floor(currentLevel) + 1)
	return baseCost * nextLevel
end

function LumberjackConfig.getGoldBonusMultiplier(level)
	if typeof(level) ~= "number" then
		return 1
	end

	local normalizedLevel = math.max(0, math.floor(level))
	return 1 + (normalizedLevel * lumberjackConstants.GOLD_BONUS_PER_LEVEL)
end

function LumberjackConfig.getGoldBonusPercent(level)
	local multiplier = LumberjackConfig.getGoldBonusMultiplier(level)
	return math.max(0, math.floor((multiplier - 1) * 100 + 0.5))
end

function LumberjackConfig.getSwingInterval()
	return lumberjackConstants.DEFAULT_SWING_INTERVAL
end

return LumberjackConfig
