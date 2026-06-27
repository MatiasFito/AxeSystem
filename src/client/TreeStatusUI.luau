local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)
local timeSync = require(utilsFolder:WaitForChild("TimeSync") :: ModuleScript)
local TreePlotCard = require(script.Parent:WaitForChild("TreePlotCard") :: ModuleScript)

local GUI_NAME = "TreeStatusGui"
local REMOTE_WAIT_TIMEOUT = 10
local REFRESH_RATE = 0.05
local TOAST_DURATION = 1.8
local CARDS_PADDING_X = 8
local CARDS_PADDING_Y = 8

local PANEL_COLOR = Color3.fromRGB(35, 44, 33)
local PANEL_HIGHLIGHT = Color3.fromRGB(52, 69, 48)
local CARD_STROKE = Color3.fromRGB(210, 229, 201)
local TEXT_COLOR = Color3.fromRGB(244, 247, 237)
local SUBTLE_COLOR = Color3.fromRGB(206, 219, 198)
local BUTTON_COLOR = Color3.fromRGB(58, 76, 53)
local CLOSE_BUTTON_COLOR = Color3.fromRGB(198, 58, 58)
local POSITIVE_COLOR = Color3.fromRGB(125, 214, 127)
local WARNING_COLOR = Color3.fromRGB(234, 195, 96)
local READY_COLOR = Color3.fromRGB(104, 202, 255)

local TreeStatusUI = {}

local started = false
local screenGui = nil
local rootFrame = nil
local toggleButton = nil
local closeButton = nil
local plotSetLabel = nil
local cardsContainer = nil
local toastFrame = nil
local toastLabel = nil
local cardsLayout = nil
local cardsPadding = nil

local getTreeStateRemote = nil
local treeStateUpdatedRemote = nil
local treeHitFeedbackRemote = nil

local cardsByPlotId = {}
local plotsByPlotId = {}
local serverTimeAtSync = 0
local localClockAtSync = 0
local lastRefreshAt = 0
local hasReceivedInitialState = false
local toastToken = 0
local currentPlotSetId = nil

local isPanelOpen = false

local function setToastVisible(visible)
	if not toastFrame or not toastLabel then
		return
	end

	toastFrame.Visible = visible
	toastFrame.BackgroundTransparency = visible and 0.08 or 1
	toastLabel.TextTransparency = visible and 0 or 1
end

