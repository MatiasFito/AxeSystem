local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local GUI_NAME = "TreeStatusGui"
local REMOTE_WAIT_TIMEOUT = 10
local REFRESH_RATE = 0.05
local TOAST_DURATION = 1.8

local PANEL_COLOR = Color3.fromRGB(35, 44, 33)
local PANEL_HIGHLIGHT = Color3.fromRGB(52, 69, 48)
local CARD_COLOR = Color3.fromRGB(58, 76, 53)
local CARD_STROKE = Color3.fromRGB(210, 229, 201)
local TEXT_COLOR = Color3.fromRGB(244, 247, 237)
local SUBTLE_COLOR = Color3.fromRGB(206, 219, 198)
local POSITIVE_COLOR = Color3.fromRGB(125, 214, 127)
local WARNING_COLOR = Color3.fromRGB(234, 195, 96)
local READY_COLOR = Color3.fromRGB(104, 202, 255)
local LOCKED_COLOR = Color3.fromRGB(116, 116, 116)
local GROWING_COLOR = Color3.fromRGB(122, 201, 118)

local TreeStatusUI = {}

local started = false
local screenGui = nil
local rootFrame = nil
local goldLabel = nil
local plotSetLabel = nil
local cardsContainer = nil
local toastFrame = nil
local toastLabel = nil

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

local leaderstatsConnection = nil
local goldValueConnection = nil

local function formatGold(amount)
	return tostring(math.max(0, math.floor(amount or 0)))
end

local function formatSeconds(seconds)
	local clampedSeconds = math.max(0, seconds or 0)

	if clampedSeconds >= 10 then
		return string.format("%.0fs", clampedSeconds)
	end

	if clampedSeconds >= 1 then
		return string.format("%.1fs", clampedSeconds)
	end

	return string.format("%.2fs", clampedSeconds)
end

local function getEstimatedServerTime()
	if serverTimeAtSync <= 0 then
		return 0
	end

	return serverTimeAtSync + (os.clock() - localClockAtSync)
end

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

local function ensurePlotCard(plotId)
	local existingCard = cardsByPlotId[plotId]

	if existingCard then
		return existingCard
	end

	local frame = Instance.new("Frame")
	frame.Name = plotId
	frame.BackgroundColor3 = CARD_COLOR
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 72)
	frame.Parent = cardsContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = CARD_STROKE
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local titleLabel = createLabel(
		frame,
		Enum.Font.GothamBlack,
		UDim2.new(0.58, 0, 0, 24),
		UDim2.fromOffset(14, 10),
		TEXT_COLOR,
		Enum.TextXAlignment.Left
	)
	local detailLabel = createLabel(
		frame,
		Enum.Font.GothamBold,
		UDim2.new(0.58, 0, 0, 20),
		UDim2.fromOffset(14, 34),
		SUBTLE_COLOR,
		Enum.TextXAlignment.Left
	)
	local footerLabel = createLabel(
		frame,
		Enum.Font.Gotham,
		UDim2.new(0.38, -16, 0, 44),
		UDim2.new(0.62, 2, 0, 14),
		SUBTLE_COLOR,
		Enum.TextXAlignment.Right
	)

	local meterBackground = Instance.new("Frame")
	meterBackground.BackgroundColor3 = Color3.fromRGB(31, 39, 29)
	meterBackground.BorderSizePixel = 0
	meterBackground.Position = UDim2.fromOffset(14, 58)
	meterBackground.Size = UDim2.new(1, -28, 0, 6)
	meterBackground.Parent = frame

	local meterCorner = Instance.new("UICorner")
	meterCorner.CornerRadius = UDim.new(1, 0)
	meterCorner.Parent = meterBackground

	local meterFill = Instance.new("Frame")
	meterFill.BackgroundColor3 = READY_COLOR
	meterFill.BorderSizePixel = 0
	meterFill.Size = UDim2.fromScale(0, 1)
	meterFill.Parent = meterBackground

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = meterFill

	existingCard = {
		Root = frame,
		Stroke = stroke,
		TitleLabel = titleLabel,
		DetailLabel = detailLabel,
		FooterLabel = footerLabel,
		MeterFill = meterFill,
	}
	cardsByPlotId[plotId] = existingCard
	return existingCard
end

local function updateGoldDisplay(amount)
	if goldLabel then
		goldLabel.Text = string.format("Gold  %s", formatGold(amount))
	end
end

