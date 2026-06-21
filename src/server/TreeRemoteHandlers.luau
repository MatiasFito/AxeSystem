local TreeRemoteHandlers = {}

function TreeRemoteHandlers.create(deps)
	local function handleTreeUpgradeRequest(player, plotId)
		if typeof(plotId) ~= "string" then
			return
		end

		local plotState = deps.getTreePlot(player, plotId)

		if not plotState or not plotState.Unlocked then
			return
		end

		deps.attemptUpgrade(player, plotId)
	end

	local function handleGetState(player)
		if not deps.hasAssignedPlotSet(player) then
			return deps.buildPlotNotFoundFailure()
		end

		return deps.buildStatePayload(player)
	end

	local function handleTreeHit(player, plotId)
		if typeof(plotId) ~= "string" then
			return
		end

		deps.processTreeHit(player, plotId)
	end

	return {
		handleGetState = handleGetState,
		handleTreeHit = handleTreeHit,
		handleTreeUpgradeRequest = handleTreeUpgradeRequest,
	}
end

function TreeRemoteHandlers.bind(remotes, handlers)
	remotes.GetTreeStateRemote.OnServerInvoke = handlers.handleGetState
	remotes.RequestTreeHitRemote.OnServerEvent:Connect(handlers.handleTreeHit)
	remotes.RequestTreeUpgradeRemote.OnServerEvent:Connect(handlers.handleTreeUpgradeRequest)
end

return TreeRemoteHandlers