local function showToast(message, accentColor)
	if not toastFrame or not toastLabel then
		return
	end

	toastToken += 1
	local currentToken = toastToken
	toastLabel.Text = message
	toastLabel.TextColor3 = accentColor or TEXT_COLOR
	setToastVisible(true)

	local fadeInInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(toastFrame, fadeInInfo, { BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(toastLabel, fadeInInfo, { TextTransparency = 0 }):Play()

	task.delay(TOAST_DURATION, function()
		if currentToken ~= toastToken or not toastFrame or not toastLabel then
			return
		end

		local fadeOutInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeFrame = TweenService:Create(toastFrame, fadeOutInfo, { BackgroundTransparency = 1 })
		local fadeText = TweenService:Create(toastLabel, fadeOutInfo, { TextTransparency = 1 })
		fadeFrame:Play()
		fadeText:Play()
		fadeText.Completed:Connect(function()
			if currentToken == toastToken then
				toastFrame.Visible = false
			end
		end)
	end)
end

local function pulseCard(card, accentColor)
	if not card or not card.Stroke then
		return
	end

	card.Stroke.Color = accentColor
	card.Stroke.Thickness = 2.5

	task.delay(0.22, function()
		if not card.Stroke then
			return
		end

		card.Stroke.Color = CARD_STROKE
		card.Stroke.Thickness = 1.5
	end)
end

local function createLabel(parent, font, size, position, textColor, xAlignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = ""
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function updateCardsCanvasSize()
	if not cardsContainer or not cardsLayout then
		return
	end

	local verticalPadding = CARDS_PADDING_Y * 2
	cardsContainer.CanvasSize = UDim2.fromOffset(0, cardsLayout.AbsoluteContentSize.Y + verticalPadding)
end

local function setPanelOpen(nextOpen)
	isPanelOpen = nextOpen == true

	if rootFrame then
		rootFrame.Visible = isPanelOpen
	end

	if toggleButton then
		toggleButton.Visible = not isPanelOpen
	end
end

local function ensurePlotCard(plotId)
	local existingCard = cardsByPlotId[plotId]

	if existingCard then
		return existingCard
	end

	existingCard = TreePlotCard.create(cardsContainer, plotId)
	cardsByPlotId[plotId] = existingCard
	return existingCard
end

local function ensureGui()
	if screenGui then
		return
	end

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

	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.AnchorPoint = Vector2.new(1, 0.5)
	toggleButton.Position = UDim2.new(1, -20, 0.5, 0)
	toggleButton.Size = UDim2.fromOffset(86, 42)
	toggleButton.BackgroundColor3 = BUTTON_COLOR
	toggleButton.BorderSizePixel = 0
	toggleButton.Font = Enum.Font.GothamBlack
	toggleButton.Text = "Trees"
	toggleButton.TextColor3 = TEXT_COLOR
	toggleButton.TextScaled = true
	toggleButton.Parent = screenGui

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 14)
	toggleCorner.Parent = toggleButton

	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = CARD_STROKE
	toggleStroke.Thickness = 1.5
	toggleStroke.Parent = toggleButton

	rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(1, 0)
	rootFrame.Position = UDim2.new(1, -18, 0, 18)
	rootFrame.Size = UDim2.fromOffset(332, 378)
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BorderSizePixel = 0
	rootFrame.Visible = false
	rootFrame.Parent = screenGui

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 22)
	rootCorner.Parent = rootFrame

	local rootStroke = Instance.new("UIStroke")
	rootStroke.Color = CARD_STROKE
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
		Enum.Font.GothamBlack,
		UDim2.new(1, -84, 0, 30),
		UDim2.fromOffset(14, 12),
		TEXT_COLOR,
		Enum.TextXAlignment.Left
	)
	titleLabel.Text = "Tree Plots"

	closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(42, 42)
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
	closeStroke.Color = CARD_STROKE
	closeStroke.Thickness = 1.5
	closeStroke.Parent = closeButton

	plotSetLabel = createLabel(
		rootFrame,
		Enum.Font.Gotham,
		UDim2.new(1, -28, 0, 20),
		UDim2.fromOffset(14, 42),
		SUBTLE_COLOR,
		Enum.TextXAlignment.Left
	)
	plotSetLabel.Text = "Loading plots..."

	cardsContainer = Instance.new("ScrollingFrame")
	cardsContainer.Name = "Cards"
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.Position = UDim2.fromOffset(14, 70)
	cardsContainer.Size = UDim2.new(1, -28, 0, 294)
	cardsContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
	cardsContainer.BottomImage = ""
	cardsContainer.CanvasSize = UDim2.fromOffset(0, 0)
	cardsContainer.MidImage = ""
	cardsContainer.ScrollBarImageColor3 = CARD_STROKE
	cardsContainer.ScrollBarThickness = 8
	cardsContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	cardsContainer.TopImage = ""
	cardsContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	cardsContainer.Parent = rootFrame

	cardsPadding = Instance.new("UIPadding")
	cardsPadding.PaddingTop = UDim.new(0, CARDS_PADDING_Y)
	cardsPadding.PaddingBottom = UDim.new(0, CARDS_PADDING_Y)
	cardsPadding.PaddingLeft = UDim.new(0, CARDS_PADDING_X)
	cardsPadding.PaddingRight = UDim.new(0, CARDS_PADDING_X)
	cardsPadding.Parent = cardsContainer

	cardsLayout = Instance.new("UIListLayout")
	cardsLayout.Padding = UDim.new(0, 12)
	cardsLayout.Parent = cardsContainer
	cardsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCardsCanvasSize)

	toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toast"
	toastFrame.AnchorPoint = Vector2.new(0.5, 1)
	toastFrame.Position = UDim2.new(0.5, 0, 1, -18)
	toastFrame.Size = UDim2.fromOffset(350, 54)
	toastFrame.BackgroundColor3 = Color3.fromRGB(24, 31, 23)
	toastFrame.BackgroundTransparency = 1
	toastFrame.BorderSizePixel = 0
	toastFrame.Visible = false
	toastFrame.Parent = screenGui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 18)
	toastCorner.Parent = toastFrame

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = CARD_STROKE
	toastStroke.Thickness = 1.5
	toastStroke.Parent = toastFrame

	toastLabel = createLabel(
		toastFrame,
		Enum.Font.GothamBlack,
		UDim2.new(1, -24, 1, -14),
		UDim2.fromOffset(12, 7),
		TEXT_COLOR,
		Enum.TextXAlignment.Center
	)
	toastLabel.TextTransparency = 1

	setToastVisible(false)
	toggleButton.Activated:Connect(function()
		setPanelOpen(true)
	end)
	closeButton.Activated:Connect(function()
		setPanelOpen(false)
	end)
	setPanelOpen(false)
end

local function renderPlotCard(plot)
	local card = ensurePlotCard(plot.plotId)
	TreePlotCard.render(card, plot, {
		estimatedServerTime = timeSync.estimateServerTime(serverTimeAtSync, localClockAtSync),
	})
end

local function renderPlots()
	local orderedPlots = {}

	for _, plot in plotsByPlotId do
		table.insert(orderedPlots, plot)
	end

	table.sort(orderedPlots, function(left, right)
		return left.plotOrder < right.plotOrder
	end)

	for _, plot in orderedPlots do
		renderPlotCard(plot)
	end

	if plotSetLabel then
		if #orderedPlots == 0 then
			plotSetLabel.Text = "Waiting for tree state..."
		else
			plotSetLabel.Text = string.format("Assigned set: %s", tostring(currentPlotSetId or "Active"))
		end
	end
	lastRefreshAt = os.clock()
