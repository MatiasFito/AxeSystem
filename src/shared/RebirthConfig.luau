local RebirthConfig = {}

RebirthConfig.MINIMUM_PLOT_ORDER = 10

local progressionProfile = {
	MaxUpgradeLevel = 25,
	RegrowthTime = {
		CostCheckpoints = {
			{ Order = 1, Value = 1 },
			{ Order = 5, Value = 8 },
			{ Order = 10, Value = 30 },
			{ Order = 15, Value = 90 },
			{ Order = 20, Value = 250 },
			{ Order = 25, Value = 600 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 0.98 },
			{ Order = 5, Value = 0.90 },
			{ Order = 10, Value = 0.80 },
			{ Order = 15, Value = 0.70 },
			{ Order = 20, Value = 0.60 },
			{ Order = 25, Value = 0.50 },
		},
	},
	AxeDamage = {
		CostCheckpoints = {
			{ Order = 1, Value = 1 },
			{ Order = 5, Value = 10 },
			{ Order = 10, Value = 40 },
			{ Order = 15, Value = 120 },
			{ Order = 20, Value = 350 },
			{ Order = 25, Value = 800 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 1.10 },
			{ Order = 5, Value = 1.50 },
			{ Order = 10, Value = 2.10 },
			{ Order = 15, Value = 2.90 },
			{ Order = 20, Value = 3.80 },
			{ Order = 25, Value = 5.00 },
		},
	},
	CostReduction = {
		CostCheckpoints = {
			{ Order = 1, Value = 2 },
			{ Order = 5, Value = 15 },
			{ Order = 10, Value = 50 },
			{ Order = 15, Value = 150 },
			{ Order = 20, Value = 400 },
			{ Order = 25, Value = 1000 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 0.98 },
			{ Order = 5, Value = 0.91 },
			{ Order = 10, Value = 0.83 },
			{ Order = 15, Value = 0.76 },
			{ Order = 20, Value = 0.70 },
			{ Order = 25, Value = 0.65 },
		},
	},
	GoldMultiplier = {
		CostCheckpoints = {
			{ Order = 1, Value = 1 },
			{ Order = 5, Value = 12 },
			{ Order = 10, Value = 45 },
			{ Order = 15, Value = 135 },
			{ Order = 20, Value = 380 },
			{ Order = 25, Value = 900 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 1.15 },
			{ Order = 5, Value = 1.75 },
			{ Order = 10, Value = 2.70 },
			{ Order = 15, Value = 3.90 },
			{ Order = 20, Value = 5.25 },
			{ Order = 25, Value = 6.00 },
		},
	},
	AmberGain = {
		CostCheckpoints = {
			{ Order = 1, Value = 3 },
			{ Order = 5, Value = 25 },
			{ Order = 10, Value = 80 },
			{ Order = 15, Value = 250 },
			{ Order = 20, Value = 750 },
			{ Order = 25, Value = 1800 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 1.10 },
			{ Order = 5, Value = 1.50 },
			{ Order = 10, Value = 2.20 },
			{ Order = 15, Value = 3.20 },
			{ Order = 20, Value = 4.50 },
			{ Order = 25, Value = 6.00 },
		},
	},
}

local upgradeKeys = {
	"RegrowthTime",
	"AxeDamage",
	"CostReduction",
	"GoldMultiplier",
	"AmberGain",
}

local function copyCheckpoints(checkpoints)
	local copy = {}

	for index, checkpoint in ipairs(checkpoints) do
		copy[index] = {
			Order = checkpoint.Order,
			Value = checkpoint.Value,
		}
	end

	return copy
end

local function copyProgressionTable()
	local copy = {
		MaxUpgradeLevel = progressionProfile.MaxUpgradeLevel,
	}

	for _, key in ipairs(upgradeKeys) do
		local profile = progressionProfile[key]
		copy[key] = {
			CostCheckpoints = copyCheckpoints(profile.CostCheckpoints),
			EffectCheckpoints = copyCheckpoints(profile.EffectCheckpoints),
		}
	end

	return copy
end

local function interpolateCheckpoints(checkpoints, targetOrder)
	local firstCheckpoint = checkpoints[1]

	if targetOrder <= firstCheckpoint.Order then
		return firstCheckpoint.Value
	end

	for index = 2, #checkpoints do
		local previousCheckpoint = checkpoints[index - 1]
		local nextCheckpoint = checkpoints[index]

		if targetOrder <= nextCheckpoint.Order then
			local range = nextCheckpoint.Order - previousCheckpoint.Order
			local alpha = range > 0 and ((targetOrder - previousCheckpoint.Order) / range) or 0
			return previousCheckpoint.Value + ((nextCheckpoint.Value - previousCheckpoint.Value) * alpha)
		end
	end

	return checkpoints[#checkpoints].Value
end

local function normalizeUpgradeLevel(level)
	if typeof(level) ~= "number" then
		return 0
	end

	return math.clamp(math.floor(level), 0, progressionProfile.MaxUpgradeLevel)
end

RebirthConfig.AmberProgression = copyProgressionTable()

function RebirthConfig.getUpgradeKeys()
	return table.clone(upgradeKeys)
end

function RebirthConfig.createDefaultAmberUpgrades()
	local defaultUpgrades = {}

	for _, key in ipairs(upgradeKeys) do
		defaultUpgrades[key] = 0
	end

	return defaultUpgrades
end

function RebirthConfig.cloneAmberUpgrades(amberUpgrades)
	local normalizedUpgrades = RebirthConfig.createDefaultAmberUpgrades()

	if typeof(amberUpgrades) ~= "table" then
		return normalizedUpgrades
	end

	for _, key in ipairs(upgradeKeys) do
		normalizedUpgrades[key] = normalizeUpgradeLevel(amberUpgrades[key])
	end

	return normalizedUpgrades
end

function RebirthConfig.calculateBaseAmberReward(maxPlotUnlocked)
	if typeof(maxPlotUnlocked) ~= "number" then
		return 0
	end

	local normalizedPlotOrder = math.floor(maxPlotUnlocked)

	if normalizedPlotOrder < RebirthConfig.MINIMUM_PLOT_ORDER then
		return 0
	end

	return math.floor((normalizedPlotOrder - 9) ^ 1.5)
end

function RebirthConfig.getAmberGainMultiplier(level)
	local normalizedLevel = normalizeUpgradeLevel(level)

	if normalizedLevel < 1 then
		return 1
	end

	return interpolateCheckpoints(progressionProfile.AmberGain.EffectCheckpoints, normalizedLevel)
end

function RebirthConfig.calculateAmberReward(maxPlotUnlocked, amberGainLevel)
	local baseReward = RebirthConfig.calculateBaseAmberReward(maxPlotUnlocked)

	if baseReward <= 0 then
		return 0
	end

	return math.max(0, math.floor(baseReward * RebirthConfig.getAmberGainMultiplier(amberGainLevel)))
end

function RebirthConfig.getUpgradeDefinition(upgradeKey)
	local profile = progressionProfile[upgradeKey]

	if not profile then
		return nil
	end

	return {
		CostCheckpoints = copyCheckpoints(profile.CostCheckpoints),
		EffectCheckpoints = copyCheckpoints(profile.EffectCheckpoints),
	}
end

return RebirthConfig
