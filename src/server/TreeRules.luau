local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)

local TreeRules = {}

function TreeRules.create(deps)
	local function getAmberUpgradeLevel(player, upgradeKey)
		if not deps.getAmberUpgradeLevel then
			return 0
		end

		return deps.getAmberUpgradeLevel(player, upgradeKey) or 0
	end

	local function getDiscountedCost(player, baseCost)
		if typeof(baseCost) ~= "number" then
			return nil
		end

		return rebirthConfig.getReducedCost(baseCost, getAmberUpgradeLevel(player, "CostReduction"))
	end

	local function getUnlockCost(player, tree)
		if not tree or typeof(tree.UnlockCost) ~= "number" then
			return nil
		end

		return getDiscountedCost(player, tree.UnlockCost)
	end

	local function getEffectiveGrowTime(player, baseGrowTime)
		if typeof(baseGrowTime) ~= "number" then
			return 0
		end

		return math.max(
			0,
			baseGrowTime * rebirthConfig.getRegrowthTimeMultiplier(getAmberUpgradeLevel(player, "RegrowthTime"))
		)
	end

	return {
		getAmberUpgradeLevel = getAmberUpgradeLevel,
		getDiscountedCost = getDiscountedCost,
		getUnlockCost = getUnlockCost,
		getEffectiveGrowTime = getEffectiveGrowTime,
	}
end

return TreeRules
