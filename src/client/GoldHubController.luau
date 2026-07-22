local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GoldHubUI = require(script.Parent:WaitForChild("GoldHubUI") :: ModuleScript)
local TopGoldLabelView = require(script.Parent:WaitForChild("TopGoldLabelView") :: ModuleScript)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local goldHubConstants = require(sharedFolder:WaitForChild("GoldHubConstants") :: ModuleScript)
local sessionTimeConfig = require(sharedFolder:WaitForChild("SessionTimeConfig") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local GoldHubController = {}

local REMOTE_WAIT_TIMEOUT = 10
local INITIAL_SEED_RETRY_INTERVAL = 1

local started = false
local getGoldHubStateRemote = nil
local hudTickerToken = 0
local lastResolvedState = nil
local lastResolvedStateAt = 0
local initialSeedToken = 0

local function sanitizeMultiplier(multiplier)
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function formatTotalBonusText(totalMultiplier)
	return string.format("x%.2f Total Gold", sanitizeMultiplier(totalMultiplier))
end

local function computeCurrentTotalBonusText(state)
	if typeof(state) ~= "table" then
		return formatTotalBonusText(1)
	end

	local baseSessionSeconds = state.sessionTime and state.sessionTime.sessionSeconds or 0
	local elapsedSeconds = math.max(0, math.floor(os.clock() - lastResolvedStateAt))
	local sessionMultiplier =
		sanitizeMultiplier(sessionTimeConfig.getGoldMultiplier(baseSessionSeconds + elapsedSeconds))
	local axeMultiplier = sanitizeMultiplier(state.axe and state.axe.multiplier or 1)
	local amberMultiplier = sanitizeMultiplier(state.amber and state.amber.multiplier or 1)
	local rebirthMultiplier = sanitizeMultiplier(state.rebirth and state.rebirth.multiplier or 1)
	local vipMultiplier = sanitizeMultiplier(state.passes and state.passes.vip and state.passes.vip.multiplier or 1)
	local doubleGoldMultiplier =
		sanitizeMultiplier(state.passes and state.passes.doubleGold and state.passes.doubleGold.multiplier or 1)

	return formatTotalBonusText(
		axeMultiplier * amberMultiplier * rebirthMultiplier * sessionMultiplier * vipMultiplier * doubleGoldMultiplier
	)
end

local function applyHudBonus(state)
	TopGoldLabelView.setGoldHubBonusText(computeCurrentTotalBonusText(state))
end

local function stopHudTicker()
	hudTickerToken += 1
end

local function stopInitialSeedLoop()
	initialSeedToken += 1
end

local function startHudTicker()
	stopHudTicker()
	hudTickerToken += 1
	local currentToken = hudTickerToken

	task.spawn(function()
		while currentToken == hudTickerToken do
			if typeof(lastResolvedState) ~= "table" then
				return
			end

			applyHudBonus(lastResolvedState)
			task.wait(1)
		end
	end)
end

local function applyResolvedState(state, shouldOpenModal)
	lastResolvedState = state
	lastResolvedStateAt = os.clock()
	stopInitialSeedLoop()
	applyHudBonus(state)
	startHudTicker()
	GoldHubUI.renderState(state)

	if shouldOpenModal then
		GoldHubUI.open()
	end
end

local function resolveGoldHubRemotes()
	local goldHubFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = goldHubConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Gold Hub remotes folder was not found",
		},
		{
			Name = goldHubConstants.GOLD_HUB_REMOTE_FOLDER_NAME,
			ErrorMessage = "Gold Hub remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not goldHubFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(
		goldHubFolder,
		{ goldHubConstants.GET_STATE_REMOTE_NAME },
		REMOTE_WAIT_TIMEOUT,
		"Gold Hub remote"
	)

	if not remotes then
		return false
	end

	getGoldHubStateRemote = remotes[goldHubConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	return getGoldHubStateRemote ~= nil
end

local function requestAndRenderState(shouldOpenModal, shouldShowFailure)
	if not getGoldHubStateRemote then
		if shouldShowFailure then
			GoldHubUI.showFailure(goldHubConstants.getFailureMessage(goldHubConstants.FailureReason.ConfigError))
		end
		return false
	end

	local success, payload = pcall(function()
		return getGoldHubStateRemote:InvokeServer()
	end)

	if not success or not payload then
		if shouldShowFailure then
			GoldHubUI.showFailure(goldHubConstants.getFailureMessage(goldHubConstants.FailureReason.RequestFailed))
		end
		return false
	end

	if not payload.success then
		if payload.state then
			applyResolvedState(payload.state, false)
		end

		if shouldShowFailure then
			GoldHubUI.showFailure(payload.message or goldHubConstants.getFailureMessage(payload.reason))
		end
		return false
	end

	applyResolvedState(payload.state, shouldOpenModal == true)
	return true
end

function GoldHubController.refreshState(shouldShowFailure)
	local shouldKeepModalOpen = GoldHubUI.isOpen()
	return requestAndRenderState(shouldKeepModalOpen, shouldShowFailure == true)
end

local function startInitialSeedLoop()
	if typeof(lastResolvedState) == "table" then
		return
	end

	stopInitialSeedLoop()
	initialSeedToken += 1
	local currentToken = initialSeedToken

	task.spawn(function()
		while currentToken == initialSeedToken and typeof(lastResolvedState) ~= "table" do
			if GoldHubController.refreshState(false) then
				return
			end

			task.wait(INITIAL_SEED_RETRY_INTERVAL)
		end
	end)
end

local function handleGoldHubActivated()
	if GoldHubUI.isOpen() then
		return
	end

	requestAndRenderState(true, true)
end

local function handlePurchaseRequested(passKey)
	local passId = gamePassConfig.getPassId(passKey)

	if typeof(passId) ~= "number" or passId <= 0 then
		GoldHubUI.showFailure(goldHubConstants.getFailureMessage(goldHubConstants.FailureReason.ConfigError))
		return
	end

	MarketplaceService:PromptGamePassPurchase(player, passId)
end

function GoldHubController.start()
	if started then
		return
	end

	started = true
	TopGoldLabelView.setGoldHubActivatedHandler(handleGoldHubActivated)
	GoldHubUI.setPurchaseHandler(handlePurchaseRequested)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(playerOrUserId, _passId, _wasPurchased)
		local matchesLocalPlayer = false

		if typeof(playerOrUserId) == "Instance" then
			matchesLocalPlayer = playerOrUserId == player
		elseif typeof(playerOrUserId) == "number" then
			matchesLocalPlayer = playerOrUserId == player.UserId
		end

		if not matchesLocalPlayer then
			return
		end

		GoldHubController.refreshState(false)
	end)

	if not resolveGoldHubRemotes() then
		GoldHubUI.showFailure(goldHubConstants.getFailureMessage(goldHubConstants.FailureReason.ConfigError))
		return
	end

	if not GoldHubController.refreshState(false) then
		startInitialSeedLoop()
	end
end

return GoldHubController
