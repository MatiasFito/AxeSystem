local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local progressionProfile = {
	MaxLevel = 15,
	MinGrowTime = 0.125,
	HealthCheckpoints = {
		{ Order = 1, Value = 25 },
		{ Order = 5, Value = 50 },
		{ Order = 10, Value = 85 },
		{ Order = 15, Value = 135 },
		{ Order = 20, Value = 195 },
		{ Order = 25, Value = 270 },
		{ Order = 30, Value = 360 },
	},
	RewardCheckpoints = {
		{ Order = 1, Value = 15 },
		{ Order = 5, Value = 35 },
		{ Order = 10, Value = 80 },
		{ Order = 15, Value = 160 },
		{ Order = 20, Value = 300 },
		{ Order = 25, Value = 525 },
		{ Order = 30, Value = 900 },
	},
	GrowTimeCheckpoints = {
		{ Order = 1, Value = 1 },
		{ Order = 5, Value = 1.2 },
		{ Order = 10, Value = 1.55 },
		{ Order = 15, Value = 1.95 },
		{ Order = 20, Value = 2.35 },
		{ Order = 25, Value = 2.75 },
		{ Order = 30, Value = 3.15 },
	},
	UnlockHarvestCheckpoints = {
		{ Order = 2, Value = 7.5 },
		{ Order = 10, Value = 9 },
		{ Order = 20, Value = 11.5 },
		{ Order = 30, Value = 14 },
	},
	UpgradePaybackCheckpoints = {
		{ Level = 2, Value = 4 },
		{ Level = 4, Value = 6.8 },
		{ Level = 7, Value = 10.4 },
		{ Level = 10, Value = 14 },
		{ Level = 12, Value = 15.2 },
		{ Level = 15, Value = 17.8 },
	},
	LevelHealthMultipliers = { 1, 0.92, 0.85, 0.79, 0.74, 0.69, 0.65, 0.61, 0.58, 0.55, 0.49, 0.44, 0.4, 0.37, 0.34 },
	LevelRewardMultipliers = { 1, 1.25, 1.55, 1.9, 2.3, 2.75, 3.25, 3.8, 4.4, 5, 6, 7.15, 8.45, 9.9, 11.5 },
	LevelGrowTimeMultipliers = { 1, 0.84, 0.72, 0.64, 0.58, 0.54, 0.52, 0.51, 0.5, 0.5, 0.4, 0.31, 0.24, 0.18, 0.14 },
}

local orderedTreeTemplateNames = {
	"OakTree",
	"BirchTree",
	"AcaciaTree",
	"PineTree",
	"PalmTree",
	"MapleTree",
	"CherryBlossomTree",
	"BaobabTree",
	"WillowTree",
	"RedwoodTree",
	"CottonCandyTree",
	"AlienTree",
	"MarbleTree",
	"LollypopTree",
	"MagmaTree",
	"CrystalTree",
	"GoldTree",
	"MushroomTree",
	"CactusTree",
	"CandyCaneTree",
	"BubblegumTree",
	"ObsidianTree",
	"CyberTree",
	"IceTree",
	"BambooTree",
	"CloudTree",
	"AutumnTree",
	"VoidTree",
	"BonsaiTree",
	"RainbowTree",
}

local function roundToNearest(value, step)
	return math.floor((value / step) + 0.5) * step
end

local function roundCurrency(value)
	local absoluteValue = math.abs(value)
	local step = 1

	if absoluteValue >= 20000 then
		step = 100
	elseif absoluteValue >= 5000 then
		step = 50
	elseif absoluteValue >= 1000 then
		step = 25
	elseif absoluteValue >= 100 then
		step = 10
	elseif absoluteValue >= 25 then
		step = 5
	end

	return math.max(0, roundToNearest(value, step))
end

local function roundStat(value)
	return math.max(1, math.floor(value + 0.5))
end

local function roundGrowTime(value)
	return math.max(progressionProfile.MinGrowTime, math.floor((value * 100) + 0.5) / 100)
end

