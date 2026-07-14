local Players = game:GetService("Players")

local player = Players.LocalPlayer

local AmberShopUI = {}

local GUI_NAME = "AmberShopGui"

local GREEN_BUTTON_COLOR = Color3.fromRGB(69, 164, 90)
local RED_BUTTON_COLOR = Color3.fromRGB(133, 83, 78)
local LOCKED_BUTTON_COLOR = Color3.fromRGB(84, 84, 84)

local started = false
local screenGui = nil
local modalOverlay = nil
local rootFrame = nil
local balanceLabel = nil
local statusLabel = nil
local scrollingFrame = nil
local listLayout = nil
local closeButton = nil
local cardTemplate = nil
local upgradeHandler = nil
local closeHandler = nil
local busyUpgradeKey = nil
local renderedState = nil

local function formatAmber(amount)
	return tostring(math.max(0, math.floor(tonumber(amount) or 0)))
end

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

local function findCardTemplateCandidate()
	if not scrollingFrame then
		return nil
	end

	local explicitTemplate = findDirectChild(rootFrame, "CardTemplate")
		or findDirectChild(scrollingFrame, "CardTemplate")

	if explicitTemplate and explicitTemplate:IsA("Frame") then
		return explicitTemplate
	end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") and string.sub(child.Name, 1, 5) == "Card_" then
			return child
		end
	end

	return nil
end

local function bindCardTemplate()
	if cardTemplate and cardTemplate.Parent then
		return cardTemplate
	end

	local template = findCardTemplateCandidate()

	if not template then
		return nil
	end

	template.Name = "CardTemplate"
	template.Visible = false

	if rootFrame and template.Parent ~= rootFrame then
		template.Parent = rootFrame
	end

	cardTemplate = template
	return cardTemplate
end

local function clearCards()
	if not scrollingFrame then
		return
	end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child ~= listLayout and child ~= cardTemplate and not child:IsA("UIPadding") then
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
	modalOverlay = findDirectChild(screenGui, "Overlay")
	rootFrame = (modalOverlay and findDirectChild(modalOverlay, "Root")) or findDirectChild(screenGui, "Root")
	balanceLabel = rootFrame and findDirectChild(rootFrame, "Balance") or nil
	statusLabel = rootFrame and findDirectChild(rootFrame, "Status") or nil
	scrollingFrame = rootFrame and findDirectChild(rootFrame, "ScrollingFrame") or nil
	listLayout = scrollingFrame and scrollingFrame:FindFirstChildOfClass("UIListLayout") or nil
	closeButton = rootFrame and findDirectChild(rootFrame, "CloseButton") or nil

	if listLayout then
		listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
	end

	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.Activated:Connect(handleCloseActivated)
	end

	bindCardTemplate()
	screenGui.Enabled = false
end

local function renderUpgradeCard(layoutOrder, upgradeState)
	local template = bindCardTemplate()

	if not template or not scrollingFrame then
		return
	end

	local cardFrame = template:Clone()
	cardFrame.Name = string.format("Card_%s", upgradeState.key)
	cardFrame.LayoutOrder = layoutOrder
	cardFrame.Visible = true
	cardFrame.Parent = scrollingFrame

	local comparisonLabel = findDirectChild(cardFrame, "Comparison")
	setText(findDirectChild(cardFrame, "Title"), upgradeState.displayName or upgradeState.key)
	setText(
		findDirectChild(cardFrame, "Level"),
		string.format("Lvl %d / %d", upgradeState.level or 0, upgradeState.maxLevel or 25)
	)
	setText(findDirectChild(cardFrame, "Description"), upgradeState.description or "")

	if upgradeState.isMaxLevel then
		setText(comparisonLabel, string.format("Current: %s (MAX LEVEL)", upgradeState.currentText or ""))
	else
		setText(
			comparisonLabel,
			string.format("Current: %s   ===>   Next: %s", upgradeState.currentText or "", upgradeState.nextText or "")
		)
	end

	local upgradeButton = findDirectChild(cardFrame, "UpgradeButton")

	if not upgradeButton or not upgradeButton:IsA("GuiButton") then
		return
	end

	local isBusy = busyUpgradeKey == upgradeState.key

	if upgradeState.isMaxLevel then
		upgradeButton.BackgroundColor3 = LOCKED_BUTTON_COLOR
		setText(upgradeButton, "[ MAX LEVEL ]")
		upgradeButton.Active = false
		upgradeButton.AutoButtonColor = false
	elseif isBusy then
		upgradeButton.BackgroundColor3 = GREEN_BUTTON_COLOR
		setText(upgradeButton, "Processing...")
		upgradeButton.Active = false
		upgradeButton.AutoButtonColor = false
	else
		upgradeButton.BackgroundColor3 = upgradeState.canAfford and GREEN_BUTTON_COLOR or RED_BUTTON_COLOR
		setText(upgradeButton, string.format("[ UPGRADE: %s ]", formatAmber(upgradeState.costToNextLevel or 0)))
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
	setText(statusLabel, "")
	rerender()
end

function AmberShopUI.setBusy(upgradeKey, isBusy)
	ensureGui()
	busyUpgradeKey = isBusy and upgradeKey or nil
	rerender()
end

function AmberShopUI.showFailure(message)
	ensureGui()
	setText(statusLabel, typeof(message) == "string" and message or "Amber shop request failed.")
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
	return screenGui ~= nil and screenGui.Enabled == true
end

return AmberShopUI
