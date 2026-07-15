local TreeRuntimeManager = {}

local function createPlotRuntimeState()
	return {
		UnlockButtonModel = nil,
		UnlockTouchConnection = nil,
		UnlockTweenToken = 0,
		IsUnlockAnimating = false,
		LastUnlockTouchAt = 0,
		ReadyTaskToken = 0,
	}
end

local function createTreeRuntimeState()
	return {
		CurrentHealth = nil,
		FullHealth = nil,
		SpawnedTreeModel = nil,
		LastAcceptedHitAt = 0,
		AnimationToken = 0,
		VisualState = nil,
		VisualScale = 1,
		ShakeToken = 0,
	}
end

function TreeRuntimeManager.create(deps)
	local runtimeFolder = nil
	local runtimeByPlayer = {}

	local function getOrCreateChild(parent, name, className)
		local child = parent:FindFirstChild(name)

		if child and child.ClassName == className then
			return child
		end

		if child then
			child:Destroy()
		end

		child = Instance.new(className)
		child.Name = name
		child.Parent = parent

		return child
	end

	local function getOrCreateRuntimeFolder()
		if runtimeFolder and runtimeFolder.Parent == deps.workspace then
			return runtimeFolder
		end

		runtimeFolder = getOrCreateChild(deps.workspace, deps.runtimeFolderName, "Folder")
		return runtimeFolder
	end

	local function getOrCreateSetRuntimeFolder(plotSetId)
		return getOrCreateChild(getOrCreateRuntimeFolder(), plotSetId, "Folder")
	end

	local function getRuntimePlayerState(player)
		local runtimeState = runtimeByPlayer[player]

		if runtimeState then
			return runtimeState
		end

		runtimeState = {
			PlotSetId = deps.getAssignedPlotSetId(player),
			PlotRuntimeByPlotId = {},
			TreeRuntimeByPlotId = {},
		}
		runtimeByPlayer[player] = runtimeState

		return runtimeState
	end

	local function getOrCreateRuntimeStateBundle(player, plotId)
		local runtimeState = getRuntimePlayerState(player)
		local plotRuntimeState = runtimeState.PlotRuntimeByPlotId[plotId]
		local treeRuntimeState = runtimeState.TreeRuntimeByPlotId[plotId]

		if not plotRuntimeState then
			plotRuntimeState = createPlotRuntimeState()
			runtimeState.PlotRuntimeByPlotId[plotId] = plotRuntimeState
		end

		if not treeRuntimeState then
			treeRuntimeState = createTreeRuntimeState()
			runtimeState.TreeRuntimeByPlotId[plotId] = treeRuntimeState
		end

		return runtimeState, plotRuntimeState, treeRuntimeState
	end

	local function getPlotRuntimeState(player, plotId)
		local _, plotRuntimeState = getOrCreateRuntimeStateBundle(player, plotId)
		return plotRuntimeState
	end

	local function getTreeRuntimeState(player, plotId)
		local _, _, treeRuntimeState = getOrCreateRuntimeStateBundle(player, plotId)
		return treeRuntimeState
	end

	local function getActivePlotRuntimeState(player, plotId)
		local runtimeState = runtimeByPlayer[player]

		if not runtimeState then
			return nil
		end

		return runtimeState.PlotRuntimeByPlotId[plotId]
	end

	local function getActiveTreeRuntimeState(player, plotId)
		local runtimeState = runtimeByPlayer[player]

		if not runtimeState then
			return nil
		end

		return runtimeState.TreeRuntimeByPlotId[plotId]
	end

	local function setPlotSetId(player, plotSetId)
		getRuntimePlayerState(player).PlotSetId = plotSetId
	end

	local function cleanupPlayerRuntime(player)
		local runtimeState = runtimeByPlayer[player]

		if not runtimeState then
			return
		end

		local destroyedTreeStates = {}

		for plotId, plotRuntimeState in runtimeState.PlotRuntimeByPlotId do
			deps.clearScheduledReady(plotRuntimeState)
			deps.destroyUnlockButton(plotRuntimeState)

			local treeRuntimeState = runtimeState.TreeRuntimeByPlotId[plotId]

			if treeRuntimeState then
				deps.destroySpawnedTree(treeRuntimeState)
				destroyedTreeStates[plotId] = true
			end
		end

		for plotId, treeRuntimeState in runtimeState.TreeRuntimeByPlotId do
			if not destroyedTreeStates[plotId] then
				deps.destroySpawnedTree(treeRuntimeState)
			end
		end

		local plotSetId = runtimeState.PlotSetId

		if plotSetId and runtimeFolder then
			local setFolder = runtimeFolder:FindFirstChild(plotSetId)

			if setFolder then
				setFolder:Destroy()
			end
		end

		runtimeByPlayer[player] = nil
	end

	return {
		getOrCreateRuntimeFolder = getOrCreateRuntimeFolder,
		getOrCreateSetRuntimeFolder = getOrCreateSetRuntimeFolder,
		getRuntimePlayerState = getRuntimePlayerState,
		getPlotRuntimeState = getPlotRuntimeState,
		getTreeRuntimeState = getTreeRuntimeState,
		getActivePlotRuntimeState = getActivePlotRuntimeState,
		getActiveTreeRuntimeState = getActiveTreeRuntimeState,
		setPlotSetId = setPlotSetId,
		cleanupPlayerRuntime = cleanupPlayerRuntime,
	}
end

return TreeRuntimeManager
