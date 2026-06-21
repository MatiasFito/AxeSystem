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

local runtimeFolder = nil
local getTreeStateRemote = nil
local requestTreeHitRemote = nil
local requestTreeUpgradeRemote = nil
local treeStateUpdatedRemote = nil
local treeHitFeedbackRemote = nil

local runtimeByPlayer = {}
local attemptUnlock = nil
local unlockPromptManager = nil
local treeVisualController = nil
local treeGrowthController = nil

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
	local runtimeState = runtimeByPlayer[player]

	if not runtimeState then
		return nil
	end

	return runtimeState.Plots[plotId]
end

local function getServerNow()
	return Workspace:GetServerTimeNow()
end

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

local function getTreeTemplatesFolder()
	return ServerStorage:FindFirstChild(treeConstants.TREE_TEMPLATE_FOLDER_NAME)
end

local function getOrCreateRuntimeFolder()
	if runtimeFolder and runtimeFolder.Parent == Workspace then
		return runtimeFolder
	end

	runtimeFolder = getOrCreateChild(Workspace, treeConstants.TREE_RUNTIME_FOLDER_NAME, "Folder")
	return runtimeFolder
end

local function getOrCreateSetRuntimeFolder(plotSetId)
	return getOrCreateChild(getOrCreateRuntimeFolder(), plotSetId, "Folder")
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

local function getRuntimePlayerState(player)
	local runtimeState = runtimeByPlayer[player]

	if runtimeState then
		return runtimeState
	end

	local plotSetId = treePlotService.getAssignedPlotSetId(player)

	runtimeState = {
		PlotSetId = plotSetId,
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

local function emitTreeParticles(treeInstance, particleCount, sourcePosition)
	treeVisualController.emitTreeParticles(treeInstance, particleCount, sourcePosition)
end

local function playTreeSound(treeInstance, soundId, volume)
	treeVisualController.playTreeSound(treeInstance, soundId, volume)
end

local function captureTreeVisualState(runtimePlotState, treeInstance)
	treeVisualController.captureTreeVisualState(runtimePlotState, treeInstance)
end

local function applyTreeVisual(runtimePlotState, plotRecord, scale, pivotOverride, transparencyAlpha, shouldAlignBottom)
	return treeVisualController.applyTreeVisual(
		runtimePlotState,
		plotRecord,
		scale,
		pivotOverride,
		transparencyAlpha,
		shouldAlignBottom
	)
end

local function applyTreeScale(runtimePlotState, plotRecord, scale)
	return treeVisualController.applyTreeScale(runtimePlotState, plotRecord, scale)
end

local function getGrowthScale(progress)
	return treeVisualController.getGrowthScale(progress)
end

local function getHarvestScale(currentHealth, maxHealth)
	return treeVisualController.getHarvestScale(currentHealth, maxHealth)
end

local function startGrowthAnimation(player, plotId, growingUntil, growTime)
	treeGrowthController.startGrowthAnimation(player, plotId, growingUntil, growTime)
end

local function playReadyBounce(player, plotId)
	treeGrowthController.playReadyBounce(player, plotId)
end

local function scheduleReadyTransition(player, plotId, growingUntil, onReady)
	treeGrowthController.scheduleReadyTransition(player, plotId, growingUntil, onReady)
end

local function spawnTreeForPlot(player, plotId, initialScale)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)

	if not plotRecord or not plotState then
		return false
	end

	local tree = treeConfig.getTree(plotState.TreeId)
	local levelData = tree and treeConfig.getLevelData(tree.Id, plotState.Level) or nil
	local templatesFolder = getTreeTemplatesFolder()

	if not tree or not levelData or not templatesFolder then
		return false
	end

	local template = templatesFolder:FindFirstChild(tree.TemplateName)

	if not template then
		warn(string.format("Missing tree template '%s'", tree.TemplateName))
		return false
	end

	destroySpawnedTree(runtimePlotState)

	local clone = template:Clone()
	clone.Name = string.format("%s_%s", plotRecord.PlotSetId, plotId)
	clone:SetAttribute(treeConstants.IS_MANAGED_TREE_ATTRIBUTE, true)
	clone:SetAttribute(treeConstants.TREE_ID_ATTRIBUTE, tree.Id)
	clone:SetAttribute(treeConstants.TREE_PLOT_ID_ATTRIBUTE, plotId)

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute(treeConstants.IS_MANAGED_TREE_ATTRIBUTE, true)
			descendant:SetAttribute(treeConstants.TREE_ID_ATTRIBUTE, tree.Id)
			descendant:SetAttribute(treeConstants.TREE_PLOT_ID_ATTRIBUTE, plotId)
		end
	end

	clone.Parent = getOrCreateSetRuntimeFolder(plotRecord.PlotSetId)

	local spawnCFrame = getSpawnCFrame(plotRecord.TreeSpawn)

	if clone:IsA("Model") then
		clone:PivotTo(spawnCFrame)
		alignCloneBottomToPlot(clone, plotRecord)
	elseif clone:IsA("BasePart") then
		clone.CFrame = spawnCFrame
		alignCloneBottomToPlot(clone, plotRecord)
	end

	captureTreeVisualState(runtimePlotState, clone)
	runtimePlotState.SpawnedTreeModel = clone
	runtimePlotState.CurrentHealth = levelData.Health
	runtimePlotState.FullHealth = levelData.Health
	applyTreeScale(runtimePlotState, plotRecord, initialScale or 1)
	return true
