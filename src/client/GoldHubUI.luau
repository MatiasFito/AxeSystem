local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local sessionTimeConfig = require(sharedFolder:WaitForChild("SessionTimeConfig") :: ModuleScript)
local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local POPUPS_HUD_NAME = "PopupsHUD"
local GOLD_HUB_MODAL_PATH = { POPUPS_HUD_NAME, "GoldHubModal" }
local DARK_OVERLAY_PATH = { POPUPS_HUD_NAME, "DarkOverlay" }
local OWNED_BUTTON_COLOR = Color3.fromRGB(84, 84, 84)

local GoldHubUI = {}

local started = false
local modalFrame = nil
local overlayFrame = nil
local rootFrame = nil
local listFrame = nil
local listLayout = nil
local titleLabel = nil
local totalPowerLabel = nil
local axeBonusRow = nil
local amberBonusRow = nil
local rebirthBonusRow = nil
local premiumBonusRow = nil
local playTimeContainer = nil
local vipGamePassRow = nil
local doubleGoldGamePassRow = nil
local renderedState = nil
local purchaseHandler = nil
local overlayConnection = nil
local vipBuyButtonConnection = nil
local doubleGoldBuyButtonConnection = nil
local listLayoutConnection = nil
local sessionTickerToken = 0
local sessionBaseSeconds = 0
local sessionRenderedAt = 0
local progressBarFillBaseSize = nil
local vipBuyButtonBaseColor = nil
local doubleGoldBuyButtonBaseColor = nil

local function findDirectChild(parent, name)
	if not parent then
		return nil
	end

	return parent:FindFirstChild(name)
end

local function setText(instance, text)
	if not instance then
		return
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.Text = text
	end
end

local function setVisible(instance, isVisible)
	if not instance then
		return
	end

	if instance:IsA("ScreenGui") then
		instance.Enabled = isVisible
		return
	end

	if instance:IsA("GuiObject") then
		instance.Visible = isVisible
	end
end

local function sanitizeMultiplier(multiplier)
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function toBonusPercent(multiplier)
	return math.max(0, math.floor(((sanitizeMultiplier(multiplier) - 1) * 100) + 0.5))
end

local function formatPercentBonus(multiplier)
	return string.format("+%d%% Gold", toBonusPercent(multiplier))
end

local function formatDuration(totalSeconds)
	local resolvedSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
	local minutes = math.floor(resolvedSeconds / 60)
	local seconds = resolvedSeconds % 60
	return string.format("%d:%02d", minutes, seconds)
end

local function disconnectConnections()
	if overlayConnection then
		overlayConnection:Disconnect()
		overlayConnection = nil
	end

	if vipBuyButtonConnection then
		vipBuyButtonConnection:Disconnect()
		vipBuyButtonConnection = nil
	end

	if doubleGoldBuyButtonConnection then
		doubleGoldBuyButtonConnection:Disconnect()
		doubleGoldBuyButtonConnection = nil
	end

	if listLayoutConnection then
		listLayoutConnection:Disconnect()
		listLayoutConnection = nil
	end
end

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

local function updateCanvasSize()
	if not listFrame or not listLayout then
		return
	end

	listFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 12)
end

local function bindRow(rowFrame)
	return {
		frame = rowFrame,
		icon = findDirectChild(rowFrame, "Icon"),
		nameLabel = findDirectChild(rowFrame, "NameLabel"),
		bonusLabel = findDirectChild(rowFrame, "BonusLabel"),
		buyButton = findDirectChild(rowFrame, "BuyButton"),
	}
end

local function bindPlayTimeContainer(container)
	local mainRow = container and findDirectChild(container, "MainRow") or nil
	local subRow = container and findDirectChild(container, "SubRow") or nil
	local progressBarBackground = subRow and findDirectChild(subRow, "ProgressBarBg") or nil
	local progressBarFill = progressBarBackground and findDirectChild(progressBarBackground, "ProgressBarFill") or nil

	return {
		frame = container,
		mainRow = mainRow,
		subRow = subRow,
		timerLabel = mainRow and findDirectChild(mainRow, "TimerLabel") or nil,
		bonusLabel = mainRow and findDirectChild(mainRow, "BonusLabel") or nil,
		countdownLabel = subRow and findDirectChild(subRow, "CountdownLabel") or nil,
		progressBarFill = progressBarFill,
	}
end

local function hideIgnoredRows() end

local function stopSessionTicker()
	sessionTickerToken += 1
end

