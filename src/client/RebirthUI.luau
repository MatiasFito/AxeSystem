local Players = game:GetService("Players")

local player = Players.LocalPlayer

local GUI_NAME = "RebirthGui"

local PANEL_COLOR = Color3.fromRGB(28, 30, 23)
local PANEL_HIGHLIGHT = Color3.fromRGB(53, 61, 44)
local PANEL_STROKE = Color3.fromRGB(230, 219, 173)
local LABEL_COLOR = Color3.fromRGB(244, 240, 221)
local BUTTON_READY_COLOR = Color3.fromRGB(184, 120, 46)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(92, 92, 92)
local CONFIRM_COLOR = Color3.fromRGB(108, 169, 83)
local CANCEL_COLOR = Color3.fromRGB(152, 70, 70)
local MODAL_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0)

local RebirthUI = {}

local started = false
local screenGui = nil
local rootFrame = nil
local actionButton = nil
local statusLabel = nil
local modalOverlay = nil
local modalMessageLabel = nil
local confirmButton = nil
local cancelButton = nil
local openHandler = nil
local confirmHandler = nil
local previewState = nil
local isBusy = false

local ROOT_BOTTOM_OFFSET = -24
local ROOT_RIGHT_OFFSET = -24
local ROOT_WIDTH = 348
local ROOT_HEIGHT = 116
local CONTENT_CENTER_Y = 40

local function formatAmount(amount)
	return tostring(math.max(0, math.floor(amount or 0)))
end

local function buildStatusText(state)
	if typeof(state) ~= "table" then
		return "Reach Plot 10 to unlock Rebirth."
	end

	if typeof(state.statusText) == "string" and state.statusText ~= "" then
		return state.statusText
	end

	if state.isEligible == true then
		return string.format("Ready: %s Amber", formatAmount(state.estimatedAmber))
	end

	return string.format(
		"Reach Plot %d. Current max plot: %d",
		tonumber(state.minimumPlotOrder) or 10,
		tonumber(state.maxUnlockedPlotOrder) or 0
	)
end

local function updateButtonState()
	if not actionButton or typeof(previewState) ~= "table" then
		return
	end

	local isEligible = previewState.isEligible == true
	local isEnabled = isEligible and not isBusy
	actionButton.Active = isEnabled
	actionButton.AutoButtonColor = isEnabled
	actionButton.BackgroundColor3 = isEnabled and BUTTON_READY_COLOR or BUTTON_DISABLED_COLOR
	actionButton.Text = isBusy and "Processing..." or "Rebirth"
	statusLabel.Text = buildStatusText(previewState)
end

local function closeModal()
	if modalOverlay then
		modalOverlay.Visible = false
	end
end

local function updateModalMessage(state)
	if not modalMessageLabel then
		return
	end

	local amberReward = typeof(state) == "table" and state.estimatedAmber or 0
	modalMessageLabel.Text = string.format("Are you sure? You will receive %s Amber.", formatAmount(amberReward))
end

local function handleButtonActivated()
	if isBusy or typeof(previewState) ~= "table" or previewState.isEligible ~= true then
		return
	end

	if openHandler then
		openHandler(previewState)
		return
	end

	RebirthUI.openConfirm(previewState)
end

local function handleConfirmActivated()
	if isBusy or not confirmHandler then
		return
	end

	confirmHandler(previewState)
end

