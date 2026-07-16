local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)

local AXE_DAMAGE_UPGRADE_KEY = "AxeDamage"

local AxeDamageResolver = {}

local function normalizeBasePower(basePower)
	if typeof(basePower) ~= "number" then
		return 1
	end

	return math.max(1, math.floor(basePower))
end

function AxeDamageResolver.create(deps)
	local function getGamePassDamageMultiplier(player)
		if not deps.getGamePassDamageMultiplier then
			return 1
		end

		local multiplier = deps.getGamePassDamageMultiplier(player)

		if typeof(multiplier) ~= "number" or multiplier <= 0 then
			return 1
		end

		return multiplier
	end

	local function getDamageMultiplier(player)
		if not deps.getAmberUpgradeLevel then
			return 1
		end

		local level = deps.getAmberUpgradeLevel(player, AXE_DAMAGE_UPGRADE_KEY) or 0
		return rebirthConfig.getAxeDamageMultiplier(level) * getGamePassDamageMultiplier(player)
	end

	local function resolveFinalDamageFromBasePower(player, basePower)
		local normalizedBasePower = normalizeBasePower(basePower)
		return math.max(1, math.floor((normalizedBasePower * getDamageMultiplier(player)) + 0.5))
	end

	local function resolveFinalDamageForTier(player, tier)
		if not tier then
			return nil
		end

		return resolveFinalDamageFromBasePower(player, tier.Power)
	end

	local function resolveFinalDamageForTierId(player, tierId)
		local tier = axeConfig.getTier(tierId) or axeConfig.getDefaultTier()
		return resolveFinalDamageForTier(player, tier)
	end

	return {
		resolveFinalDamageForTier = resolveFinalDamageForTier,
		resolveFinalDamageForTierId = resolveFinalDamageForTierId,
		resolveFinalDamageFromBasePower = resolveFinalDamageFromBasePower,
	}
end

return AxeDamageResolver