end

local function materializePlot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)

	if not plotState then
		return
	end

	clearScheduledReady(runtimePlotState)

	if not plotState.Unlocked then
		destroySpawnedTree(runtimePlotState)
		updatePromptForPlot(player, plotId)
		return
	end

	if plotState.State == treeConstants.PlotState.Grown then
		spawnTreeForPlot(player, plotId, 1)
		updatePromptForPlot(player, plotId)
		return
	end

	destroySpawnedTree(runtimePlotState)

	local tree = treeConfig.getTree(plotState.TreeId)
	local levelData = tree and treeConfig.getLevelData(tree.Id, plotState.Level) or nil

	if not tree or not levelData then
		return
	end

	local growingUntil = plotState.GrowingUntil or getServerNow()

	if growingUntil <= getServerNow() then
		local updatedPlotState = {
			PlotId = plotState.PlotId,
			TreeId = plotState.TreeId,
			Unlocked = true,
			Level = plotState.Level,
			State = treeConstants.PlotState.Grown,
			GrowingUntil = nil,
		}

		playerData.setTreePlot(player, plotId, updatedPlotState)
		spawnTreeForPlot(player, plotId, 1)
		playReadyBounce(player, plotId)
		updatePromptForPlot(player, plotId)
		pushStateUpdate(player, { plotId })
		return
	end

	local remaining = math.max(0, growingUntil - getServerNow())
	local initialProgress = math.clamp(1 - (remaining / math.max(0.01, levelData.GrowTime)), 0, 1)
	spawnTreeForPlot(player, plotId, getGrowthScale(initialProgress))
	startGrowthAnimation(player, plotId, growingUntil, levelData.GrowTime)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)

	updatePromptForPlot(player, plotId)

	scheduleReadyTransition(player, plotId, growingUntil, function(latestPlotState)
		playerData.setTreePlot(player, plotId, {
			PlotId = latestPlotState.PlotId,
			TreeId = latestPlotState.TreeId,
			Unlocked = true,
			Level = latestPlotState.Level,
			State = treeConstants.PlotState.Grown,
			GrowingUntil = nil,
		})

		applyTreeScale(runtimePlotState, plotRecord, 1)
		playReadyBounce(player, plotId)
		updatePromptForPlot(player, plotId)
		pushStateUpdate(player, { plotId })
	end)
end

local function refreshAllAssignedPlots(player)
	local plotSet = treePlotService.getAssignedPlotSet(player)

	if not plotSet then
		return false
	end

	for _, plotId in plotSet.OrderedPlotIds do
		materializePlot(player, plotId)
	end

	pushStateUpdate(player)
	return true
end

local function cleanupPlayerRuntime(player)
	local runtimeState = runtimeByPlayer[player]

	if not runtimeState then
		return
	end

	for _, runtimePlotState in runtimeState.Plots do
		clearScheduledReady(runtimePlotState)
		destroySpawnedTree(runtimePlotState)
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

