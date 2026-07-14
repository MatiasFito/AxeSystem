local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)

local GUI_NAME = "AutoSwingGui"
local BUTTON_NAME = "ToggleButton"
local AUTO_SWING_ATTRIBUTE_NAME = "AutoSwingHeld"

local AUTO_ON_COLOR = Color3.fromRGB(78, 168, 106)
local AUTO_OFF_COLOR = Color3.fromRGB(180, 95, 95)

local AutoSwingUI = {}

local started = false
local autoSwingEnabled = false

local screenGui = nil
local toggleButton = nil
local stateLabel = nil
local trackedTool = nil
local childAddedConnection = nil
local childRemovedConnection = nil
local playerGuiChildAddedConnection = nil
local toggleButtonConnection = nil

local function findDescendant(parent, name)
	if not parent then
		return nil
	end

	return parent:FindFirstChild(name, true)
end

local function disconnectGuiConnections()
	if toggleButtonConnection then
		toggleButtonConnection:Disconnect()
		toggleButtonConnection = nil
	end
end

local function clearGuiRefs()
	disconnectGuiConnections()
	screenGui = nil
	toggleButton = nil
	stateLabel = nil
end

local function getCharacter()
	return player.Character
end

local function getEquippedAxe()
	local character = getCharacter()

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

local function updateButtonVisuals()
	if not toggleButton or not stateLabel then
		return
	end

	if autoSwingEnabled then
		toggleButton.BackgroundColor3 = AUTO_ON_COLOR
		stateLabel.Text = "ON"
	else
		toggleButton.BackgroundColor3 = AUTO_OFF_COLOR
		stateLabel.Text = "OFF"
	end
end

local function setToolAutoSwing(tool, enabled)
	if tool and tool:IsA("Tool") then
		tool:SetAttribute(AUTO_SWING_ATTRIBUTE_NAME, enabled)
	end
end

local function syncAutoSwingOnEquippedTool()
	local equippedTool = getEquippedAxe()

	if trackedTool and trackedTool ~= equippedTool then
		setToolAutoSwing(trackedTool, false)
	end

	trackedTool = equippedTool

	if trackedTool then
		setToolAutoSwing(trackedTool, autoSwingEnabled)
	end
end

local function setAutoSwingEnabled(enabled)
	if autoSwingEnabled == enabled then
		updateButtonVisuals()
		syncAutoSwingOnEquippedTool()
		return
	end

	autoSwingEnabled = enabled
	updateButtonVisuals()
	syncAutoSwingOnEquippedTool()
end

local function toggleAutoSwing()
	setAutoSwingEnabled(not autoSwingEnabled)
end

local function buildGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild(GUI_NAME)

	if not existingGui or not existingGui:IsA("ScreenGui") then
		clearGuiRefs()

		if not playerGuiChildAddedConnection then
			playerGuiChildAddedConnection = playerGui.ChildAdded:Connect(function(child)
				if child.Name == GUI_NAME and child:IsA("ScreenGui") then
					buildGui()
				end
			end)
		end

		return
	end

	screenGui = existingGui
	toggleButton = findDescendant(screenGui, BUTTON_NAME)
	stateLabel = toggleButton and findDescendant(toggleButton, "State") or nil

	if playerGuiChildAddedConnection then
		playerGuiChildAddedConnection:Disconnect()
		playerGuiChildAddedConnection = nil
	end

	disconnectGuiConnections()

	if toggleButton and toggleButton:IsA("GuiButton") then
		toggleButtonConnection = toggleButton.Activated:Connect(toggleAutoSwing)
	end

	updateButtonVisuals()
end

local function connectCharacter(character)
	if childAddedConnection then
		childAddedConnection:Disconnect()
		childAddedConnection = nil
	end

	if childRemovedConnection then
		childRemovedConnection:Disconnect()
		childRemovedConnection = nil
	end

	trackedTool = nil

	if not character then
		return
	end

	childAddedConnection = character.ChildAdded:Connect(function(child)
		if axeConfig.isAxeTool(child) then
			syncAutoSwingOnEquippedTool()
		end
	end)

	childRemovedConnection = character.ChildRemoved:Connect(function(child)
		if axeConfig.isAxeTool(child) then
			syncAutoSwingOnEquippedTool()
		end
	end)

	syncAutoSwingOnEquippedTool()
end

function AutoSwingUI.start()
	if started then
		return
	end

	started = true
	buildGui()
	connectCharacter(player.Character)

	player.CharacterAdded:Connect(function(character)
		updateButtonVisuals()
		connectCharacter(character)
	end)
end

return AutoSwingUI
