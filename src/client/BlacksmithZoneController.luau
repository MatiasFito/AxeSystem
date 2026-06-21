local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local blacksmithUI = require(script.Parent:WaitForChild("BlacksmithUI"))

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local blacksmithZoneUtils = require(sharedFolder:WaitForChild("BlacksmithZoneUtils") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local POLL_INTERVAL = 0.15
local MISS_THRESHOLD = 3

local BlacksmithZoneController = {}

local started = false
local getStateRemote = nil
local requestUpgradeRemote = nil
local timeSincePoll = 0
local insideZone = false
local missCount = 0

local function resolveRemotes()
	local blacksmithFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = blacksmithConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Blacksmith remotes folder was not found",
		},
		{
			Name = blacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME,
			ErrorMessage = "Blacksmith remote folder was not found",
		},
	}, 10)

	if not blacksmithFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(blacksmithFolder, {
		blacksmithConstants.GET_STATE_REMOTE_NAME,
		blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME,
	}, 10, "Blacksmith remote")

	if not remotes then
		return false
	end

	getStateRemote = remotes[blacksmithConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	requestUpgradeRemote = remotes[blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteFunction

	return getStateRemote ~= nil and requestUpgradeRemote ~= nil
end

local function applyPayload(payload)
	if payload.success then
		blacksmithUI.renderState(payload.state)
		return
	end

	if payload.state then
		blacksmithUI.renderState(payload.state)
	end

	blacksmithUI.showFailure(payload.reason or blacksmithConstants.FailureReason.ShopUnavailable)
end

local function requestState()
	if not getStateRemote then
		return
	end

	local success, payload = pcall(function()
		return getStateRemote:InvokeServer()
	end)

	if not success then
		blacksmithUI.showFailure(blacksmithConstants.FailureReason.ShopUnavailable)
		return
	end

	applyPayload(payload)
end

function BlacksmithZoneController.refreshState()
	if not insideZone then
		return
	end

	requestState()
end

local function requestUpgrade(requestedTierId)
	if not requestUpgradeRemote or not insideZone then
		blacksmithUI.showFailure(blacksmithConstants.FailureReason.NotInRange)
		return
	end

	blacksmithUI.setBusy(true)

	local success, payload = pcall(function()
		return requestUpgradeRemote:InvokeServer(requestedTierId)
	end)

	if not success then
		blacksmithUI.showFailure(blacksmithConstants.FailureReason.ShopUnavailable)
		return
	end

	applyPayload(payload)
end

local function closeShop()
	insideZone = false
	missCount = 0
	blacksmithUI.close()
end

local function dismissShopWhileInside()
	blacksmithUI.close()
end

local function updateZoneState()
	local part = blacksmithZoneUtils.getBlacksmithPart()
	local isInZone = part ~= nil and blacksmithZoneUtils.isCharacterInZone(player.Character, part)

	if isInZone then
		missCount = 0

		if not insideZone then
			insideZone = true
			blacksmithUI.open()
			requestState()
		end

		return
	end

	if not insideZone then
		return
	end

	missCount += 1

	if missCount >= MISS_THRESHOLD then
		closeShop()
	end
end

function BlacksmithZoneController.start()
	if started then
		return
	end

	started = true

	if not resolveRemotes() then
		return
	end

	blacksmithUI.setUpgradeHandler(requestUpgrade)
	blacksmithUI.setCloseHandler(dismissShopWhileInside)

	player.CharacterAdded:Connect(function()
		closeShop()
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		timeSincePoll += deltaTime

		if timeSincePoll < POLL_INTERVAL then
			return
		end

		timeSincePoll = 0
		updateZoneState()
	end)
end

return BlacksmithZoneController