attemptUnlock = function(player, plotId)
	if not playerData.isLoaded(player) then
		return serviceResult.failure(treeConstants.FailureReason.DataNotLoaded, treeConstants.getFailureMessage)
	end

	local plotRecord = treePlotService.getAssignedPlot(player, plotId)

	if not plotRecord then
		return serviceResult.failure(treeConstants.FailureReason.NotOwned, treeConstants.getFailureMessage)
	end

	local plotState = playerData.getTreePlot(player, plotId)
	local allPlots = playerData.getTreePlots(player) or {}
	local tree = treeConfig.getTreeByPlotId(plotId)
	local gold = playerData.getGold(player) or 0

	if not plotState or not tree then
		return serviceResult.failure(treeConstants.FailureReason.ConfigError, treeConstants.getFailureMessage)
	end

	if plotState.Unlocked then
		return serviceResult.failure(treeConstants.FailureReason.AlreadyUnlocked, treeConstants.getFailureMessage)
	end

	if not treeStateBuilder.isPlotUnlockable(allPlots, plotId) then
		return serviceResult.failure(treeConstants.FailureReason.NotUnlockable, treeConstants.getFailureMessage)
	end

	if gold < tree.UnlockCost then
		return serviceResult.failure(treeConstants.FailureReason.InsufficientGold, treeConstants.getFailureMessage)
	end

	local levelData = treeConfig.getLevelData(tree.Id, 1)

	if not levelData then
		return serviceResult.failure(treeConstants.FailureReason.ConfigError, treeConstants.getFailureMessage)
	end

	playerData.setGold(player, gold - tree.UnlockCost)
	playerData.setTreePlot(player, plotId, {
		PlotId = plotId,
		TreeId = tree.Id,
		Unlocked = true,
		Level = 1,
		State = treeConstants.PlotState.Growing,
		GrowingUntil = getServerNow() + levelData.GrowTime,
	})

	playUnlockButtonSuccessTween(getRuntimePlotState(player, plotId))

	materializePlot(player, plotId)

	local nextTree = treeConfig.getTreeByOrder(tree.PlotOrder + 1)
	local changedPlots = { plotId }

	if nextTree then
		updatePromptForPlot(player, nextTree.PlotId)
		table.insert(changedPlots, nextTree.PlotId)
	end

	refreshUnlockButtons(player)

	pushStateUpdate(player, changedPlots)
	return serviceResult.success(buildStatePayload(player, changedPlots).state)
end

local function attemptUpgrade(player, plotId)
	if not playerData.isLoaded(player) then
		return serviceResult.failure(treeConstants.FailureReason.DataNotLoaded, treeConstants.getFailureMessage)
	end

	if not treePlotService.getAssignedPlot(player, plotId) then
		return serviceResult.failure(treeConstants.FailureReason.NotOwned, treeConstants.getFailureMessage)
	end

	local plotState = playerData.getTreePlot(player, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)
	local gold = playerData.getGold(player) or 0

	if not plotState or not tree or not plotState.Unlocked then
		return serviceResult.failure(treeConstants.FailureReason.PlotNotFound, treeConstants.getFailureMessage)
	end

	local nextLevel = treeConfig.getUpgradeLevel(tree.Id, plotState.Level)

	if not nextLevel then
		return serviceResult.failure(treeConstants.FailureReason.AlreadyMaxed, treeConstants.getFailureMessage)
	end

	local upgradeCost = treeConfig.getUpgradeCost(tree.Id, plotState.Level)

	if not upgradeCost then
		return serviceResult.failure(treeConstants.FailureReason.ConfigError, treeConstants.getFailureMessage)
	end

	if gold < upgradeCost then
		return serviceResult.failure(treeConstants.FailureReason.InsufficientGold, treeConstants.getFailureMessage)
	end

	local nextLevelData = treeConfig.getLevelData(tree.Id, nextLevel)

	if not nextLevelData then
		return serviceResult.failure(treeConstants.FailureReason.ConfigError, treeConstants.getFailureMessage)
	end

	playerData.setGold(player, gold - upgradeCost)

	local updatedPlotState = {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = true,
		Level = nextLevel,
		State = plotState.State,
		GrowingUntil = plotState.GrowingUntil,
	}

	if plotState.State == treeConstants.PlotState.Growing then
		updatedPlotState.GrowingUntil = getServerNow() + nextLevelData.GrowTime
	end

	playerData.setTreePlot(player, plotId, updatedPlotState)
	materializePlot(player, plotId)
	refreshUnlockButtons(player)
	pushStateUpdate(player, { plotId })

	return serviceResult.success(buildStatePayload(player, { plotId }).state)