local function buildSessionDisplay(sessionSeconds)
	local tiers = sessionTimeConfig.getTiers()
	local resolvedSessionSeconds = math.max(0, math.floor(tonumber(sessionSeconds) or 0))
	local currentLevel = 0

	for index, tier in ipairs(tiers) do
		if resolvedSessionSeconds < (tier.TimeRequired or 0) then
			break
		end

		currentLevel = index
	end

	local currentTier = currentLevel > 0 and tiers[currentLevel] or nil
	local nextTier = tiers[currentLevel + 1]
	local currentThreshold = currentTier and currentTier.TimeRequired or 0
	local nextThreshold = nextTier and nextTier.TimeRequired or currentThreshold
	local multiplier = sanitizeMultiplier(sessionTimeConfig.getGoldMultiplier(resolvedSessionSeconds))
	local progressAlpha = 1
	local countdownText = "Max tier reached"

	if nextTier then
		local thresholdRange = math.max(1, nextThreshold - currentThreshold)
		local remainingSeconds = math.max(0, nextThreshold - resolvedSessionSeconds)
		progressAlpha = math.clamp((resolvedSessionSeconds - currentThreshold) / thresholdRange, 0, 1)
		countdownText = string.format("Next in %s", formatDuration(remainingSeconds))
	end

	return {
		level = currentLevel,
		multiplier = multiplier,
		bonusText = formatPercentBonus(multiplier),
		countdownText = countdownText,
		progressAlpha = progressAlpha,
	}
end

local function renderSessionTime(sessionSeconds)
	if not playTimeContainer then
		return
	end

	local display = buildSessionDisplay(sessionSeconds)
	setText(playTimeContainer.timerLabel, string.format("LVL %d", display.level))
	setText(playTimeContainer.bonusLabel, display.bonusText)
	setText(playTimeContainer.countdownLabel, display.countdownText)

	if playTimeContainer.progressBarFill then
		local baseSize = progressBarFillBaseSize or playTimeContainer.progressBarFill.Size
		progressBarFillBaseSize = baseSize
		playTimeContainer.progressBarFill.Size =
			UDim2.new(display.progressAlpha, 0, baseSize.Y.Scale, baseSize.Y.Offset)
	end
end

local function startSessionTicker()
	stopSessionTicker()
	sessionTickerToken += 1
	local currentToken = sessionTickerToken

	task.spawn(function()
		while currentToken == sessionTickerToken do
			if not GoldHubUI.isOpen() then
				return
			end

			local elapsedSeconds = math.max(0, math.floor(os.clock() - sessionRenderedAt))
			renderSessionTime(sessionBaseSeconds + elapsedSeconds)
			task.wait(1)
		end
	end)
end

local function renderBonusRow(row, defaultName, rowState)
	if not row then
		return
	end

	if row.frame then
		row.frame.Visible = true
	end

	setText(row.nameLabel, defaultName)
	setText(row.bonusLabel, rowState and rowState.bonusText or formatPercentBonus(1))
end

local function renderPassRow(row, defaultName, rowState)
	if not row then
		return
	end

	setText(row.nameLabel, defaultName)
	setText(row.bonusLabel, rowState and rowState.bonusText or formatPercentBonus(2))

	if row.buyButton and row.buyButton:IsA("TextButton") then
		local owned = rowState and rowState.owned == true
		row.buyButton.Active = not owned
		row.buyButton.AutoButtonColor = not owned
		row.buyButton.Text = owned and "Owned" or "Buy"

		if row == vipGamePassRow then
			vipBuyButtonBaseColor = vipBuyButtonBaseColor or row.buyButton.BackgroundColor3
			row.buyButton.BackgroundColor3 = owned and OWNED_BUTTON_COLOR or vipBuyButtonBaseColor
		elseif row == doubleGoldGamePassRow then
			doubleGoldBuyButtonBaseColor = doubleGoldBuyButtonBaseColor or row.buyButton.BackgroundColor3
			row.buyButton.BackgroundColor3 = owned and OWNED_BUTTON_COLOR or doubleGoldBuyButtonBaseColor
		end
	end
end

local function bindPurchaseButtons()
	if vipBuyButtonConnection then
		vipBuyButtonConnection:Disconnect()
		vipBuyButtonConnection = nil
	end

	if doubleGoldBuyButtonConnection then
		doubleGoldBuyButtonConnection:Disconnect()
		doubleGoldBuyButtonConnection = nil
	end

	if vipGamePassRow and vipGamePassRow.buyButton and vipGamePassRow.buyButton:IsA("GuiButton") then
		vipBuyButtonConnection = vipGamePassRow.buyButton.Activated:Connect(function()
			if purchaseHandler then
				purchaseHandler(gamePassConfig.Pass.VIP)
			end
		end)
	end

	if
		doubleGoldGamePassRow
		and doubleGoldGamePassRow.buyButton
		and doubleGoldGamePassRow.buyButton:IsA("GuiButton")
	then
		doubleGoldBuyButtonConnection = doubleGoldGamePassRow.buyButton.Activated:Connect(function()
			if purchaseHandler then
				purchaseHandler(gamePassConfig.Pass.DoubleGold)
			end
		end)
	end
