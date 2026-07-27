local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)

local DamageHubStateBuilder = {}

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
	return string.format("+%d%% DMG", toBonusPercent(multiplier))
end

local function formatPassBonus(multiplier)
	return string.format("x%.1f DMG", sanitizeMultiplier(multiplier))
end

local function buildCurrentAxeState(player, deps)
	local tier = deps.getTier(deps.getAxeTierId(player))

	if not tier then
		return nil
	end

	return {
		id = tier.Id,
		name = tier.Name,
		imageId = tier.ImageId,
		baseDamage = tier.Power,
		finalDamage = deps.resolveFinalDamageForTier(player, tier),
	}
end

local function buildAmberState(player, deps)
	local level = deps.getAmberUpgradeLevel(player, "AxeDamage") or 0
	local multiplier = sanitizeMultiplier(rebirthConfig.getAxeDamageMultiplier(level))

	return {
		level = level,
		multiplier = multiplier,
		bonusPercent = toBonusPercent(multiplier),
		bonusText = formatPercentBonus(multiplier),
	}
end

local function buildPassState(passKey, ownership)
	local definition = gamePassConfig.getPassDefinition(passKey)
	local passMultiplier = definition and sanitizeMultiplier(definition.Benefits[gamePassConfig.Benefit.Damage]) or 1

	return {
		passKey = passKey,
		passId = gamePassConfig.getPassId(passKey),
		owned = ownership[passKey] == true,
		multiplier = passMultiplier,
		bonusText = formatPassBonus(passMultiplier),
	}
end

function DamageHubStateBuilder.create(deps)
	local function buildStatePayload(player)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		local currentAxe = buildCurrentAxeState(player, deps)

		if not currentAxe then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		local ownership = deps.getOwnership(player)
		local amberState = buildAmberState(player, deps)
		local vipState = buildPassState(gamePassConfig.Pass.VIP, ownership)
		local doubleDamageState = buildPassState(gamePassConfig.Pass.DoubleDamage, ownership)

		return deps.buildSuccess({
			currentAxe = currentAxe,
			amber = amberState,
			passes = {
				vip = vipState,
				doubleDamage = doubleDamageState,
			},
			totalDamage = currentAxe.finalDamage,
			totalDamageText = string.format("TOTAL DAMAGE: %d DMG", currentAxe.finalDamage),
		})
	end

	return {
		buildStatePayload = buildStatePayload,
	}
end

return DamageHubStateBuilder
