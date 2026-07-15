local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local lumberjackConfig = require(sharedFolder:WaitForChild("LumberjackConfig") :: ModuleScript)
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local axeToolBuilder = require(script.Parent:WaitForChild("AxeToolBuilder") :: ModuleScript)
local lumberjackHirePromptManagerModule =
	require(script.Parent:WaitForChild("LumberjackHirePromptManager") :: ModuleScript)
local lumberjackProgressionResolverModule =
	require(script.Parent:WaitForChild("LumberjackProgressionResolver") :: ModuleScript)
local treeInteractionUtils = require(script.Parent:WaitForChild("TreeInteractionUtils") :: ModuleScript)
local treeSpatialUtils = require(script.Parent:WaitForChild("TreeSpatialUtils") :: ModuleScript)

local LumberjackService = {}

local started = false
local playerData = nil
local treePlotService = nil
local treeService = nil
local hirePromptManager = nil
local progressionResolver = nil
local runtimeFolder = nil
local runtimeByPlayer = {}
local hireRemote = nil
local upgradeRemote = nil

local PROMPT_TOUCH_COOLDOWN = 0.3
local PROMPT_EDGE_OFFSET = 3.5
local PROMPT_COLOR_READY = Color3.fromRGB(255, 255, 255)
local PROMPT_COLOR_LOCKED = Color3.fromRGB(126, 126, 126)
local PROMPT_BASE_COLOR_READY = Color3.fromRGB(70, 145, 65)
local PROMPT_BASE_COLOR_LOCKED = Color3.fromRGB(92, 92, 92)
local PROMPT_TEXT_READY = Color3.fromRGB(70, 145, 65)
local PROMPT_TEXT_LOCKED = Color3.fromRGB(126, 126, 126)
local PROMPT_TWEEN_DURATION = 0.75
local PROMPT_MIN_THICKNESS = 0.05
local REFRESH_LOOP_SECONDS = 0.35
local IDLE_LOOP_SECONDS = 0.2
local TREE_OFFSET_DISTANCE = 8
local UPGRADE_PAD_SIZE = Vector3.new(4, 0.2, 4)
local UPGRADE_PAD_SURFACE_OFFSET = 0.05
local AXE_WELD_OFFSET = CFrame.new(0, -0.6, -0.2) * CFrame.Angles(math.rad(90), 0, math.rad(90))

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
	if runtimeFolder and runtimeFolder.Parent == Workspace then
		return runtimeFolder
	end

	runtimeFolder = getOrCreateChild(Workspace, lumberjackConstants.RUNTIME_FOLDER_NAME, "Folder")
	return runtimeFolder
end

local function getOrCreateSetRuntimeFolder(plotSetId)
	return getOrCreateChild(getOrCreateRuntimeFolder(), plotSetId, "Folder")
end

local function isCollisionGroupRegistered(groupName)
	for _, groupInfo in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		if groupInfo.name == groupName then
			return true
		end
	end

	return false
end

local function ensureCollisionGroup()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(lumberjackConstants.COLLISION_GROUP_NAME)
	end)
	PhysicsService:CollisionGroupSetCollidable(lumberjackConstants.COLLISION_GROUP_NAME, "Default", false)

	if isCollisionGroupRegistered("Players") then
		PhysicsService:CollisionGroupSetCollidable(lumberjackConstants.COLLISION_GROUP_NAME, "Players", false)
	end
end

local function getRuntimePlayerState(player)
	local runtimeState = runtimeByPlayer[player]

	if runtimeState then
		return runtimeState
	end

	runtimeState = {
		PlotSetId = treePlotService.getAssignedPlotSetId(player),
		Plots = {},
		RefreshToken = 0,
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
		LumberjackModel = nil,
		UpgradePadPart = nil,
		AnimationTrack = nil,
		AnimationInstance = nil,
		AutomationToken = 0,
		IsAutomationActive = false,
		HireButtonModel = nil,
		HireTouchConnection = nil,
		HireTweenToken = 0,
		IsHireAnimating = false,
		LastHireTouchAt = 0,
		LastAxeTierId = nil,
	}
	runtimeState.Plots[plotId] = runtimePlotState
	return runtimePlotState
end

local function stopAutomation(runtimePlotState)
	runtimePlotState.AutomationToken += 1
	runtimePlotState.IsAutomationActive = false
end

local function stopAnimation(runtimePlotState)
	if runtimePlotState.AnimationTrack then
		runtimePlotState.AnimationTrack:Stop(0.05)
		runtimePlotState.AnimationTrack:Destroy()
		runtimePlotState.AnimationTrack = nil
	end

	if runtimePlotState.AnimationInstance then
		runtimePlotState.AnimationInstance:Destroy()
		runtimePlotState.AnimationInstance = nil
	end
