local RebirthRemoteHandlers = {}

function RebirthRemoteHandlers.create(deps)
	local function handleGetState(player)
		return deps.getState(player)
	end

	local function handleRebirthRequest(player)
		return deps.requestRebirth(player)
	end

	return {
		handleGetState = handleGetState,
		handleRebirthRequest = handleRebirthRequest,
	}
end

function RebirthRemoteHandlers.bind(remotes, handlers)
	remotes.GetRebirthStateRemote.OnServerInvoke = handlers.handleGetState
	remotes.RequestRebirthRemote.OnServerInvoke = handlers.handleRebirthRequest
end

return RebirthRemoteHandlers
