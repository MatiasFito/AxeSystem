local BlacksmithRemoteHandlers = {}

function BlacksmithRemoteHandlers.create(deps)
	local function handleGetState(player)
		if not deps.isShopAvailable(player) then
			return deps.buildShopUnavailableFailure()
		end

		return deps.buildStatePayload(player)
	end

	local function handleUpgrade(player, requestedTierId)
		return deps.handleUpgrade(player, requestedTierId)
	end

	local function handleSwingSpeedChange(player, requestedSpeed)
		deps.setPlayerSwingSpeed(player, requestedSpeed)
	end

	return {
		handleGetState = handleGetState,
		handleUpgrade = handleUpgrade,
		handleSwingSpeedChange = handleSwingSpeedChange,
	}
end

function BlacksmithRemoteHandlers.bind(remotes, handlers)
	remotes.GetStateRemote.OnServerInvoke = handlers.handleGetState
	remotes.RequestUpgradeRemote.OnServerInvoke = handlers.handleUpgrade
	remotes.RequestSwingSpeedRemote.OnServerEvent:Connect(handlers.handleSwingSpeedChange)
end

return BlacksmithRemoteHandlers