local function bindLeaderstats()
	if goldValueConnection then
		goldValueConnection:Disconnect()
		goldValueConnection = nil
	end

	if leaderstatsConnection then
		leaderstatsConnection:Disconnect()
		leaderstatsConnection = nil
	end

	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", REMOTE_WAIT_TIMEOUT)

	if not leaderstats then
		return
	end

	local function attachGoldValue()
		if goldValueConnection then
			goldValueConnection:Disconnect()
			goldValueConnection = nil
		end

		local goldValue = leaderstats:FindFirstChild("Gold") or leaderstats:WaitForChild("Gold", REMOTE_WAIT_TIMEOUT)

		if goldValue and goldValue:IsA("IntValue") then
			updateGoldDisplay(goldValue.Value)
			goldValueConnection = goldValue:GetPropertyChangedSignal("Value"):Connect(function()
				updateGoldDisplay(goldValue.Value)
			end)
		end
	end

	attachGoldValue()
	leaderstatsConnection = leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Gold" and child:IsA("IntValue") then
			attachGoldValue()
		end
	end)
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

	rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(1, 0)
	rootFrame.Position = UDim2.new(1, -18, 0, 18)
	rootFrame.Size = UDim2.fromOffset(332, 378)
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BorderSizePixel = 0
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
		UDim2.new(1, -28, 0, 30),
		UDim2.fromOffset(14, 12),
		TEXT_COLOR,
		Enum.TextXAlignment.Left
	)
	titleLabel.Text = "Tree Plots"

	goldLabel = createLabel(
		rootFrame,
		Enum.Font.GothamBold,
		UDim2.new(1, -28, 0, 24),
		UDim2.fromOffset(14, 42),
		WARNING_COLOR,
		Enum.TextXAlignment.Left
	)
	updateGoldDisplay(0)

	plotSetLabel = createLabel(
		rootFrame,
		Enum.Font.Gotham,
		UDim2.new(1, -28, 0, 20),
		UDim2.fromOffset(14, 64),
		SUBTLE_COLOR,
		Enum.TextXAlignment.Left
	)
	plotSetLabel.Text = "Loading plots..."

	cardsContainer = Instance.new("Frame")
	cardsContainer.Name = "Cards"
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.Position = UDim2.fromOffset(14, 92)
	cardsContainer.Size = UDim2.new(1, -28, 0, 272)
	cardsContainer.Parent = rootFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = cardsContainer

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
	bindLeaderstats()
end

local function getCardColors(plot)
	if not plot.unlocked then
		return LOCKED_COLOR, 0
	end

	if plot.state == treeConstants.PlotState.Growing then
		return GROWING_COLOR, 0.2
	end

	return READY_COLOR, 1
end

local function renderPlotCard(plot)
	local card = ensurePlotCard(plot.plotId)
	local accentColor, baseProgress = getCardColors(plot)
	local titleSuffix = plot.unlocked and string.format("Lv.%d", plot.level) or "Locked"
	local levelStats = plot.stats or {}
	card.Root.LayoutOrder = plot.plotOrder
	card.TitleLabel.Text = string.format("%s  %s", plot.treeName, titleSuffix)
	card.MeterFill.BackgroundColor3 = accentColor

	if not plot.unlocked then
		card.DetailLabel.Text = plot.isUnlockable and "Ready to unlock" or "Unlock previous plot first"
		card.FooterLabel.Text = string.format("Cost %s Gold", formatGold(plot.unlockCost))
		card.MeterFill.Size = UDim2.fromScale(baseProgress, 1)
		return
	end

	card.FooterLabel.Text =
		string.format("HP %s  Reward %s", formatGold(levelStats.health), formatGold(levelStats.reward))

	if plot.state == treeConstants.PlotState.Growing then
		local maxGrowTime = math.max(0.01, levelStats.growTime or 0.01)
		local remaining = math.max(0, (plot.growingUntil or 0) - getEstimatedServerTime())
		local progress = math.clamp(1 - (remaining / maxGrowTime), 0, 1)
		card.DetailLabel.Text = string.format("Growing  %s", formatSeconds(remaining))
		card.MeterFill.Size = UDim2.fromScale(progress, 1)
		return
	end

	card.DetailLabel.Text = "Ready to chop"

	card.MeterFill.Size = UDim2.fromScale(1, 1)
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

		showToast(string.format("+%s Gold from %s", formatGold(payload.reward), treeName), POSITIVE_COLOR)
		return
	end

	if card then
		pulseCard(card, WARNING_COLOR)
	end

	showToast(
		string.format(
			"%s  -%s HP  (%s/%s)",
			treeName,
			formatGold(payload.damage),
			formatGold(payload.currentHealth),
			formatGold(payload.maxHealth)
		),
		WARNING_COLOR
	)
end

local function resolveRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild(treeConstants.REMOTE_FOLDER_NAME, REMOTE_WAIT_TIMEOUT)

	if not remotesFolder then
		warn("Tree remotes folder was not found")
		return false
	end

	local treesFolder = remotesFolder:WaitForChild(treeConstants.TREE_REMOTE_FOLDER_NAME, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		warn("Tree remote folder was not found")
		return false
	end

	getTreeStateRemote = treesFolder:WaitForChild(treeConstants.GET_STATE_REMOTE_NAME, REMOTE_WAIT_TIMEOUT)
	treeStateUpdatedRemote = treesFolder:WaitForChild(treeConstants.STATE_UPDATED_REMOTE_NAME, REMOTE_WAIT_TIMEOUT)
	treeHitFeedbackRemote = treesFolder:WaitForChild(treeConstants.HIT_FEEDBACK_REMOTE_NAME, REMOTE_WAIT_TIMEOUT)

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
