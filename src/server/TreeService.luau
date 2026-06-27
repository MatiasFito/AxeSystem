local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
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
local treeProgressionResolverModule = require(script.Parent:WaitForChild("TreeProgressionResolver") :: ModuleScript)
local treeRuntimeManagerModule = require(script.Parent:WaitForChild("TreeRuntimeManager") :: ModuleScript)

local TreeService = {}

local TREE_HIT_DISTANCE = 16
local HIT_COOLDOWN_SECONDS = 0.18
local TREE_MIN_SCALE = 0.05
local TREE_DEAD_SCALE = 0.5
local TREE_GROWTH_STEP_SECONDS = 0.05
local TREE_READY_BOUNCE_STEP_SECONDS = 0.04
local TREE_HARVEST_RESPAWN_DELAY = 0.18
local TREE_HIT_SOUND_ID = "rbxassetid://136507037003210"
local TREE_DEATH_SOUND_ID = "rbxassetid://7214256592"
local TREE_IMPACT_PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local TREE_IMPACT_SURFACE_OFFSET = 0.35
local TREE_READY_BOUNCE_SCALES = { 1.08, 0.96, 1 }
local UNLOCK_BUTTON_COLOR_READY = Color3.fromRGB(255, 255, 255)
local UNLOCK_BUTTON_COLOR_LOCKED = Color3.fromRGB(126, 126, 126)
local UNLOCK_BUTTON_BASE_COLOR_READY = Color3.fromRGB(70, 145, 65)
local UNLOCK_BUTTON_BASE_COLOR_LOCKED = Color3.fromRGB(92, 92, 92)
local UNLOCK_BUTTON_TOUCH_COOLDOWN = 0.3
local UNLOCK_BUTTON_EDGE_OFFSET = 3.5
local UNLOCK_BUTTON_SCALE = 1.25
local UNLOCK_BUTTON_TEXT_READY = Color3.fromRGB(70, 145, 65)
local UNLOCK_BUTTON_TEXT_LOCKED = Color3.fromRGB(126, 126, 126)
local UNLOCK_BUTTON_SOUND_ID = "rbxassetid://138273059623491"
local UNLOCK_BUTTON_TWEEN_DURATION = 0.75
local UNLOCK_BUTTON_MIN_THICKNESS = 0.05

local started = false
local playerData = nil
local treePlotService = nil
local treePlotMaterializer = nil
local treeRuntimeManager = nil
local treeNetworkBridge = nil
local treeHitController = nil

local function getServerNow()
	return Workspace:GetServerTimeNow()
end

function TreeService.start(playerDataModule, treePlotServiceModule, axeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotService = treePlotServiceModule
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
		getRuntimePlotState = treeRuntimeManager.getRuntimePlotState,
		getActiveRuntimePlotState = treeRuntimeManager.getActiveRuntimePlotState,
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
		getRuntimePlotState = treeRuntimeManager.getRuntimePlotState,
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
			return ServerStorage:FindFirstChild(treeConstants.TREE_TEMPLATE_FOLDER_NAME)
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
		setGold = playerData.setGold,
		setTreePlot = playerData.setTreePlot,
		playUnlockButtonSuccessTween = function(player, plotId)
			if unlockPromptManager then
				unlockPromptManager.playUnlockButtonSuccessTween(treeRuntimeManager.getRuntimePlotState(player, plotId))
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
			HitSoundId = TREE_HIT_SOUND_ID,
			DeathSoundId = TREE_DEATH_SOUND_ID,
			HarvestRespawnDelay = TREE_HARVEST_RESPAWN_DELAY,
		},
		isPlayerLoaded = playerData.isLoaded,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getTreePlot = playerData.getTreePlot,
		getCharacterRootPart = treeInteractionUtils.getCharacterRootPart,
		getEquippedAxeTool = treeInteractionUtils.getEquippedAxeTool,
		getRuntimePlotState = treeRuntimeManager.getRuntimePlotState,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getLevelData = treeConfig.getLevelData,
		getToolStatValue = treeInteractionUtils.getToolStatValue,
		emitTreeParticles = treeVisualController.emitTreeParticles,
		playTreeSound = treeVisualController.playTreeSound,
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
		pushHitFeedback = treeNetworkBridge.pushHitFeedback,
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
			Scale = UNLOCK_BUTTON_SCALE,
			ColorReady = UNLOCK_BUTTON_COLOR_READY,
			ColorLocked = UNLOCK_BUTTON_COLOR_LOCKED,
			BaseColorReady = UNLOCK_BUTTON_BASE_COLOR_READY,
			BaseColorLocked = UNLOCK_BUTTON_BASE_COLOR_LOCKED,
			TextReady = UNLOCK_BUTTON_TEXT_READY,
			TextLocked = UNLOCK_BUTTON_TEXT_LOCKED,
			SoundId = UNLOCK_BUTTON_SOUND_ID,
			TweenDuration = UNLOCK_BUTTON_TWEEN_DURATION,
			MinThickness = UNLOCK_BUTTON_MIN_THICKNESS,
		},
		setAllSurfacesStuds = treeSpatialUtils.setAllSurfacesStuds,
		getHorizontalDirection = treeSpatialUtils.getHorizontalDirection,
		getPartExtentAlongDirection = treeSpatialUtils.getPartExtentAlongDirection,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getAssignedPlotSet = treePlotService.getAssignedPlotSet,
		getTreePlot = playerData.getTreePlot,
		getTreePlots = playerData.getTreePlots,
		getGold = playerData.getGold,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getRuntimePlotState = treeRuntimeManager.getRuntimePlotState,
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

function TreeService.onPlayerAdded(player)
	if not playerData.isLoaded(player) then
		return false
	end

	local plotSet, errorMessage = treePlotService.assignPlayer(player)

	if not plotSet then
		warn(string.format("Failed to assign tree plot set to %s: %s", player.Name, tostring(errorMessage)))
		return false
	end

	treeRuntimeManager.cleanupPlayerRuntime(player)
	treeRuntimeManager.setPlotSetId(player, plotSet.Id)
	return treePlotMaterializer.refreshAllAssignedPlots(player)
end

function TreeService.onPlayerRemoving(player)
	treeRuntimeManager.cleanupPlayerRuntime(player)
	treePlotService.releasePlayer(player)
end

function TreeService.onPlayerDataReset(player)
	if not playerData.isLoaded(player) then
		return false
	end

	treeRuntimeManager.cleanupPlayerRuntime(player)
	treeRuntimeManager.setPlotSetId(player, treePlotService.getAssignedPlotSetId(player))
	return treePlotMaterializer.refreshAllAssignedPlots(player)
end

return TreeService
