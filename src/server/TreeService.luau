local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local treeRemoteHandlers = require(script.Parent:WaitForChild("TreeRemoteHandlers") :: ModuleScript)
local treeStateBuilder = require(script.Parent:WaitForChild("TreeStateBuilder") :: ModuleScript)
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
local axeService = nil

local getTreeStateRemote = nil
local requestTreeHitRemote = nil
local requestTreeUpgradeRemote = nil
local treeStateUpdatedRemote = nil
local treeHitFeedbackRemote = nil

local attemptUnlock = nil
local unlockPromptManager = nil
local treeVisualController = nil
local treeGrowthController = nil
local treeHitController = nil
local treePlotMaterializer = nil
local treeProgressionResolver = nil
local treeRuntimeManager = nil

local function playUnlockButtonSuccessTween(runtimePlotState)
	if unlockPromptManager then
		unlockPromptManager.playUnlockButtonSuccessTween(runtimePlotState)
	end
end

local function refreshUnlockButtons(player)
	if unlockPromptManager then
		unlockPromptManager.refreshUnlockButtons(player)
	end
end

local function updatePromptForPlot(player, plotId)
	if unlockPromptManager then
		unlockPromptManager.updatePromptForPlot(player, plotId)
	end
end

local function getActiveRuntimePlotState(player, plotId)
	return treeRuntimeManager.getActiveRuntimePlotState(player, plotId)
end

local function getServerNow()
	return Workspace:GetServerTimeNow()
end

local function getTreeTemplatesFolder()
	return ServerStorage:FindFirstChild(treeConstants.TREE_TEMPLATE_FOLDER_NAME)
end

local function getOrCreateRuntimeFolder()
	return treeRuntimeManager.getOrCreateRuntimeFolder()
end

local function getOrCreateSetRuntimeFolder(plotSetId)
	return treeRuntimeManager.getOrCreateSetRuntimeFolder(plotSetId)
end

local function getCharacterRootPart(player)
	local character = player.Character

	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function getEquippedAxeTool(player)
	local character = player.Character

	if not character then
		return nil
	end

	for _, child in character:GetChildren() do
		if axeConfig.isAxeTool(child) then
			return child
		end
	end

	return nil
end

local function getToolStatValue(tool, statName, fallbackValue)
	if not tool or not tool:IsA("Tool") then
		return fallbackValue
	end

	local statsFolder = tool:FindFirstChild("Stats")

	if not statsFolder then
		return fallbackValue
	end

	local statValue = statsFolder:FindFirstChild(statName)

	if statValue and statValue:IsA("NumberValue") then
		return statValue.Value
	end

	return fallbackValue
end

local function getSpawnCFrame(spawnInstance)
	if spawnInstance:IsA("Attachment") then
		return spawnInstance.WorldCFrame
	end

	return spawnInstance.CFrame
end

local function alignCloneBottomToPlot(clone, plotRecord)
	local targetBottomY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y / 2)

	if clone:IsA("Model") then
		local boundingBoxCFrame, boundingBoxSize = clone:GetBoundingBox()
		local currentBottomY = boundingBoxCFrame.Position.Y - (boundingBoxSize.Y / 2)
		local offsetY = targetBottomY - currentBottomY
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, offsetY, 0))
		return
	end

	if clone:IsA("BasePart") then
		local currentBottomY = clone.Position.Y - (clone.Size.Y / 2)
		local offsetY = targetBottomY - currentBottomY
		clone.CFrame += Vector3.new(0, offsetY, 0)
	end
end

local function getRuntimePlotState(player, plotId)
	return treeRuntimeManager.getRuntimePlotState(player, plotId)
end

local function clearScheduledReady(runtimePlotState)
	treeGrowthController.clearScheduledReady(runtimePlotState)
end

local function destroySpawnedTree(runtimePlotState)
	treeVisualController.destroySpawnedTree(runtimePlotState)
end

local function buildStatePayload(player, changedPlotIds)
	return treeStateBuilder.buildStatePayload(playerData, treePlotService, getServerNow, player, changedPlotIds)
end