local function interpolateCheckpoints(checkpoints, positionKey, positionValue)
	local firstCheckpoint = checkpoints[1]

	if positionValue <= firstCheckpoint[positionKey] then
		return firstCheckpoint.Value
	end

	for index = 2, #checkpoints do
		local previousCheckpoint = checkpoints[index - 1]
		local nextCheckpoint = checkpoints[index]

		if positionValue <= nextCheckpoint[positionKey] then
			local range = nextCheckpoint[positionKey] - previousCheckpoint[positionKey]
			local alpha = range > 0 and ((positionValue - previousCheckpoint[positionKey]) / range) or 0
			return previousCheckpoint.Value + ((nextCheckpoint.Value - previousCheckpoint.Value) * alpha)
		end
	end

	return checkpoints[#checkpoints].Value
end

local function formatTreeName(templateName)
	return templateName:gsub("(%l)(%u)", "%1 %2")
end

local function buildDescription(plotOrder)
	if plotOrder <= 6 then
		return "An early progression tree with quick access and steady payouts."
	end

	if plotOrder <= 20 then
		return "A mid-path tree that keeps the chopping economy moving."
	end

	return "A late-path tree with stronger payouts and longer investment loops."
end

local function buildLevels(plotOrder)
	local levels = {}
	local baseHealth = interpolateCheckpoints(progressionProfile.HealthCheckpoints, "Order", plotOrder)
	local baseReward = interpolateCheckpoints(progressionProfile.RewardCheckpoints, "Order", plotOrder)
	local baseGrowTime = interpolateCheckpoints(progressionProfile.GrowTimeCheckpoints, "Order", plotOrder)

	for level = 1, progressionProfile.MaxLevel do
		local reward = roundCurrency(baseReward * progressionProfile.LevelRewardMultipliers[level])
		levels[level] = {
			Level = level,
			Health = roundStat(baseHealth * progressionProfile.LevelHealthMultipliers[level]),
			GrowTime = roundGrowTime(baseGrowTime * progressionProfile.LevelGrowTimeMultipliers[level]),
			Reward = reward,
			UpgradeCost = level == 1 and 0 or roundCurrency(
				reward * interpolateCheckpoints(progressionProfile.UpgradePaybackCheckpoints, "Level", level)
			),
		}
	end

	return levels
end

local function buildTreeDefinition(templateName, plotOrder)
	local levels = buildLevels(plotOrder)
	return {
		Id = templateName,
		Name = formatTreeName(templateName),
		Description = buildDescription(plotOrder),
		TemplateName = templateName,
		PlotId = string.format("Plot%02d", plotOrder),
		PlotOrder = plotOrder,
		UnlockCost = plotOrder == 1 and 0 or roundCurrency(
			levels[1].Reward * interpolateCheckpoints(progressionProfile.UnlockHarvestCheckpoints, "Order", plotOrder)
		),
		ImageId = "",
		MaxLevel = progressionProfile.MaxLevel,
		Levels = levels,
	}
end

local function buildOrderedTrees()
	local generatedTrees = {}

	for plotOrder, templateName in orderedTreeTemplateNames do
		generatedTrees[plotOrder] = buildTreeDefinition(templateName, plotOrder)
	end

	return generatedTrees
end

local orderedTrees = buildOrderedTrees()

local TreeConfig = {
	Order = {},
	ById = {},
	ByPlotId = {},
}

local function cloneDefaultPlotState(plotState)
	return {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = plotState.Unlocked,
		Level = plotState.Level,
		State = plotState.State,
		GrowingUntil = plotState.GrowingUntil,
		HasLumberjack = plotState.HasLumberjack,
		LumberjackLevel = plotState.LumberjackLevel,
	}
end

for index, tree in orderedTrees do
	TreeConfig.Order[index] = tree.Id
	TreeConfig.ById[tree.Id] = tree
	TreeConfig.ByPlotId[tree.PlotId] = tree
end

function TreeConfig.getTree(treeId)
	if typeof(treeId) ~= "string" then
		return nil
	end

	return TreeConfig.ById[treeId]
end

function TreeConfig.getTreeByPlotId(plotId)
	if typeof(plotId) ~= "string" then
		return nil
	end

	return TreeConfig.ByPlotId[plotId]
end

function TreeConfig.getTreeByOrder(index)
	if typeof(index) ~= "number" then
		return nil
	end

	local treeId = TreeConfig.Order[math.floor(index)]

	if not treeId then
		return nil
	end

	return TreeConfig.ById[treeId]
end

function TreeConfig.getLevelData(treeId, level)
	local tree = TreeConfig.getTree(treeId)

	if not tree or typeof(level) ~= "number" then
		return nil
	end

	return tree.Levels[math.floor(level)]
end

function TreeConfig.getUpgradeLevel(treeId, currentLevel)
	local tree = TreeConfig.getTree(treeId)

	if not tree or typeof(currentLevel) ~= "number" then
		return nil
	end

	local nextLevel = math.floor(currentLevel) + 1

	if nextLevel > tree.MaxLevel or tree.Levels[nextLevel] == nil then
		return nil
	end

	return nextLevel
end

function TreeConfig.getUpgradeCost(treeId, currentLevel)
	local nextLevel = TreeConfig.getUpgradeLevel(treeId, currentLevel)

	if not nextLevel then
		return nil
	end

	local nextLevelData = TreeConfig.getLevelData(treeId, nextLevel)
	return nextLevelData and nextLevelData.UpgradeCost or nil
end

function TreeConfig.getDefaultPlotStates()
	local defaultPlotStates = {}

	for _, treeId in TreeConfig.Order do
		local tree = TreeConfig.ById[treeId]

		defaultPlotStates[tree.PlotId] = cloneDefaultPlotState({
			PlotId = tree.PlotId,
			TreeId = tree.Id,
			Unlocked = false,
			Level = 0,
			State = treeConstants.PlotState.Locked,
			GrowingUntil = nil,
			HasLumberjack = false,
			LumberjackLevel = 0,
		})
	end

	return defaultPlotStates
end

return TreeConfig
