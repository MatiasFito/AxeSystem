local SessionTimeConfig = {}

local sessionTimeProgression = {
	Tiers = {
		{ TimeRequired = 300, Multiplier = 1.10, Label = "5 Mins (+10% Gold)" },
		{ TimeRequired = 600, Multiplier = 1.25, Label = "10 Mins (+25% Gold)" },
		{ TimeRequired = 1200, Multiplier = 1.50, Label = "20 Mins (+50% Gold)" },
		{ TimeRequired = 1800, Multiplier = 1.75, Label = "30 Mins (+75% Gold)" },
		{ TimeRequired = 3600, Multiplier = 2.00, Label = "60 Mins (DOUBLE Gold!)" },
	},
}

local function normalizeSessionSeconds(sessionSeconds)
	if typeof(sessionSeconds) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(sessionSeconds))
end

local function copyTier(tier)
	return {
		TimeRequired = tier.TimeRequired,
		Multiplier = tier.Multiplier,
		Label = tier.Label,
	}
end

function SessionTimeConfig.getTiers()
	local tiers = table.create(#sessionTimeProgression.Tiers)

	for index, tier in ipairs(sessionTimeProgression.Tiers) do
		tiers[index] = copyTier(tier)
	end

	return tiers
end

function SessionTimeConfig.getCurrentTier(sessionSeconds)
	local normalizedSessionSeconds = normalizeSessionSeconds(sessionSeconds)
	local currentTier = nil

	for _, tier in ipairs(sessionTimeProgression.Tiers) do
		if normalizedSessionSeconds < tier.TimeRequired then
			break
		end

		currentTier = tier
	end

	if not currentTier then
		return nil
	end

	return copyTier(currentTier)
end

function SessionTimeConfig.getGoldMultiplier(sessionSeconds)
	local currentTier = SessionTimeConfig.getCurrentTier(sessionSeconds)

	if not currentTier then
		return 1
	end

	return currentTier.Multiplier or 1
end

return SessionTimeConfig
