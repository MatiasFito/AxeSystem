local blacksmithConstants = require(script.Parent:WaitForChild("BlacksmithConstants"))

local orderedTiers = {
	{
		Id = "WoodAxe",
		Name = "Wood Axe",
		Description = "The most basic axe.",
		Cost = 0,
		Power = 10,
		GoldMultiplier = 1,
		ImageId = "rbxassetid://258100839",
		ToolTemplateName = "WoodAxe",
		NextTierId = "CopperAxe",
	},
	{
		Id = "CopperAxe",
		Name = "Copper Axe",
		Description = "A sharper blade with a better payout.",
		Cost = 250,
		Power = 20,
		GoldMultiplier = 1.25,
		ImageId = "rbxassetid://943374104",
		ToolTemplateName = "CopperAxe",
		NextTierId = "IronAxe",
	},
	{
		Id = "IronAxe",
		Name = "Iron Axe",
		Description = "Built for serious lumber work.",
		Cost = 750,
		Power = 35,
		GoldMultiplier = 1.5,
		ImageId = "rbxassetid://441548784",
		ToolTemplateName = "IronAxe",
		NextTierId = nil,
	},
}

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
