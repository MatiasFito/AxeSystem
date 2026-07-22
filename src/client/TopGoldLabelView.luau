local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)
local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local DYNAMIC_HUD_NAME = "DynamicHUD"
local TOP_CONTAINER_PATH = { DYNAMIC_HUD_NAME, "TopContainer" }
local MIN_ANIMATION_DURATION = 0.08
local MAX_ANIMATION_DURATION = 0.5
local SECONDS_PER_STEP = 0.013
local MAX_VISIBLE_STEPS = 42

local TopGoldLabelView = {}

local screenGui = nil
local amountLabel = nil
local amberRootFrame = nil
local amberAmountLabel = nil
local amberButton = nil
local goldHubRootFrame = nil
local goldHubAmountLabel = nil
local playerGui = nil
local mountedPlayer = nil
local displayedGold = 0
local displayedAmber = 0
local displayedGoldHubBonusText = "x1.00 Total Gold"
local animationToken = 0
local amberAnimationToken = 0
local amberActivatedHandler = nil
local goldHubActivatedHandler = nil
local playerGuiChildAddedConnection = nil
local amberButtonConnection = nil
local goldHubConnection = nil

local function connectGuiActivated(instance, callback)
	if not instance or not callback then
		return nil
	end

	if instance:IsA("GuiButton") then
		return instance.Activated:Connect(callback)
	end

	if instance:IsA("GuiObject") then
		instance.Active = true
		return instance.InputEnded:Connect(function(inputObject)
			if
				inputObject.UserInputType == Enum.UserInputType.MouseButton1
				or inputObject.UserInputType == Enum.UserInputType.Touch
			then
				callback()
			end
		end)
	end

	return nil
end

local function formatGold(amount)
	return string.format("$ %s", currencyFormatter.formatGold(amount))
end

local function formatAmber(amount)
	return string.format("🔶 %s", currencyFormatter.formatGold(amount))
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

local function renderGoldHubBonusText(text)
	local resolvedText = typeof(text) == "string" and text ~= "" and text or "x1.00 Total Gold"
	displayedGoldHubBonusText = resolvedText

	if goldHubAmountLabel and goldHubAmountLabel:IsA("TextLabel") then
		goldHubAmountLabel.Text = resolvedText
	end
end

local function disconnectGuiConnections()
	if amberButtonConnection then
		amberButtonConnection:Disconnect()
		amberButtonConnection = nil
	end

	if goldHubConnection then
		goldHubConnection:Disconnect()
		goldHubConnection = nil
	end
end

local function clearGuiRefs()
	disconnectGuiConnections()
	screenGui = nil
	amountLabel = nil
	amberRootFrame = nil
	amberAmountLabel = nil
	amberButton = nil
	goldHubRootFrame = nil
	goldHubAmountLabel = nil
end

local function bindButtons()
	if amberButtonConnection then
		amberButtonConnection:Disconnect()
		amberButtonConnection = nil
	end

	if goldHubConnection then
		goldHubConnection:Disconnect()
		goldHubConnection = nil
	end

	if amberButton and amberButton:IsA("GuiButton") then
		amberButtonConnection = amberButton.Activated:Connect(function()
			if amberActivatedHandler then
				amberActivatedHandler()
			end
		end)
	end

	local goldHubActivationTarget = goldHubRootFrame and goldHubRootFrame:FindFirstChild("Button") or goldHubRootFrame
	goldHubConnection = connectGuiActivated(goldHubActivationTarget, function()
		if goldHubActivatedHandler then
			goldHubActivatedHandler()
		end
	end)
end

local function ensureGui(player)
	if screenGui and screenGui.Parent then
		return
	end

	playerGui = playerGui or GuiLocator.getPlayerGui()
	local topContainer = GuiLocator.findPath(TOP_CONTAINER_PATH)
	local existingGui = topContainer and topContainer:FindFirstAncestorWhichIsA("ScreenGui") or nil

	if not topContainer or not existingGui or existingGui.Name ~= DYNAMIC_HUD_NAME then
		clearGuiRefs()

		if not playerGuiChildAddedConnection then
			playerGuiChildAddedConnection = playerGui.ChildAdded:Connect(function(child)
				if child.Name == DYNAMIC_HUD_NAME and child:IsA("ScreenGui") then
					ensureGui(player)
				end
			end)
		end

		return
	end

	screenGui = existingGui
	local goldRootFrame = GuiLocator.findPath({ DYNAMIC_HUD_NAME, "TopContainer", "GoldRoot" })
	amberRootFrame = GuiLocator.findPath({ DYNAMIC_HUD_NAME, "TopContainer", "AmberRoot" })
	goldHubRootFrame = GuiLocator.findPath({ DYNAMIC_HUD_NAME, "TopContainer", "GoldHubRoot" })
	amountLabel = goldRootFrame and goldRootFrame:FindFirstChild("Amount") or nil
	amberAmountLabel = amberRootFrame and amberRootFrame:FindFirstChild("Amount") or nil
	amberButton = amberRootFrame and amberRootFrame:FindFirstChild("Button") or nil
	goldHubAmountLabel = goldHubRootFrame and goldHubRootFrame:FindFirstChild("Amount") or nil

	if playerGuiChildAddedConnection then
		playerGuiChildAddedConnection:Disconnect()
		playerGuiChildAddedConnection = nil
	end

	bindButtons()

	renderGold(displayedGold)
	renderAmber(displayedAmber)
	renderGoldHubBonusText(displayedGoldHubBonusText)
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
	bindButtons()
end

function TopGoldLabelView.setGoldHubActivatedHandler(callback)
	if mountedPlayer then
		ensureGui(mountedPlayer)
	end
	goldHubActivatedHandler = callback
	bindButtons()
end

function TopGoldLabelView.setGold(nextAmount)
	nextAmount = math.max(0, math.floor(tonumber(nextAmount) or 0))

	if mountedPlayer then
		ensureGui(mountedPlayer)
	end

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

	if mountedPlayer then
		ensureGui(mountedPlayer)
	end

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

function TopGoldLabelView.setGoldHubBonusText(text)
	if mountedPlayer then
		ensureGui(mountedPlayer)
	end

	renderGoldHubBonusText(text)
end

return TopGoldLabelView
