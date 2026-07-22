local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local amberShopUI = require(script.Parent:WaitForChild("AmberShopUI") :: ModuleScript)
local GoldHubController = require(script.Parent:WaitForChild("GoldHubController") :: ModuleScript)
local TopGoldLabelView = require(script.Parent:WaitForChild("TopGoldLabelView") :: ModuleScript)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local amberShopConstants = require(sharedFolder:WaitForChild("AmberShopConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local AmberShopController = {}

local REMOTE_WAIT_TIMEOUT = 10

local started = false
local getAmberShopStateRemote = nil
local buyAmberUpgradeRemote = nil

local function applyAmberAttribute()
	TopGoldLabelView.setAmber(player:GetAttribute(amberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME))
end

local function resolveAmberShopRemotes()
	local amberShopFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = amberShopConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Amber shop remotes folder was not found",
		},
		{
			Name = amberShopConstants.AMBER_SHOP_REMOTE_FOLDER_NAME,
			ErrorMessage = "Amber shop remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not amberShopFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(
		amberShopFolder,
		{ amberShopConstants.GET_STATE_REMOTE_NAME, amberShopConstants.BUY_UPGRADE_REMOTE_NAME },
		REMOTE_WAIT_TIMEOUT,
		"Amber shop remote"
	)

	if not remotes then
		return false
	end

	getAmberShopStateRemote = remotes[amberShopConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	buyAmberUpgradeRemote = remotes[amberShopConstants.BUY_UPGRADE_REMOTE_NAME] :: RemoteFunction
	return getAmberShopStateRemote ~= nil and buyAmberUpgradeRemote ~= nil
end

local function requestAndRenderState()
	if not getAmberShopStateRemote then
		amberShopUI.showFailure(amberShopConstants.getFailureMessage(amberShopConstants.FailureReason.ConfigError))
		return
	end

	local success, payload = pcall(function()
		return getAmberShopStateRemote:InvokeServer()
	end)

	if not success or not payload then
		amberShopUI.showFailure(amberShopConstants.getFailureMessage(amberShopConstants.FailureReason.RequestFailed))
		return
	end

	if not payload.success then
		if payload.state then
			amberShopUI.renderState(payload.state)
		end
		amberShopUI.showFailure(payload.message or amberShopConstants.getFailureMessage(payload.reason))
		return
	end

	amberShopUI.renderState(payload.state)
	applyAmberAttribute()
	amberShopUI.open()
end

local function handleUpgradeRequested(upgradeKey)
	if not buyAmberUpgradeRemote then
		amberShopUI.showFailure(amberShopConstants.getFailureMessage(amberShopConstants.FailureReason.ConfigError))
		return
	end

	amberShopUI.setBusy(upgradeKey, true)

	local success, payload = pcall(function()
		return buyAmberUpgradeRemote:InvokeServer(upgradeKey)
	end)

	if not success or not payload then
		amberShopUI.showFailure(amberShopConstants.getFailureMessage(amberShopConstants.FailureReason.RequestFailed))
		return
	end

	if payload.state then
		amberShopUI.renderState(payload.state)
	else
		amberShopUI.setBusy(upgradeKey, false)
	end

	if not payload.success then
		amberShopUI.showFailure(payload.message or amberShopConstants.getFailureMessage(payload.reason))
		return
	end

	applyAmberAttribute()
	GoldHubController.refreshState(false)
	amberShopUI.open()
end

local function handleAmberCounterActivated()
	if amberShopUI.isOpen() then
		amberShopUI.close()
		return
	end

	requestAndRenderState()
end

function AmberShopController.start()
	if started then
		return
	end

	started = true
	TopGoldLabelView.mount(player)
	TopGoldLabelView.setAmberActivatedHandler(handleAmberCounterActivated)
	amberShopUI.setUpgradeHandler(handleUpgradeRequested)
	amberShopUI.setCloseHandler(function()
		amberShopUI.close()
	end)

	applyAmberAttribute()
	player:GetAttributeChangedSignal(amberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME):Connect(applyAmberAttribute)

	if not resolveAmberShopRemotes() then
		amberShopUI.showFailure(amberShopConstants.getFailureMessage(amberShopConstants.FailureReason.ConfigError))
		return
	end
end

return AmberShopController
