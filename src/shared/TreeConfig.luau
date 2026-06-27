local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local infinitreeConfig = require(sharedFolder:WaitForChild("InfinitreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local orderedTrees = {
	{
		Id = "OakTree",
		Name = "Oak Tree",
		Description = "A sturdy beginner tree with steady payouts.",
		TemplateName = "OakTree",
		PlotId = "Plot01",
		PlotOrder = 1,
		UnlockCost = 0,
		ImageId = "",
		MaxLevel = 10,
		Levels = {
			[1] = { Level = 1, Health = 25, GrowTime = 1, Reward = 15, UpgradeCost = 0 },
			[2] = { Level = 2, Health = 22, GrowTime = 0.82, Reward = 20, UpgradeCost = 75 },
			[3] = { Level = 3, Health = 20, GrowTime = 0.72, Reward = 26, UpgradeCost = 140 },
			[4] = { Level = 4, Health = 18, GrowTime = 0.65, Reward = 33, UpgradeCost = 220 },
			[5] = { Level = 5, Health = 16, GrowTime = 0.6, Reward = 41, UpgradeCost = 310 },
			[6] = { Level = 6, Health = 15, GrowTime = 0.57, Reward = 50, UpgradeCost = 410 },
			[7] = { Level = 7, Health = 14, GrowTime = 0.54, Reward = 60, UpgradeCost = 520 },
			[8] = { Level = 8, Health = 13, GrowTime = 0.52, Reward = 71, UpgradeCost = 640 },
			[9] = { Level = 9, Health = 12, GrowTime = 0.51, Reward = 83, UpgradeCost = 770 },
			[10] = { Level = 10, Health = 11, GrowTime = 0.5, Reward = 96, UpgradeCost = 910 },
		},
	},
	{
		Id = "PineTree",
		Name = "Pine Tree",
		Description = "A faster-growing tree that rewards stronger axes.",
		TemplateName = "PineTree",
		PlotId = "Plot02",
		PlotOrder = 2,
		UnlockCost = 225,
		ImageId = "",
		MaxLevel = 10,
		Levels = {
			[1] = { Level = 1, Health = 50, GrowTime = 2, Reward = 32, UpgradeCost = 0 },
			[2] = { Level = 2, Health = 45, GrowTime = 1.45, Reward = 42, UpgradeCost = 160 },
			[3] = { Level = 3, Health = 41, GrowTime = 1.12, Reward = 53, UpgradeCost = 275 },
			[4] = { Level = 4, Health = 37, GrowTime = 0.92, Reward = 66, UpgradeCost = 420 },
			[5] = { Level = 5, Health = 34, GrowTime = 0.8, Reward = 80, UpgradeCost = 600 },
			[6] = { Level = 6, Health = 31, GrowTime = 0.72, Reward = 95, UpgradeCost = 820 },
			[7] = { Level = 7, Health = 29, GrowTime = 0.65, Reward = 111, UpgradeCost = 1080 },
			[8] = { Level = 8, Health = 27, GrowTime = 0.59, Reward = 128, UpgradeCost = 1380 },
			[9] = { Level = 9, Health = 25, GrowTime = 0.54, Reward = 146, UpgradeCost = 1720 },
			[10] = { Level = 10, Health = 23, GrowTime = 0.5, Reward = 165, UpgradeCost = 2100 },
		},
	},
	{
		Id = "BirchTree",
		Name = "Birch Tree",
		Description = "A premium tree line with strong gold returns.",
		TemplateName = "BirchTree",
		PlotId = "Plot03",
		PlotOrder = 3,
		UnlockCost = 650,
		ImageId = "",
		MaxLevel = 10,
		Levels = {
			[1] = { Level = 1, Health = 90, GrowTime = 3, Reward = 75, UpgradeCost = 0 },
			[2] = { Level = 2, Health = 82, GrowTime = 2.1, Reward = 92, UpgradeCost = 300 },
			[3] = { Level = 3, Health = 75, GrowTime = 1.55, Reward = 111, UpgradeCost = 480 },
			[4] = { Level = 4, Health = 69, GrowTime = 1.18, Reward = 132, UpgradeCost = 700 },
			[5] = { Level = 5, Health = 63, GrowTime = 0.95, Reward = 155, UpgradeCost = 960 },
			[6] = { Level = 6, Health = 58, GrowTime = 0.8, Reward = 180, UpgradeCost = 1260 },
			[7] = { Level = 7, Health = 54, GrowTime = 0.7, Reward = 207, UpgradeCost = 1600 },
			[8] = { Level = 8, Health = 50, GrowTime = 0.62, Reward = 236, UpgradeCost = 1980 },
			[9] = { Level = 9, Health = 46, GrowTime = 0.55, Reward = 267, UpgradeCost = 2400 },
			[10] = { Level = 10, Health = 43, GrowTime = 0.5, Reward = 300, UpgradeCost = 2860 },
		},
	},
	{
		Id = "MapleTree",
		Name = "Maple Tree",
		Description = "A dense late-game tree with high payouts and longer regrowth.",
		TemplateName = "MapleTree",
		PlotId = "Plot04",
		PlotOrder = 4,
		UnlockCost = 1400,
		ImageId = "",
		MaxLevel = 10,
		Levels = {
			[1] = { Level = 1, Health = 130, GrowTime = 4, Reward = 120, UpgradeCost = 0 },
			[2] = { Level = 2, Health = 120, GrowTime = 2.75, Reward = 145, UpgradeCost = 520 },
			[3] = { Level = 3, Health = 111, GrowTime = 1.95, Reward = 172, UpgradeCost = 780 },
			[4] = { Level = 4, Health = 103, GrowTime = 1.42, Reward = 201, UpgradeCost = 1080 },
			[5] = { Level = 5, Health = 95, GrowTime = 1.08, Reward = 232, UpgradeCost = 1420 },
			[6] = { Level = 6, Health = 88, GrowTime = 0.87, Reward = 265, UpgradeCost = 1800 },
			[7] = { Level = 7, Health = 82, GrowTime = 0.73, Reward = 300, UpgradeCost = 2220 },
			[8] = { Level = 8, Health = 76, GrowTime = 0.64, Reward = 337, UpgradeCost = 2680 },
			[9] = { Level = 9, Health = 71, GrowTime = 0.56, Reward = 376, UpgradeCost = 3180 },
			[10] = { Level = 10, Health = 66, GrowTime = 0.5, Reward = 420, UpgradeCost = 3720 },
		},
	},
	{
		Id = "Infinitree",
		Name = "Infinitree",
		Description = "An endlessly upgradeable palm tree that pays Gold every hit.",
		TemplateName = "Infinitree",
		PlotId = "InfinitreePlot",
		PlotOrder = 5,
		UnlockCost = infinitreeConfig.UNLOCK_COST,
		ImageId = "",
		MaxLevel = math.huge,
		IsInfiniteTree = true,
		SupportsLumberjack = false,
		UnlockMode = "Affordable",
	},
}

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

	if tree.IsInfiniteTree then
		return infinitreeConfig.getLevelData(level)
	end

	return tree.Levels[math.floor(level)]
end

function TreeConfig.getUpgradeLevel(treeId, currentLevel)
	local tree = TreeConfig.getTree(treeId)

	if not tree or typeof(currentLevel) ~= "number" then
		return nil
	end

	local nextLevel = math.floor(currentLevel) + 1

	if tree.IsInfiniteTree then
		return nextLevel
	end

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

	local tree = TreeConfig.getTree(treeId)

	if tree and tree.IsInfiniteTree then
		return infinitreeConfig.getUpgradeCost(nextLevel)
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
