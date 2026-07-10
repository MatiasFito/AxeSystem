local Players = game:GetService("Players")

local player = Players.LocalPlayer

local AmberShopUI = {}

local GUI_NAME = "AmberShopGui"

local OVERLAY_COLOR = Color3.fromRGB(0, 0, 0)
local PANEL_COLOR = Color3.fromRGB(42, 29, 18)
local PANEL_HIGHLIGHT = Color3.fromRGB(78, 52, 28)
local PANEL_STROKE = Color3.fromRGB(244, 214, 136)
local CARD_COLOR = Color3.fromRGB(56, 39, 25)
local CARD_STROKE = Color3.fromRGB(216, 190, 128)
local TEXT_COLOR = Color3.fromRGB(255, 246, 228)
local SUBTLE_TEXT_COLOR = Color3.fromRGB(231, 215, 184)
local GREEN_BUTTON_COLOR = Color3.fromRGB(69, 164, 90)
local RED_BUTTON_COLOR = Color3.fromRGB(133, 83, 78)
local LOCKED_BUTTON_COLOR = Color3.fromRGB(84, 84, 84)
local CLOSE_BUTTON_COLOR = Color3.fromRGB(177, 68, 61)

local started = false
local screenGui = nil
local modalOverlay = nil
local rootFrame = nil
local balanceLabel = nil
local statusLabel = nil
local scrollingFrame = nil
local listLayout = nil
local upgradeHandler = nil
local closeHandler = nil
local busyUpgradeKey = nil
local renderedState = nil

local function formatAmber(amount)
	return tostring(math.max(0, math.floor(tonumber(amount) or 0)))
end

local function clearCards()
	if not scrollingFrame then
		return
	end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child ~= listLayout and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function updateCanvasSize()
	if not scrollingFrame or not listLayout then
		return
	end

	scrollingFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 12)
end

local function handleCloseActivated()
	if closeHandler then
		closeHandler()
		return
	end

	AmberShopUI.close()
end

local function createLabel(parent, name, position, size, font, textSize, color, textXAlignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = textXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
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
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	modalOverlay = Instance.new("Frame")
	modalOverlay.Name = "Overlay"
	modalOverlay.BackgroundColor3 = OVERLAY_COLOR
	modalOverlay.BackgroundTransparency = 0.3
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.Parent = screenGui

	rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rootFrame.Position = UDim2.fromScale(0.5, 0.5)
	rootFrame.Size = UDim2.fromOffset(700, 560)
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BorderSizePixel = 0
	rootFrame.Parent = modalOverlay

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 22)
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

	local titleLabel = createLabel(
		rootFrame,
		"Title",
		UDim2.fromOffset(28, 20),
		UDim2.new(1, -120, 0, 32),
		Enum.Font.GothamBlack,
		28,
		TEXT_COLOR,
		Enum.TextXAlignment.Center
	)
	titleLabel.Position = UDim2.new(0.5, -220, 0, 18)
	titleLabel.Size = UDim2.fromOffset(440, 34)
	titleLabel.Text = "AMBER SHOP"

	balanceLabel = createLabel(
		rootFrame,
		"Balance",
		UDim2.fromOffset(28, 58),
		UDim2.new(1, -56, 0, 28),
		Enum.Font.GothamBold,
		22,
		TEXT_COLOR,
		Enum.TextXAlignment.Center
	)
	balanceLabel.Text = "Your Balance: [ 0 ]"

	statusLabel = createLabel(
		rootFrame,
		"Status",
		UDim2.fromOffset(28, 88),
		UDim2.new(1, -56, 0, 22),
		Enum.Font.Gotham,
		18,
		SUBTLE_TEXT_COLOR,
		Enum.TextXAlignment.Center
	)
	statusLabel.Text = ""

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -18, 0, 16)
	closeButton.Size = UDim2.fromOffset(44, 44)
	closeButton.BackgroundColor3 = CLOSE_BUTTON_COLOR
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBlack
	closeButton.Text = "X"
	closeButton.TextColor3 = TEXT_COLOR
	closeButton.TextScaled = true
	closeButton.Parent = rootFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 12)
	closeCorner.Parent = closeButton

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = PANEL_STROKE
	closeStroke.Thickness = 1.5
	closeStroke.Parent = closeButton

	scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "ScrollingFrame"
	scrollingFrame.Position = UDim2.fromOffset(22, 124)
	scrollingFrame.Size = UDim2.new(1, -44, 1, -146)
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
	scrollingFrame.ScrollBarThickness = 8
	scrollingFrame.Parent = rootFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = scrollingFrame

	listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 14)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollingFrame
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

	closeButton.Activated:Connect(handleCloseActivated)
end

