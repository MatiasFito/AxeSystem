local TreeGrowthController = {}

function TreeGrowthController.create(deps)
	local constants = deps.constants

	local function clearScheduledReady(runtimePlotState)
		runtimePlotState.ReadyTaskToken += 1
	end

	local function startGrowthAnimation(player, plotId, growingUntil, growTime)
		local plotRecord = deps.getAssignedPlot(player, plotId)
		local treeRuntimeState = deps.getTreeRuntimeState(player, plotId)

		if not plotRecord or not treeRuntimeState.SpawnedTreeModel then
			return
		end

		local duration = math.max(0.01, growTime)
		local startTime = growingUntil - duration
		local token = deps.beginVisualAnimation(treeRuntimeState)

		task.spawn(function()
			while true do
				local activeTreeState = deps.getActiveTreeRuntimeState(player, plotId)
				local latestPlotState = deps.getTreePlot(player, plotId)

				if not activeTreeState or activeTreeState.AnimationToken ~= token then
					return
				end

				if not latestPlotState or latestPlotState.State ~= deps.growingState then
					return
				end

				local progress = math.clamp((deps.getServerNow() - startTime) / duration, 0, 1)
				deps.applyTreeScale(treeRuntimeState, plotRecord, deps.getGrowthScale(progress))

				if progress >= 1 then
					return
				end

				task.wait(constants.GrowthStepSeconds)
			end
		end)
	end

	local function playReadyBounce(player, plotId)
		local plotRecord = deps.getAssignedPlot(player, plotId)
		local treeRuntimeState = deps.getTreeRuntimeState(player, plotId)

		if not plotRecord or not treeRuntimeState.SpawnedTreeModel then
			return
		end

		local token = deps.beginVisualAnimation(treeRuntimeState)

		task.spawn(function()
			for _, bounceScale in constants.ReadyBounceScales do
				local activeTreeState = deps.getActiveTreeRuntimeState(player, plotId)

				if not activeTreeState or activeTreeState.AnimationToken ~= token then
					return
				end

				deps.applyTreeScale(treeRuntimeState, plotRecord, bounceScale)
				task.wait(constants.ReadyBounceStepSeconds)
			end
		end)
	end

	local function scheduleReadyTransition(player, plotId, growingUntil, onReady)
		local plotRuntimeState = deps.getPlotRuntimeState(player, plotId)
		local token = plotRuntimeState.ReadyTaskToken + 1
		plotRuntimeState.ReadyTaskToken = token

		task.delay(math.max(0, growingUntil - deps.getServerNow()), function()
			local activePlotState = deps.getActivePlotRuntimeState(player, plotId)

			if not activePlotState or activePlotState.ReadyTaskToken ~= token then
				return
			end

			local latestPlotState = deps.getTreePlot(player, plotId)

			if not latestPlotState or latestPlotState.State ~= deps.growingState then
				return
			end

			onReady(latestPlotState)
		end)
	end

	return {
		clearScheduledReady = clearScheduledReady,
		startGrowthAnimation = startGrowthAnimation,
		playReadyBounce = playReadyBounce,
		scheduleReadyTransition = scheduleReadyTransition,
	}
end

return TreeGrowthController
