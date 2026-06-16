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
local SUBTLE_COLOR = Color3.fromRGB(216, 201, 183)
local BUTTON_COLOR = Color3.fromRGB(167, 96, 49)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(157, 62, 62)
local CLOSE_BUTTON_COLOR = Color3.fromRGB(198, 58, 58)
local ERROR_COLOR = Color3.fromRGB(255, 196, 196)

local BlacksmithUI = {}

local started = false
local screenGui = nil
local rootFrame = nil
local axeNameLabel = nil
local descriptionLabel = nil
local axeImageLabel = nil
local currentPowerLabel = nil
local nextPowerLabel = nil
local currentGoldBonusLabel = nil
local nextGoldBonusLabel = nil
local statusLabel = nil
local upgradeButton = nil
local closeButton = nil
local currentTitleLabel = nil
local nextTitleLabel = nil
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

local function setStatus(message, isError)
	if not statusLabel then
		return
	end

	statusLabel.Text = message or ""
	statusLabel.TextColor3 = isError and ERROR_COLOR or SUBTLE_COLOR
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

local function createSectionTitle(parent, text)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, 0)
	label.Size = UDim2.fromScale(1, 0.26)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = LABEL_COLOR
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createStatLabel(parent, position)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = UDim2.fromScale(1, 0.24)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = LABEL_COLOR
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
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
	rootFrame.Size = UDim2.fromOffset(560, 528)
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

	axeNameLabel = Instance.new("TextLabel")
	axeNameLabel.Name = "AxeName"
	axeNameLabel.BackgroundTransparency = 1
	axeNameLabel.Position = UDim2.fromOffset(0, 24)
	axeNameLabel.Size = UDim2.new(1, 0, 0, 44)
	axeNameLabel.Font = Enum.Font.GothamBlack
	axeNameLabel.TextColor3 = LABEL_COLOR
	axeNameLabel.TextScaled = true
	axeNameLabel.Parent = rootFrame

	closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.fromScale(1, 0)
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

	descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "Description"
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Position = UDim2.fromOffset(40, 70)
	descriptionLabel.Size = UDim2.new(1, -80, 0, 48)
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.TextColor3 = SUBTLE_COLOR
	descriptionLabel.TextScaled = true
	descriptionLabel.TextWrapped = true
	descriptionLabel.Parent = rootFrame

	axeImageLabel = Instance.new("ImageLabel")
	axeImageLabel.Name = "AxeImage"
	axeImageLabel.BackgroundTransparency = 1
	axeImageLabel.AnchorPoint = Vector2.new(0.5, 0)
	axeImageLabel.Position = UDim2.new(0.5, 0, 0, 112)
	axeImageLabel.Size = UDim2.fromOffset(180, 118)
	axeImageLabel.ScaleType = Enum.ScaleType.Fit
	axeImageLabel.Image = ""
	axeImageLabel.Parent = rootFrame

	local currentStatsFrame = Instance.new("Frame")
	currentStatsFrame.Name = "CurrentStats"
	currentStatsFrame.BackgroundTransparency = 1
	currentStatsFrame.Position = UDim2.fromOffset(34, 248)
	currentStatsFrame.Size = UDim2.new(0.42, 0, 0, 120)
	currentStatsFrame.Parent = rootFrame

	local nextStatsFrame = Instance.new("Frame")
	nextStatsFrame.Name = "NextStats"
	nextStatsFrame.BackgroundTransparency = 1
	nextStatsFrame.Position = UDim2.new(0.56, 0, 0, 248)
	nextStatsFrame.Size = UDim2.new(0.34, 0, 0, 120)
	nextStatsFrame.Parent = rootFrame

	currentTitleLabel = createSectionTitle(currentStatsFrame, "Current")
	nextTitleLabel = createSectionTitle(nextStatsFrame, "Next")
	currentPowerLabel = createStatLabel(currentStatsFrame, UDim2.fromScale(0, 0.34))
	nextPowerLabel = createStatLabel(nextStatsFrame, UDim2.fromScale(0, 0.34))
	currentGoldBonusLabel = createStatLabel(currentStatsFrame, UDim2.fromScale(0, 0.66))
	nextGoldBonusLabel = createStatLabel(nextStatsFrame, UDim2.fromScale(0, 0.66))

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(36, 376)
	statusLabel.Size = UDim2.new(1, -72, 0, 44)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextScaled = true
	statusLabel.TextWrapped = true
	statusLabel.Parent = rootFrame

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
	setStatus("", false)
end

function BlacksmithUI.renderState(state)
	ensureGui()

	local currentAxe = state.currentAxe
	local nextAxe = state.nextAxe
	canAttemptUpgrade = false

	axeNameLabel.Text = currentAxe.name
	descriptionLabel.Text = currentAxe.description
	axeImageLabel.Image = currentAxe.imageId or ""
	currentTitleLabel.Text = "Current"
	nextTitleLabel.Text = "Next"
	currentPowerLabel.Text = string.format("Power: %s", formatPower(currentAxe.power))
	currentGoldBonusLabel.Text = string.format("Gold Bonus: %s%%", formatGoldBonus(currentAxe.goldMultiplier))

	if nextAxe then
		nextPowerLabel.Text = string.format("Power: %s", formatPower(nextAxe.power))
		nextGoldBonusLabel.Text = string.format("Gold Bonus: %s%%", formatGoldBonus(nextAxe.goldMultiplier))
		buttonBaseText = string.format("Upgrade - %s Gold", tostring(nextAxe.cost))
		currentNextTierId = state.nextTierId
		canAttemptUpgrade = state.canUpgrade == true

		if canAttemptUpgrade then
			setStatus("", false)
		else
			setStatus(blacksmithConstants.getFailureMessage(blacksmithConstants.FailureReason.InsufficientGold), false)
		end
	else
		nextPowerLabel.Text = "Power: Maxed"
		nextGoldBonusLabel.Text = "Gold Bonus: Maxed"
		buttonBaseText = "Maxed"
		currentNextTierId = nil
		canAttemptUpgrade = false
		setStatus(blacksmithConstants.getFailureMessage(blacksmithConstants.FailureReason.AlreadyMaxed), false)
	end

	BlacksmithUI.setBusy(false)
end

function BlacksmithUI.showFailure(reason)
	ensureGui()
	setStatus(blacksmithConstants.getFailureMessage(reason), true)
	BlacksmithUI.setBusy(false)
end

return BlacksmithUI
