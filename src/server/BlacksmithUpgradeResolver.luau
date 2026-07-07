local BlacksmithUpgradeResolver = {}

function BlacksmithUpgradeResolver.create(deps)
	local function handleUpgrade(player, requestedTierId)
		local statePayload = deps.buildStatePayload(player)

		if not statePayload.success then
			return statePayload
		end

		local state = statePayload.state
		local blacksmithPart = deps.getBlacksmithPart(player)

		if not blacksmithPart then
			return deps.buildFailure(deps.failureReasons.ShopUnavailable, state)
		end

		if not deps.isCharacterInZone(player.Character, blacksmithPart) then
			return deps.buildFailure(deps.failureReasons.NotInRange, state)
		end

		if state.isMaxTier then
			return deps.buildFailure(deps.failureReasons.AlreadyMaxed, state)
		end

		if typeof(requestedTierId) ~= "string" or requestedTierId ~= state.nextTierId then
			return deps.buildFailure(deps.failureReasons.InvalidTier, state)
		end

		local nextAxe = state.nextAxe

		if not nextAxe then
			return deps.buildFailure(deps.failureReasons.ConfigError, state)
		end

		if state.gold < nextAxe.cost then
			return deps.buildFailure(deps.failureReasons.InsufficientGold, state)
		end

		local canGrantTier = deps.canGrantTier(requestedTierId)

		if not canGrantTier then
			return deps.buildFailure(deps.failureReasons.ConfigError, state)
		end

		local grantSuccess, grantResult = deps.grantAxe(player, requestedTierId, true)

		if not grantSuccess then
			deps.warnGrantFailure(player, requestedTierId, grantResult)
			return deps.buildFailure(deps.failureReasons.ConfigError, state)
		end

		deps.setGold(player, state.gold - nextAxe.cost)
		deps.setAxeTierId(player, requestedTierId)

		local refreshedStatePayload = deps.buildStatePayload(player)

		if not refreshedStatePayload.success then
			return refreshedStatePayload
		end

		return deps.buildSuccess(refreshedStatePayload.state, {
			purchase = {
				previousTierId = state.currentTierId,
				newTierId = requestedTierId,
				costPaid = nextAxe.cost,
				goldAfter = refreshedStatePayload.state.gold,
			},
		})
	end

	return {
		handleUpgrade = handleUpgrade,
	}
end

return BlacksmithUpgradeResolver
