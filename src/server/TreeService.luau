local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local TreeService = {}

local PLOT_INTERACTION_DISTANCE = 14
local TREE_HIT_DISTANCE = 16
local HIT_COOLDOWN_SECONDS = 0.18
local TREE_MIN_SCALE = 0.05
local TREE_DEAD_SCALE = 0.5
local TREE_GROWTH_STEP_SECONDS = 0.05
local TREE_READY_BOUNCE_STEP_SECONDS = 0.04
local TREE_HARVEST_RESPAWN_DELAY = 0.18
local TREE_HIT_SOUND_ID = "rbxassetid://136507037003210"
local TREE_DEATH_SOUND_ID = "rbxassetid://7214256592"
local TREE_READY_BOUNCE_SCALES = { 1.08, 0.96, 1 }
local UNLOCK_BUTTON_COLOR_READY = Color3.fromRGB(255, 255, 255)
local UNLOCK_BUTTON_COLOR_LOCKED = Color3.fromRGB(126, 126, 126)
local UNLOCK_BUTTON_BASE_COLOR_READY = Color3.fromRGB(70, 145, 65)
local UNLOCK_BUTTON_BASE_COLOR_LOCKED = Color3.fromRGB(92, 92, 92)
local UNLOCK_BUTTON_TOUCH_COOLDOWN = 0.3
local UNLOCK_BUTTON_EDGE_OFFSET = 3.5
local UNLOCK_BUTTON_SCALE = 1.25

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
local updatePromptForPlot = nil
local attemptUnlock = nil

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
	runtimePlotState.ReadyTaskToken += 1
end

local function beginVisualAnimation(runtimePlotState)
	runtimePlotState.AnimationToken += 1
	return runtimePlotState.AnimationToken
end

local function destroySpawnedTree(runtimePlotState)
	beginVisualAnimation(runtimePlotState)
	runtimePlotState.VisualState = nil
	runtimePlotState.VisualScale = 1
	runtimePlotState.FullHealth = nil
	runtimePlotState.CurrentHealth = nil

	if runtimePlotState.SpawnedTreeModel and runtimePlotState.SpawnedTreeModel.Parent then
		runtimePlotState.SpawnedTreeModel:Destroy()
	end

	runtimePlotState.SpawnedTreeModel = nil
end

local function destroyUnlockButton(runtimePlotState)
	if runtimePlotState.UnlockTouchConnection then
		runtimePlotState.UnlockTouchConnection:Disconnect()
		runtimePlotState.UnlockTouchConnection = nil
	end

	if runtimePlotState.UnlockButtonModel and runtimePlotState.UnlockButtonModel.Parent then
		runtimePlotState.UnlockButtonModel:Destroy()
	end

	runtimePlotState.UnlockButtonModel = nil
	if runtimePlotState.LastUnlockTouchAt == nil then
		runtimePlotState.LastUnlockTouchAt = 0
	end
end

local function buildFailure(reason, state)
	local payload = {
		success = false,
		reason = reason,
		message = treeConstants.getFailureMessage(reason),
	}

	if state then
		payload.state = state
	end

	return payload
end

