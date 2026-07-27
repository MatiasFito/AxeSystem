local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local DamageHubUI = require(script.Parent:WaitForChild("DamageHubUI") :: ModuleScript)
local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local damageHubConstants = require(sharedFolder:WaitForChild("DamageHubConstants") :: ModuleScript)
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local DamageHubController = {}

local STATIC_HUD_NAME = "StaticHUD"
local DAMAGE_HUB_ROOT_PATH = { STATIC_HUD_NAME, "LeftContainer", "DamageHubRoot" }
local REMOTE_WAIT_TIMEOUT = 10

local started = false
local getDamageHubStateRemote = nil
local activationTarget = nil
local playerGuiChildAddedConnection = nil
local activationConnection = nil

local function connectGuiActivated(instance, callback)
	if not instance or not callback then
		return nil
	end

	if instance:IsA("GuiButton") then
		return instance.Activated:Connect(callback)
	end

	if instance:IsA("GuiObject") then
		instance.Active = true
		return instance.InputEnded:Connect(function(inputObject)
			if
				inputObject.UserInputType == Enum.UserInputType.MouseButton1
				or inputObject.UserInputType == Enum.UserInputType.Touch
			then
				callback()
			end
		end)
	end

	return nil
end

local function bindActivator()
	if activationConnection then
		activationConnection:Disconnect()
		activationConnection = nil
	end

	local playerGui = GuiLocator.getPlayerGui()
	local root = GuiLocator.findPath(DAMAGE_HUB_ROOT_PATH)
	local existingGui = root and root:FindFirstAncestorWhichIsA("ScreenGui") or nil

	if not root or not existingGui or existingGui.Name ~= STATIC_HUD_NAME then
		activationTarget = nil

		if not playerGuiChildAddedConnection then
			playerGuiChildAddedConnection = playerGui.ChildAdded:Connect(function(child)
				if child.Name == STATIC_HUD_NAME and child:IsA("ScreenGui") then
					bindActivator()
				end
			end)
		end

		return
	end

	activationTarget = root

	if playerGuiChildAddedConnection then
		playerGuiChildAddedConnection:Disconnect()
		playerGuiChildAddedConnection = nil
	end

	activationConnection = connectGuiActivated(activationTarget, function()
		DamageHubController.open()
	end)
end

local function resolveDamageHubRemotes()
	local damageHubFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = damageHubConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Damage Hub remotes folder was not found",
		},
		{
			Name = damageHubConstants.DAMAGE_HUB_REMOTE_FOLDER_NAME,
			ErrorMessage = "Damage Hub remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not damageHubFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(
		damageHubFolder,
		{ damageHubConstants.GET_STATE_REMOTE_NAME },
		REMOTE_WAIT_TIMEOUT,
		"Damage Hub remote"
	)

	if not remotes then
		return false
	end

	getDamageHubStateRemote = remotes[damageHubConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	return getDamageHubStateRemote ~= nil
end

local function requestAndRenderState(shouldOpenModal, shouldShowFailure)
	if not getDamageHubStateRemote then
		if shouldShowFailure then
			DamageHubUI.showFailure(damageHubConstants.getFailureMessage(damageHubConstants.FailureReason.ConfigError))
		end

		return false
	end

	local success, payload = pcall(function()
		return getDamageHubStateRemote:InvokeServer()
	end)

	if not success or not payload then
		if shouldShowFailure then
			DamageHubUI.showFailure(
				damageHubConstants.getFailureMessage(damageHubConstants.FailureReason.RequestFailed)
			)
		end

		return false
	end

	if not payload.success then
		if payload.state then
			DamageHubUI.renderState(payload.state)
		end

		if shouldShowFailure then
			DamageHubUI.showFailure(payload.message or damageHubConstants.getFailureMessage(payload.reason))
		end

		return false
	end

	DamageHubUI.renderState(payload.state)

	if shouldOpenModal then
		DamageHubUI.open()
	end

	return true
end

local function handlePurchaseRequested(passKey)
	local passId = gamePassConfig.getPassId(passKey)

	if typeof(passId) ~= "number" or passId <= 0 then
		DamageHubUI.showFailure(damageHubConstants.getFailureMessage(damageHubConstants.FailureReason.ConfigError))
		return
	end

	MarketplaceService:PromptGamePassPurchase(player, passId)
end

function DamageHubController.refreshState(shouldShowFailure)
	local shouldKeepModalOpen = DamageHubUI.isOpen()
	return requestAndRenderState(shouldKeepModalOpen, shouldShowFailure == true)
end

function DamageHubController.open()
	if DamageHubUI.isOpen() then
		return
	end

	requestAndRenderState(true, true)
end

function DamageHubController.start()
	if started then
		return
	end

	started = true
	bindActivator()
	DamageHubUI.setPurchaseHandler(handlePurchaseRequested)

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

		DamageHubController.refreshState(false)
	end)

	if not resolveDamageHubRemotes() then
		DamageHubUI.showFailure(damageHubConstants.getFailureMessage(damageHubConstants.FailureReason.ConfigError))
		return
	end
end

return DamageHubController
