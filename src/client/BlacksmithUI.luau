local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)

local GUI_NAME = "BlacksmithGui"
local BUTTON_DISABLED_COLOR = Color3.fromRGB(157, 62, 62)

local BlacksmithUI = {}

local started = false
local screenGui = nil
local rootFrame = nil
local currentAxeCard = nil
local nextAxeCard = nil
local upgradeArrow = nil
local upgradeButton = nil
local closeButton = nil
local currentNextTierId = nil
local buttonBaseText = "Upgrade"
local upgradeHandler = nil
local closeHandler = nil
local isBusy = false
local canAttemptUpgrade = false
local currentCardSideAnchorPoint = nil
local currentCardCenterAnchorPoint = nil
local currentCardSidePosition = nil
local currentCardCenterPosition = nil
local nextCardSidePosition = nil
local upgradeButtonEnabledColor = nil

local function formatNumber(value)
	local numericValue = tonumber(value) or 0

	if math.floor(numericValue) == numericValue then
		return tostring(numericValue)
	end

	return string.format("%.1f", numericValue)
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
	upgradeButton.BackgroundColor3 = enabled and (upgradeButtonEnabledColor or upgradeButton.BackgroundColor3)
		or BUTTON_DISABLED_COLOR
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

local function setText(instance, text)
	if not instance then
		return
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.Text = text
	end
end

local function setImage(instance, imageId)
	if instance and instance:IsA("ImageLabel") then
		instance.Image = imageId or ""
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

local function findDirectChild(parent, name)
	if not parent then
		return nil
	end

	return parent:FindFirstChild(name)
end

local function findDescendantByPath(parent, path)
	local current = parent

	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)

		if not current then
			return nil
		end
	end

	return current
end

local function bindAxeCard(cardFrame)
	if not cardFrame then
		return nil
	end

	return {
		Frame = cardFrame,
		AxeImage = findDescendantByPath(cardFrame, { "AxeImage" }),
		AxeNameLabel = findDescendantByPath(cardFrame, { "AxeName" }),
		BaseDamageLabel = findDescendantByPath(cardFrame, { "BaseDamage" }),
		YourDamageLabel = findDescendantByPath(cardFrame, { "YourDamage" }),
		GoldBonusLabel = findDescendantByPath(cardFrame, { "GoldBonus" }),
	}
end

local function renderAxeCard(card, axe)
	if not card then
		return
	end

	setImage(card.AxeImage, axe and axe.imageId or "")
	setText(card.AxeNameLabel, axe and axe.name or "")
	setText(
		card.BaseDamageLabel,
		axe and string.format("Base Damage: %s", formatNumber(axe.baseDamage or axe.power or 0)) or ""
	)
	setText(
		card.YourDamageLabel,
		axe and string.format("Your Damage: %s", formatNumber(axe.finalDamage or axe.baseDamage or axe.power or 0))
			or ""
	)

	setText(card.GoldBonusLabel, axe and string.format("Gold Bonus: %s%%", formatGoldBonus(axe.goldMultiplier)) or "")
end

local function ensureGui()
	if started and screenGui and screenGui.Parent then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild(GUI_NAME)

	if not existingGui or not existingGui:IsA("ScreenGui") then
		return
	end

	started = true
	screenGui = existingGui
	rootFrame = findDirectChild(screenGui, "Root")
	currentAxeCard = bindAxeCard(rootFrame and findDescendantByPath(rootFrame, { "CurrentAxe" }) or nil)
	nextAxeCard = bindAxeCard(rootFrame and findDescendantByPath(rootFrame, { "NextAxe" }) or nil)
	upgradeArrow = rootFrame and findDescendantByPath(rootFrame, { "UpgradeArrow" }) or nil
	upgradeButton = rootFrame and findDescendantByPath(rootFrame, { "UpgradeButton" }) or nil
	closeButton = rootFrame and findDescendantByPath(rootFrame, { "CloseButton" }) or nil
	currentCardSideAnchorPoint = currentAxeCard and currentAxeCard.Frame and currentAxeCard.Frame.AnchorPoint or nil
	currentCardSidePosition = currentAxeCard and currentAxeCard.Frame and currentAxeCard.Frame.Position or nil
	nextCardSidePosition = nextAxeCard and nextAxeCard.Frame and nextAxeCard.Frame.Position or nil

	if currentCardSideAnchorPoint then
		currentCardCenterAnchorPoint = Vector2.new(0.5, currentCardSideAnchorPoint.Y)
	end

	if currentCardSidePosition then
		currentCardCenterPosition = UDim2.new(0.5, 0, currentCardSidePosition.Y.Scale, currentCardSidePosition.Y.Offset)
	end

	if upgradeButton then
		upgradeButtonEnabledColor = upgradeButton.BackgroundColor3
		upgradeButton.Activated:Connect(handleUpgradeActivated)
	end

	if closeButton then
		closeButton.Activated:Connect(handleCloseActivated)
	end

	setVisible(screenGui, false)
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

	renderAxeCard(currentAxeCard, currentAxe)

	if nextAxe then
		if currentAxeCard and currentAxeCard.Frame and currentCardSidePosition then
			if currentCardSideAnchorPoint then
				currentAxeCard.Frame.AnchorPoint = currentCardSideAnchorPoint
			end

			currentAxeCard.Frame.Position = currentCardSidePosition
		end

		if nextAxeCard and nextAxeCard.Frame and nextCardSidePosition then
			nextAxeCard.Frame.Position = nextCardSidePosition
		end

		setVisible(nextAxeCard and nextAxeCard.Frame or nil, true)
		setVisible(upgradeArrow, true)
		renderAxeCard(nextAxeCard, nextAxe)
		buttonBaseText = string.format("%s Gold", currencyFormatter.formatGold(nextAxe.cost or 0))
		currentNextTierId = state.nextTierId
		canAttemptUpgrade = state.canUpgrade == true
	else
		if currentAxeCard and currentAxeCard.Frame and currentCardCenterPosition then
			if currentCardCenterAnchorPoint then
				currentAxeCard.Frame.AnchorPoint = currentCardCenterAnchorPoint
			end

			currentAxeCard.Frame.Position = currentCardCenterPosition
		end

		setVisible(nextAxeCard and nextAxeCard.Frame or nil, false)
		setVisible(upgradeArrow, false)
		renderAxeCard(nextAxeCard, nil)
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