local function isPlotUnlockable(treePlots, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not tree then
		return false
	end

	if tree.PlotOrder == 1 then
		return true
	end

	local previousTree = treeConfig.getTreeByOrder(tree.PlotOrder - 1)

	if not previousTree then
		return false
	end

	local previousPlotState = treePlots[previousTree.PlotId]
	return previousPlotState ~= nil and previousPlotState.Unlocked == true
end

local function buildPlotSnapshot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not plotState or not tree then
		return nil
	end

	local levelData = nil
	local isMaxLevel = false
	local canUpgrade = false
	local upgradeCost = nil

	if plotState.Unlocked and plotState.Level > 0 then
		levelData = treeConfig.getLevelData(tree.Id, plotState.Level)
		isMaxLevel = plotState.Level >= tree.MaxLevel
		upgradeCost = treeConfig.getUpgradeCost(tree.Id, plotState.Level)
		canUpgrade = upgradeCost ~= nil
	end

	return {
		plotId = plotId,
		plotOrder = tree.PlotOrder,
		treeId = tree.Id,
		treeName = tree.Name,
		unlocked = plotState.Unlocked,
		level = plotState.Level,
		state = plotState.State,
		isUnlockable = not plotState.Unlocked and isPlotUnlockable(playerData.getTreePlots(player) or {}, plotId),
		unlockCost = tree.UnlockCost,
		canUpgrade = canUpgrade,
		upgradeCost = upgradeCost,
		isMaxLevel = isMaxLevel,
		stats = levelData and {
			health = levelData.Health,
			growTime = levelData.GrowTime,
			reward = levelData.Reward,
		} or nil,
		growingUntil = plotState.GrowingUntil,
	}
end

local function buildStatePayload(player, changedPlotIds)
	if not playerData.isLoaded(player) then
		return buildFailure(treeConstants.FailureReason.DataNotLoaded)
	end

	local plotSnapshots = {}
	local plotSetId = treePlotService.getAssignedPlotSetId(player)
	local plotIds = changedPlotIds

	if not plotIds then
		plotIds = {}

		for _, treeId in treeConfig.Order do
			table.insert(plotIds, treeConfig.ById[treeId].PlotId)
		end
	end

	for _, plotId in plotIds do
		local snapshot = buildPlotSnapshot(player, plotId)

		if snapshot then
			table.insert(plotSnapshots, snapshot)
		end
	end

	table.sort(plotSnapshots, function(left, right)
		return left.plotOrder < right.plotOrder
	end)

	return {
		success = true,
		state = {
			serverTime = getServerNow(),
			plotSetId = plotSetId,
			plots = plotSnapshots,
		},
	}
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

local function createUnlockButtonModel(plotRecord)
	local model = Instance.new("Model")
	model.Name = string.format("%sUnlockButton", plotRecord.PlotId)

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Material = Enum.Material.Plastic
	base.Anchored = true
	base.CanCollide = true
	base.CanQuery = true
	base.CanTouch = true
	base.Size = Vector3.new(0.9, 3.8, 3.8) * UNLOCK_BUTTON_SCALE
	setAllSurfacesStuds(base)
	base.Parent = model

	local button = Instance.new("Part")
	button.Name = "Button"
	button.Shape = Enum.PartType.Cylinder
	button.Material = Enum.Material.Plastic
	button.Anchored = true
	button.CanCollide = true
	button.CanQuery = true
	button.CanTouch = true
	button.Size = Vector3.new(0.75, 2.9, 2.9) * UNLOCK_BUTTON_SCALE
	setAllSurfacesStuds(button)
	button.Parent = model

	local forwardDirection = getHorizontalDirection(plotRecord.DirtPatch.CFrame.LookVector)
	local dirtPatchExtent = getPartExtentAlongDirection(plotRecord.DirtPatch, forwardDirection)
	local targetPosition = plotRecord.DirtPatch.Position
		+ forwardDirection * (dirtPatchExtent + UNLOCK_BUTTON_EDGE_OFFSET)
	local pivotCFrame = CFrame.lookAt(targetPosition, targetPosition + forwardDirection, Vector3.yAxis)
		* CFrame.Angles(0, 0, math.rad(90))
	base.CFrame = pivotCFrame
	button.CFrame = pivotCFrame * CFrame.new(0.2, 0, 0)

	local baseVerticalHalfExtent = base.Size.X * 0.5
	local dirtPatchTopY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y * 0.5)
	local yOffset = (dirtPatchTopY - baseVerticalHalfExtent) - base.Position.Y
	base.CFrame += Vector3.new(0, yOffset, 0)
	button.CFrame += Vector3.new(0, yOffset, 0)

	return model, button, base
end

local function refreshUnlockButtons(player)
	local plotSet = treePlotService.getAssignedPlotSet(player)

	if not plotSet then
		return
	end

	for _, ownedPlotId in plotSet.OrderedPlotIds do
		updatePromptForPlot(player, ownedPlotId)
	end
end

updatePromptForPlot = function(player, plotId)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)

	if not plotRecord then
		return
	end

	local plotState = playerData.getTreePlot(player, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)

	if not plotState or not tree then
		destroyUnlockButton(runtimePlotState)
		return
	end

	if not plotState.Unlocked then
		if not isPlotUnlockable(playerData.getTreePlots(player) or {}, plotId) then
			destroyUnlockButton(runtimePlotState)
			return
		end

		local buttonModel = runtimePlotState.UnlockButtonModel
		local buttonPart = buttonModel and buttonModel:FindFirstChild("Button")
		local basePart = buttonModel and buttonModel:FindFirstChild("Base")

		if not buttonModel or not buttonPart or not basePart then
			destroyUnlockButton(runtimePlotState)
			buttonModel, buttonPart, basePart = createUnlockButtonModel(plotRecord)
			buttonModel.Parent = plotRecord.Model
			runtimePlotState.UnlockButtonModel = buttonModel
			runtimePlotState.UnlockTouchConnection = buttonPart.Touched:Connect(function(hit)
				local touchingPlayer = getTouchingPlayer(hit)

				if touchingPlayer ~= player then
					return
				end

				local now = os.clock()

				if now - runtimePlotState.LastUnlockTouchAt < UNLOCK_BUTTON_TOUCH_COOLDOWN then
					return
				end

				runtimePlotState.LastUnlockTouchAt = now
				attemptUnlock(player, plotId)
			end)
		end

		local canAfford = (playerData.getGold(player) or 0) >= tree.UnlockCost
		buttonPart.Color = canAfford and UNLOCK_BUTTON_COLOR_READY or UNLOCK_BUTTON_COLOR_LOCKED
		basePart.Color = canAfford and UNLOCK_BUTTON_BASE_COLOR_READY or UNLOCK_BUTTON_BASE_COLOR_LOCKED
		return
	end

	destroyUnlockButton(runtimePlotState)
