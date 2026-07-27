local WishingTreeRemoteHandlers = {}

function WishingTreeRemoteHandlers.create(deps)
	local function handleRollBlessing(player)
		return deps.rollBlessing(player)
	end

	return {
		handleRollBlessing = handleRollBlessing,
	}
end

function WishingTreeRemoteHandlers.bind(remotes, handlers)
	remotes.RollBlessingRemote.OnServerInvoke = handlers.handleRollBlessing
end

return WishingTreeRemoteHandlers
