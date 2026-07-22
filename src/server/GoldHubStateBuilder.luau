local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local sessionTimeConfig = require(sharedFolder:WaitForChild("SessionTimeConfig") :: ModuleScript)

local GoldHubStateBuilder = {}

local function sanitizeMultiplier(multiplier)
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function toBonusPercent(multiplier)
	return math.max(0, math.floor(((sanitizeMultiplier(multiplier) - 1) * 100) + 0.5))
end

local function formatPercentBonus(multiplier)
	return string.format("+%d%% Gold", toBonusPercent(multiplier))
end

local function getSessionTierIndex(tiers, sessionSeconds)
	local resolvedSessionSeconds = math.max(0, math.floor(tonumber(sessionSeconds) or 0))
	local currentTierIndex = 0

	for index, tier in ipairs(tiers) do
		if resolvedSessionSeconds < (tier.TimeRequired or 0) then
			break
		end

		currentTierIndex = index
	end

	return currentTierIndex
end

local function buildAxeState(player, deps)
	local tier = axeConfig.getTier(deps.getAxeTierId(player)) or axeConfig.getDefaultTier()
	local multiplier = tier and sanitizeMultiplier(tier.GoldMultiplier) or 1

	return {
		tierId = tier and tier.Id or nil,
		tierName = tier and tier.Name or "Unknown Axe",
		multiplier = multiplier,
		bonusPercent = toBonusPercent(multiplier),
		bonusText = formatPercentBonus(multiplier),
		imageId = tier and tier.ImageId or "",
	}
end

local function buildAmberState(player, deps)
	local level = deps.getAmberUpgradeLevel(player, "GoldMultiplier") or 0
	local stats = rebirthConfig.getUpgradeStats("GoldMultiplier", level)
	local multiplier = stats and sanitizeMultiplier(stats.currentValue) or 1

	return {
		level = level,
		multiplier = multiplier,
		bonusPercent = toBonusPercent(multiplier),
		bonusText = stats and stats.currentText or formatPercentBonus(multiplier),
	}
end

local function buildSessionTimeState(player, deps)
	local tiers = sessionTimeConfig.getTiers()
	local sessionSeconds = deps.getSessionSeconds(player)
	local currentTierIndex = getSessionTierIndex(tiers, sessionSeconds)
	local currentTier = currentTierIndex > 0 and tiers[currentTierIndex] or nil
	local nextTier = tiers[currentTierIndex + 1]
	local currentThreshold = currentTier and currentTier.TimeRequired or 0
	local nextThreshold = nextTier and nextTier.TimeRequired or currentThreshold
	local multiplier = sanitizeMultiplier(sessionTimeConfig.getGoldMultiplier(sessionSeconds))
	local progressAlpha = 1
	local secondsRemaining = 0

	if nextTier then
		local thresholdRange = math.max(1, nextThreshold - currentThreshold)
		secondsRemaining = math.max(0, nextThreshold - sessionSeconds)
		progressAlpha = math.clamp((sessionSeconds - currentThreshold) / thresholdRange, 0, 1)
	end

	return {
		sessionSeconds = sessionSeconds,
		level = currentTierIndex,
		multiplier = multiplier,
		bonusPercent = toBonusPercent(multiplier),
		bonusText = formatPercentBonus(multiplier),
		currentTierLabel = currentTier and currentTier.Label or "LVL 0",
		currentThreshold = currentThreshold,
		nextThreshold = nextTier and nextTier.TimeRequired or nil,
		nextTierLabel = nextTier and nextTier.Label or nil,
		secondsRemaining = secondsRemaining,
		progressAlpha = progressAlpha,
		isMaxLevel = nextTier == nil,
	}
end

local function buildPassState(passKey, ownership)
	local multiplier = sanitizeMultiplier(gamePassConfig.getBenefitMultiplier(ownership, gamePassConfig.Benefit.Gold))
	local owned = ownership[passKey] == true
	local passId = gamePassConfig.getPassId(passKey)
	local definition = gamePassConfig.getPassDefinition(passKey)
	local passMultiplier = definition and sanitizeMultiplier(definition.Benefits[gamePassConfig.Benefit.Gold]) or 1

	return {
		passKey = passKey,
		passId = passId,
		owned = owned,
		multiplier = owned and passMultiplier or 1,
		bonusPercent = owned and toBonusPercent(passMultiplier) or toBonusPercent(passMultiplier),
		bonusText = formatPercentBonus(passMultiplier),
		totalOwnedGoldMultiplier = multiplier,
	}
end

function GoldHubStateBuilder.create(deps)
	local function buildStatePayload(player)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		local ownership = deps.getOwnership(player)
		local axeState = buildAxeState(player, deps)
		local amberState = buildAmberState(player, deps)
		local sessionTimeState = buildSessionTimeState(player, deps)
		local vipState = buildPassState(gamePassConfig.Pass.VIP, ownership)
		local doubleGoldState = buildPassState(gamePassConfig.Pass.DoubleGold, ownership)
		local totalMultiplier = sanitizeMultiplier(axeState.multiplier)
			* sanitizeMultiplier(amberState.multiplier)
			* sanitizeMultiplier(sessionTimeState.multiplier)
			* sanitizeMultiplier(gamePassConfig.getBenefitMultiplier(ownership, gamePassConfig.Benefit.Gold))

		return deps.buildSuccess({
			axe = axeState,
			amber = amberState,
			sessionTime = sessionTimeState,
			passes = {
				vip = vipState,
				doubleGold = doubleGoldState,
			},
			totalMultiplier = totalMultiplier,
			totalBonusPercent = toBonusPercent(totalMultiplier),
			totalBonusText = string.format("x%.2f Total Gold", totalMultiplier),
		})
	end

	return {
		buildStatePayload = buildStatePayload,
	}
end

return GoldHubStateBuilder
