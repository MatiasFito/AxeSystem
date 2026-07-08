local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)

local GUI_NAME = "BlacksmithGui"

local PANEL_COLOR = Color3.fromRGB(42, 31, 24)
local PANEL_HIGHLIGHT = Color3.fromRGB(84, 58, 43)
local BORDER_COLOR = Color3.fromRGB(228, 211, 187)
local LABEL_COLOR = Color3.fromRGB(248, 242, 230)
local CARD_COLOR = Color3.fromRGB(68, 49, 38)
local BUTTON_COLOR = Color3.fromRGB(167, 96, 49)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(157, 62, 62)
local CLOSE_BUTTON_COLOR = Color3.fromRGB(198, 58, 58)
local UPGRADE_ARROW_IMAGE = "rbxassetid://16844557963"
local SIDE_CARD_POSITION = UDim2.new(0.26, 0, 0, 88)
local CENTER_CARD_POSITION = UDim2.new(0.5, 0, 0, 88)
local NEXT_CARD_POSITION = UDim2.new(0.74, 0, 0, 88)

local BlacksmithUI = {}

local started = false
local screenGui = nil
local rootFrame = nil
local currentAxeFrame = nil
local nextAxeFrame = nil
local currentAxeImageLabel = nil
local nextAxeImageLabel = nil
local upgradeArrowImageLabel = nil
local currentPowerLabel = nil
local nextPowerLabel = nil
local currentGoldBonusLabel = nil
local nextGoldBonusLabel = nil
local upgradeButton = nil
local closeButton = nil
local currentNextTierId = nil
local buttonBaseText = "Upgrade"
local upgradeHandler = nil
local closeHandler = nil
local isBusy = false
local canAttemptUpgrade = false

local function formatPower(power)
	if math.floor(power) == power then
		return tostring(power)
	end

	return string.format("%.1f", power)
end

local function formatGoldBonus(multiplier)
	local percentage = math.max(0, math.floor(((multiplier or 1) - 1) * 100 + 0.5))
	return tostring(percentage)
end

local function updateButtonVisualState(enabled)
	if not upgradeButton then
		return
	end

	upgradeButton.Active = enabled
	upgradeButton.AutoButtonColor = enabled
	upgradeButton.BackgroundColor3 = enabled and BUTTON_COLOR or BUTTON_DISABLED_COLOR
	upgradeButton.Text = isBusy and "Processing..." or buttonBaseText
end

local function handleUpgradeActivated()
	if isBusy or not currentNextTierId or not upgradeHandler then
		return
	end

	upgradeHandler(currentNextTierId)
end

local function handleCloseActivated()
	if closeHandler then
		closeHandler()
		return
	end

	BlacksmithUI.close()
end

local function createStatLabel(parent, position)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = UDim2.new(1, -28, 0, 34)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = LABEL_COLOR
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = parent
	return label
end

local function createAxeCard(parent, name, position)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = position
	frame.Size = UDim2.fromOffset(196, 240)
	frame.BackgroundColor3 = CARD_COLOR
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER_COLOR
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_HIGHLIGHT),
		ColorSequenceKeypoint.new(1, CARD_COLOR),
	})
	gradient.Rotation = 90
	gradient.Parent = frame

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "AxeImage"
	imageLabel.BackgroundTransparency = 1
	imageLabel.Position = UDim2.fromOffset(22, 18)
	imageLabel.Size = UDim2.new(1, -44, 0, 118)
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.Image = ""
	imageLabel.Parent = frame

	local powerLabel = createStatLabel(frame, UDim2.fromOffset(14, 150))
	local goldBonusLabel = createStatLabel(frame, UDim2.fromOffset(14, 186))

	return frame, imageLabel, powerLabel, goldBonusLabel
end

