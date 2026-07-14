local BlacksmithStateBuilder = {}

local function buildAxeSnapshot(player, tier, includeCost, resolveFinalDamageForTier)
	if not tier then
		return nil
	end

	local snapshot = {
		id = tier.Id,
		name = tier.Name,
		description = tier.Description,
		baseDamage = tier.Power,
		finalDamage = resolveFinalDamageForTier and resolveFinalDamageForTier(player, tier) or tier.Power,
		power = tier.Power,
		goldMultiplier = tier.GoldMultiplier,
		imageId = tier.ImageId,
	}

	if includeCost then
		snapshot.cost = tier.Cost
	end

	return snapshot
end

function BlacksmithStateBuilder.create(deps)
	local function buildStatePayload(player)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		local currentTierId = deps.getAxeTierId(player)
		local currentTier = deps.getTier(currentTierId)

		if not currentTier then
			return deps.buildFailure(deps.failureReasons.ConfigError)
		end

		local nextTier = deps.getNextTier(currentTierId)
		local gold = deps.getGold(player) or 0

		return deps.buildSuccess({
			gold = gold,
			currentTierId = currentTierId,
			currentAxe = buildAxeSnapshot(player, currentTier, false, deps.resolveFinalDamageForTier),
			nextTierId = nextTier and nextTier.Id or nil,
			nextAxe = buildAxeSnapshot(player, nextTier, true, deps.resolveFinalDamageForTier),
			canUpgrade = nextTier ~= nil and gold >= nextTier.Cost,
			isMaxTier = nextTier == nil,
		})
	end

	return {
		buildStatePayload = buildStatePayload,
	}
end

return BlacksmithStateBuilder
