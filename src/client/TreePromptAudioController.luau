local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameFeelConfig = require(sharedFolder:WaitForChild("GameFeelConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local leaderstatsWatcher = require(utilsFolder:WaitForChild("LeaderstatsWatcher") :: ModuleScript)
local localSoundPlayer = require(utilsFolder:WaitForChild("LocalSoundPlayer") :: ModuleScript)
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local TreePromptAudioController = {}

local REMOTE_WAIT_TIMEOUT = 10
local REFRESH_RATE = 0.1
local TOUCH_SOUND_COOLDOWN = 0.3
local UNLOCK_BUTTON_NAME_SUFFIX = "UnlockButton"
local HIRE_BUTTON_NAME_SUFFIX = "LumberjackHireButton"

local started = false
local getTreeStateRemote = nil
local treeStateUpdatedRemote = nil
local disconnectLeaderstatsWatcher = nil
local plotSetId = nil
local goldAmount = 0
local plotStatesById = {}
local promptConnectionsByKey = {}
local promptPartsByKey = {}
local lastTouchAtByKey = {}
local lastRefreshAt = 0

local function playPromptSuccessSound()
	localSoundPlayer.playOneShot(
		"TreePromptSuccess",
		gameFeelConfig.TreePromptSuccessSoundId,
		gameFeelConfig.TreePromptSuccessSoundVolume,
		1,
		2
	)
end

local function disconnectPrompt(key)
	local connection = promptConnectionsByKey[key]

	if connection then
		connection:Disconnect()
		promptConnectionsByKey[key] = nil
	end

	promptPartsByKey[key] = nil
	lastTouchAtByKey[key] = nil
end

local function disconnectAllPrompts()
	for key in promptConnectionsByKey do
		disconnectPrompt(key)
	end
end

local function getOwnedPlotSetFolder()
	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		return nil
	end

	local plotSetsFolder = Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)

	if not plotSetsFolder then
		return nil
	end

	return plotSetsFolder:FindFirstChild(plotSetId)
end

local function getPlotModel(plotId)
	local plotSetFolder = getOwnedPlotSetFolder()

	if not plotSetFolder or typeof(plotId) ~= "string" then
		return nil
	end

	local generatedFolder = plotSetFolder:FindFirstChild(treeConstants.TREE_PLOT_GENERATED_FOLDER_NAME)

	if generatedFolder and generatedFolder:IsA("Folder") then
		return generatedFolder:FindFirstChild(plotId)
	end

	return plotSetFolder:FindFirstChild(plotId)
end

local function getPromptButtonPart(plotId, modelNameSuffix)
	local plotModel = getPlotModel(plotId)

	if not plotModel then
		return nil
	end

	local promptModel = plotModel:FindFirstChild(string.format("%s%s", plotId, modelNameSuffix))

	if not promptModel then
		return nil
	end

	local buttonPart = promptModel:FindFirstChild("Button")

	if buttonPart and buttonPart:IsA("BasePart") then
		return buttonPart
	end

	return nil
end

local function isTouchFromLocalCharacter(hit)
	local character = player.Character

	if not character or not hit then
		return false
	end

	return hit:IsDescendantOf(character)
end

local function connectPrompt(key, buttonPart, shouldPlay)
	if promptPartsByKey[key] == buttonPart and promptConnectionsByKey[key] ~= nil then
		return
	end

	disconnectPrompt(key)
	promptPartsByKey[key] = buttonPart
	promptConnectionsByKey[key] = buttonPart.Touched:Connect(function(hit)
		if not isTouchFromLocalCharacter(hit) then
			return
		end

		if not shouldPlay() then
			return
		end

		local now = os.clock()
		local lastTouchAt = lastTouchAtByKey[key] or 0

		if now - lastTouchAt < TOUCH_SOUND_COOLDOWN then
			return
		end

		lastTouchAtByKey[key] = now
		playPromptSuccessSound()
	end)
end

local function refreshPromptConnections()
	local trackedKeys = {}

	for plotId, plotState in plotStatesById do
		if plotState.unlocked ~= true and plotState.isUnlockable == true and plotState.unlockCost ~= nil then
			local unlockKey = string.format("unlock:%s", plotId)
			trackedKeys[unlockKey] = true
			local buttonPart = getPromptButtonPart(plotId, UNLOCK_BUTTON_NAME_SUFFIX)

			if buttonPart then
				connectPrompt(unlockKey, buttonPart, function()
					local latestPlotState = plotStatesById[plotId]
					return latestPlotState ~= nil
						and latestPlotState.unlocked ~= true
						and latestPlotState.isUnlockable == true
						and latestPlotState.unlockCost ~= nil
						and goldAmount >= latestPlotState.unlockCost
				end)
			else
				disconnectPrompt(unlockKey)
			end
		end

		if plotState.canHireLumberjack == true and plotState.lumberjackHireCost ~= nil then
			local hireKey = string.format("hire:%s", plotId)
			trackedKeys[hireKey] = true
			local buttonPart = getPromptButtonPart(plotId, HIRE_BUTTON_NAME_SUFFIX)

			if buttonPart then
				connectPrompt(hireKey, buttonPart, function()
					local latestPlotState = plotStatesById[plotId]
					return latestPlotState ~= nil
						and latestPlotState.canHireLumberjack == true
						and latestPlotState.lumberjackHireCost ~= nil
						and goldAmount >= latestPlotState.lumberjackHireCost
				end)
			else
				disconnectPrompt(hireKey)
			end
		end
	end

	for key in promptConnectionsByKey do
		if trackedKeys[key] ~= true then
			disconnectPrompt(key)
		end
	end
end

local function applyState(state)
	if typeof(state) ~= "table" then
		return
	end

	if typeof(state.plotSetId) == "string" and state.plotSetId ~= plotSetId then
		plotSetId = state.plotSetId
		disconnectAllPrompts()
		table.clear(plotStatesById)
	end

	for _, plotState in state.plots or {} do
		plotStatesById[plotState.plotId] = plotState
	end

	refreshPromptConnections()
end

local function bindLeaderstats()
	if disconnectLeaderstatsWatcher then
		disconnectLeaderstatsWatcher()
		disconnectLeaderstatsWatcher = nil
	end

	disconnectLeaderstatsWatcher = leaderstatsWatcher.watchIntValue(player, "Gold", REMOTE_WAIT_TIMEOUT, function(value)
		goldAmount = value
		refreshPromptConnections()
	end)
end

local function resolveRemotes()
	local treesFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remotes folder was not found for prompt audio",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found for prompt audio",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(treesFolder, {
		treeConstants.GET_STATE_REMOTE_NAME,
		treeConstants.STATE_UPDATED_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Tree remote")

	if not remotes then
		return false
	end

	getTreeStateRemote = remotes[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	treeStateUpdatedRemote = remotes[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent
	return getTreeStateRemote ~= nil and treeStateUpdatedRemote ~= nil
end

local function requestInitialState()
	if not getTreeStateRemote then
		return
	end

	local success, payload = pcall(function()
		return getTreeStateRemote:InvokeServer()
	end)

	if success and payload and payload.success then
		applyState(payload.state)
	end
end

function TreePromptAudioController.start()
	if started then
		return
	end

	started = true
	localSoundPlayer.preloadOneShot("TreePromptSuccess", gameFeelConfig.TreePromptSuccessSoundId)

	if not resolveRemotes() then
		return
	end

	bindLeaderstats()
	treeStateUpdatedRemote.OnClientEvent:Connect(applyState)
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastRefreshAt >= REFRESH_RATE then
			refreshPromptConnections()
			lastRefreshAt = os.clock()
		end
	end)
	requestInitialState()
end

return TreePromptAudioController
