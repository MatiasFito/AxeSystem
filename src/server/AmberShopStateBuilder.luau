local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)

local AmberShopStateBuilder = {}

function AmberShopStateBuilder.buildState(playerData, player)
	local amber = playerData.getAmber(player) or 0
	local amberUpgrades = playerData.getAmberUpgrades(player) or rebirthConfig.createDefaultAmberUpgrades()
	local upgrades = {}

	for _, upgradeKey in ipairs(rebirthConfig.getUpgradeKeys()) do
		local currentLevel = rebirthConfig.getUpgradeLevel(amberUpgrades, upgradeKey)
		local upgradeStats = rebirthConfig.getUpgradeStats(upgradeKey, currentLevel)

		if upgradeStats then
			table.insert(upgrades, {
				key = upgradeKey,
				displayName = upgradeStats.displayName,
				description = upgradeStats.description,
				level = upgradeStats.currentLevel,
				currentLevel = upgradeStats.currentLevel,
				maxLevel = upgradeStats.maxLevel,
				isMaxLevel = upgradeStats.isMaxLevel,
				costToNextLevel = upgradeStats.costToNextLevel,
				currentValue = upgradeStats.currentValue,
				nextValue = upgradeStats.nextValue,
				currentText = upgradeStats.currentText,
				nextText = upgradeStats.nextText,
				canAfford = not upgradeStats.isMaxLevel and amber >= (upgradeStats.costToNextLevel or math.huge),
			})
		end
	end

	return {
		amber = amber,
		maxLevel = rebirthConfig.getMaxUpgradeLevel(),
		upgrades = upgrades,
	}
end

return AmberShopStateBuilder
