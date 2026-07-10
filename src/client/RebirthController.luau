local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local rebirthUI = require(script.Parent:WaitForChild("RebirthUI") :: ModuleScript)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local amberShopConstants = require(sharedFolder:WaitForChild("AmberShopConstants") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local rebirthConstants = require(sharedFolder:WaitForChild("RebirthConstants") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local REMOTE_WAIT_TIMEOUT = 10

local RebirthController = {}

local started = false
local getTreeStateRemote = nil
local treeStateUpdatedRemote = nil
local getRebirthStateRemote = nil
local requestRebirthRemote = nil
local plotStatesById = {}
local amberAmount = 0
local amberGainLevel = 0

local function getMaxUnlockedPlotOrder()
	local maxUnlockedPlotOrder = 0

	for _, plotState in plotStatesById do
		if plotState.unlocked == true then
			local plotOrder = tonumber(plotState.plotOrder) or 0

			if plotOrder > maxUnlockedPlotOrder then
				maxUnlockedPlotOrder = plotOrder
			end
		end
	end

	return maxUnlockedPlotOrder
end

local function buildPreviewState(extraFields)
	local maxUnlockedPlotOrder = getMaxUnlockedPlotOrder()
	local minimumPlotOrder = rebirthConfig.MINIMUM_PLOT_ORDER
	local previewState = {
		isEligible = maxUnlockedPlotOrder >= minimumPlotOrder,
		minimumPlotOrder = minimumPlotOrder,
		maxUnlockedPlotOrder = maxUnlockedPlotOrder,
		estimatedAmber = rebirthConfig.calculateAmberReward(maxUnlockedPlotOrder, amberGainLevel),
		amber = amberAmount,
	}

	if typeof(extraFields) == "table" then
		for key, value in extraFields do
			previewState[key] = value
		end
	end

	return previewState
end

local function applyPreviewState(extraFields)
	rebirthUI.setEligibility(buildPreviewState(extraFields))
end

local function applyAmberAttribute()
	amberAmount = tonumber(player:GetAttribute(amberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME)) or 0
	applyPreviewState()
end

local function applyAmberGainLevelAttribute()
	amberGainLevel = tonumber(player:GetAttribute(amberShopConstants.PLAYER_AMBER_GAIN_LEVEL_ATTRIBUTE_NAME)) or 0
	applyPreviewState()
end

local function applyTreeState(state)
	if typeof(state) ~= "table" then
		return
	end

	for _, plotState in state.plots or {} do
		if typeof(plotState) == "table" and typeof(plotState.plotId) == "string" then
			plotStatesById[plotState.plotId] = plotState
		end
	end

	applyPreviewState()
end

local function requestInitialTreeState()
	local success, payload = pcall(function()
		return getTreeStateRemote:InvokeServer()
	end)

	if success and payload and payload.success then
		applyTreeState(payload.state)
		return
	end

	applyPreviewState({
		statusText = rebirthConstants.getFailureMessage(rebirthConstants.FailureReason.DataNotLoaded),
	})
end

local function requestInitialRebirthState()
	local success, payload = pcall(function()
		return getRebirthStateRemote:InvokeServer()
	end)

	if success and payload and payload.success and payload.state then
		amberAmount = tonumber(payload.state.amber) or 0
		amberGainLevel = tonumber(payload.state.amberGainLevel) or amberGainLevel
		applyPreviewState()
	end
end

local function resolveTreeRemotes()
	local treesFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remotes folder was not found for rebirth",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found for rebirth",
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

local function resolveRebirthRemote()
	local rebirthFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = rebirthConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Rebirth remotes folder was not found",
		},
		{
			Name = rebirthConstants.REBIRTH_REMOTE_FOLDER_NAME,
			ErrorMessage = "Rebirth remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not rebirthFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(
		rebirthFolder,
		{ rebirthConstants.GET_STATE_REMOTE_NAME, rebirthConstants.REQUEST_REMOTE_NAME },
		REMOTE_WAIT_TIMEOUT,
		"Rebirth remote"
	)

	if not remotes then
		return false
	end

	getRebirthStateRemote = remotes[rebirthConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	requestRebirthRemote = remotes[rebirthConstants.REQUEST_REMOTE_NAME] :: RemoteFunction
	return getRebirthStateRemote ~= nil and requestRebirthRemote ~= nil
end

local function handleOpenRequested(previewState)
	if previewState and previewState.isEligible == true then
		rebirthUI.openConfirm(previewState)
	end
end

local function handleConfirmRequested()
	if not requestRebirthRemote then
		rebirthUI.showFailure(rebirthConstants.getFailureMessage(rebirthConstants.FailureReason.ConfigError))
		return
	end

	rebirthUI.setBusy(true)

	local success, payload = pcall(function()
		return requestRebirthRemote:InvokeServer()
	end)

	rebirthUI.setBusy(false)

	if not success or not payload then
		rebirthUI.showFailure(rebirthConstants.getFailureMessage(rebirthConstants.FailureReason.RequestFailed))
		return
	end

	if not payload.success then
		rebirthUI.showFailure(payload.message or rebirthConstants.getFailureMessage(payload.reason))
		return
	end

	amberAmount = tonumber(payload.state and payload.state.amber) or amberAmount
	rebirthUI.closeConfirm()
	applyPreviewState()
	plotStatesById = {}
	requestInitialTreeState()
end

function RebirthController.start()
	if started then
		return
	end

	started = true
	rebirthUI.setOpenHandler(handleOpenRequested)
	rebirthUI.setConfirmHandler(handleConfirmRequested)
	applyPreviewState()
	applyAmberAttribute()
	applyAmberGainLevelAttribute()
	player:GetAttributeChangedSignal(amberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME):Connect(applyAmberAttribute)
	player
		:GetAttributeChangedSignal(amberShopConstants.PLAYER_AMBER_GAIN_LEVEL_ATTRIBUTE_NAME)
		:Connect(applyAmberGainLevelAttribute)

	if not resolveTreeRemotes() or not resolveRebirthRemote() then
		rebirthUI.showFailure(rebirthConstants.getFailureMessage(rebirthConstants.FailureReason.ConfigError))
		return
	end

	treeStateUpdatedRemote.OnClientEvent:Connect(applyTreeState)
	requestInitialRebirthState()
	requestInitialTreeState()
end

return RebirthController
