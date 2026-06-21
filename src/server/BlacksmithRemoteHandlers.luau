local BlacksmithRemoteHandlers = {}

function BlacksmithRemoteHandlers.create(deps)
	local function handleGetState(player)
		if not deps.isShopAvailable() then
			return deps.buildShopUnavailableFailure()
		end

		return deps.buildStatePayload(player)
	end

	local function handleUpgrade(player, requestedTierId)
		return deps.handleUpgrade(player, requestedTierId)
	end

	return {
		handleGetState = handleGetState,
		handleUpgrade = handleUpgrade,
	}
end

function BlacksmithRemoteHandlers.bind(remotes, handlers)
	remotes.GetStateRemote.OnServerInvoke = handlers.handleGetState
	remotes.RequestUpgradeRemote.OnServerInvoke = handlers.handleUpgrade
end

return BlacksmithRemoteHandlers
