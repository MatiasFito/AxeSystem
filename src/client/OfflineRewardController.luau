local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local OfflineRewardUI = require(script.Parent:WaitForChild("OfflineRewardUI") :: ModuleScript)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local offlineProgressionConstants = require(sharedFolder:WaitForChild("OfflineProgressionConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local OfflineRewardController = {}

local REMOTE_WAIT_TIMEOUT = 10
local INITIAL_SEED_RETRY_INTERVAL = 1

local started = false
local offlineProgressionFolder = nil
local getOfflineRewardRemote = nil
local claimOfflineRewardRemote = nil
local doublePurchaseProcessedRemote = nil
local pendingRewardData = nil
local hasClaimed = false
local initialSeedToken = 0
local doublePurchaseConnection = nil

local function cleanupDoublePurchaseConnection()
	if doublePurchaseConnection then
		doublePurchaseConnection:Disconnect()
		doublePurchaseConnection = nil
	end
end

local function stopInitialSeedLoop()
	initialSeedToken += 1
end

local function resolveRemotes()
	offlineProgressionFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = offlineProgressionConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Remotes folder was not found",
		},
		{
			Name = offlineProgressionConstants.OFFLINE_PROGRESSION_REMOTE_FOLDER_NAME,
			ErrorMessage = "OfflineProgression remotes folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not offlineProgressionFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(offlineProgressionFolder, {
		offlineProgressionConstants.GET_REWARD_REMOTE_NAME,
		offlineProgressionConstants.CLAIM_REWARD_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Offline Progression remote")

	if not remotes then
		return false
	end

	getOfflineRewardRemote = remotes[offlineProgressionConstants.GET_REWARD_REMOTE_NAME] :: RemoteFunction
	claimOfflineRewardRemote = remotes[offlineProgressionConstants.CLAIM_REWARD_REMOTE_NAME] :: RemoteEvent
	return getOfflineRewardRemote ~= nil and claimOfflineRewardRemote ~= nil
end

local function fetchAndShowReward()
	if not getOfflineRewardRemote then
		return false
	end

	local success, rewardData = pcall(function()
		return getOfflineRewardRemote:InvokeServer()
	end)

	if not success or not rewardData then
		return false
	end

	if typeof(rewardData) ~= "table" or not rewardData.offlineGoldEarned or rewardData.offlineGoldEarned <= 0 then
		return false
	end

	pendingRewardData = rewardData
	hasClaimed = false

	OfflineRewardUI.open({
		offlineGoldEarned = rewardData.offlineGoldEarned,
		offlineSeconds = rewardData.offlineSeconds,
		offlineCapSeconds = rewardData.offlineCapSeconds,
		totalGps = rewardData.totalGps,
	})

	return true
end

local function startInitialSeedLoop()
	stopInitialSeedLoop()
	initialSeedToken += 1
	local currentToken = initialSeedToken

	task.spawn(function()
		while currentToken == initialSeedToken do
			if fetchAndShowReward() then
				return
			end

			task.wait(INITIAL_SEED_RETRY_INTERVAL)
		end
	end)
end

local function handleCollect()
	if hasClaimed or not pendingRewardData then
		return
	end

	hasClaimed = true

	if claimOfflineRewardRemote then
		claimOfflineRewardRemote:FireServer(pendingRewardData.offlineGoldEarned)
	end

	pendingRewardData = nil
	OfflineRewardUI.close()
end

local function handleGetDouble()
	if hasClaimed or not pendingRewardData then
		return
	end

	MarketplaceService:PromptProductPurchase(player, offlineProgressionConstants.DEVELOPER_PRODUCT_ID)
end

function OfflineRewardController.start()
	if started then
		return
	end

	started = true

	OfflineRewardUI.setCollectHandler(handleCollect)
	OfflineRewardUI.setGetDoubleHandler(handleGetDouble)

	if not resolveRemotes() then
		warn("[OfflineRewardController] Failed to resolve remotes")
		return
	end

	local doubleRemote =
		offlineProgressionFolder:FindFirstChild(offlineProgressionConstants.DOUBLE_PURCHASED_REMOTE_NAME)
	if doubleRemote and doubleRemote:IsA("RemoteEvent") then
		doublePurchaseProcessedRemote = doubleRemote :: RemoteEvent
		cleanupDoublePurchaseConnection()
		doublePurchaseConnection = doublePurchaseProcessedRemote.OnClientEvent:Connect(function()
			if hasClaimed or not pendingRewardData then
				return
			end

			hasClaimed = true
			pendingRewardData = nil
			OfflineRewardUI.close()
		end)
	end

	if not fetchAndShowReward() then
		startInitialSeedLoop()
	end
end

return OfflineRewardController