end

local function announcePlotTransitions(previousPlot, nextPlot)
	if not hasReceivedInitialState then
		return
	end

	local card = ensurePlotCard(nextPlot.plotId)

	if (not previousPlot or previousPlot.unlocked ~= true) and nextPlot.unlocked then
		pulseCard(card, POSITIVE_COLOR)
		showToast(string.format("%s unlocked", nextPlot.treeName), POSITIVE_COLOR)
		return
	end

	if previousPlot and nextPlot.level > previousPlot.level then
		pulseCard(card, WARNING_COLOR)
		showToast(string.format("%s reached Lv.%d", nextPlot.treeName, nextPlot.level), WARNING_COLOR)
		return
	end

	if
		previousPlot
		and previousPlot.state ~= treeConstants.PlotState.Grown
		and nextPlot.state == treeConstants.PlotState.Grown
	then
		pulseCard(card, READY_COLOR)
		showToast(string.format("%s is ready", nextPlot.treeName), READY_COLOR)
	end
end

local function applyState(state)
	if typeof(state) ~= "table" then
		return
	end

	serverTimeAtSync = tonumber(state.serverTime) or 0
	localClockAtSync = os.clock()
	currentPlotSetId = typeof(state.plotSetId) == "string" and state.plotSetId or currentPlotSetId

	for _, plot in state.plots or {} do
		local previousPlot = plotsByPlotId[plot.plotId]
		plotsByPlotId[plot.plotId] = plot
		announcePlotTransitions(previousPlot, plot)
	end

	if plotSetLabel and currentPlotSetId and currentPlotSetId ~= "" then
		plotSetLabel.Text = string.format("Assigned set: %s", currentPlotSetId)
	end

	renderPlots()
	hasReceivedInitialState = true
end

local function handleHitFeedback(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local plot = payload.plotId and plotsByPlotId[payload.plotId] or nil
	local treeName = payload.treeName or (plot and plot.treeName) or "Tree"
	local card = payload.plotId and cardsByPlotId[payload.plotId] or nil

	if payload.kind == "felled" then
		if card then
			pulseCard(card, POSITIVE_COLOR)
		end

		showToast(
			string.format("+%s Gold from %s", currencyFormatter.formatGold(payload.reward), treeName),
			POSITIVE_COLOR
		)
		return
	end

	if payload.kind == "infinitreeHit" then
		if card then
			pulseCard(card, POSITIVE_COLOR)
		end

		showToast(
			string.format("+%s Gold from %s", currencyFormatter.formatGold(payload.reward), treeName),
			POSITIVE_COLOR
		)
		return
	end

	if card then
		pulseCard(card, WARNING_COLOR)
	end

	showToast(
		string.format(
			"%s  -%s HP  (%s/%s)",
			treeName,
			currencyFormatter.formatGold(payload.damage),
			currencyFormatter.formatGold(payload.currentHealth),
			currencyFormatter.formatGold(payload.maxHealth)
		),
		WARNING_COLOR
	)
end

local function resolveRemotes()
	local treesFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remotes folder was not found",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(treesFolder, {
		treeConstants.GET_STATE_REMOTE_NAME,
		treeConstants.STATE_UPDATED_REMOTE_NAME,
		treeConstants.HIT_FEEDBACK_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Tree remote")

	if not remotes then
		return false
	end

	getTreeStateRemote = remotes[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	treeStateUpdatedRemote = remotes[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent
	treeHitFeedbackRemote = remotes[treeConstants.HIT_FEEDBACK_REMOTE_NAME] :: RemoteEvent

	return getTreeStateRemote ~= nil and treeStateUpdatedRemote ~= nil and treeHitFeedbackRemote ~= nil
end

local function requestInitialState()
	if not getTreeStateRemote then
		return
	end

	local success, payload = pcall(function()
		return getTreeStateRemote:InvokeServer()
	end)

	if not success then
		showToast("Tree state unavailable", WARNING_COLOR)
		return
	end

	if payload.success then
		applyState(payload.state)
		return
	end

	showToast(payload.message or "Tree state unavailable", WARNING_COLOR)
end

function TreeStatusUI.start()
	if started then
		return
	end

	started = true
	ensureGui()

	if not resolveRemotes() then
		return
	end

	treeStateUpdatedRemote.OnClientEvent:Connect(applyState)
	treeHitFeedbackRemote.OnClientEvent:Connect(handleHitFeedback)

	RunService.Heartbeat:Connect(function()
		if os.clock() - lastRefreshAt >= REFRESH_RATE then
			renderPlots()
		end
	end)

	requestInitialState()
end

return TreeStatusUI
