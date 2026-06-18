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

local started = false
local playerData = nil
local treePlotService = nil
local axeService = nil

local runtimeFolder = nil
local getTreeStateRemote = nil
local requestTreeHitRemote = nil
local treeStateUpdatedRemote = nil

local runtimeByPlayer = {}
local promptConnectionsByPlot = {}

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
		SpawnedTreeModel = nil,
		ReadyTaskToken = 0,
		LastAcceptedHitAt = 0,
	}
	runtimeState.Plots[plotId] = runtimePlotState
	return runtimePlotState
end

local function clearScheduledReady(runtimePlotState)
	runtimePlotState.ReadyTaskToken += 1
end

local function destroySpawnedTree(runtimePlotState)
	if runtimePlotState.SpawnedTreeModel and runtimePlotState.SpawnedTreeModel.Parent then
		runtimePlotState.SpawnedTreeModel:Destroy()
	end

	runtimePlotState.SpawnedTreeModel = nil
	runtimePlotState.CurrentHealth = nil
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
			serverTime = os.time(),
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

local function ensurePlotPrompt(plotRecord)
	local promptParent = plotRecord.PromptHost
	local prompt = promptParent:FindFirstChild(treeConstants.PLOT_PROMPT_NAME)

	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end

	if prompt then
		prompt:Destroy()
	end

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = treeConstants.PLOT_PROMPT_NAME
	prompt.Parent = promptParent
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = PLOT_INTERACTION_DISTANCE
	prompt.HoldDuration = 0.35
	return prompt
end

local function ensurePromptConnection(plotRecord)
	if promptConnectionsByPlot[plotRecord] then
		return
	end

	local prompt = ensurePlotPrompt(plotRecord)
	promptConnectionsByPlot[plotRecord] = prompt.Triggered:Connect(function(player)
		TreeService.handlePlotPromptTriggered(player, plotRecord.PlotId)
	end)
end

local function updatePromptForPlot(player, plotId)
	local plotRecord = treePlotService.getAssignedPlot(player, plotId)

	if not plotRecord then
		return
	end

	ensurePromptConnection(plotRecord)

	local prompt = ensurePlotPrompt(plotRecord)
	local plotState = playerData.getTreePlot(player, plotId)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not plotState or not tree then
		prompt.Enabled = false
		return
	end

	prompt.ObjectText = tree.Name

	if not plotState.Unlocked then
		if isPlotUnlockable(playerData.getTreePlots(player) or {}, plotId) then
			prompt.Enabled = true
			prompt.ActionText = string.format("Unlock (%d Gold)", tree.UnlockCost)
		else
			prompt.Enabled = false
			prompt.ActionText = "Locked"
		end
		return
	end

	local upgradeCost = treeConfig.getUpgradeCost(tree.Id, plotState.Level)

	if upgradeCost then
		prompt.Enabled = true
		prompt.ActionText = string.format("Upgrade (%d Gold)", upgradeCost)
		return
	end

	prompt.Enabled = false
	prompt.ActionText = "Max Level"
end

local function spawnTreeForPlot(player, plotId)
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

	runtimePlotState.SpawnedTreeModel = clone
	runtimePlotState.CurrentHealth = levelData.Health
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
		spawnTreeForPlot(player, plotId)
		updatePromptForPlot(player, plotId)
		return
	end

	destroySpawnedTree(runtimePlotState)

	local growingUntil = plotState.GrowingUntil or os.time()

	if growingUntil <= os.time() then
		local updatedPlotState = {
			PlotId = plotState.PlotId,
			TreeId = plotState.TreeId,
			Unlocked = true,
			Level = plotState.Level,
			State = treeConstants.PlotState.Grown,
			GrowingUntil = nil,
		}

		playerData.setTreePlot(player, plotId, updatedPlotState)
		spawnTreeForPlot(player, plotId)
		updatePromptForPlot(player, plotId)
		pushStateUpdate(player, { plotId })
		return
	end

	local token = runtimePlotState.ReadyTaskToken + 1
	runtimePlotState.ReadyTaskToken = token
	updatePromptForPlot(player, plotId)

	task.delay(growingUntil - os.time(), function()
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

		spawnTreeForPlot(player, plotId)
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

local function attemptUnlock(player, plotId)
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
		GrowingUntil = os.time() + levelData.GrowTime,
	})

	materializePlot(player, plotId)

	local nextTree = treeConfig.getTreeByOrder(tree.PlotOrder + 1)
	local changedPlots = { plotId }

	if nextTree then
		updatePromptForPlot(player, nextTree.PlotId)
		table.insert(changedPlots, nextTree.PlotId)
	end

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
		updatedPlotState.GrowingUntil = os.time() + nextLevelData.GrowTime
	end

	playerData.setTreePlot(player, plotId, updatedPlotState)
	materializePlot(player, plotId)
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
	runtimePlotState.CurrentHealth -= power

	if runtimePlotState.CurrentHealth > 0 then
		return
	end

	local reward = resolveReward(levelData, tool)
	local currentGold = playerData.getGold(player) or 0
	playerData.setGold(player, currentGold + reward)

	destroySpawnedTree(runtimePlotState)
	playerData.setTreePlot(player, plotId, {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = true,
		Level = plotState.Level,
		State = treeConstants.PlotState.Growing,
		GrowingUntil = os.time() + levelData.GrowTime,
	})

	materializePlot(player, plotId)
	pushStateUpdate(player, { plotId })
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
	treeStateUpdatedRemote = getOrCreateChild(treesFolder, treeConstants.STATE_UPDATED_REMOTE_NAME, "RemoteEvent")

	getTreeStateRemote.OnServerInvoke = handleGetState
	requestTreeHitRemote.OnServerEvent:Connect(handleTreeHit)

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

function TreeService.handlePlotPromptTriggered(player, plotId)
	if typeof(plotId) ~= "string" then
		return buildFailure(treeConstants.FailureReason.PlotNotFound)
	end

	if not isPlayerNearPlot(player, plotId, PLOT_INTERACTION_DISTANCE) then
		return buildFailure(treeConstants.FailureReason.NotInRange)
	end

	local plotState = playerData.getTreePlot(player, plotId)

	if not plotState then
		return buildFailure(treeConstants.FailureReason.PlotNotFound)
	end

	if not plotState.Unlocked then
		return attemptUnlock(player, plotId)
	end

	return attemptUpgrade(player, plotId)
end

return TreeService
