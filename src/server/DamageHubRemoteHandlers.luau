local DamageHubRemoteHandlers = {}

function DamageHubRemoteHandlers.create(deps)
	local function handleGetState(player)
		return deps.getState(player)
	end

	return {
		handleGetState = handleGetState,
	}
end

function DamageHubRemoteHandlers.bind(remotes, handlers)
	remotes.GetDamageHubStateRemote.OnServerInvoke = handlers.handleGetState
end

return DamageHubRemoteHandlers