local function renderUpgradeCard(layoutOrder, upgradeState)
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = string.format("Card_%s", upgradeState.key)
	cardFrame.LayoutOrder = layoutOrder
	cardFrame.Size = UDim2.new(1, -8, 0, 138)
	cardFrame.BackgroundColor3 = CARD_COLOR
	cardFrame.BorderSizePixel = 0
	cardFrame.Parent = scrollingFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = cardFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = CARD_STROKE
	cardStroke.Thickness = 1.5
	cardStroke.Parent = cardFrame

	createLabel(
		cardFrame,
		"Title",
		UDim2.fromOffset(18, 14),
		UDim2.new(1, -180, 0, 28),
		Enum.Font.GothamBlack,
		22,
		TEXT_COLOR
	).Text = upgradeState.displayName
		or upgradeState.key

	createLabel(
		cardFrame,
		"Level",
		UDim2.new(1, -156, 0, 16),
		UDim2.fromOffset(136, 24),
		Enum.Font.GothamBold,
		18,
		TEXT_COLOR,
		Enum.TextXAlignment.Right
	).Text =
		string.format("Lvl %d / %d", upgradeState.level or 0, upgradeState.maxLevel or 25)

	createLabel(
		cardFrame,
		"Description",
		UDim2.fromOffset(18, 46),
		UDim2.new(1, -36, 0, 22),
		Enum.Font.Gotham,
		17,
		SUBTLE_TEXT_COLOR
	).Text = upgradeState.description
		or ""

	local comparisonLabel = createLabel(
		cardFrame,
		"Comparison",
		UDim2.fromOffset(18, 74),
		UDim2.new(1, -220, 0, 34),
		Enum.Font.GothamBold,
		18,
		TEXT_COLOR
	)

	if upgradeState.isMaxLevel then
		comparisonLabel.Text = string.format("Current: %s (MAX LEVEL)", upgradeState.currentText or "")
	else
		comparisonLabel.Text =
			string.format("Current: %s   ===>   Next: %s", upgradeState.currentText or "", upgradeState.nextText or "")
	end

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.AnchorPoint = Vector2.new(1, 1)
	upgradeButton.Position = UDim2.new(1, -16, 1, -16)
	upgradeButton.Size = UDim2.fromOffset(204, 44)
	upgradeButton.BorderSizePixel = 0
	upgradeButton.Font = Enum.Font.GothamBlack
	upgradeButton.TextColor3 = TEXT_COLOR
	upgradeButton.TextScaled = true
	upgradeButton.Parent = cardFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 14)
	buttonCorner.Parent = upgradeButton

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = CARD_STROKE
	buttonStroke.Thickness = 1.5
	buttonStroke.Parent = upgradeButton

	local isBusy = busyUpgradeKey == upgradeState.key

	if upgradeState.isMaxLevel then
		upgradeButton.BackgroundColor3 = LOCKED_BUTTON_COLOR
		upgradeButton.Text = "[ MAX LEVEL ]"
		upgradeButton.Active = false
		upgradeButton.AutoButtonColor = false
	elseif isBusy then
		upgradeButton.BackgroundColor3 = GREEN_BUTTON_COLOR
		upgradeButton.Text = "Processing..."
		upgradeButton.Active = false
		upgradeButton.AutoButtonColor = false
	else
		upgradeButton.BackgroundColor3 = upgradeState.canAfford and GREEN_BUTTON_COLOR or RED_BUTTON_COLOR
		upgradeButton.Text = string.format("[ UPGRADE: %s ]", formatAmber(upgradeState.costToNextLevel or 0))
		upgradeButton.Active = true
		upgradeButton.AutoButtonColor = true
		upgradeButton.Activated:Connect(function()
			if upgradeHandler then
				upgradeHandler(upgradeState.key)
			end
		end)
	end
end

local function rerender()
	clearCards()

	if typeof(renderedState) ~= "table" then
		updateCanvasSize()
		return
	end

	balanceLabel.Text = string.format("Your Balance: [ %s ]", formatAmber(renderedState.amber))

	for index, upgradeState in ipairs(renderedState.upgrades or {}) do
		renderUpgradeCard(index, upgradeState)
	end

	updateCanvasSize()
end

function AmberShopUI.setUpgradeHandler(callback)
	ensureGui()
	upgradeHandler = callback
end

function AmberShopUI.setCloseHandler(callback)
	ensureGui()
	closeHandler = callback
end

function AmberShopUI.renderState(state)
	ensureGui()
	renderedState = state
	busyUpgradeKey = nil
	statusLabel.Text = ""
	rerender()
end

function AmberShopUI.setBusy(upgradeKey, isBusy)
	ensureGui()
	busyUpgradeKey = isBusy and upgradeKey or nil
	rerender()
end

function AmberShopUI.showFailure(message)
	ensureGui()
	statusLabel.Text = typeof(message) == "string" and message or "Amber shop request failed."
	busyUpgradeKey = nil
	rerender()
end

function AmberShopUI.open()
	ensureGui()
	screenGui.Enabled = true
end

function AmberShopUI.close()
	ensureGui()
	busyUpgradeKey = nil
	screenGui.Enabled = false
end

function AmberShopUI.toggle()
	ensureGui()
	if screenGui.Enabled then
		AmberShopUI.close()
	else
		AmberShopUI.open()
	end
end

function AmberShopUI.isOpen()
	ensureGui()
	return screenGui.Enabled
end

return AmberShopUI
