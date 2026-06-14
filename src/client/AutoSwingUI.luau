local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)

local GUI_NAME = "AutoSwingGui"
local BUTTON_NAME = "ToggleButton"
local TOOL_NAME = "BaseAxe"

local AUTO_ON_COLOR = Color3.fromRGB(78, 168, 106)
local AUTO_OFF_COLOR = Color3.fromRGB(180, 95, 95)
local STROKE_COLOR = Color3.fromRGB(238, 232, 216)
local PANEL_COLOR = Color3.fromRGB(37, 31, 28)
local LABEL_COLOR = Color3.fromRGB(245, 239, 224)

local AutoSwingUI = {}

local started = false
local autoSwingEnabled = false
local runnerId = 0

local screenGui = nil
local toggleButton = nil
local stateLabel = nil

local function getCharacter()
	return player.Character
end

local function getEquippedBaseAxe()
	local character = getCharacter()

	if not character then
		return nil
	end

	local tool = character:FindFirstChild(TOOL_NAME)

	if tool and tool:IsA("Tool") then
		return tool
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

local function runAutoSwing(currentRunnerId)
	while autoSwingEnabled and runnerId == currentRunnerId do
		local tool = getEquippedBaseAxe()

		if tool then
			tool:Activate()
			task.wait(swingSpeed.getAutoSwingInterval(tool))
		else
			task.wait(swingSpeed.MIN_EFFECTIVE_SWING_DURATION)
		end
	end
end

local function startAutoSwingLoop()
	runnerId += 1
	local currentRunnerId = runnerId

	task.spawn(runAutoSwing, currentRunnerId)
end

local function setAutoSwingEnabled(enabled)
	if autoSwingEnabled == enabled then
		updateButtonVisuals()
		return
	end

	autoSwingEnabled = enabled
	updateButtonVisuals()

	if autoSwingEnabled then
		startAutoSwingLoop()
	else
		runnerId += 1
	end
end

local function toggleAutoSwing()
	setAutoSwingEnabled(not autoSwingEnabled)
end

local function buildGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild(GUI_NAME)

	if existingGui and existingGui:IsA("ScreenGui") then
		existingGui:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	toggleButton = Instance.new("ImageButton")
	toggleButton.Name = BUTTON_NAME
	toggleButton.AnchorPoint = Vector2.new(0, 1)
	toggleButton.Position = UDim2.new(0, 18, 1, -18)
	toggleButton.Size = UDim2.fromOffset(112, 112)
	toggleButton.AutoButtonColor = false
	toggleButton.Image = ""
	toggleButton.BackgroundColor3 = AUTO_OFF_COLOR
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = toggleButton

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 2
	stroke.Parent = toggleButton

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_COLOR),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(78, 58, 45)),
	})
	gradient.Rotation = 90
	gradient.Parent = toggleButton

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(10, 16)
	titleLabel.Size = UDim2.new(1, -20, 0, 42)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "AUTO\nSWING"
	titleLabel.TextColor3 = LABEL_COLOR
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.Parent = toggleButton

	stateLabel = Instance.new("TextLabel")
	stateLabel.Name = "State"
	stateLabel.BackgroundTransparency = 1
	stateLabel.AnchorPoint = Vector2.new(0.5, 1)
	stateLabel.Position = UDim2.new(0.5, 0, 1, -14)
	stateLabel.Size = UDim2.new(1, -20, 0, 30)
	stateLabel.Font = Enum.Font.GothamBlack
	stateLabel.TextColor3 = LABEL_COLOR
	stateLabel.TextScaled = true
	stateLabel.Parent = toggleButton

	toggleButton.Activated:Connect(toggleAutoSwing)
	updateButtonVisuals()
end

function AutoSwingUI.start()
	if started then
		return
	end

	started = true
	buildGui()

	player.CharacterAdded:Connect(function()
		updateButtonVisuals()
	end)
end

return AutoSwingUI