end

local function destroyLumberjackModel(runtimePlotState)
	stopAutomation(runtimePlotState)
	stopAnimation(runtimePlotState)

	if runtimePlotState.LumberjackModel and runtimePlotState.LumberjackModel.Parent then
		runtimePlotState.LumberjackModel:Destroy()
	end

	runtimePlotState.LumberjackModel = nil
	runtimePlotState.UpgradePadPart = nil
	runtimePlotState.LastAxeTierId = nil
end

local function cleanupPlayerRuntime(player)
	local runtimeState = runtimeByPlayer[player]

	if not runtimeState then
		return
	end

	runtimeState.RefreshToken += 1

	for _, runtimePlotState in runtimeState.Plots do
		hirePromptManager.destroyHireButton(runtimePlotState)
		destroyLumberjackModel(runtimePlotState)
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

local function getTreeRemoteFolder()
	return remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
end

local function getOrCreateUpgradeRemote()
	if upgradeRemote then
		return upgradeRemote
	end

	local remotes = remoteRegistry.getOrCreateNamedChildren(getTreeRemoteFolder(), {
		{
			Name = treeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
	})

	upgradeRemote = remotes[treeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME] :: RemoteEvent
	return upgradeRemote
end

local function getOrCreateHireRemote()
	if hireRemote then
		return hireRemote
	end

	local remotes = remoteRegistry.getOrCreateNamedChildren(getTreeRemoteFolder(), {
		{
			Name = treeConstants.REQUEST_LUMBERJACK_HIRE_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
	})

	hireRemote = remotes[treeConstants.REQUEST_LUMBERJACK_HIRE_REMOTE_NAME] :: RemoteEvent
	return hireRemote
end

local function pushStateUpdate(player, changedPlotIds)
	if treeService then
		treeService.pushStateUpdate(player, changedPlotIds)
	end
end

local function getAmberUpgradeLevel(player, upgradeKey)
	if not playerData or not playerData.getAmberUpgradeLevel then
		return 0
	end

	return playerData.getAmberUpgradeLevel(player, upgradeKey) or 0
end

local function getDiscountedCost(player, baseCost)
	if typeof(baseCost) ~= "number" then
		return nil
	end

	return rebirthConfig.getReducedCost(baseCost, getAmberUpgradeLevel(player, "CostReduction"))
end

local function getHireCost(player, plotId)
	return getDiscountedCost(player, lumberjackConfig.getHireCostByPlotId(plotId))
end

local function getUpgradeCost(player, plotId, currentLevel)
	return getDiscountedCost(player, lumberjackConfig.getUpgradeCostByPlotId(plotId, currentLevel))
end

local function getLumberjackTemplate()
	local npcFolder = ServerStorage:FindFirstChild(lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME)

	if not npcFolder then
		error(
			string.format(
				"Validated Studio asset 'ServerStorage/%s' is missing at runtime",
				lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME
			)
		)
	end

	local template = npcFolder:FindFirstChild(lumberjackConstants.NPC_TEMPLATE_NAME)

	if template and template:IsA("Model") then
		return template
	end

	error(
		string.format(
			"Validated lumberjack template 'ServerStorage/%s/%s' is missing or invalid at runtime",
			lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME,
			lumberjackConstants.NPC_TEMPLATE_NAME
		)
	)
end

local function getCosmeticAxeTool(tierId)
	local tier = axeConfig.getTier(tierId) or axeConfig.getDefaultTier()

	if not tier then
		return nil, nil
	end

	local success, tool = axeToolBuilder.createCosmeticToolForTier(tier.Id)

	if success and tool and tool:IsA("Tool") then
		return tier, tool
	end

	error(
		string.format(
			"Validated axe template 'ServerStorage/%s/%s' could not be built for lumberjack cosmetics",
			blacksmithConstants.AXE_TEMPLATE_FOLDER_NAME,
			tier.ToolTemplateName
		)
	)
end

local function getPlotAnchorPosition(plotRecord)
	local spawnCFrame = treeSpatialUtils.getSpawnCFrame(plotRecord.TreeSpawn)
	local sideDirection = treeSpatialUtils.getHorizontalDirection(-plotRecord.DirtPatch.CFrame.RightVector)
	return spawnCFrame.Position + sideDirection * TREE_OFFSET_DISTANCE, sideDirection
end

local function getNpcPlacementCFrame(plotRecord)
	local targetPosition = getPlotAnchorPosition(plotRecord)

	return CFrame.lookAt(targetPosition, plotRecord.DirtPatch.Position, Vector3.yAxis)
end

local function createUpgradePadPart(plotRecord, model)
	local targetPosition = getPlotAnchorPosition(plotRecord)
	local dirtPatchTopY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y * 0.5)

	local pad = Instance.new("Part")
	pad.Name = lumberjackConstants.UPGRADE_PAD_PART_NAME
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = true
	pad.CanTouch = false
	pad.Transparency = 1
	pad.Size = UPGRADE_PAD_SIZE
	pad.CFrame = CFrame.new(targetPosition.X, dirtPatchTopY + UPGRADE_PAD_SURFACE_OFFSET, targetPosition.Z)
	pad.Parent = model
	return pad
end

local function attachCosmeticAxe(player, runtimePlotState)
	local model = runtimePlotState.LumberjackModel

	if not model then
		return
	end

	local rightHand = model:FindFirstChild("RightHand")

	if not rightHand or not rightHand:IsA("BasePart") then
		return
	end

	local gripAttachment = rightHand:FindFirstChild("RightGripAttachment")

	local existingAxe = model:FindFirstChild(lumberjackConstants.COSMETIC_AXE_NAME)

	if existingAxe then
		existingAxe:Destroy()
	end

	local tierId = playerData.getAxeTierId(player)
	local tier, cosmeticTool = getCosmeticAxeTool(tierId)

	if not tier or not cosmeticTool then
		return
	end

	cosmeticTool.Name = lumberjackConstants.COSMETIC_AXE_NAME
	local handle = cosmeticTool:FindFirstChild("Handle")

	if not handle or not handle:IsA("BasePart") then
		cosmeticTool:Destroy()
		return
	end

	for _, descendant in cosmeticTool:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.CollisionGroup = lumberjackConstants.COLLISION_GROUP_NAME
		end
	end

	if gripAttachment and gripAttachment:IsA("Attachment") then
		handle.CFrame = rightHand.CFrame * gripAttachment.CFrame * AXE_WELD_OFFSET
	else
		handle.CFrame = rightHand.CFrame * AXE_WELD_OFFSET
	end
	cosmeticTool.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = handle
	weld.Parent = handle

	runtimePlotState.LastAxeTierId = tier.Id
end

local function ensureAnimationTrack(runtimePlotState)
	local model = runtimePlotState.LumberjackModel

	if not model then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if runtimePlotState.AnimationTrack then
		return runtimePlotState.AnimationTrack
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = lumberjackConstants.SWING_ANIMATION_ID
	animation.Parent = model

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	runtimePlotState.AnimationInstance = animation
	runtimePlotState.AnimationTrack = track

	return track
end

local function playSwingAnimation(runtimePlotState)
	local track = ensureAnimationTrack(runtimePlotState)

	if not track then
		return
	end

	track:Play(0.05, 1, 1)
end

local function applyCollisionSettings(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.CanQuery = descendant.Name == lumberjackConstants.UPGRADE_PAD_PART_NAME or descendant.CanQuery
			descendant.CanTouch = descendant.Name == "HumanoidRootPart"
			descendant.Massless = descendant.Name ~= "HumanoidRootPart"
			descendant.CollisionGroup = lumberjackConstants.COLLISION_GROUP_NAME
		end
	end
end

local function getSwingOrigin(runtimePlotState, plotRecord)
	local model = runtimePlotState.LumberjackModel

	if model then
		local rightHand = model:FindFirstChild("RightHand")

		if rightHand and rightHand:IsA("BasePart") then
			return rightHand.Position
		end

		local rootPart = model:FindFirstChild("HumanoidRootPart")

		if rootPart and rootPart:IsA("BasePart") then
			return rootPart.Position
		end
	end

	return plotRecord.DirtPatch.Position
end

local function getPlayerSwingMultiplier(player)
	if not player then
		return swingSpeed.DEFAULT_MULTIPLIER
	end

	return swingSpeed.getPlayerSwingSpeedMultiplier(player)
end

local function getLumberjackSwingInterval(player)
	return swingSpeed.getEffectiveSwingDuration(
		swingSpeed.DEFAULT_BASE_SWING_DURATION,
		getPlayerSwingMultiplier(player)
	)
end

local function buildAutomationHitContext(player, plotId, runtimePlotState, plotRecord)
	local plotState = playerData.getTreePlot(player, plotId)
	local tier = axeConfig.getTier(playerData.getAxeTierId(player)) or axeConfig.getDefaultTier()
	local lumberjackLevel = plotState and plotState.LumberjackLevel or 0
	local goldMultiplier = tier and tier.GoldMultiplier or 1
	local swingInterval = getLumberjackSwingInterval(player)

	return {
		power = tier and tier.Power or 1,
		goldMultiplier = goldMultiplier * lumberjackConfig.getGoldBonusMultiplier(lumberjackLevel),
		effectOrigin = getSwingOrigin(runtimePlotState, plotRecord),
		hitCooldownSeconds = swingInterval,
		source = "lumberjack",
	}
end

local function ensureAutomationLoop(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)

	if runtimePlotState.IsAutomationActive then
		return
	end

	runtimePlotState.AutomationToken += 1
	runtimePlotState.IsAutomationActive = true
	local automationToken = runtimePlotState.AutomationToken

	task.spawn(function()
		while runtimePlotState.AutomationToken == automationToken do
			if not player.Parent then
				break
			end

			local plotRecord = treePlotService.getAssignedPlot(player, plotId)
			local plotState = playerData.getTreePlot(player, plotId)
			local hireCost = lumberjackConfig.getHireCostByPlotId(plotId)

			if
				not plotRecord
				or not plotState
				or typeof(hireCost) ~= "number"
				or not plotState.Unlocked
				or plotState.HasLumberjack ~= true
			then
				break
			end

			if plotState.State == treeConstants.PlotState.Grown then
				local swingInterval = getLumberjackSwingInterval(player)

				playSwingAnimation(runtimePlotState)
				treeService.processAutomationHit(
					player,
					plotId,
					buildAutomationHitContext(player, plotId, runtimePlotState, plotRecord)
				)
				task.wait(swingInterval)
			else
				task.wait(IDLE_LOOP_SECONDS)
			end
		end

		runtimePlotState.IsAutomationActive = false
	end)
end

local function spawnLumberjack(player, plotId)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)
	local hireCost = lumberjackConfig.getHireCostByPlotId(plotId)

	if
		not plotRecord
		or not plotState
		or typeof(hireCost) ~= "number"
		or not plotState.Unlocked
		or plotState.HasLumberjack ~= true
	then
		destroyLumberjackModel(runtimePlotState)
		return
	end

	if runtimePlotState.LumberjackModel and runtimePlotState.LumberjackModel.Parent then
		ensureAutomationLoop(player, plotId)
		return
	end

	local template = getLumberjackTemplate()

	if not template then
		return
	end

	local model = template:Clone()
	model.Name = string.format("%s%s", plotId, lumberjackConstants.MODEL_NAME_SUFFIX)
	model.Parent = getOrCreateSetRuntimeFolder(plotRecord.PlotSetId)
	model:SetAttribute(treeConstants.TREE_PLOT_ID_ATTRIBUTE, plotId)
	model:SetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE, plotRecord.PlotSetId)
	model:PivotTo(getNpcPlacementCFrame(plotRecord))
	treeSpatialUtils.alignCloneBottomToPlot(model, plotRecord)
	applyCollisionSettings(model)
	runtimePlotState.LumberjackModel = model
	runtimePlotState.UpgradePadPart = createUpgradePadPart(plotRecord, model)
	attachCosmeticAxe(player, runtimePlotState)
	ensureAutomationLoop(player, plotId)
