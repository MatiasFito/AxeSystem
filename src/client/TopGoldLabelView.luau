local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)

local GUI_NAME = "TopGoldLabelGui"
local PILL_WIDTH_SCALE = 0.22
local LABEL_HEIGHT = 56
local TOP_PADDING = 6
local INNER_HORIZONTAL_PADDING = 16
local INNER_VERTICAL_PADDING = 8
local MIN_ANIMATION_DURATION = 0.08
local MAX_ANIMATION_DURATION = 0.5
local SECONDS_PER_STEP = 0.013
local MAX_VISIBLE_STEPS = 42

local BACKGROUND_COLOR = Color3.fromRGB(12, 11, 9)
local SHADOW_COLOR = Color3.fromRGB(0, 0, 0)
local GRADIENT_TOP_COLOR = Color3.fromRGB(35, 28, 14)
local GRADIENT_BOTTOM_COLOR = Color3.fromRGB(12, 11, 9)
local STROKE_COLOR = Color3.fromRGB(234, 195, 96)
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 233, 162)
local TEXT_COLOR = Color3.fromRGB(245, 214, 118)
local AMBER_STROKE_COLOR = Color3.fromRGB(238, 165, 68)
local AMBER_HIGHLIGHT_COLOR = Color3.fromRGB(255, 196, 96)
local AMBER_TEXT_COLOR = Color3.fromRGB(255, 216, 132)
local GOLD_CENTER_X = 0.38
local AMBER_CENTER_X = 0.62

local TopGoldLabelView = {}

local screenGui = nil
local amountLabel = nil
local amberRootFrame = nil
local amberAmountLabel = nil
local amberButton = nil
local mountedPlayer = nil
local displayedGold = 0
local displayedAmber = 0
local animationToken = 0
local amberAnimationToken = 0
local amberActivatedHandler = nil

local function formatGold(amount)
	return string.format("$ %s", currencyFormatter.formatGold(amount))
end

local function formatAmber(amount)
	return string.format("Amber %s", currencyFormatter.formatGold(amount))
end

local function renderGold(amount)
	displayedGold = amount

	if amountLabel then
		amountLabel.Text = formatGold(amount)
	end
end

local function renderAmber(amount)
	displayedAmber = amount

	if amberAmountLabel then
		amberAmountLabel.Text = formatAmber(amount)
	end
end

local function createPill(screenGuiParent, centerX, strokeColor, highlightColor, textColor)
	local shadowFrame = Instance.new("Frame")
	shadowFrame.Name = "Shadow"
	shadowFrame.AnchorPoint = Vector2.new(0.5, 0)
	shadowFrame.Position = UDim2.new(centerX, 0, 0, TOP_PADDING + 4)
	shadowFrame.Size = UDim2.new(PILL_WIDTH_SCALE, 0, 0, LABEL_HEIGHT)
	shadowFrame.BackgroundColor3 = SHADOW_COLOR
	shadowFrame.BackgroundTransparency = 0.45
	shadowFrame.BorderSizePixel = 0
	shadowFrame.ZIndex = 0
	shadowFrame.Parent = screenGuiParent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 14)
	shadowCorner.Parent = shadowFrame

	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(centerX, 0, 0, TOP_PADDING)
	frame.Size = UDim2.new(PILL_WIDTH_SCALE, 0, 0, LABEL_HEIGHT)
	frame.BackgroundColor3 = BACKGROUND_COLOR
	frame.BorderSizePixel = 0
	frame.ZIndex = 1
	frame.Parent = screenGuiParent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GRADIENT_TOP_COLOR),
		ColorSequenceKeypoint.new(1, GRADIENT_BOTTOM_COLOR),
	})
	gradient.Rotation = 90
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 2
	stroke.Parent = frame

	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.AnchorPoint = Vector2.new(0.5, 0)
	highlight.Position = UDim2.new(0.5, 0, 0, 1)
	highlight.Size = UDim2.new(1, -18, 0, 2)
	highlight.BackgroundColor3 = highlightColor
	highlight.BackgroundTransparency = 0.2
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 2
	highlight.Parent = frame

	local highlightCorner = Instance.new("UICorner")
	highlightCorner.CornerRadius = UDim.new(1, 0)
	highlightCorner.Parent = highlight

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(INNER_HORIZONTAL_PADDING, INNER_VERTICAL_PADDING)
	label.Size = UDim2.new(1, -(INNER_HORIZONTAL_PADDING * 2), 1, -(INNER_VERTICAL_PADDING * 2))
	label.Font = Enum.Font.GothamBlack
	label.Text = ""
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextStrokeColor3 = BACKGROUND_COLOR
	label.TextStrokeTransparency = 0.5
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 3
	label.Parent = frame

	return frame, label
end