end

local function resolveReward(levelData, tool)
	local goldMultiplier = getToolStatValue(tool, "GoldBonus", 1)
	return math.max(0, math.floor(levelData.Reward * goldMultiplier))
end

local function processTreeHit(player, plotId)
	if not playerData.isLoaded(player) then
		return
	end

	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)

	if not plotRecord or not plotState or plotState.State ~= treeConstants.PlotState.Grown then
		return
	end

	local rootPart = getCharacterRootPart(player)

	if not rootPart then
		return
	end

	if (rootPart.Position - plotRecord.DirtPatch.Position).Magnitude > TREE_HIT_DISTANCE then
		return
	end

	local tool = getEquippedAxeTool(player)

	if not tool then
		return
	end

	local runtimePlotState = getRuntimePlotState(player, plotId)
	local now = os.clock()

	if now - runtimePlotState.LastAcceptedHitAt < HIT_COOLDOWN_SECONDS then
		return
	end

	runtimePlotState.LastAcceptedHitAt = now

	local tree = treeConfig.getTreeByPlotId(plotId)
	local levelData = tree and treeConfig.getLevelData(tree.Id, plotState.Level) or nil

	if not tree or not levelData then
		return
	end

	if runtimePlotState.CurrentHealth == nil then
		runtimePlotState.CurrentHealth = levelData.Health
	end

	local power = math.max(1, math.floor(getToolStatValue(tool, "Power", 1)))
	local actualDamage = math.min(runtimePlotState.CurrentHealth, power)
	runtimePlotState.CurrentHealth -= actualDamage
	emitTreeParticles(
		runtimePlotState.SpawnedTreeModel,
		runtimePlotState.CurrentHealth > 0 and 10 or 16,
		rootPart.Position
	)
	playTreeSound(runtimePlotState.SpawnedTreeModel, TREE_HIT_SOUND_ID, 1.15)

	if runtimePlotState.CurrentHealth > 0 then
		applyTreeScale(runtimePlotState, plotRecord, getHarvestScale(runtimePlotState.CurrentHealth, levelData.Health))
		pushHitFeedback(player, {
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
	local currentGold = playerData.getGold(player) or 0
	local growingUntil = getServerNow() + levelData.GrowTime
	playerData.setGold(player, currentGold + reward)
	refreshUnlockButtons(player)
	runtimePlotState.CurrentHealth = 0
	applyTreeVisual(
		runtimePlotState,
		plotRecord,
		runtimePlotState.VisualScale > 0 and runtimePlotState.VisualScale or 1,
		nil,
		1,
		true
	)
	playTreeSound(runtimePlotState.SpawnedTreeModel, TREE_DEATH_SOUND_ID, 1.4)
	playerData.setTreePlot(player, plotId, {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = true,
		Level = plotState.Level,
		State = treeConstants.PlotState.Growing,
		GrowingUntil = growingUntil,
	})
	updatePromptForPlot(player, plotId)

	pushHitFeedback(player, {
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

	pushStateUpdate(player, { plotId })

	task.delay(TREE_HARVEST_RESPAWN_DELAY, function()
		local latestPlotState = playerData.getTreePlot(player, plotId)

		if latestPlotState and latestPlotState.State == treeConstants.PlotState.Growing then
			materializePlot(player, plotId)
		end
	end)
end

function TreeService.start(playerDataModule, treePlotServiceModule, axeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotService = treePlotServiceModule
	axeService = axeServiceModule
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
	getRuntimePlayerState(player).PlotSetId = plotSet.Id
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
	getRuntimePlayerState(player).PlotSetId = treePlotService.getAssignedPlotSetId(player)
	return refreshAllAssignedPlots(player)
end

return TreeService
