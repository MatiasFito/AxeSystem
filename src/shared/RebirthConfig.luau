local RebirthConfig = {}

RebirthConfig.MINIMUM_PLOT_ORDER = 10

local progressionProfile = {
	MaxUpgradeLevel = 25,
	WalkSpeed = {
		CostCheckpoints = {
			{ Order = 1, Value = 1 },
			{ Order = 5, Value = 8 },
			{ Order = 10, Value = 30 },
			{ Order = 15, Value = 90 },
			{ Order = 20, Value = 250 },
			{ Order = 25, Value = 600 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 1.10 },
			{ Order = 5, Value = 1.35 },
			{ Order = 10, Value = 1.45 },
			{ Order = 15, Value = 1.65 },
			{ Order = 20, Value = 1.85 },
			{ Order = 25, Value = 2.20 },
		},
	},
	SwingSpeed = {
		CostCheckpoints = {
			{ Order = 1, Value = 2 },
			{ Order = 5, Value = 15 },
			{ Order = 10, Value = 50 },
			{ Order = 15, Value = 150 },
			{ Order = 20, Value = 400 },
			{ Order = 25, Value = 1000 },
		},
		EffectCheckpoints = {
			{ Order = 1, Value = 1.20 },
			{ Order = 5, Value = 1.80 },
			{ Order = 10, Value = 2.40 },
			{ Order = 15, Value = 3.00 },
			{ Order = 20, Value = 3.50 },
			{ Order = 25, Value = 4.00 },
		},
	},
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

local upgradeMetadata = {
	WalkSpeed = {
		DisplayName = "Fleet Foot",
		Description = "Permanently increases player walk speed.",
	},
	SwingSpeed = {
		DisplayName = "Fast Edge",
		Description = "Permanently increases player swing speed.",
	},
	RegrowthTime = {
		DisplayName = "Golden Fertilizer",
		Description = "Reduces tree regrowth time globally.",
	},
	AxeDamage = {
		DisplayName = "Heavy Edge",
		Description = "Permanently increases base axe damage.",
	},
	CostReduction = {
		DisplayName = "Bargain Instinct",
		Description = "Reduces tree and lumberjack purchase costs.",
	},
	GoldMultiplier = {
		DisplayName = "Golden Touch",
		Description = "Increases gold gained from all felling.",
	},
	AmberGain = {
		DisplayName = "Amber Resonance",
		Description = "Increases Amber gained from rebirth.",
	},
}

local upgradeKeys = {
	"WalkSpeed",
	"SwingSpeed",
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

local function normalizeRebirthCount(rebirths)
	if typeof(rebirths) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(rebirths))
end

local function roundPercent(value)
	return math.max(0, math.floor(value + 0.5))
end

local function getUpgradeProfile(upgradeKey)
	if typeof(upgradeKey) ~= "string" then
		return nil
	end

	return progressionProfile[upgradeKey]
end

local function getUpgradeEffect(upgradeKey, level)
	local profile = getUpgradeProfile(upgradeKey)

	if not profile then
		return nil
	end

	local normalizedLevel = normalizeUpgradeLevel(level)

	if normalizedLevel < 1 then
		return 1
	end

	return interpolateCheckpoints(profile.EffectCheckpoints, normalizedLevel)
end

RebirthConfig.AmberProgression = copyProgressionTable()

function RebirthConfig.getUpgradeKeys()
	return table.clone(upgradeKeys)
end

function RebirthConfig.getMaxUpgradeLevel()
	return progressionProfile.MaxUpgradeLevel
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

function RebirthConfig.getUpgradeLevel(amberUpgrades, upgradeKey)
	if typeof(amberUpgrades) ~= "table" then
		return 0
	end

	if not getUpgradeProfile(upgradeKey) then
		return 0
	end

	return normalizeUpgradeLevel(amberUpgrades[upgradeKey])
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
	return RebirthConfig.getUpgradeEffect("AmberGain", level) or 1
end

function RebirthConfig.getWalkSpeedMultiplier(level)
	return RebirthConfig.getUpgradeEffect("WalkSpeed", level) or 1
end

function RebirthConfig.getSwingSpeedMultiplier(level)
	return RebirthConfig.getUpgradeEffect("SwingSpeed", level) or 1
end

function RebirthConfig.getRegrowthTimeMultiplier(level)
	return RebirthConfig.getUpgradeEffect("RegrowthTime", level) or 1
end

function RebirthConfig.getAxeDamageMultiplier(level)
	return RebirthConfig.getUpgradeEffect("AxeDamage", level) or 1
end

function RebirthConfig.getCostReductionMultiplier(level)
	return RebirthConfig.getUpgradeEffect("CostReduction", level) or 1
end

function RebirthConfig.getGoldMultiplier(level)
	return RebirthConfig.getUpgradeEffect("GoldMultiplier", level) or 1
end

function RebirthConfig.getRebirthGoldMultiplier(rebirths)
	return 1 + (normalizeRebirthCount(rebirths) * 0.1)
end

function RebirthConfig.getUpgradeEffect(upgradeKey, level)
	return getUpgradeEffect(upgradeKey, level)
end

function RebirthConfig.getUpgradeCostForNextLevel(upgradeKey, currentLevel)
	local profile = getUpgradeProfile(upgradeKey)

	if not profile then
		return nil
	end

	local normalizedLevel = normalizeUpgradeLevel(currentLevel)

	if normalizedLevel >= progressionProfile.MaxUpgradeLevel then
		return nil
	end

	return math.max(0, math.floor(interpolateCheckpoints(profile.CostCheckpoints, normalizedLevel + 1) + 0.5))
end

function RebirthConfig.getReducedCost(baseCost, costReductionLevel)
	if typeof(baseCost) ~= "number" then
		return nil
	end

	return math.max(0, math.floor((baseCost * RebirthConfig.getCostReductionMultiplier(costReductionLevel)) + 0.5))
end

function RebirthConfig.getUpgradeMetadata(upgradeKey)
	local metadata = upgradeMetadata[upgradeKey]

	if not metadata then
		return nil
	end

	return {
		DisplayName = metadata.DisplayName,
		Description = metadata.Description,
	}
end

function RebirthConfig.getUpgradeBenefitText(upgradeKey, value)
	if typeof(value) ~= "number" then
		return ""
	end

	if upgradeKey == "WalkSpeed" then
		return string.format("+%d%% Speed", roundPercent((value - 1) * 100))
	end

	if upgradeKey == "SwingSpeed" then
		return string.format("%d%% Speed", roundPercent(value * 100))
	end

	if upgradeKey == "RegrowthTime" then
		return string.format("-%d%% Time", roundPercent((1 - value) * 100))
	end

	if upgradeKey == "AxeDamage" then
		return string.format("+%d%% DMG", roundPercent((value - 1) * 100))
	end

	if upgradeKey == "CostReduction" then
		return string.format("-%d%% Cost", roundPercent((1 - value) * 100))
	end

	if upgradeKey == "GoldMultiplier" then
		return string.format("+%d%% Gold", roundPercent((value - 1) * 100))
	end

	if upgradeKey == "AmberGain" then
		return string.format("+%d%% Amber", roundPercent((value - 1) * 100))
	end

	return tostring(value)
end

function RebirthConfig.getUpgradeStats(upgradeName, currentLevel)
	if not getUpgradeProfile(upgradeName) then
		return nil
	end

	local normalizedLevel = normalizeUpgradeLevel(currentLevel)
	local maxLevel = progressionProfile.MaxUpgradeLevel
	local isMaxLevel = normalizedLevel >= maxLevel
	local metadata = RebirthConfig.getUpgradeMetadata(upgradeName)
	local currentValue = RebirthConfig.getUpgradeEffect(upgradeName, normalizedLevel) or 1
	local nextValue = not isMaxLevel and RebirthConfig.getUpgradeEffect(upgradeName, normalizedLevel + 1) or nil

	return {
		upgradeName = upgradeName,
		displayName = metadata and metadata.DisplayName or upgradeName,
		description = metadata and metadata.Description or "",
		currentLevel = normalizedLevel,
		maxLevel = maxLevel,
		isMaxLevel = isMaxLevel,
		costToNextLevel = RebirthConfig.getUpgradeCostForNextLevel(upgradeName, normalizedLevel),
		currentValue = currentValue,
		nextValue = nextValue,
		currentText = RebirthConfig.getUpgradeBenefitText(upgradeName, currentValue),
		nextText = nextValue and RebirthConfig.getUpgradeBenefitText(upgradeName, nextValue) or nil,
	}
end

RebirthConfig.GetUpgradeStats = RebirthConfig.getUpgradeStats

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