local function ensureGui()
	if started then
		return
	end

	started = true

	local playerGui = player:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild(GUI_NAME)

	if existingGui and existingGui:IsA("ScreenGui") then
		existingGui:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.Enabled = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rootFrame.Position = UDim2.fromScale(0.5, 0.46)
	rootFrame.Size = UDim2.fromOffset(620, 430)
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BorderSizePixel = 0
	rootFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = rootFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER_COLOR
	stroke.Thickness = 2
	stroke.Parent = rootFrame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_HIGHLIGHT),
		ColorSequenceKeypoint.new(1, PANEL_COLOR),
	})
	gradient.Rotation = 90
	gradient.Parent = rootFrame

	closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.new(1, -30, 0, 30)
	closeButton.Size = UDim2.fromOffset(42, 42)
	closeButton.BackgroundColor3 = CLOSE_BUTTON_COLOR
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBlack
	closeButton.Text = "X"
	closeButton.TextColor3 = LABEL_COLOR
	closeButton.TextScaled = true
	closeButton.Parent = rootFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 12)
	closeCorner.Parent = closeButton

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = BORDER_COLOR
	closeStroke.Thickness = 1.5
	closeStroke.Parent = closeButton

	currentAxeFrame, currentAxeImageLabel, currentPowerLabel, currentGoldBonusLabel =
		createAxeCard(rootFrame, "CurrentAxe", SIDE_CARD_POSITION)
	nextAxeFrame, nextAxeImageLabel, nextPowerLabel, nextGoldBonusLabel =
		createAxeCard(rootFrame, "NextAxe", NEXT_CARD_POSITION)

	upgradeArrowImageLabel = Instance.new("ImageLabel")
	upgradeArrowImageLabel.Name = "UpgradeArrow"
	upgradeArrowImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	upgradeArrowImageLabel.BackgroundTransparency = 1
	upgradeArrowImageLabel.Position = UDim2.new(0.5, 0, 0, 146)
	upgradeArrowImageLabel.Size = UDim2.fromOffset(58, 58)
	upgradeArrowImageLabel.Image = UPGRADE_ARROW_IMAGE
	upgradeArrowImageLabel.ScaleType = Enum.ScaleType.Fit
	upgradeArrowImageLabel.Parent = rootFrame

	upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.AnchorPoint = Vector2.new(0.5, 1)
	upgradeButton.Position = UDim2.new(0.5, 0, 1, -26)
	upgradeButton.Size = UDim2.fromOffset(344, 54)
	upgradeButton.BackgroundColor3 = BUTTON_COLOR
	upgradeButton.BorderSizePixel = 0
	upgradeButton.Font = Enum.Font.GothamBlack
	upgradeButton.TextColor3 = LABEL_COLOR
	upgradeButton.TextScaled = true
	upgradeButton.Parent = rootFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 18)
	buttonCorner.Parent = upgradeButton

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = BORDER_COLOR
	buttonStroke.Thickness = 1.5
	buttonStroke.Parent = upgradeButton

	upgradeButton.Activated:Connect(handleUpgradeActivated)
	closeButton.Activated:Connect(handleCloseActivated)
	updateButtonVisualState(false)
end

function BlacksmithUI.setUpgradeHandler(callback)
	ensureGui()
	upgradeHandler = callback
end

function BlacksmithUI.setCloseHandler(callback)
	ensureGui()
	closeHandler = callback
end

function BlacksmithUI.setBusy(nextBusy)
	ensureGui()
	isBusy = nextBusy == true
	updateButtonVisualState(canAttemptUpgrade and not isBusy)
end

function BlacksmithUI.open()
	ensureGui()
	screenGui.Enabled = true
end

function BlacksmithUI.close()
	ensureGui()
	screenGui.Enabled = false
	BlacksmithUI.setBusy(false)
end

function BlacksmithUI.renderState(state)
	ensureGui()

	local currentAxe = state.currentAxe
	local nextAxe = state.nextAxe
	canAttemptUpgrade = false

	currentAxeImageLabel.Image = currentAxe.imageId or ""
	currentPowerLabel.Text = string.format("Power: %s", formatPower(currentAxe.power))
	currentGoldBonusLabel.Text = string.format("Gold Bonus: %s%%", formatGoldBonus(currentAxe.goldMultiplier))

	if nextAxe then
		currentAxeFrame.Position = SIDE_CARD_POSITION
		nextAxeFrame.Visible = true
		upgradeArrowImageLabel.Visible = true
		nextAxeImageLabel.Image = nextAxe.imageId or ""
		nextPowerLabel.Text = string.format("Power: %s", formatPower(nextAxe.power))
		nextGoldBonusLabel.Text = string.format("Gold Bonus: %s%%", formatGoldBonus(nextAxe.goldMultiplier))
		buttonBaseText = string.format("%s Gold", tostring(nextAxe.cost))
		currentNextTierId = state.nextTierId
		canAttemptUpgrade = state.canUpgrade == true
	else
		currentAxeFrame.Position = CENTER_CARD_POSITION
		nextAxeFrame.Visible = false
		upgradeArrowImageLabel.Visible = false
		nextAxeImageLabel.Image = ""
		nextPowerLabel.Text = ""
		nextGoldBonusLabel.Text = ""
		buttonBaseText = "Maxed"
		currentNextTierId = nil
		canAttemptUpgrade = false
	end

	BlacksmithUI.setBusy(false)
end

function BlacksmithUI.showFailure(reason)
	ensureGui()
	warn(blacksmithConstants.getFailureMessage(reason))
	BlacksmithUI.setBusy(false)
end

return BlacksmithUI