local function pushStateUpdate(player, changedPlotIds)
	if not treeStateUpdatedRemote then
		return
	end

	local payload = buildStatePayload(player, changedPlotIds)

	if payload.success then
		treeStateUpdatedRemote:FireClient(player, payload.state)
	end
end

local function pushHitFeedback(player, payload)
	if not treeHitFeedbackRemote then
		return
	end

	treeHitFeedbackRemote:FireClient(player, payload)
end

local function setAllSurfacesStuds(part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
end

local function getTouchingPlayer(hit)
	if not hit then
		return nil
	end

	local character = hit.Parent

	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getHorizontalDirection(vector)
	local flattened = Vector3.new(vector.X, 0, vector.Z)

	if flattened.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flattened.Unit
end

local function getPartExtentAlongDirection(part, direction)
	local unitDirection = direction.Unit
	local rightVector = part.CFrame.RightVector
	local upVector = part.CFrame.UpVector
	local lookVector = part.CFrame.LookVector
	local halfSize = part.Size * 0.5

	return math.abs(unitDirection:Dot(rightVector)) * halfSize.X
		+ math.abs(unitDirection:Dot(upVector)) * halfSize.Y
		+ math.abs(unitDirection:Dot(lookVector)) * halfSize.Z
end

local function captureTreeVisualState(runtimePlotState, treeInstance)
	treeVisualController.captureTreeVisualState(runtimePlotState, treeInstance)
end

local function applyTreeScale(runtimePlotState, plotRecord, scale)
	return treeVisualController.applyTreeScale(runtimePlotState, plotRecord, scale)
end

local function materializePlot(player, plotId)
	treePlotMaterializer.materializePlot(player, plotId)
end

local function refreshAllAssignedPlots(player)
	return treePlotMaterializer.refreshAllAssignedPlots(player)
end

local function cleanupPlayerRuntime(player)
	treeRuntimeManager.cleanupPlayerRuntime(player)
end

attemptUnlock = function(player, plotId)
	return treeProgressionResolver.attemptUnlock(player, plotId)
end

local function attemptUpgrade(player, plotId)
	return treeProgressionResolver.attemptUpgrade(player, plotId)
end

local function processTreeHit(player, plotId)
	treeHitController.processTreeHit(player, plotId)
end

function TreeService.start(playerDataModule, treePlotServiceModule, axeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotService = treePlotServiceModule
	axeService = axeServiceModule
	treeRuntimeManager = treeRuntimeManagerModule.create({
		workspace = Workspace,
		runtimeFolderName = treeConstants.TREE_RUNTIME_FOLDER_NAME,
		getAssignedPlotSetId = function(player)
			return treePlotService.getAssignedPlotSetId(player)
		end,
		clearScheduledReady = clearScheduledReady,
		destroySpawnedTree = destroySpawnedTree,
	})
	treeVisualController = treeVisualControllerModule.create({
		constants = {
			MinScale = TREE_MIN_SCALE,
			DeadScale = TREE_DEAD_SCALE,
			ImpactSurfaceOffset = TREE_IMPACT_SURFACE_OFFSET,
			ImpactParticleTexture = TREE_IMPACT_PARTICLE_TEXTURE,
		},
		getPartExtentAlongDirection = getPartExtentAlongDirection,
		alignCloneBottomToPlot = alignCloneBottomToPlot,
	})
	treeGrowthController = treeGrowthControllerModule.create({
		constants = {
			GrowthStepSeconds = TREE_GROWTH_STEP_SECONDS,
			ReadyBounceStepSeconds = TREE_READY_BOUNCE_STEP_SECONDS,
			ReadyBounceScales = TREE_READY_BOUNCE_SCALES,
		},
		getAssignedPlot = function(player, plotId)
			return treePlotService.getAssignedPlot(player, plotId)
		end,
		getRuntimePlotState = getRuntimePlotState,
		getActiveRuntimePlotState = getActiveRuntimePlotState,
		getTreePlot = function(player, plotId)
			return playerData.getTreePlot(player, plotId)
		end,
		getServerNow = getServerNow,
		applyTreeScale = function(runtimePlotState, plotRecord, scale)
			return treeVisualController.applyTreeScale(runtimePlotState, plotRecord, scale)
		end,
		getGrowthScale = function(progress)
			return treeVisualController.getGrowthScale(progress)
		end,
		beginVisualAnimation = treeVisualController.beginVisualAnimation,
		growingState = treeConstants.PlotState.Growing,
	})
	treePlotMaterializer = treePlotMaterializerModule.create({
		constants = {
			IsManagedTreeAttribute = treeConstants.IS_MANAGED_TREE_ATTRIBUTE,
			TreeIdAttribute = treeConstants.TREE_ID_ATTRIBUTE,
			TreePlotIdAttribute = treeConstants.TREE_PLOT_ID_ATTRIBUTE,
		},
		getAssignedPlot = function(player, plotId)
			return treePlotService.getAssignedPlot(player, plotId)
		end,
		getAssignedPlotSet = function(player)
			return treePlotService.getAssignedPlotSet(player)
		end,
		getTreePlot = function(player, plotId)
			return playerData.getTreePlot(player, plotId)
		end,
		setTreePlot = playerData.setTreePlot,
		getRuntimePlotState = getRuntimePlotState,
		clearScheduledReady = clearScheduledReady,
		destroySpawnedTree = destroySpawnedTree,
		updatePromptForPlot = updatePromptForPlot,
		getTree = treeConfig.getTree,
		getLevelData = treeConfig.getLevelData,
		getTreeTemplatesFolder = getTreeTemplatesFolder,
		getOrCreateSetRuntimeFolder = getOrCreateSetRuntimeFolder,
		getSpawnCFrame = getSpawnCFrame,
		alignCloneBottomToPlot = alignCloneBottomToPlot,
		captureTreeVisualState = captureTreeVisualState,
		applyTreeScale = applyTreeScale,
		getGrowthScale = treeVisualController.getGrowthScale,
		startGrowthAnimation = treeGrowthController.startGrowthAnimation,
		playReadyBounce = treeGrowthController.playReadyBounce,
		scheduleReadyTransition = treeGrowthController.scheduleReadyTransition,
		pushStateUpdate = pushStateUpdate,
		getServerNow = getServerNow,
		grownState = treeConstants.PlotState.Grown,
	})
	treeProgressionResolver = treeProgressionResolverModule.create({
		failureReasons = treeConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAssignedPlot = function(player, plotId)
			return treePlotService.getAssignedPlot(player, plotId)
		end,
		getTreePlot = function(player, plotId)
			return playerData.getTreePlot(player, plotId)
		end,
		getTreePlots = function(player)
			return playerData.getTreePlots(player)
		end,
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
			playUnlockButtonSuccessTween(getRuntimePlotState(player, plotId))
		end,
		materializePlot = materializePlot,
		updatePromptForPlot = updatePromptForPlot,
		refreshUnlockButtons = refreshUnlockButtons,
		pushStateUpdate = pushStateUpdate,
		buildStatePayload = buildStatePayload,
		buildFailure = function(reason)
			return serviceResult.failure(reason, treeConstants.getFailureMessage)
		end,
		buildSuccess = serviceResult.success,
		getServerNow = getServerNow,
		growingState = treeConstants.PlotState.Growing,
	})
	attemptUnlock = treeProgressionResolver.attemptUnlock
	treeHitController = treeHitControllerModule.create({
		constants = {
			HitDistance = TREE_HIT_DISTANCE,
			HitCooldownSeconds = HIT_COOLDOWN_SECONDS,
			HitSoundId = TREE_HIT_SOUND_ID,
			DeathSoundId = TREE_DEATH_SOUND_ID,
			HarvestRespawnDelay = TREE_HARVEST_RESPAWN_DELAY,
		},
		isPlayerLoaded = playerData.isLoaded,
		getAssignedPlot = function(player, plotId)
			return treePlotService.getAssignedPlot(player, plotId)
		end,
		getTreePlot = function(player, plotId)
			return playerData.getTreePlot(player, plotId)
		end,
		getCharacterRootPart = getCharacterRootPart,
		getEquippedAxeTool = getEquippedAxeTool,
		getRuntimePlotState = getRuntimePlotState,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getLevelData = treeConfig.getLevelData,
		getToolStatValue = getToolStatValue,
		emitTreeParticles = treeVisualController.emitTreeParticles,
		playTreeSound = treeVisualController.playTreeSound,
		applyTreeScale = function(runtimePlotState, plotRecord, scale)
			return treeVisualController.applyTreeScale(runtimePlotState, plotRecord, scale)
		end,
		getHarvestScale = treeVisualController.getHarvestScale,
		getGold = playerData.getGold,
		setGold = playerData.setGold,
		refreshUnlockButtons = refreshUnlockButtons,
		applyTreeVisual = treeVisualController.applyTreeVisual,
		setTreePlot = playerData.setTreePlot,
		updatePromptForPlot = updatePromptForPlot,
		pushHitFeedback = pushHitFeedback,
		pushStateUpdate = pushStateUpdate,
		materializePlot = materializePlot,
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
		setAllSurfacesStuds = setAllSurfacesStuds,
		getHorizontalDirection = getHorizontalDirection,
		getPartExtentAlongDirection = getPartExtentAlongDirection,
		getAssignedPlot = function(player, plotId)
			return treePlotService.getAssignedPlot(player, plotId)
		end,
		getAssignedPlotSet = function(player)
			return treePlotService.getAssignedPlotSet(player)
		end,
		getTreePlot = function(player, plotId)
			return playerData.getTreePlot(player, plotId)
		end,
		getTreePlots = function(player)
			return playerData.getTreePlots(player)
		end,
		getGold = function(player)
			return playerData.getGold(player)
		end,
		getTreeByPlotId = treeConfig.getTreeByPlotId,
		getRuntimePlotState = getRuntimePlotState,
		getTouchingPlayer = getTouchingPlayer,
		attemptUnlock = function(player, plotId)
			return attemptUnlock(player, plotId)
		end,
		isPlotUnlockable = treeStateBuilder.isPlotUnlockable,
	})

	getOrCreateRuntimeFolder()

	local treesFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local remotes = remoteRegistry.getOrCreateNamedChildren(treesFolder, {
		{
			Name = treeConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
		{
			Name = treeConstants.REQUEST_HIT_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
		{
			Name = treeConstants.REQUEST_UPGRADE_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
		{
			Name = treeConstants.STATE_UPDATED_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
		{
			Name = treeConstants.HIT_FEEDBACK_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
	})
	getTreeStateRemote = remotes[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	requestTreeHitRemote = remotes[treeConstants.REQUEST_HIT_REMOTE_NAME] :: RemoteEvent
	requestTreeUpgradeRemote = remotes[treeConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteEvent
	treeStateUpdatedRemote = remotes[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent
	treeHitFeedbackRemote = remotes[treeConstants.HIT_FEEDBACK_REMOTE_NAME] :: RemoteEvent

	local handlers = treeRemoteHandlers.create({
		getTreePlot = function(player, plotId)
			return playerData.getTreePlot(player, plotId)
		end,
		attemptUpgrade = attemptUpgrade,
		hasAssignedPlotSet = function(player)
			return treePlotService.getAssignedPlotSet(player) ~= nil
		end,
		buildPlotNotFoundFailure = function()
			return serviceResult.failure(treeConstants.FailureReason.PlotNotFound, treeConstants.getFailureMessage)
		end,
		buildStatePayload = buildStatePayload,
		processTreeHit = processTreeHit,
	})

	treeRemoteHandlers.bind({
		GetTreeStateRemote = getTreeStateRemote,
		RequestTreeHitRemote = requestTreeHitRemote,
		RequestTreeUpgradeRemote = requestTreeUpgradeRemote,
	}, handlers)

	if axeService == nil then
		warn("TreeService started without AxeService")
	end
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

	cleanupPlayerRuntime(player)
	treeRuntimeManager.setPlotSetId(player, plotSet.Id)
	return refreshAllAssignedPlots(player)
end

function TreeService.onPlayerRemoving(player)
	cleanupPlayerRuntime(player)
	treePlotService.releasePlayer(player)
end

function TreeService.onPlayerDataReset(player)
	if not playerData.isLoaded(player) then
		return false
	end

	cleanupPlayerRuntime(player)
	treeRuntimeManager.setPlotSetId(player, treePlotService.getAssignedPlotSetId(player))
	return refreshAllAssignedPlots(player)
end

return TreeService
