local WishingTreeBlessingConfig = {}

local blessingDefinitions = {
	{
		Id = "WindBlessing",
		Name = "Wind Blessing",
		ChanceWeight = 50,
		DurationSeconds = 5 * 60,
		EffectType = "MovementSpeedMultiplier",
		EffectValue = 1.5,
	},
	{
		Id = "GoldBlessing",
		Name = "Gold Blessing",
		ChanceWeight = 30,
		DurationSeconds = 5 * 60,
		EffectType = "GoldMultiplier",
		EffectValue = 1.5,
	},
	{
		Id = "HasteBlessing",
		Name = "Haste Blessing",
		ChanceWeight = 15,
		DurationSeconds = 3 * 60,
		EffectType = "AttackSpeedMultiplier",
		EffectValue = 1.25,
	},
	{
		Id = "StrengthBlessing",
		Name = "Strength Blessing",
		ChanceWeight = 5,
		DurationSeconds = 3 * 60,
		EffectType = "AxePowerMultiplier",
		EffectValue = 1.5,
	},
}

local blessingById = {}
local totalChanceWeight = 0

for _, definition in ipairs(blessingDefinitions) do
	blessingById[definition.Id] = definition
	totalChanceWeight += definition.ChanceWeight
end

local function cloneBlessing(definition)
	return {
		Id = definition.Id,
		Name = definition.Name,
		ChanceWeight = definition.ChanceWeight,
		DurationSeconds = definition.DurationSeconds,
		EffectType = definition.EffectType,
		EffectValue = definition.EffectValue,
	}
end

function WishingTreeBlessingConfig.getBlessings()
	local blessings = {}

	for index, definition in ipairs(blessingDefinitions) do
		blessings[index] = cloneBlessing(definition)
	end

	return blessings
end

function WishingTreeBlessingConfig.getBlessingById(blessingId)
	local definition = blessingById[blessingId]

	if not definition then
		return nil
	end

	return cloneBlessing(definition)
end

function WishingTreeBlessingConfig.isValidBlessingId(blessingId)
	return blessingById[blessingId] ~= nil
end

function WishingTreeBlessingConfig.getTotalChanceWeight()
	return totalChanceWeight
end

function WishingTreeBlessingConfig.rollBlessing(randomValue)
	local numericRandomValue = tonumber(randomValue)

	if typeof(numericRandomValue) ~= "number" or numericRandomValue <= 0 or numericRandomValue > totalChanceWeight then
		numericRandomValue = math.random(1, totalChanceWeight)
	end

	local cumulativeWeight = 0

	for _, definition in ipairs(blessingDefinitions) do
		cumulativeWeight += definition.ChanceWeight

		if numericRandomValue <= cumulativeWeight then
			return cloneBlessing(definition)
		end
	end

	return cloneBlessing(blessingDefinitions[#blessingDefinitions])
end

return WishingTreeBlessingConfig
