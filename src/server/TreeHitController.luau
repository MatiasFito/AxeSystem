local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)

local TreeHitController = {}

function TreeHitController.create(deps)
	local constants = deps.constants

	local function pushTreeEffect(player, plotRecord, payload)
		payload.plotCFrame = plotRecord.DirtPatch.CFrame
		payload.plotSize = plotRecord.DirtPatch.Size
		deps.pushAudioEvent(player, payload)
	end

	local function pushTreeAudio(player, plotRecord, kind, soundId, volume)
		pushTreeEffect(player, plotRecord, {
			effectType = "audio",
			kind = kind,
			soundId = soundId,
			volume = volume,
		})
	end

	local function pushTreeParticles(player, plotRecord, particleCount, particleCFrame)
		if particleCount <= 0 or particleCFrame == nil then
			return
		end

		pushTreeEffect(player, plotRecord, {
			effectType = "particles",
			particleCount = particleCount,
			particleCFrame = particleCFrame,
			particleTexture = constants.ImpactParticleTexture,
		})
	end

	local function resolveHitCooldownGraceSeconds(hitCooldownSeconds)
		local configuredGrace = constants.HitCooldownGraceSeconds or 0

		if configuredGrace > 0 then
			return math.min(configuredGrace, hitCooldownSeconds * 0.5)
		end

		return math.min(0.03, math.max(0.01, hitCooldownSeconds * 0.12))
	end

	local function resolveReward(levelData, goldMultiplier)
		return math.max(0, math.floor(levelData.Reward * goldMultiplier))
	end

	local function resolveNearestOwnedGrownPlot(player, rootPosition)
		local assignedPlotSet = deps.getAssignedPlotSet(player)

		if not assignedPlotSet or typeof(rootPosition) ~= "Vector3" then
			return nil, nil, nil
		end

		local nearestPlotId = nil
		local nearestPlotRecord = nil
		local nearestPlotState = nil
		local nearestDistance = constants.HitDistance

		for _, candidatePlotId in assignedPlotSet.OrderedPlotIds do
			local plotRecord = assignedPlotSet.PlotsById[candidatePlotId]
			local plotState = plotRecord and deps.getTreePlot(player, candidatePlotId) or nil

			if plotRecord and plotState and plotState.State == deps.grownState then
				local distance = (rootPosition - plotRecord.DirtPatch.Position).Magnitude

				if distance <= nearestDistance then
					nearestPlotId = candidatePlotId
					nearestPlotRecord = plotRecord
					nearestPlotState = plotState
					nearestDistance = distance
				end
			end
		end

		return nearestPlotId, nearestPlotRecord, nearestPlotState
	end

	local function resolveHitCooldownSeconds(hitContext)
		if typeof(hitContext) == "table" then
			local requestedCooldown = hitContext.hitCooldownSeconds

			if typeof(requestedCooldown) == "number" and requestedCooldown > 0 then
				return requestedCooldown
			end

			local tool = hitContext.tool

			if tool then
				return swingSpeed.getAutoSwingInterval(tool, swingSpeed.DEFAULT_BASE_SWING_DURATION)
			end
		end

		return constants.HitCooldownSeconds
	end

	local function processResolvedHit(player, plotId, hitContext)
		if not deps.isPlayerLoaded(player) then
			return false
		end

		local plotRecord = deps.getAssignedPlot(player, plotId)
		local plotState = deps.getTreePlot(player, plotId)

		if not plotRecord or not plotState or plotState.State ~= deps.grownState then
			return false
		end

		local runtimePlotState = deps.getRuntimePlotState(player, plotId)
		local now = os.clock()
		local hitCooldownSeconds = resolveHitCooldownSeconds(hitContext)
		local hitCooldownGraceSeconds = resolveHitCooldownGraceSeconds(hitCooldownSeconds)
		local elapsedSinceLastAccept = now - runtimePlotState.LastAcceptedHitAt

		if elapsedSinceLastAccept + hitCooldownGraceSeconds < hitCooldownSeconds then
			return false
		end

		runtimePlotState.LastAcceptedHitAt = now

		local tree = deps.getTreeByPlotId(plotId)
		local levelData = tree and deps.getLevelData(tree.Id, plotState.Level) or nil
		local supportsLumberjack = tree and tree.SupportsLumberjack ~= false or false
		local hitSource = hitContext.source == "lumberjack" and "lumberjack" or "player"

		if not tree or not levelData then
			return false
		end

		if runtimePlotState.CurrentHealth == nil then
			runtimePlotState.CurrentHealth = levelData.Health
		end

		local power = math.max(1, math.floor(hitContext.power or 1))
		local effectOrigin = hitContext.effectOrigin or plotRecord.DirtPatch.Position

		if tree.IsInfiniteTree then
			local reward = resolveReward(levelData, hitContext.goldMultiplier or 1)
			local currentGold = deps.getGold(player) or 0
			deps.setGold(player, currentGold + reward)
			deps.refreshUnlockButtons(player)
			deps.emitTreeParticles(runtimePlotState.SpawnedTreeModel, constants.HitParticleCount, effectOrigin)
			pushTreeAudio(player, plotRecord, "hit", constants.HitSoundId, constants.HitSoundVolume)
			deps.applyTreeShake(runtimePlotState, plotRecord, constants.ShakeDuration, constants.ShakeAngleDegrees)

			return true
		end

		local actualDamage = math.min(runtimePlotState.CurrentHealth, power)
		runtimePlotState.CurrentHealth -= actualDamage

		if runtimePlotState.CurrentHealth > 0 then
			deps.emitTreeParticles(runtimePlotState.SpawnedTreeModel, constants.HitParticleCount, effectOrigin)
		else
			pushTreeParticles(
				player,
				plotRecord,
				constants.FellParticleCount,
				deps.getTreeImpactWorldCFrame(runtimePlotState.SpawnedTreeModel, effectOrigin)
			)
		end

		pushTreeAudio(player, plotRecord, "hit", constants.HitSoundId, constants.HitSoundVolume)

		if runtimePlotState.CurrentHealth > 0 then
			deps.applyTreeScale(
				runtimePlotState,
				plotRecord,
				deps.getHarvestScale(runtimePlotState.CurrentHealth, levelData.Health)
			)
			deps.applyTreeShake(runtimePlotState, plotRecord, constants.ShakeDuration, constants.ShakeAngleDegrees)

			return true
		end

		local reward = resolveReward(levelData, hitContext.goldMultiplier or 1)
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

		if hitSource == "player" then
			pushTreeAudio(player, plotRecord, "death", constants.DeathSoundId, constants.DeathSoundVolume)
		end
		deps.setTreePlot(player, plotId, {
			PlotId = plotState.PlotId,
			TreeId = plotState.TreeId,
			Unlocked = true,
			Level = plotState.Level,
			State = deps.growingState,
			GrowingUntil = growingUntil,
			HasLumberjack = supportsLumberjack and plotState.HasLumberjack == true,
			LumberjackLevel = supportsLumberjack and plotState.HasLumberjack and math.max(
				1,
				plotState.LumberjackLevel or 0
			) or 0,
		})
		deps.updatePromptForPlot(player, plotId)

		deps.pushStateUpdate(player, { plotId })

		task.delay(constants.HarvestRespawnDelay, function()
			local latestPlotState = deps.getTreePlot(player, plotId)

			if latestPlotState and latestPlotState.State == deps.growingState then
				deps.materializePlot(player, plotId)
			end
		end)

		return true
	end

	local function processTreeHit(player, plotId)
		if not deps.isPlayerLoaded(player) then
			return
		end

		local rootPart = deps.getCharacterRootPart(player)

		if not rootPart then
			return
		end

		local rootPosition = rootPart.Position
		local plotRecord = deps.getAssignedPlot(player, plotId)
		local plotState = plotRecord and deps.getTreePlot(player, plotId) or nil

		if not plotRecord or not plotState or plotState.State ~= deps.grownState then
			plotId, plotRecord, plotState = resolveNearestOwnedGrownPlot(player, rootPosition)
		end

		if not plotRecord or not plotState or plotState.State ~= deps.grownState then
			return
		end

		if (rootPosition - plotRecord.DirtPatch.Position).Magnitude > constants.HitDistance then
			plotId, plotRecord, plotState = resolveNearestOwnedGrownPlot(player, rootPosition)

			if not plotRecord or not plotState or plotState.State ~= deps.grownState then
				return
			end
		end

		local tool = deps.getEquippedAxeTool(player)

		if not tool then
			return
		end

		processResolvedHit(player, plotId, {
			power = deps.getToolStatValue(tool, "Power", 1),
			goldMultiplier = deps.getToolStatValue(tool, "GoldBonus", 1),
			tool = tool,
			effectOrigin = rootPosition,
			source = "player",
		})
	end

	local function processAutomationHit(player, plotId, hitContext)
		if typeof(hitContext) ~= "table" then
			return false
		end

		return processResolvedHit(player, plotId, hitContext)
	end

	return {
		processTreeHit = processTreeHit,
		processAutomationHit = processAutomationHit,
	}
end

return TreeHitController