end

local function ensureGui()
	if started and modalFrame and modalFrame.Parent and overlayFrame and overlayFrame.Parent then
		return
	end

	local playerGui = GuiLocator.getPlayerGui()
	local popupsHud = playerGui:FindFirstChild(POPUPS_HUD_NAME)

	if not popupsHud or not popupsHud:IsA("ScreenGui") then
		return
	end

	local nextModalFrame = GuiLocator.findPath(GOLD_HUB_MODAL_PATH)
	local nextOverlayFrame = GuiLocator.findPath(DARK_OVERLAY_PATH)
	local nextRootFrame = nextModalFrame and findDirectChild(nextModalFrame, "Root") or nil
	local nextListFrame = nextRootFrame and findDirectChild(nextRootFrame, "List") or nil

	if not nextModalFrame or not nextOverlayFrame or not nextRootFrame or not nextListFrame then
		return
	end

	disconnectConnections()
	started = true
	modalFrame = nextModalFrame
	overlayFrame = nextOverlayFrame
	rootFrame = nextRootFrame
	listFrame = nextListFrame
	listLayout = listFrame:FindFirstChild("ListLayout") or listFrame:FindFirstChildOfClass("UIListLayout")
	titleLabel = findDirectChild(rootFrame, "Title")
	totalPowerLabel = findDirectChild(rootFrame, "TotalPowerLabel")
	axeBonusRow = bindRow(findDirectChild(listFrame, "AxeBonusRow"))
	amberBonusRow = bindRow(findDirectChild(listFrame, "AmberBonusRow"))
	rebirthBonusRow = bindRow(findDirectChild(listFrame, "RebirthBonusRow"))
	premiumBonusRow = bindRow(findDirectChild(listFrame, "PremiumBonusRow"))
	playTimeContainer = bindPlayTimeContainer(findDirectChild(listFrame, "PlayTimeContainer"))
	vipGamePassRow = bindRow(findDirectChild(listFrame, "VipGamePass"))
	doubleGoldGamePassRow = bindRow(findDirectChild(listFrame, "x2GoldGamePass"))
	vipBuyButtonBaseColor = vipGamePassRow and vipGamePassRow.buyButton and vipGamePassRow.buyButton.BackgroundColor3
		or nil
	doubleGoldBuyButtonBaseColor = doubleGoldGamePassRow
			and doubleGoldGamePassRow.buyButton
			and doubleGoldGamePassRow.buyButton.BackgroundColor3
		or nil

	if listLayout then
		listLayoutConnection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
	end

	overlayConnection = connectGuiActivated(overlayFrame, function()
		GoldHubUI.close()
	end)

	bindPurchaseButtons()
	hideIgnoredRows()
	setVisible(modalFrame, false)
	setVisible(overlayFrame, false)
	updateCanvasSize()
	setText(titleLabel, "Gold Hub")
end

function GoldHubUI.setPurchaseHandler(callback)
	ensureGui()
	purchaseHandler = callback
	bindPurchaseButtons()
end

function GoldHubUI.renderState(state)
	ensureGui()
	renderedState = state
	hideIgnoredRows()
	renderBonusRow(axeBonusRow, "Axe Bonus", state and state.axe or nil)
	renderBonusRow(amberBonusRow, "Amber Bonus", state and state.amber or nil)
	renderBonusRow(rebirthBonusRow, "Rebirth Bonus", state and state.rebirth or nil)
	renderBonusRow(premiumBonusRow, "Premium Bonus", state and state.premium or nil)
	renderPassRow(vipGamePassRow, "VIP", state and state.passes and state.passes.vip or nil)
	renderPassRow(doubleGoldGamePassRow, "x2 Gold", state and state.passes and state.passes.doubleGold or nil)
	setText(totalPowerLabel, state and state.totalBonusText or "x1.00 Total Gold")
	sessionBaseSeconds = state and state.sessionTime and state.sessionTime.sessionSeconds or 0
	sessionRenderedAt = os.clock()
	renderSessionTime(sessionBaseSeconds)
	updateCanvasSize()

	if GoldHubUI.isOpen() then
		startSessionTicker()
	end
end

function GoldHubUI.open()
	ensureGui()
	setVisible(modalFrame, true)
	setVisible(overlayFrame, true)
	if renderedState then
		sessionRenderedAt = os.clock()
		startSessionTicker()
	end
end

function GoldHubUI.close()
	ensureGui()
	stopSessionTicker()
	setVisible(modalFrame, false)
	setVisible(overlayFrame, false)
end

function GoldHubUI.isOpen()
	ensureGui()
	return modalFrame ~= nil and modalFrame.Visible == true
end

function GoldHubUI.showFailure(message)
	warn(typeof(message) == "string" and message or "Gold Hub request failed.")
	GoldHubUI.close()
end

return GoldHubUI