end

local function refreshPlot(player, plotId)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)
	local hireCost = lumberjackConfig.getHireCostByPlotId(plotId)

	if not plotRecord or not plotState then
		hirePromptManager.destroyHireButton(runtimePlotState)
		destroyLumberjackModel(runtimePlotState)
		return
	end

	if typeof(hireCost) ~= "number" then
		hirePromptManager.destroyHireButton(runtimePlotState)
		destroyLumberjackModel(runtimePlotState)
		return
	end

	if plotState.Unlocked and plotState.HasLumberjack == true then
		hirePromptManager.updatePromptForPlot(player, plotId)
		spawnLumberjack(player, plotId)

		local currentTierId = playerData.getAxeTierId(player)

		if runtimePlotState.LumberjackModel and runtimePlotState.LastAxeTierId ~= currentTierId then
			attachCosmeticAxe(player, runtimePlotState)
		end

		return
	end

	destroyLumberjackModel(runtimePlotState)
	hirePromptManager.updatePromptForPlot(player, plotId)
end

local function refreshAssignedPlots(player)
	local plotSet = treePlotService.getAssignedPlotSet(player)

	if not plotSet then
		return false
	end

	for _, plotId in plotSet.OrderedPlotIds do
		refreshPlot(player, plotId)
	end

	return true