end

local function getTreeEffectPart(treeInstance)
	if not treeInstance then
		return nil
	end

	if treeInstance:IsA("BasePart") then
		return treeInstance
	end

	local trunk = treeInstance:FindFirstChild("Trunk", true)

	if trunk and trunk:IsA("BasePart") then
		return trunk
	end

	for _, descendant in treeInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function emitTreeParticles(treeInstance, particleCount)
	local effectPart = getTreeEffectPart(treeInstance)

	if not effectPart then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "TreeImpactAttachment"
	attachment.Parent = effectPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "TreeImpactParticles"
	emitter.Color = ColorSequence.new(Color3.fromRGB(196, 164, 116), Color3.fromRGB(104, 73, 46))
	emitter.Lifetime = NumberRange.new(0.18, 0.35)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 0
	emitter.LockedToPart = true
	emitter.Acceleration = Vector3.new(0, -16, 0)
	emitter.Parent = attachment
	emitter:Emit(particleCount)

	task.delay(1, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local function playTreeSound(treeInstance, soundId, volume)
	local effectPart = getTreeEffectPart(treeInstance)

	if not effectPart then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "TreeEffectSound"
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMaxDistance = 70
	sound.Parent = effectPart
	sound:Play()

	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function captureTreeVisualState(runtimePlotState, treeInstance)
	local pivot = if treeInstance:IsA("Model") then treeInstance:GetPivot() else treeInstance.CFrame
	local partStates = {}

	if treeInstance:IsA("Model") then
		for _, descendant in treeInstance:GetDescendants() do
			if descendant:IsA("BasePart") then
				local relativeCFrame = pivot:ToObjectSpace(descendant.CFrame)
				table.insert(partStates, {
					Part = descendant,
					Size = descendant.Size,
					RelativePosition = relativeCFrame.Position,
					RelativeXVector = relativeCFrame.XVector,
					RelativeYVector = relativeCFrame.YVector,
					RelativeZVector = relativeCFrame.ZVector,
				})
			end
		end
	else
		local relativeCFrame = CFrame.new()
		table.insert(partStates, {
			Part = treeInstance,
			Size = treeInstance.Size,
			RelativePosition = relativeCFrame.Position,
			RelativeXVector = relativeCFrame.XVector,
			RelativeYVector = relativeCFrame.YVector,
			RelativeZVector = relativeCFrame.ZVector,
		})
	end

	runtimePlotState.VisualState = {
		Pivot = pivot,
		PartStates = partStates,
	}
end

local function applyTreeScale(runtimePlotState, plotRecord, scale)
	local visualState = runtimePlotState.VisualState
	local treeInstance = runtimePlotState.SpawnedTreeModel

	if not visualState or not treeInstance or not treeInstance.Parent then
		return false
	end

	local clampedScale = math.max(TREE_MIN_SCALE, scale)
	local pivot = visualState.Pivot

	for _, partState in visualState.PartStates do
		local part = partState.Part

		if part and part.Parent then
			part.Size = partState.Size * clampedScale
			part.CFrame = pivot
				* CFrame.fromMatrix(
					partState.RelativePosition * clampedScale,
					partState.RelativeXVector,
					partState.RelativeYVector,
					partState.RelativeZVector
				)
		end
	end

	alignCloneBottomToPlot(treeInstance, plotRecord)
	runtimePlotState.VisualScale = clampedScale
	return true
end

local function getGrowthScale(progress)
	return TREE_MIN_SCALE + ((1 - TREE_MIN_SCALE) * math.clamp(progress, 0, 1))
end

local function getHarvestScale(currentHealth, maxHealth)
	if not maxHealth or maxHealth <= 0 then
		return 1
	end

	local healthRatio = math.clamp(currentHealth / maxHealth, 0, 1)
	return TREE_DEAD_SCALE + ((1 - TREE_DEAD_SCALE) * healthRatio)
end

local function startGrowthAnimation(player, plotId, growingUntil, growTime)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)

	if not plotRecord or not runtimePlotState.SpawnedTreeModel then
		return
	end

	local duration = math.max(0.01, growTime)
	local startTime = growingUntil - duration
	local token = beginVisualAnimation(runtimePlotState)

	task.spawn(function()
		while true do
			local activeRuntimeState = runtimeByPlayer[player]
			local activePlotState = activeRuntimeState and activeRuntimeState.Plots[plotId]
			local latestPlotState = playerData.getTreePlot(player, plotId)

			if not activePlotState or activePlotState.AnimationToken ~= token then
				return
			end

			if not latestPlotState or latestPlotState.State ~= treeConstants.PlotState.Growing then
				return
			end

			local progress = math.clamp((getServerNow() - startTime) / duration, 0, 1)
			applyTreeScale(runtimePlotState, plotRecord, getGrowthScale(progress))

			if progress >= 1 then
				return
			end

			task.wait(TREE_GROWTH_STEP_SECONDS)
		end
	end)
