local blacksmithConstants = require(script.Parent:WaitForChild("BlacksmithConstants"))
local treeConfig = require(script.Parent:WaitForChild("TreeConfig"))

local orderedTierIds = {
	"WoodAxe",
	"StoneAxe",
	"CopperAxe",
	"IronAxe",
	"SteelAxe",
	"ObsidianAxe",
	"MeteoriteAxe",
}

local tierMetadataById = {
	WoodAxe = {
		Name = "Wood Axe",
		Description = "The most basic axe.",
		ImageId = "rbxassetid://258100839",
		ToolTemplateName = "WoodAxe",
		TargetPlotOrder = 1,
	},
	StoneAxe = {
		Name = "Stone Axe",
		Description = "A rough upgrade that gets you through the early grind faster.",
		ImageId = "",
		ToolTemplateName = "StoneAxe",
		TargetPlotOrder = 5,
	},
	CopperAxe = {
		Name = "Copper Axe",
		Description = "A sharper blade with a better payout.",
		ImageId = "rbxassetid://943374104",
		ToolTemplateName = "CopperAxe",
		TargetPlotOrder = 10,
	},
	IronAxe = {
		Name = "Iron Axe",
		Description = "Built for serious lumber work.",
		ImageId = "rbxassetid://441548784",
		ToolTemplateName = "IronAxe",
		TargetPlotOrder = 15,
	},
	SteelAxe = {
		Name = "Steel Axe",
		Description = "Reliable midgame power for thicker trunks and better yields.",
		ImageId = "",
		ToolTemplateName = "SteelAxe",
		TargetPlotOrder = 20,
	},
	ObsidianAxe = {
		Name = "Obsidian Axe",
		Description = "A late-game edge built to cash out tougher plots.",
		ImageId = "",
		ToolTemplateName = "ObsidianAxe",
		TargetPlotOrder = 25,
	},
	MeteoriteAxe = {
		Name = "Meteorite Axe",
		Description = "Endgame power tuned for the top of the chopping economy.",
		ImageId = "",
		ToolTemplateName = "MeteoriteAxe",
		TargetPlotOrder = 30,
	},
}

local progressionProfile = {
	Power = {
		TargetHitsToFellCheckpoints = {
			{ Order = 1, Value = 2.5 },
			{ Order = 5, Value = 3.6 },
			{ Order = 10, Value = 3.9 },
			{ Order = 15, Value = 3.85 },
			{ Order = 20, Value = 3.9 },
			{ Order = 25, Value = 3.85 },
			{ Order = 30, Value = 3.8 },
		},
	},
	Economy = {
		CostHarvestCheckpoints = {
			{ Order = 1, Value = 0 },
			{ Order = 5, Value = 10 },
			{ Order = 10, Value = 12 },
			{ Order = 15, Value = 14 },
			{ Order = 20, Value = 16 },
			{ Order = 25, Value = 18 },
			{ Order = 30, Value = 20 },
		},
		GoldMultiplierCheckpoints = {
			{ Order = 1, Value = 1 },
			{ Order = 5, Value = 1.05 },
			{ Order = 10, Value = 1.12 },
			{ Order = 15, Value = 1.2 },
			{ Order = 20, Value = 1.3 },
			{ Order = 25, Value = 1.42 },
			{ Order = 30, Value = 1.55 },
		},
	},
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

local function roundGoldMultiplier(value)
	return math.max(1, math.floor((value * 100) + 0.5) / 100)
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

local function getTierMetadata(tierId)
	local metadata = tierMetadataById[tierId]

	if metadata then
		return metadata
	end

	error(string.format("Missing axe metadata for tier '%s'", tostring(tierId)))
end

local function getProfileValue(checkpoints, targetPlotOrder)
	return interpolateCheckpoints(checkpoints, "Order", targetPlotOrder)
end

local function resolveTargetLevelData(targetPlotOrder)
	local tree = treeConfig.getTreeByOrder(targetPlotOrder)

	if not tree then
		error(string.format("Missing tree progression data for axe target plot order %d", targetPlotOrder))
	end

	local levelData = treeConfig.getLevelData(tree.Id, 1)

	if not levelData then
		error(string.format("Missing level 1 data for axe target tree '%s'", tree.Id))
	end

	return tree, levelData
end

local function buildTier(index, tierId)
	local metadata = getTierMetadata(tierId)
	local nextTierId = orderedTierIds[index + 1]
	local targetTree, levelData = resolveTargetLevelData(metadata.TargetPlotOrder)
	local targetHitsToFell =
		getProfileValue(progressionProfile.Power.TargetHitsToFellCheckpoints, metadata.TargetPlotOrder)
	local targetHarvestsToAfford =
		getProfileValue(progressionProfile.Economy.CostHarvestCheckpoints, metadata.TargetPlotOrder)
	local goldMultiplier = roundGoldMultiplier(
		getProfileValue(progressionProfile.Economy.GoldMultiplierCheckpoints, metadata.TargetPlotOrder)
	)

	return {
		Id = tierId,
		Name = metadata.Name,
		Description = metadata.Description,
		Cost = index == 1 and 0 or roundCurrency(levelData.Reward * targetHarvestsToAfford),
		Power = roundStat(levelData.Health / targetHitsToFell),
		GoldMultiplier = goldMultiplier,
		ImageId = metadata.ImageId,
		ToolTemplateName = metadata.ToolTemplateName,
		TargetPlotOrder = metadata.TargetPlotOrder,
		TargetTreeId = targetTree.Id,
		NextTierId = nextTierId,
	}
end

local function buildOrderedTiers()
	local tiers = {}

	for index, tierId in orderedTierIds do
		tiers[index] = buildTier(index, tierId)
	end

	return tiers
end

local orderedTiers = buildOrderedTiers()

local AxeConfig = {
	Order = {},
	ById = {},
}

local knownToolNames = {
	BaseAxe = true,
}

for index, tier in orderedTiers do
	AxeConfig.Order[index] = tier.Id
	AxeConfig.ById[tier.Id] = tier
	knownToolNames[tier.Id] = true
end

function AxeConfig.getTier(tierId)
	if typeof(tierId) ~= "string" then
		return nil
	end

	return AxeConfig.ById[tierId]
end

function AxeConfig.getDefaultTier()
	return AxeConfig.ById[blacksmithConstants.DEFAULT_AXE_TIER_ID]
end

function AxeConfig.getTierByIndex(index)
	if typeof(index) ~= "number" then
		return nil
	end

	local tierId = AxeConfig.Order[math.floor(index)]

	if not tierId then
		return nil
	end

	return AxeConfig.ById[tierId]
end

function AxeConfig.getTierDefinitions()
	return orderedTiers
end

function AxeConfig.getProgressionProfile()
	return progressionProfile
end

function AxeConfig.getNextTier(tierId)
	local currentTier = AxeConfig.getTier(tierId)

	if not currentTier or currentTier.NextTierId == nil then
		return nil
	end

	return AxeConfig.getTier(currentTier.NextTierId)
end

function AxeConfig.isAxeTool(instance)
	if not instance or not instance:IsA("Tool") then
		return false
	end

	if instance:GetAttribute(blacksmithConstants.IS_AXE_TOOL_ATTRIBUTE) == true then
		return true
	end

	local tierId = instance:GetAttribute(blacksmithConstants.AXE_TIER_ID_ATTRIBUTE)

	if typeof(tierId) == "string" and AxeConfig.ById[tierId] ~= nil then
		return true
	end

	return knownToolNames[instance.Name] == true
end

return AxeConfig
