local TreeHitController = {}

function TreeHitController.create(deps)
	local constants = deps.constants

	local function resolveReward(levelData, tool)
		local goldMultiplier = deps.getToolStatValue(tool, "GoldBonus", 1)
		return math.max(0, math.floor(levelData.Reward * goldMultiplier))
	end

	local function processTreeHit(player, plotId)
		if not deps.isPlayerLoaded(player) then
			return
		end

		local plotRecord = deps.getAssignedPlot(player, plotId)
		local plotState = deps.getTreePlot(player, plotId)

		if not plotRecord or not plotState or plotState.State ~= deps.grownState then
			return
		end

		local rootPart = deps.getCharacterRootPart(player)

		if not rootPart then
			return
		end

		if (rootPart.Position - plotRecord.DirtPatch.Position).Magnitude > constants.HitDistance then
			return
		end

		local tool = deps.getEquippedAxeTool(player)

		if not tool then
			return
		end

		local runtimePlotState = deps.getRuntimePlotState(player, plotId)
		local now = os.clock()

		if now - runtimePlotState.LastAcceptedHitAt < constants.HitCooldownSeconds then
			return
		end

		runtimePlotState.LastAcceptedHitAt = now

		local tree = deps.getTreeByPlotId(plotId)
		local levelData = tree and deps.getLevelData(tree.Id, plotState.Level) or nil

		if not tree or not levelData then
			return
		end

		if runtimePlotState.CurrentHealth == nil then
			runtimePlotState.CurrentHealth = levelData.Health
		end

		local power = math.max(1, math.floor(deps.getToolStatValue(tool, "Power", 1)))
		local actualDamage = math.min(runtimePlotState.CurrentHealth, power)
		runtimePlotState.CurrentHealth -= actualDamage
		deps.emitTreeParticles(
			runtimePlotState.SpawnedTreeModel,
			runtimePlotState.CurrentHealth > 0 and 10 or 16,
			rootPart.Position
		)
		deps.playTreeSound(runtimePlotState.SpawnedTreeModel, constants.HitSoundId, 1.15)

		if runtimePlotState.CurrentHealth > 0 then
			deps.applyTreeScale(
				runtimePlotState,
				plotRecord,
				deps.getHarvestScale(runtimePlotState.CurrentHealth, levelData.Health)
			)
			deps.pushHitFeedback(player, {
				plotId = plotId,
				treeId = tree.Id,
				treeName = tree.Name,
				kind = "hit",
				damage = actualDamage,
				currentHealth = runtimePlotState.CurrentHealth,
				maxHealth = levelData.Health,
			})
			return
		end

		local reward = resolveReward(levelData, tool)
		local currentGold = deps.getGold(player) or 0
		local growingUntil = deps.getServerNow() + levelData.GrowTime
		deps.setGold(player, currentGold + reward)
		deps.refreshUnlockButtons(player)
		runtimePlotState.CurrentHealth = 0
		deps.applyTreeVisual(
			runtimePlotState,
			plotRecord,
			runtimePlotState.VisualScale > 0 and runtimePlotState.VisualScale or 1,
			nil,
			1,
			true
		)
		deps.playTreeSound(runtimePlotState.SpawnedTreeModel, constants.DeathSoundId, 1.4)
		deps.setTreePlot(player, plotId, {
			PlotId = plotState.PlotId,
			TreeId = plotState.TreeId,
			Unlocked = true,
			Level = plotState.Level,
			State = deps.growingState,
			GrowingUntil = growingUntil,
		})
		deps.updatePromptForPlot(player, plotId)

		deps.pushHitFeedback(player, {
			plotId = plotId,
			treeId = tree.Id,
			treeName = tree.Name,
			kind = "felled",
			damage = actualDamage,
			currentHealth = 0,
			maxHealth = levelData.Health,
			reward = reward,
			goldAfter = currentGold + reward,
			regrowDuration = levelData.GrowTime,
		})

		deps.pushStateUpdate(player, { plotId })

		task.delay(constants.HarvestRespawnDelay, function()
			local latestPlotState = deps.getTreePlot(player, plotId)

			if latestPlotState and latestPlotState.State == deps.growingState then
				deps.materializePlot(player, plotId)
			end
		end)
	end

	return {
		processTreeHit = processTreeHit,
	}
end

return TreeHitController
