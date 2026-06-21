local BlacksmithStateBuilder = {}

local function buildAxeSnapshot(tier, includeCost)
	if not tier then
		return nil
	end

	local snapshot = {
		id = tier.Id,
		name = tier.Name,
		description = tier.Description,
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
			currentAxe = buildAxeSnapshot(currentTier, false),
			nextTierId = nextTier and nextTier.Id or nil,
			nextAxe = buildAxeSnapshot(nextTier, true),
			canUpgrade = nextTier ~= nil and gold >= nextTier.Cost,
			isMaxTier = nextTier == nil,
		})
	end

	return {
		buildStatePayload = buildStatePayload,
	}
end

return BlacksmithStateBuilder