local function createButton(parent, name, size, position, backgroundColor, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = backgroundColor
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = LABEL_COLOR
	button.TextScaled = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = PANEL_STROKE
	stroke.Thickness = 1.5
	stroke.Parent = button

	return button
end

local function ensureGui()
	if started then
		return
	end

	started = true
	previewState = {
		isEligible = false,
		minimumPlotOrder = 10,
		maxUnlockedPlotOrder = 0,
		estimatedAmber = 0,
	}

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

	rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(1, 1)
	rootFrame.Position = UDim2.new(1, ROOT_RIGHT_OFFSET, 1, ROOT_BOTTOM_OFFSET)
	rootFrame.Size = UDim2.fromOffset(ROOT_WIDTH, ROOT_HEIGHT)
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BorderSizePixel = 0
	rootFrame.Parent = screenGui

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 18)
	rootCorner.Parent = rootFrame

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = PANEL_STROKE
	rootStroke.Thickness = 2
	rootStroke.Parent = rootFrame

	local rootGradient = Instance.new("UIGradient")
	rootGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_HIGHLIGHT),
		ColorSequenceKeypoint.new(1, PANEL_COLOR),
	})
	rootGradient.Rotation = 90
	rootGradient.Parent = rootFrame

	actionButton = createButton(
		rootFrame,
		"RebirthButton",
		UDim2.fromOffset(220, 48),
		UDim2.new(0.5, -110, 0, CONTENT_CENTER_Y),
		BUTTON_DISABLED_COLOR,
		"Rebirth"
	)
	actionButton.AnchorPoint = Vector2.new(0, 0.5)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(16, 88)
	statusLabel.Size = UDim2.new(1, -32, 0, 18)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextColor3 = LABEL_COLOR
	statusLabel.TextScaled = true
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.Parent = rootFrame

	modalOverlay = Instance.new("Frame")
	modalOverlay.Name = "ModalOverlay"
	modalOverlay.BackgroundColor3 = MODAL_OVERLAY_COLOR
	modalOverlay.BackgroundTransparency = 0.35
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.Visible = false
	modalOverlay.Parent = screenGui

	local modalFrame = Instance.new("Frame")
	modalFrame.Name = "Modal"
	modalFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	modalFrame.Position = UDim2.fromScale(0.5, 0.5)
	modalFrame.Size = UDim2.fromOffset(340, 180)
	modalFrame.BackgroundColor3 = PANEL_COLOR
	modalFrame.BorderSizePixel = 0
	modalFrame.Parent = modalOverlay

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 20)
	modalCorner.Parent = modalFrame

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = PANEL_STROKE
	modalStroke.Thickness = 2
	modalStroke.Parent = modalFrame

	local modalGradient = Instance.new("UIGradient")
	modalGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_HIGHLIGHT),
		ColorSequenceKeypoint.new(1, PANEL_COLOR),
	})
	modalGradient.Rotation = 90
	modalGradient.Parent = modalFrame

	modalMessageLabel = Instance.new("TextLabel")
	modalMessageLabel.Name = "MessageLabel"
	modalMessageLabel.BackgroundTransparency = 1
	modalMessageLabel.Position = UDim2.fromOffset(24, 28)
	modalMessageLabel.Size = UDim2.new(1, -48, 0, 68)
	modalMessageLabel.Font = Enum.Font.GothamBold
	modalMessageLabel.TextColor3 = LABEL_COLOR
	modalMessageLabel.TextScaled = true
	modalMessageLabel.TextWrapped = true
	modalMessageLabel.Parent = modalFrame

	confirmButton = createButton(
		modalFrame,
		"ConfirmButton",
		UDim2.fromOffset(132, 44),
		UDim2.fromOffset(24, 126),
		CONFIRM_COLOR,
		"Confirm"
	)
	confirmButton.AnchorPoint = Vector2.new(0, 0)

	cancelButton = createButton(
		modalFrame,
		"CancelButton",
		UDim2.fromOffset(132, 44),
		UDim2.new(1, -156, 0, 126),
		CANCEL_COLOR,
		"Cancel"
	)
	cancelButton.AnchorPoint = Vector2.new(0, 0)

	actionButton.Activated:Connect(handleButtonActivated)
	confirmButton.Activated:Connect(handleConfirmActivated)
	cancelButton.Activated:Connect(closeModal)
	updateModalMessage(previewState)
	updateButtonState()
end

function RebirthUI.setOpenHandler(callback)
	ensureGui()
	openHandler = callback
end

function RebirthUI.setConfirmHandler(callback)
	ensureGui()
	confirmHandler = callback
end

function RebirthUI.setBusy(nextBusy)
	ensureGui()
	isBusy = nextBusy == true
	confirmButton.Active = not isBusy
	confirmButton.AutoButtonColor = not isBusy
	confirmButton.Text = isBusy and "Processing..." or "Confirm"
	cancelButton.Active = not isBusy
	cancelButton.AutoButtonColor = not isBusy
	updateButtonState()
end

function RebirthUI.setEligibility(state)
	ensureGui()
	previewState = {
		isEligible = state and state.isEligible == true,
		minimumPlotOrder = state and state.minimumPlotOrder or 10,
		maxUnlockedPlotOrder = state and state.maxUnlockedPlotOrder or 0,
		estimatedAmber = state and state.estimatedAmber or 0,
		amber = state and state.amber or 0,
		statusText = state and state.statusText or nil,
	}
	updateModalMessage(previewState)
	updateButtonState()
end

function RebirthUI.openConfirm(state)
	ensureGui()

	if state then
		RebirthUI.setEligibility(state)
	end

	if previewState.isEligible ~= true then
		return
	end

	updateModalMessage(previewState)
	modalOverlay.Visible = true
end

function RebirthUI.closeConfirm()
	ensureGui()
	closeModal()
end

function RebirthUI.showFailure(message)
	ensureGui()
	previewState.statusText = typeof(message) == "string" and message or "Rebirth failed. Please try again."
	RebirthUI.setBusy(false)
	updateButtonState()
end

return RebirthUI
