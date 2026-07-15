local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameFeelConfig = require(sharedFolder:WaitForChild("GameFeelConfig") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local axeDamageResolverModule = require(script.Parent:WaitForChild("AxeDamageResolver") :: ModuleScript)
local treeRemoteHandlers = require(script.Parent:WaitForChild("TreeRemoteHandlers") :: ModuleScript)
local treeStateBuilder = require(script.Parent:WaitForChild("TreeStateBuilder") :: ModuleScript)
local treeInteractionUtils = require(script.Parent:WaitForChild("TreeInteractionUtils") :: ModuleScript)
local treeSpatialUtils = require(script.Parent:WaitForChild("TreeSpatialUtils") :: ModuleScript)
local treeNetworkBridgeModule = require(script.Parent:WaitForChild("TreeNetworkBridge") :: ModuleScript)
local treeUnlockPromptManager = require(script.Parent:WaitForChild("TreeUnlockPromptManager") :: ModuleScript)
local treeVisualControllerModule = require(script.Parent:WaitForChild("TreeVisualController") :: ModuleScript)
local treeGrowthControllerModule = require(script.Parent:WaitForChild("TreeGrowthController") :: ModuleScript)
local treeHitControllerModule = require(script.Parent:WaitForChild("TreeHitController") :: ModuleScript)
local treePlotMaterializerModule = require(script.Parent:WaitForChild("TreePlotMaterializer") :: ModuleScript)
local treePlotRuntimeOrchestratorModule =
	require(script.Parent:WaitForChild("TreePlotRuntimeOrchestrator") :: ModuleScript)
local treeProgressionResolverModule = require(script.Parent:WaitForChild("TreeProgressionResolver") :: ModuleScript)
local treeRulesModule = require(script.Parent:WaitForChild("TreeRules") :: ModuleScript)
local treeRuntimeManagerModule = require(script.Parent:WaitForChild("TreeRuntimeManager") :: ModuleScript)

local TreeService = {}

local TREE_HIT_DISTANCE = treeConstants.HIT_DISTANCE
local HIT_COOLDOWN_SECONDS = swingSpeed.MIN_EFFECTIVE_SWING_DURATION
local HIT_COOLDOWN_GRACE_SECONDS = 0.02
local TREE_MIN_SCALE = 0.05
local TREE_DEAD_SCALE = 0.5
local TREE_GROWTH_STEP_SECONDS = 0.05
local TREE_READY_BOUNCE_STEP_SECONDS = 0.04
local TREE_HARVEST_RESPAWN_DELAY = 0.18
local TREE_IMPACT_PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local TREE_IMPACT_SURFACE_OFFSET = 0.35
local TREE_READY_BOUNCE_SCALES = { 1.08, 0.96, 1 }
local UNLOCK_BUTTON_COLOR_READY = Color3.fromRGB(255, 255, 255)
local UNLOCK_BUTTON_COLOR_LOCKED = Color3.fromRGB(126, 126, 126)
local UNLOCK_BUTTON_BASE_COLOR_READY = Color3.fromRGB(70, 145, 65)
local UNLOCK_BUTTON_BASE_COLOR_LOCKED = Color3.fromRGB(92, 92, 92)
local UNLOCK_BUTTON_TOUCH_COOLDOWN = 0.3
local UNLOCK_BUTTON_EDGE_OFFSET = 3.5
local UNLOCK_BUTTON_TEXT_READY = Color3.fromRGB(70, 145, 65)
local UNLOCK_BUTTON_TEXT_LOCKED = Color3.fromRGB(126, 126, 126)
local UNLOCK_BUTTON_TWEEN_DURATION = 0.75
local UNLOCK_BUTTON_MIN_THICKNESS = 0.05

local started = false
local playerData = nil
local treePlotService = nil
local treePlotMaterializer = nil
local treeRuntimeManager = nil
local treeNetworkBridge = nil
local treeHitController = nil
local treeRules = nil
local sessionTimeService = nil

local function getServerNow()
	return Workspace:GetServerTimeNow()
end

local function getAmberUpgradeLevel(player, upgradeKey)
	if not treeRules then
		return 0
	end

	return treeRules.getAmberUpgradeLevel(player, upgradeKey)
end

local function getEffectiveGrowTime(player, baseGrowTime)
	if not treeRules then
		return 0
	end

	return treeRules.getEffectiveGrowTime(player, baseGrowTime)
end

local function getUnlockCost(player, tree)
	if not treeRules then
		return nil
	end

	return treeRules.getUnlockCost(player, tree)
end

function TreeService.start(
	playerDataModule,
	treePlotServiceModule,
	treePlotRuntimeServiceModule,
	axeServiceModule,
	sessionTimeServiceModule
)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotService = treePlotServiceModule
	sessionTimeService = sessionTimeServiceModule
	treeRules = treeRulesModule.create({
		getAmberUpgradeLevel = function(player, upgradeKey)
			if not playerData or not playerData.getAmberUpgradeLevel then
				return 0
			end

			return playerData.getAmberUpgradeLevel(player, upgradeKey) or 0
		end,
	})
	local axeDamageResolver = axeDamageResolverModule.create({
		getAmberUpgradeLevel = getAmberUpgradeLevel,
	})
	local treeVisualController = nil
	local treeGrowthController = nil
	local unlockPromptManager = nil
	treeNetworkBridge = treeNetworkBridgeModule.create({
		buildStatePayload = function(player, changedPlotIds)
			return treeStateBuilder.buildStatePayload(playerData, treePlotService, getServerNow, player, changedPlotIds)
		end,
	})
	treeRuntimeManager = treeRuntimeManagerModule.create({
		workspace = Workspace,
		runtimeFolderName = treeConstants.TREE_RUNTIME_FOLDER_NAME,
		getAssignedPlotSetId = treePlotService.getAssignedPlotSetId,
		clearScheduledReady = function(runtimePlotState)
			if treeGrowthController then
				treeGrowthController.clearScheduledReady(runtimePlotState)
			end
		end,
		destroyUnlockButton = function(runtimePlotState)
			if unlockPromptManager then
				unlockPromptManager.destroyUnlockButton(runtimePlotState)
			end
		end,
		destroySpawnedTree = function(runtimePlotState)
			if treeVisualController then
				treeVisualController.destroySpawnedTree(runtimePlotState)
			end
		end,
	})
	treeVisualController = treeVisualControllerModule.create({
		constants = {
			MinScale = TREE_MIN_SCALE,
			DeadScale = TREE_DEAD_SCALE,
			ImpactSurfaceOffset = TREE_IMPACT_SURFACE_OFFSET,
			ImpactParticleTexture = TREE_IMPACT_PARTICLE_TEXTURE,
		},
		getPartExtentAlongDirection = treeSpatialUtils.getPartExtentAlongDirection,
		alignCloneBottomToPlot = treeSpatialUtils.alignCloneBottomToPlot,
	})
	treeGrowthController = treeGrowthControllerModule.create({
		constants = {
			GrowthStepSeconds = TREE_GROWTH_STEP_SECONDS,
			ReadyBounceStepSeconds = TREE_READY_BOUNCE_STEP_SECONDS,
			ReadyBounceScales = TREE_READY_BOUNCE_SCALES,
		},
		getAssignedPlot = treePlotService.getAssignedPlot,
		getPlotRuntimeState = treeRuntimeManager.getPlotRuntimeState,
		getActivePlotRuntimeState = treeRuntimeManager.getActivePlotRuntimeState,
		getTreeRuntimeState = treeRuntimeManager.getTreeRuntimeState,
		getActiveTreeRuntimeState = treeRuntimeManager.getActiveTreeRuntimeState,
		getTreePlot = playerData.getTreePlot,
		getServerNow = getServerNow,
		applyTreeScale = treeVisualController.applyTreeScale,
		getGrowthScale = treeVisualController.getGrowthScale,
		beginVisualAnimation = treeVisualController.beginVisualAnimation,
		growingState = treeConstants.PlotState.Growing,
	})
	treePlotMaterializer = treePlotMaterializerModule.create({
		constants = {
			IsManagedTreeAttribute = treeConstants.IS_MANAGED_TREE_ATTRIBUTE,
			TreeIdAttribute = treeConstants.TREE_ID_ATTRIBUTE,
			TreePlotIdAttribute = treeConstants.TREE_PLOT_ID_ATTRIBUTE,
		},
		getAssignedPlot = treePlotService.getAssignedPlot,
		getAssignedPlotSet = treePlotService.getAssignedPlotSet,
		getTreePlot = playerData.getTreePlot,
		setTreePlot = playerData.setTreePlot,
		getPlotRuntimeState = treeRuntimeManager.getPlotRuntimeState,
		getTreeRuntimeState = treeRuntimeManager.getTreeRuntimeState,
		clearScheduledReady = treeGrowthController.clearScheduledReady,
		destroySpawnedTree = treeVisualController.destroySpawnedTree,
		updatePromptForPlot = function(player, plotId)
			if unlockPromptManager then
				unlockPromptManager.updatePromptForPlot(player, plotId)
			end
		end,
		getTree = treeConfig.getTree,
		getLevelData = treeConfig.getLevelData,
		getTreeTemplatesFolder = function()
			local templatesFolder = ServerStorage:FindFirstChild(treeConstants.TREE_TEMPLATE_FOLDER_NAME)

			if not templatesFolder then
				error(
					string.format(
						"Validated Studio asset 'ServerStorage/%s' is missing at runtime",
						treeConstants.TREE_TEMPLATE_FOLDER_NAME
					)
				)
			end

			return templatesFolder
		end,
		getOrCreateSetRuntimeFolder = treeRuntimeManager.getOrCreateSetRuntimeFolder,
		getSpawnCFrame = treeSpatialUtils.getSpawnCFrame,
		alignCloneBottomToPlot = treeSpatialUtils.alignCloneBottomToPlot,
		captureTreeVisualState = treeVisualController.captureTreeVisualState,
		applyTreeScale = treeVisualController.applyTreeScale,
		getGrowthScale = treeVisualController.getGrowthScale,
		startGrowthAnimation = treeGrowthController.startGrowthAnimation,
		playReadyBounce = treeGrowthController.playReadyBounce,
		scheduleReadyTransition = treeGrowthController.scheduleReadyTransition,
		pushStateUpdate = treeNetworkBridge.pushStateUpdate,
		getServerNow = getServerNow,
		grownState = treeConstants.PlotState.Grown,
	})
	treePlotRuntimeOrchestratorModule.configure({
		constants = {
			PlotSetIdAttribute = treeConstants.PLOT_SET_ID_ATTRIBUTE,
			PlotSetSpawnName = treeConstants.PLOT_SET_SPAWN_NAME,
		},
		treePlotRuntimeService = treePlotRuntimeServiceModule,
		treeRuntimeManager = treeRuntimeManager,
		treePlotMaterializer = treePlotMaterializer,
	})
	local treeProgressionResolver = treeProgressionResolverModule.create({
		failureReasons = treeConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getTreePlot = playerData.getTreePlot,
		getTreePlots = playerData.getTreePlots,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getTreeByOrder = treeConfig.getTreeByOrder,
		getGold = playerData.getGold,
		isPlotUnlockable = treeStateBuilder.isPlotUnlockable,
		getLevelData = treeConfig.getLevelData,
		getUpgradeLevel = treeConfig.getUpgradeLevel,
		getUpgradeCost = treeConfig.getUpgradeCost,
		getUnlockCost = getUnlockCost,
		getEffectiveGrowTime = getEffectiveGrowTime,
		setGold = playerData.setGold,
		setTreePlot = playerData.setTreePlot,
		playUnlockButtonSuccessTween = function(player, plotId)
			if unlockPromptManager then
				unlockPromptManager.playUnlockButtonSuccessTween(treeRuntimeManager.getPlotRuntimeState(player, plotId))
			end
		end,
		materializePlot = treePlotMaterializer.materializePlot,
		updatePromptForPlot = function(player, plotId)
			if unlockPromptManager then
				unlockPromptManager.updatePromptForPlot(player, plotId)
			end
		end,
		refreshUnlockButtons = function(player)
			if unlockPromptManager then
				unlockPromptManager.refreshUnlockButtons(player)
			end
		end,
		pushStateUpdate = treeNetworkBridge.pushStateUpdate,
		buildStatePayload = treeNetworkBridge.buildStatePayload,
		buildFailure = function(reason)
			return serviceResult.failure(reason, treeConstants.getFailureMessage)
		end,
		buildSuccess = serviceResult.success,
		getServerNow = getServerNow,
		growingState = treeConstants.PlotState.Growing,
	})
	treeHitController = treeHitControllerModule.create({
		constants = {
			HitDistance = TREE_HIT_DISTANCE,
			HitCooldownSeconds = HIT_COOLDOWN_SECONDS,
			HitCooldownGraceSeconds = HIT_COOLDOWN_GRACE_SECONDS,
			HitSoundId = gameFeelConfig.TreeHitSoundId,
			HitSoundVolume = gameFeelConfig.TreeHitSoundVolume,
			DeathSoundId = gameFeelConfig.TreeDeathSoundId,
			DeathSoundVolume = gameFeelConfig.TreeDeathSoundVolume,
			ImpactParticleTexture = TREE_IMPACT_PARTICLE_TEXTURE,
			HitParticleCount = gameFeelConfig.TreeHitParticleCount,
			FellParticleCount = gameFeelConfig.TreeFellParticleCount,
			ShakeDuration = gameFeelConfig.TreeShakeDuration,
			ShakeAngleDegrees = gameFeelConfig.TreeShakeAngleDegrees,
			HarvestRespawnDelay = TREE_HARVEST_RESPAWN_DELAY,
		},
		isPlayerLoaded = playerData.isLoaded,
		getAssignedPlotSet = treePlotService.getAssignedPlotSet,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getTreePlot = playerData.getTreePlot,
		getCharacterRootPart = treeInteractionUtils.getCharacterRootPart,
		getEquippedAxeTool = treeInteractionUtils.getEquippedAxeTool,
		getTreeRuntimeState = treeRuntimeManager.getTreeRuntimeState,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getLevelData = treeConfig.getLevelData,
		getToolStatValue = treeInteractionUtils.getToolStatValue,
		getAmberUpgradeLevel = getAmberUpgradeLevel,
		resolveFinalDamageFromBasePower = axeDamageResolver.resolveFinalDamageFromBasePower,
		getGoldMultiplier = rebirthConfig.getGoldMultiplier,
		getSessionGoldMultiplier = function(player)
			if sessionTimeService and sessionTimeService.getGoldMultiplier then
				return sessionTimeService.getGoldMultiplier(player)
			end

			return 1
		end,
		getEffectiveGrowTime = getEffectiveGrowTime,
		emitTreeParticles = treeVisualController.emitTreeParticles,
		getTreeImpactWorldCFrame = treeVisualController.getTreeImpactWorldCFrame,
		applyTreeShake = treeVisualController.applyTreeShake,
		applyTreeScale = treeVisualController.applyTreeScale,
		getHarvestScale = treeVisualController.getHarvestScale,
		getGold = playerData.getGold,
		setGold = playerData.setGold,
		refreshUnlockButtons = function(player)
			if unlockPromptManager then
				unlockPromptManager.refreshUnlockButtons(player)
			end
		end,
		applyTreeVisual = treeVisualController.applyTreeVisual,
		setTreePlot = playerData.setTreePlot,
		updatePromptForPlot = function(player, plotId)
			if unlockPromptManager then
				unlockPromptManager.updatePromptForPlot(player, plotId)
			end
		end,
		pushAudioEvent = treeNetworkBridge.pushAudioEvent,
		pushStateUpdate = treeNetworkBridge.pushStateUpdate,
		materializePlot = treePlotMaterializer.materializePlot,
		getServerNow = getServerNow,
		grownState = treeConstants.PlotState.Grown,
		growingState = treeConstants.PlotState.Growing,
	})
	unlockPromptManager = treeUnlockPromptManager.create({
		constants = {
			TouchCooldown = UNLOCK_BUTTON_TOUCH_COOLDOWN,
			EdgeOffset = UNLOCK_BUTTON_EDGE_OFFSET,
			ColorReady = UNLOCK_BUTTON_COLOR_READY,
			ColorLocked = UNLOCK_BUTTON_COLOR_LOCKED,
			BaseColorReady = UNLOCK_BUTTON_BASE_COLOR_READY,
			BaseColorLocked = UNLOCK_BUTTON_BASE_COLOR_LOCKED,
			TextReady = UNLOCK_BUTTON_TEXT_READY,
			TextLocked = UNLOCK_BUTTON_TEXT_LOCKED,
			TweenDuration = UNLOCK_BUTTON_TWEEN_DURATION,
			MinThickness = UNLOCK_BUTTON_MIN_THICKNESS,
		},
		getHorizontalDirection = treeSpatialUtils.getHorizontalDirection,
		getPartExtentAlongDirection = treeSpatialUtils.getPartExtentAlongDirection,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getAssignedPlotSet = treePlotService.getAssignedPlotSet,
		getTreePlot = playerData.getTreePlot,
		getTreePlots = playerData.getTreePlots,
		getGold = playerData.getGold,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getUnlockCost = getUnlockCost,
		getButtonTemplate = function()
			local template = ServerStorage:FindFirstChild("ButtonTemplate")

			if not template or not template:IsA("Model") then
				error("Validated Studio asset 'ServerStorage/ButtonTemplate' is missing or invalid at runtime")
			end

			return template
		end,
		getPlotRuntimeState = treeRuntimeManager.getPlotRuntimeState,
		getTouchingPlayer = treeInteractionUtils.getTouchingPlayer,
		attemptUnlock = treeProgressionResolver.attemptUnlock,
		isPlotUnlockable = treeStateBuilder.isPlotUnlockable,
	})
	treeRuntimeManager.getOrCreateRuntimeFolder()

	local remotes = treeNetworkBridge.getOrCreateRemotes()

	local handlers = treeRemoteHandlers.create({
		getTreePlot = playerData.getTreePlot,
		attemptUpgrade = treeProgressionResolver.attemptUpgrade,
		hasAssignedPlotSet = function(player)
			return treePlotService.getAssignedPlotSet(player) ~= nil
		end,
		buildPlotNotFoundFailure = function()
			return serviceResult.failure(treeConstants.FailureReason.PlotNotFound, treeConstants.getFailureMessage)
		end,
		buildStatePayload = treeNetworkBridge.buildStatePayload,
		processTreeHit = treeHitController.processTreeHit,
	})

	treeRemoteHandlers.bind(remotes, handlers)

	if axeServiceModule == nil then
		warn("TreeService started without AxeService")
	end
end

function TreeService.pushStateUpdate(player, changedPlotIds)
	if treeNetworkBridge then
		treeNetworkBridge.pushStateUpdate(player, changedPlotIds)
	end
end

function TreeService.processAutomationHit(player, plotId, hitContext)
	if not treeHitController then
		return false
	end

	return treeHitController.processAutomationHit(player, plotId, hitContext)
end

return TreeService
