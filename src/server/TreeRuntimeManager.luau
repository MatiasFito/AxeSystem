local TreeRuntimeManager = {}

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
			Plots = {},
		}
		runtimeByPlayer[player] = runtimeState

		return runtimeState
	end

	local function getRuntimePlotState(player, plotId)
		local runtimeState = getRuntimePlayerState(player)
		local runtimePlotState = runtimeState.Plots[plotId]

		if runtimePlotState then
			return runtimePlotState
		end

		runtimePlotState = {
			CurrentHealth = nil,
			FullHealth = nil,
			SpawnedTreeModel = nil,
			UnlockButtonModel = nil,
			UnlockTouchConnection = nil,
			UnlockTweenToken = 0,
			IsUnlockAnimating = false,
			LastUnlockTouchAt = 0,
			ReadyTaskToken = 0,
			LastAcceptedHitAt = 0,
			AnimationToken = 0,
			VisualState = nil,
			VisualScale = 1,
		}
		runtimeState.Plots[plotId] = runtimePlotState
		return runtimePlotState
	end

	local function getActiveRuntimePlotState(player, plotId)
		local runtimeState = runtimeByPlayer[player]

		if not runtimeState then
			return nil
		end

		return runtimeState.Plots[plotId]
	end

	local function setPlotSetId(player, plotSetId)
		getRuntimePlayerState(player).PlotSetId = plotSetId
	end

	local function cleanupPlayerRuntime(player)
		local runtimeState = runtimeByPlayer[player]

		if not runtimeState then
			return
		end

		for _, runtimePlotState in runtimeState.Plots do
			deps.clearScheduledReady(runtimePlotState)
			deps.destroySpawnedTree(runtimePlotState)
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
		getRuntimePlotState = getRuntimePlotState,
		getActiveRuntimePlotState = getActiveRuntimePlotState,
		setPlotSetId = setPlotSetId,
		cleanupPlayerRuntime = cleanupPlayerRuntime,
	}
end

return TreeRuntimeManager
