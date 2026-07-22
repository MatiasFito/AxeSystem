local GoldHubRemoteHandlers = {}

function GoldHubRemoteHandlers.create(deps)
	local function handleGetState(player)
		return deps.getState(player)
	end

	return {
		handleGetState = handleGetState,
	}
end

function GoldHubRemoteHandlers.bind(remotes, handlers)
	remotes.GetGoldHubStateRemote.OnServerInvoke = handlers.handleGetState
end

return GoldHubRemoteHandlers
