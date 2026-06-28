local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local GUI_NAME = "SwingSpeedPadGui"
local PART_NAME = "SwingSpeedPad"
local BUTTON_VALUES = { 1, 2, 3, 4, 5 }
local PART_WAIT_TIMEOUT = 10
local REMOTE_WAIT_TIMEOUT = 10

local PAD_COLOR = Color3.fromRGB(34, 29, 24)
local SURFACE_COLOR = Color3.fromRGB(64, 52, 42)
local LABEL_COLOR = Color3.fromRGB(245, 238, 224)
local ACTIVE_COLOR = Color3.fromRGB(118, 173, 95)
local INACTIVE_COLOR = Color3.fromRGB(108, 86, 69)
local STROKE_COLOR = Color3.fromRGB(231, 220, 197)

local SwingSpeedPad = {}

local started = false
local selectedSpeed = 1

local screenGui = nil
local surfaceGui = nil
local trackedPart = nil
local buttons = {}
local backpackConnection = nil
local characterAddedConnection = nil
local characterChildConnection = nil
local requestSwingSpeedRemote = nil

local function getBackpack()
	return player:FindFirstChildOfClass("Backpack")
end

local function clampSelectedSpeed(value)
	if typeof(value) ~= "number" then
		return blacksmithConstants.DEFAULT_SWING_SPEED
	end

	return math.clamp(math.floor(value + 0.5), blacksmithConstants.MIN_SWING_SPEED, blacksmithConstants.MAX_SWING_SPEED)
end

local function isBaseAxe(tool)
	return axeConfig.isAxeTool(tool)
end

local function resolveSwingSpeedRemote()
	if requestSwingSpeedRemote and requestSwingSpeedRemote.Parent then
		return requestSwingSpeedRemote
	end

	local blacksmithFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = blacksmithConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Blacksmith remotes folder was not found",
		},
		{
			Name = blacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME,
			ErrorMessage = "Blacksmith remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not blacksmithFolder then
		return nil
	end

	local remotes = remoteResolver.waitForNamedChildren(blacksmithFolder, {
		blacksmithConstants.REQUEST_SWING_SPEED_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Blacksmith remote")

	if not remotes then
		return nil
	end

	local remote = remotes[blacksmithConstants.REQUEST_SWING_SPEED_REMOTE_NAME]

	if remote and remote:IsA("RemoteEvent") then
		requestSwingSpeedRemote = remote
		return requestSwingSpeedRemote
	end

	return nil
end

local function setToolSwingSpeed(tool)
	if not isBaseAxe(tool) then
		return
	end

	local stats = tool:FindFirstChild("Stats")
	local swingSpeedValue = stats and stats:FindFirstChild("SwingSpeed")

	if swingSpeedValue and swingSpeedValue:IsA("NumberValue") then
		swingSpeedValue.Value = selectedSpeed
	end
end

local function applySelectedSpeed()
	local backpack = getBackpack()

	if backpack then
		for _, child in backpack:GetChildren() do
			setToolSwingSpeed(child)
		end
	end

	local character = player.Character

	if character then
		for _, child in character:GetChildren() do
			setToolSwingSpeed(child)
		end
	end
end

local function updateButtonVisuals()
	for value, button in buttons do
		button.BackgroundColor3 = value == selectedSpeed and ACTIVE_COLOR or INACTIVE_COLOR
	end
end

local function setSelectedSpeed(value)
	selectedSpeed = clampSelectedSpeed(value)
	updateButtonVisuals()
	applySelectedSpeed()

	local remote = resolveSwingSpeedRemote()

	if remote then
		remote:FireServer(selectedSpeed)
	end
end

local function buildButtons(parent)
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.BackgroundTransparency = 1
	buttonRow.Position = UDim2.fromScale(0.06, 0.46)
	buttonRow.Size = UDim2.fromScale(0.88, 0.38)
	buttonRow.Parent = parent

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(10, 0)
	layout.CellSize = UDim2.fromScale(0.18, 1)
	layout.FillDirectionMaxCells = #BUTTON_VALUES
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = buttonRow

	for _, value in BUTTON_VALUES do
		local button = Instance.new("TextButton")
		button.Name = string.format("Speed%s", value)
		button.AutoButtonColor = false
		button.BackgroundColor3 = INACTIVE_COLOR
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.Text = string.format("%sx", value)
		button.TextColor3 = LABEL_COLOR
		button.TextScaled = true
		button.Parent = buttonRow

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = STROKE_COLOR
		stroke.Thickness = 1.5
		stroke.Parent = button

		button.Activated:Connect(function()
			setSelectedSpeed(value)
		end)

		buttons[value] = button
	end
end

local function buildSurfaceGui(part)
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

	surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "Surface"
	surfaceGui.Active = true
	surfaceGui.Adornee = part
	surfaceGui.AlwaysOnTop = false
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 80
	surfaceGui.PixelsPerStud = 36
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = screenGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.BackgroundColor3 = PAD_COLOR
	rootFrame.BorderSizePixel = 0
	rootFrame.Size = UDim2.fromScale(1, 1)
	rootFrame.Parent = surfaceGui

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 14)
	padding.Parent = rootFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = rootFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 2
	stroke.Parent = rootFrame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SURFACE_COLOR),
		ColorSequenceKeypoint.new(1, PAD_COLOR),
	})
	gradient.Rotation = 90
	gradient.Parent = rootFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromScale(0.08, 0.1)
	titleLabel.Size = UDim2.fromScale(0.84, 0.22)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "Swing Speed"
	titleLabel.TextColor3 = LABEL_COLOR
	titleLabel.TextScaled = true
	titleLabel.Parent = rootFrame

	buildButtons(rootFrame)
	updateButtonVisuals()
end

local function trackCharacter(character)
	if characterChildConnection then
		characterChildConnection:Disconnect()
		characterChildConnection = nil
	end

	if not character then
		return
	end

	characterChildConnection = character.ChildAdded:Connect(function(child)
		setToolSwingSpeed(child)
	end)

	applySelectedSpeed()
end

local function connectToolSources()
	if backpackConnection then
		backpackConnection:Disconnect()
		backpackConnection = nil
	end

	local backpack = getBackpack()

	if backpack then
		backpackConnection = backpack.ChildAdded:Connect(function(child)
			setToolSwingSpeed(child)
		end)
	end

	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end

	trackCharacter(player.Character)
	characterAddedConnection = player.CharacterAdded:Connect(trackCharacter)
end

local function findPadPart()
	local part = Workspace:FindFirstChild(PART_NAME)

	if not part then
		part = Workspace:WaitForChild(PART_NAME, PART_WAIT_TIMEOUT)
	end

	if part and part:IsA("BasePart") then
		return part
	end

	return nil
end

function SwingSpeedPad.start()
	if started then
		return
	end

	started = true
	selectedSpeed = clampSelectedSpeed(player:GetAttribute(blacksmithConstants.SWING_SPEED_ATTRIBUTE_NAME))
	trackedPart = findPadPart()

	if not trackedPart then
		warn("SwingSpeedPad part was not found in Workspace")
		return
	end

	buildSurfaceGui(trackedPart)
	connectToolSources()
	applySelectedSpeed()
end

return SwingSpeedPad