end

local function startRefreshLoop(player)
	local runtimeState = getRuntimePlayerState(player)
	runtimeState.RefreshToken += 1
	local refreshToken = runtimeState.RefreshToken

	task.spawn(function()
		while runtimeState.RefreshToken == refreshToken do
			if not player.Parent then
				break
			end

			if playerData.isLoaded(player) then
				refreshAssignedPlots(player)
			end

			task.wait(REFRESH_LOOP_SECONDS)
		end
	end)
end

local function handleUpgradeRequest(player, plotId)
	if typeof(plotId) ~= "string" then
		return
	end

	progressionResolver.attemptUpgrade(player, plotId)
end

local function handleHireRequest(player, plotId)
	if typeof(plotId) ~= "string" then
		return
	end

	progressionResolver.attemptHire(player, plotId)
end

function LumberjackService.start(playerDataModule, treePlotServiceModule, treeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotService = treePlotServiceModule
	treeService = treeServiceModule

	ensureCollisionGroup()
	getOrCreateRuntimeFolder()
	hirePromptManager = lumberjackHirePromptManagerModule.create({
		constants = {
			TouchCooldown = PROMPT_TOUCH_COOLDOWN,
			EdgeOffset = PROMPT_EDGE_OFFSET,
			ColorReady = PROMPT_COLOR_READY,
			ColorLocked = PROMPT_COLOR_LOCKED,
			BaseColorReady = PROMPT_BASE_COLOR_READY,
			BaseColorLocked = PROMPT_BASE_COLOR_LOCKED,
			TextReady = PROMPT_TEXT_READY,
			TextLocked = PROMPT_TEXT_LOCKED,
			TweenDuration = PROMPT_TWEEN_DURATION,
			MinThickness = PROMPT_MIN_THICKNESS,
		},
		getSpawnCFrame = treeSpatialUtils.getSpawnCFrame,
		getHorizontalDirection = treeSpatialUtils.getHorizontalDirection,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getAssignedPlotSet = treePlotService.getAssignedPlotSet,
		getTreePlot = playerData.getTreePlot,
		getGold = playerData.getGold,
		getButtonTemplate = function()
			local template = ServerStorage:FindFirstChild("ButtonTemplate")

			if not template or not template:IsA("Model") then
				error("Validated Studio asset 'ServerStorage/ButtonTemplate' is missing or invalid at runtime")
			end

			return template
		end,
		getRuntimePlotState = getRuntimePlotState,
		getTouchingPlayer = treeInteractionUtils.getTouchingPlayer,
		getHireCost = getHireCost,
		attemptHire = function(player, plotId)
			progressionResolver.attemptHire(player, plotId)
		end,
	})
	progressionResolver = lumberjackProgressionResolverModule.create({
		failureReasons = treeConstants.FailureReason,
		isPlayerLoaded = playerData.isLoaded,
		getAssignedPlot = treePlotService.getAssignedPlot,
		getTreePlot = playerData.getTreePlot,
		getGold = playerData.getGold,
		getHireCost = getHireCost,
		getUpgradeCost = getUpgradeCost,
		setGold = playerData.setGold,
		setTreePlot = playerData.setTreePlot,
		playHireSuccessTween = function(player, plotId)
			hirePromptManager.playHireSuccessTween(getRuntimePlotState(player, plotId))
		end,
		refreshPlot = refreshPlot,
		pushStateUpdate = pushStateUpdate,
		buildFailure = function(reason)
			return serviceResult.failure(reason, treeConstants.getFailureMessage)
		end,
		buildSuccess = serviceResult.success,
	})
	getOrCreateHireRemote().OnServerEvent:Connect(handleHireRequest)
	getOrCreateUpgradeRemote().OnServerEvent:Connect(handleUpgradeRequest)
end

function LumberjackService.onPlayerAdded(player)
	if not playerData.isLoaded(player) then
		return false
	end

	getRuntimePlayerState(player).PlotSetId = treePlotService.getAssignedPlotSetId(player)
	refreshAssignedPlots(player)
	startRefreshLoop(player)
	return true
end

function LumberjackService.onPlayerRemoving(player)
	cleanupPlayerRuntime(player)
end

function LumberjackService.onPlayerDataReset(player)
	if not playerData.isLoaded(player) then
		return false
	end

	cleanupPlayerRuntime(player)
	getRuntimePlayerState(player).PlotSetId = treePlotService.getAssignedPlotSetId(player)
	refreshAssignedPlots(player)
	startRefreshLoop(player)
	return true
end

return LumberjackService