local function ensureGui(player)
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
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local goldRootFrame = nil
	goldRootFrame, amountLabel = createPill(screenGui, GOLD_CENTER_X, STROKE_COLOR, HIGHLIGHT_COLOR, TEXT_COLOR)
	amberRootFrame, amberAmountLabel =
		createPill(screenGui, AMBER_CENTER_X, AMBER_STROKE_COLOR, AMBER_HIGHLIGHT_COLOR, AMBER_TEXT_COLOR)

	amberButton = Instance.new("TextButton")
	amberButton.Name = "Button"
	amberButton.BackgroundTransparency = 1
	amberButton.Size = UDim2.fromScale(1, 1)
	amberButton.Text = ""
	amberButton.AutoButtonColor = true
	amberButton.ZIndex = 4
	amberButton.Parent = amberRootFrame
	goldRootFrame.Name = "GoldRoot"
	amberRootFrame.Name = "AmberRoot"
	amberButton.Activated:Connect(function()
		if amberActivatedHandler then
			amberActivatedHandler()
		end
	end)

	renderGold(displayedGold)
	renderAmber(displayedAmber)
end

function TopGoldLabelView.mount(player)
	mountedPlayer = player
	ensureGui(player)
end

function TopGoldLabelView.setAmberActivatedHandler(callback)
	if mountedPlayer then
		ensureGui(mountedPlayer)
	end
	amberActivatedHandler = callback
end

function TopGoldLabelView.setGold(nextAmount)
	nextAmount = math.max(0, math.floor(tonumber(nextAmount) or 0))

	if not amountLabel then
		renderGold(nextAmount)
		return
	end

	animationToken += 1
	local currentToken = animationToken
	local startAmount = displayedGold

	if startAmount == nextAmount then
		renderGold(nextAmount)
		return
	end

	local delta = nextAmount - startAmount
	local direction = delta > 0 and 1 or -1
	local distance = math.abs(delta)
	local visibleSteps = math.max(1, math.min(distance, MAX_VISIBLE_STEPS))
	local totalDuration = math.clamp(distance * SECONDS_PER_STEP, MIN_ANIMATION_DURATION, MAX_ANIMATION_DURATION)
	local stepDelay = totalDuration / visibleSteps

	task.spawn(function()
		local previousAmount = startAmount

		for stepIndex = 1, visibleSteps do
			if currentToken ~= animationToken then
				return
			end

			local progress = stepIndex / visibleSteps
			local nextDisplayAmount = startAmount + direction * math.floor(distance * progress + 0.5)

			if direction > 0 and nextDisplayAmount <= previousAmount then
				nextDisplayAmount = math.min(previousAmount + 1, nextAmount)
			elseif direction < 0 and nextDisplayAmount >= previousAmount then
				nextDisplayAmount = math.max(previousAmount - 1, nextAmount)
			end

			renderGold(nextDisplayAmount)
			previousAmount = nextDisplayAmount

			if stepIndex < visibleSteps then
				task.wait(stepDelay)
			end
		end

		if currentToken == animationToken then
			renderGold(nextAmount)
		end
	end)
end

function TopGoldLabelView.setAmber(nextAmount)
	nextAmount = math.max(0, math.floor(tonumber(nextAmount) or 0))

	if not amberAmountLabel then
		renderAmber(nextAmount)
		return
	end

	amberAnimationToken += 1
	local currentToken = amberAnimationToken
	local startAmount = displayedAmber

	if startAmount == nextAmount then
		renderAmber(nextAmount)
		return
	end

	local delta = nextAmount - startAmount
	local direction = delta > 0 and 1 or -1
	local distance = math.abs(delta)
	local visibleSteps = math.max(1, math.min(distance, MAX_VISIBLE_STEPS))
	local totalDuration = math.clamp(distance * SECONDS_PER_STEP, MIN_ANIMATION_DURATION, MAX_ANIMATION_DURATION)
	local stepDelay = totalDuration / visibleSteps

	task.spawn(function()
		local previousAmount = startAmount

		for stepIndex = 1, visibleSteps do
			if currentToken ~= amberAnimationToken then
				return
			end

			local progress = stepIndex / visibleSteps
			local nextDisplayAmount = startAmount + direction * math.floor(distance * progress + 0.5)

			if direction > 0 and nextDisplayAmount <= previousAmount then
				nextDisplayAmount = math.min(previousAmount + 1, nextAmount)
			elseif direction < 0 and nextDisplayAmount >= previousAmount then
				nextDisplayAmount = math.max(previousAmount - 1, nextAmount)
			end

			renderAmber(nextDisplayAmount)
			previousAmount = nextDisplayAmount

			if stepIndex < visibleSteps then
				task.wait(stepDelay)
			end
		end

		if currentToken == amberAnimationToken then
			renderAmber(nextAmount)
		end
	end)
end

return TopGoldLabelView