end

local function playReadyBounce(player, plotId)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local runtimePlotState = getRuntimePlotState(player, plotId)

	if not plotRecord or not runtimePlotState.SpawnedTreeModel then
		return
	end

	local token = beginVisualAnimation(runtimePlotState)

	task.spawn(function()
		for _, bounceScale in TREE_READY_BOUNCE_SCALES do
			local activeRuntimeState = runtimeByPlayer[player]
			local activePlotState = activeRuntimeState and activeRuntimeState.Plots[plotId]

			if not activePlotState or activePlotState.AnimationToken ~= token then
				return
			end

			applyTreeScale(runtimePlotState, plotRecord, bounceScale)
			task.wait(TREE_READY_BOUNCE_STEP_SECONDS)
		end
	end)
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

	local token = runtimePlotState.ReadyTaskToken + 1
	runtimePlotState.ReadyTaskToken = token
	updatePromptForPlot(player, plotId)

	task.delay(math.max(0, growingUntil - getServerNow()), function()
		local activeRuntimeState = runtimeByPlayer[player]
		local activePlotState = activeRuntimeState and activeRuntimeState.Plots[plotId]

		if not activePlotState or activePlotState.ReadyTaskToken ~= token then
			return
		end

		local latestPlotState = playerData.getTreePlot(player, plotId)

		if not latestPlotState or latestPlotState.State ~= treeConstants.PlotState.Growing then
			return
		end

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
		return buildFailure(treeConstants.FailureReason.DataNotLoaded)
	end

	local plotRecord = treePlotService.getAssignedPlot(player, plotId)

	if not plotRecord then
		return buildFailure(treeConstants.FailureReason.NotOwned)
	end

	local plotState = playerData.getTreePlot(player, plotId)
	local allPlots = playerData.getTreePlots(player) or {}
	local tree = treeConfig.getTreeByPlotId(plotId)
	local gold = playerData.getGold(player) or 0

	if not plotState or not tree then
		return buildFailure(treeConstants.FailureReason.ConfigError)
	end

	if plotState.Unlocked then
		return buildFailure(treeConstants.FailureReason.AlreadyUnlocked)
	end

	if not isPlotUnlockable(allPlots, plotId) then
		return buildFailure(treeConstants.FailureReason.NotUnlockable)
	end

	if gold < tree.UnlockCost then
		return buildFailure(treeConstants.FailureReason.InsufficientGold)
	end

	local levelData = treeConfig.getLevelData(tree.Id, 1)

	if not levelData then
		return buildFailure(treeConstants.FailureReason.ConfigError)
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

	materializePlot(player, plotId)

	local nextTree = treeConfig.getTreeByOrder(tree.PlotOrder + 1)
	local changedPlots = { plotId }

	if nextTree then
		updatePromptForPlot(player, nextTree.PlotId)
		table.insert(changedPlots, nextTree.PlotId)
	end

	refreshUnlockButtons(player)

	pushStateUpdate(player, changedPlots)
	return {
		success = true,
		state = buildStatePayload(player, changedPlots).state,
	}
end

local function attemptUpgrade(player, plotId)
	if not playerData.isLoaded(player) then
		return buildFailure(treeConstants.FailureReason.DataNotLoaded)
	end

	if not treePlotService.getAssignedPlot(player, plotId) then
		return buildFailure(treeConstants.FailureReason.NotOwned)
	end

	local plotState = playerData.getTreePlot(player, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)
	local gold = playerData.getGold(player) or 0

	if not plotState or not tree or not plotState.Unlocked then
		return buildFailure(treeConstants.FailureReason.PlotNotFound)
	end

	local nextLevel = treeConfig.getUpgradeLevel(tree.Id, plotState.Level)

	if not nextLevel then
		return buildFailure(treeConstants.FailureReason.AlreadyMaxed)
	end

	local upgradeCost = treeConfig.getUpgradeCost(tree.Id, plotState.Level)

	if not upgradeCost then
		return buildFailure(treeConstants.FailureReason.ConfigError)
	end

	if gold < upgradeCost then
		return buildFailure(treeConstants.FailureReason.InsufficientGold)
	end

	local nextLevelData = treeConfig.getLevelData(tree.Id, nextLevel)

	if not nextLevelData then
		return buildFailure(treeConstants.FailureReason.ConfigError)
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

	return {
		success = true,
		state = buildStatePayload(player, { plotId }).state,
	}
end

local function isPlayerNearPlot(player, plotId, maxDistance)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local rootPart = getCharacterRootPart(player)

	if not plotRecord or not rootPart then
		return false
	end

	return (rootPart.Position - plotRecord.DirtPatch.Position).Magnitude <= maxDistance
end

local function resolveReward(levelData, tool)
	local goldMultiplier = getToolStatValue(tool, "GoldBonus", 1)
	return math.max(0, math.floor(levelData.Reward * goldMultiplier))
end

local function handleTreeUpgradeRequest(player, plotId)
	if typeof(plotId) ~= "string" then
		return
	end

	if not isPlayerNearPlot(player, plotId, PLOT_INTERACTION_DISTANCE) then
		return
	end

	local plotState = playerData.getTreePlot(player, plotId)

	if not plotState or not plotState.Unlocked then
		return
	end

	attemptUpgrade(player, plotId)
end

local function handleGetState(player)
	if not treePlotService.getAssignedPlotSet(player) then
		return buildFailure(treeConstants.FailureReason.PlotNotFound)
	end

	return buildStatePayload(player)
end

local function handleTreeHit(player, plotId)
	if typeof(plotId) ~= "string" then
		return
	end

	if not playerData.isLoaded(player) then
		return
	end

	local plotRecord = treePlotService.getAssignedPlot(player, plotId)
	local plotState = playerData.getTreePlot(player, plotId)

	if not plotRecord or not plotState or plotState.State ~= treeConstants.PlotState.Grown then
		return
	end

	if not isPlayerNearPlot(player, plotId, TREE_HIT_DISTANCE) then
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
	emitTreeParticles(runtimePlotState.SpawnedTreeModel, runtimePlotState.CurrentHealth > 0 and 10 or 16)
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
	applyTreeScale(runtimePlotState, plotRecord, TREE_DEAD_SCALE)
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

	getOrCreateRuntimeFolder()

	local remotesFolder = getOrCreateChild(ReplicatedStorage, treeConstants.REMOTE_FOLDER_NAME, "Folder")
	local treesFolder = getOrCreateChild(remotesFolder, treeConstants.TREE_REMOTE_FOLDER_NAME, "Folder")
	getTreeStateRemote = getOrCreateChild(treesFolder, treeConstants.GET_STATE_REMOTE_NAME, "RemoteFunction")
	requestTreeHitRemote = getOrCreateChild(treesFolder, treeConstants.REQUEST_HIT_REMOTE_NAME, "RemoteEvent")
	requestTreeUpgradeRemote = getOrCreateChild(treesFolder, treeConstants.REQUEST_UPGRADE_REMOTE_NAME, "RemoteEvent")
	treeStateUpdatedRemote = getOrCreateChild(treesFolder, treeConstants.STATE_UPDATED_REMOTE_NAME, "RemoteEvent")
	treeHitFeedbackRemote = getOrCreateChild(treesFolder, treeConstants.HIT_FEEDBACK_REMOTE_NAME, "RemoteEvent")

	getTreeStateRemote.OnServerInvoke = handleGetState
	requestTreeHitRemote.OnServerEvent:Connect(handleTreeHit)
	requestTreeUpgradeRemote.OnServerEvent:Connect(handleTreeUpgradeRequest)

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
