local TreePlotMaterializer = {}

function TreePlotMaterializer.create(deps)
	local constants = deps.constants

	local function spawnTreeForPlot(player, plotId, initialScale)
		local plotRecord = deps.getAssignedPlot(player, plotId)
		local plotState = deps.getTreePlot(player, plotId)
		local treeRuntimeState = deps.getTreeRuntimeState(player, plotId)

		if not plotRecord or not plotState then
			return false
		end

		local tree = deps.getTree(plotState.TreeId)
		local levelData = tree and deps.getLevelData(tree.Id, plotState.Level) or nil
		local templatesFolder = deps.getTreeTemplatesFolder()

		if not tree or not levelData then
			return false
		end

		local template = templatesFolder:FindFirstChild(tree.TemplateName)

		if not template then
			error(
				string.format(
					"Validated tree template 'ServerStorage/Trees/%s' is missing at runtime",
					tree.TemplateName
				)
			)
		end

		if not template:IsA("Model") and not template:IsA("BasePart") then
			error(
				string.format(
					"Validated tree template 'ServerStorage/Trees/%s' is not a Model or BasePart at runtime",
					tree.TemplateName
				)
			)
		end

		deps.destroySpawnedTree(treeRuntimeState)

		local clone = template:Clone()
		clone.Name = string.format("%s_%s", plotRecord.PlotSetId, plotId)
		clone:SetAttribute(constants.IsManagedTreeAttribute, true)
		clone:SetAttribute(constants.TreeIdAttribute, tree.Id)
		clone:SetAttribute(constants.TreePlotIdAttribute, plotId)

		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant:SetAttribute(constants.IsManagedTreeAttribute, true)
				descendant:SetAttribute(constants.TreeIdAttribute, tree.Id)
				descendant:SetAttribute(constants.TreePlotIdAttribute, plotId)
			end
		end

		clone.Parent = deps.getOrCreateSetRuntimeFolder(plotRecord.PlotSetId)

		local spawnCFrame = deps.getSpawnCFrame(plotRecord.TreeSpawn)

		if clone:IsA("Model") then
			clone:PivotTo(spawnCFrame)
			deps.alignCloneBottomToPlot(clone, plotRecord)
		elseif clone:IsA("BasePart") then
			clone.CFrame = spawnCFrame
			deps.alignCloneBottomToPlot(clone, plotRecord)
		end

		deps.captureTreeVisualState(treeRuntimeState, clone)
		treeRuntimeState.SpawnedTreeModel = clone
		treeRuntimeState.CurrentHealth = levelData.Health
		treeRuntimeState.FullHealth = levelData.Health
		deps.applyTreeScale(treeRuntimeState, plotRecord, initialScale or 1)
		return true
	end

	local function materializePlot(player, plotId)
		local plotState = deps.getTreePlot(player, plotId)
		local plotRuntimeState = deps.getPlotRuntimeState(player, plotId)
		local treeRuntimeState = deps.getTreeRuntimeState(player, plotId)

		if not plotState then
			return
		end

		deps.clearScheduledReady(plotRuntimeState)

		if not plotState.Unlocked then
			deps.destroySpawnedTree(treeRuntimeState)
			deps.updatePromptForPlot(player, plotId)
			return
		end

		if plotState.State == deps.grownState then
			spawnTreeForPlot(player, plotId, 1)
			deps.updatePromptForPlot(player, plotId)
			return
		end

		deps.destroySpawnedTree(treeRuntimeState)

		local tree = deps.getTree(plotState.TreeId)
		local levelData = tree and deps.getLevelData(tree.Id, plotState.Level) or nil
		local supportsLumberjack = tree and tree.SupportsLumberjack ~= false or false

		if not tree or not levelData then
			return
		end

		local growingUntil = plotState.GrowingUntil or deps.getServerNow()

		if growingUntil <= deps.getServerNow() then
			local updatedPlotState = {
				PlotId = plotState.PlotId,
				TreeId = plotState.TreeId,
				Unlocked = true,
				Level = plotState.Level,
				State = deps.grownState,
				GrowingUntil = nil,
				HasLumberjack = supportsLumberjack and plotState.HasLumberjack == true,
				LumberjackLevel = supportsLumberjack and plotState.HasLumberjack and math.max(
					1,
					plotState.LumberjackLevel or 0
				) or 0,
			}

			deps.setTreePlot(player, plotId, updatedPlotState)
			spawnTreeForPlot(player, plotId, 1)
			deps.playReadyBounce(player, plotId)
			deps.updatePromptForPlot(player, plotId)
			deps.pushStateUpdate(player, { plotId })
			return
		end

		local remaining = math.max(0, growingUntil - deps.getServerNow())
		local initialProgress = math.clamp(1 - (remaining / math.max(0.01, levelData.GrowTime)), 0, 1)
		spawnTreeForPlot(player, plotId, deps.getGrowthScale(initialProgress))
		deps.startGrowthAnimation(player, plotId, growingUntil, levelData.GrowTime)
		local plotRecord = deps.getAssignedPlot(player, plotId)

		deps.updatePromptForPlot(player, plotId)

		deps.scheduleReadyTransition(player, plotId, growingUntil, function(latestPlotState)
			deps.setTreePlot(player, plotId, {
				PlotId = latestPlotState.PlotId,
				TreeId = latestPlotState.TreeId,
				Unlocked = true,
				Level = latestPlotState.Level,
				State = deps.grownState,
				GrowingUntil = nil,
				HasLumberjack = supportsLumberjack and latestPlotState.HasLumberjack == true,
				LumberjackLevel = supportsLumberjack and latestPlotState.HasLumberjack and math.max(
					1,
					latestPlotState.LumberjackLevel or 0
				) or 0,
			})

			deps.applyTreeScale(treeRuntimeState, plotRecord, 1)
			deps.playReadyBounce(player, plotId)
			deps.updatePromptForPlot(player, plotId)
			deps.pushStateUpdate(player, { plotId })
		end)
	end

	local function refreshAllAssignedPlots(player)
		local plotSet = deps.getAssignedPlotSet(player)

		if not plotSet then
			return false
		end

		for _, plotId in plotSet.OrderedPlotIds do
			materializePlot(player, plotId)
		end

		deps.pushStateUpdate(player)
		return true
	end

	return {
		materializePlot = materializePlot,
		refreshAllAssignedPlots = refreshAllAssignedPlots,
	}
end

return TreePlotMaterializer
