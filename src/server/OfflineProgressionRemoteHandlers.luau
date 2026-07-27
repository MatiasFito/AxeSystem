local OfflineProgressionRemoteHandlers = {}

function OfflineProgressionRemoteHandlers.create(deps)
	local function handleGetReward(player)
		return deps.getPendingReward(player)
	end

	local function handleClaimReward(player, goldAmount)
		deps.claimReward(player, goldAmount)
	end

	return {
		handleGetReward = handleGetReward,
		handleClaimReward = handleClaimReward,
	}
end

function OfflineProgressionRemoteHandlers.bind(remotes, handlers)
	remotes.GetOfflineRewardRemote.OnServerInvoke = handlers.handleGetReward
	remotes.ClaimOfflineRewardRemote.OnServerEvent:Connect(handlers.handleClaimReward)
end

return OfflineProgressionRemoteHandlers
