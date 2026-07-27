local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local POPUPS_HUD_NAME = "PopupsHUD"
local DAMAGE_HUB_MODAL_PATH = { POPUPS_HUD_NAME, "DamageHubModal" }
local DARK_OVERLAY_PATH = { POPUPS_HUD_NAME, "DarkOverlay" }

local DamageHubUI = {}

local started = false
local modalFrame = nil
local overlayFrame = nil
local listFrame = nil
local listLayout = nil
local titleLabel = nil
local currentAxeCardFrame = nil
local axeIcon = nil
local axeNameLabel = nil
local basePowerLabel = nil
local amberMultiplierRow = nil
local strengthWishRow = nil
local berserkerWishRow = nil
local sharpAxePassRow = nil
local vipStatusRow = nil
local totalDamageLabel = nil
local purchaseHandler = nil
local overlayConnection = nil
local sharpAxeBuyButtonConnection = nil
local vipBuyButtonConnection = nil
local listLayoutConnection = nil

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

local function setImage(instance, imageId)
	if not instance or not instance:IsA("ImageLabel") then
		return
	end

	instance.Image = typeof(imageId) == "string" and imageId or ""
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

local function disconnectConnections()
	if overlayConnection then
		overlayConnection:Disconnect()
		overlayConnection = nil
	end

	if sharpAxeBuyButtonConnection then
		sharpAxeBuyButtonConnection:Disconnect()
		sharpAxeBuyButtonConnection = nil
	end

	if vipBuyButtonConnection then
		vipBuyButtonConnection:Disconnect()
		vipBuyButtonConnection = nil
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
		bonusLabel = findDirectChild(rowFrame, "BonusLabel"),
		buyButton = findDirectChild(rowFrame, "BuyButton"),
	}
end

local function hideIgnoredRows()
	if strengthWishRow and strengthWishRow.frame then
		strengthWishRow.frame.Visible = false
	end

	if berserkerWishRow and berserkerWishRow.frame then
		berserkerWishRow.frame.Visible = false
	end
end

local function renderCurrentAxe(state)
	local axeState = state and state.currentAxe or nil
	setImage(axeIcon, axeState and axeState.imageId or "")
	setText(axeNameLabel, string.format("CURRENT AXE: %s", axeState and axeState.name or "Unknown Axe"))
	setText(basePowerLabel, string.format("Base Power: %d DMG", axeState and (axeState.baseDamage or 0) or 0))
end

local function renderMultiplierRow(row, rowState)
	if not row then
		return
	end

	if row.frame then
		row.frame.Visible = true
	end

	setText(row.bonusLabel, rowState and rowState.bonusText or "+0% DMG")
end

local function renderPassRow(row, rowState)
	if not row then
		return
	end

	if row.frame then
		row.frame.Visible = true
	end

	setText(row.bonusLabel, rowState and rowState.bonusText or "x1.0 DMG")

	if row.buyButton and row.buyButton:IsA("GuiObject") then
		local isOwned = rowState and rowState.owned == true
		row.buyButton.Visible = not isOwned

		if row.buyButton:IsA("GuiButton") then
			row.buyButton.Active = not isOwned
			row.buyButton.AutoButtonColor = not isOwned
		end
	end
end

local function bindPurchaseButtons()
	if sharpAxeBuyButtonConnection then
		sharpAxeBuyButtonConnection:Disconnect()
		sharpAxeBuyButtonConnection = nil
	end

	if vipBuyButtonConnection then
		vipBuyButtonConnection:Disconnect()
		vipBuyButtonConnection = nil
	end

	if sharpAxePassRow and sharpAxePassRow.buyButton and sharpAxePassRow.buyButton:IsA("GuiButton") then
		sharpAxeBuyButtonConnection = sharpAxePassRow.buyButton.Activated:Connect(function()
			if purchaseHandler then
				purchaseHandler("DoubleDamage")
			end
		end)
	end

	if vipStatusRow and vipStatusRow.buyButton and vipStatusRow.buyButton:IsA("GuiButton") then
		vipBuyButtonConnection = vipStatusRow.buyButton.Activated:Connect(function()
			if purchaseHandler then
				purchaseHandler("VIP")
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

	local nextModalFrame = GuiLocator.findPath(DAMAGE_HUB_MODAL_PATH)
	local nextOverlayFrame = GuiLocator.findPath(DARK_OVERLAY_PATH)
	local nextListFrame = nextModalFrame and findDirectChild(nextModalFrame, "List") or nil
	local nextCurrentAxeCardFrame = nextModalFrame and findDirectChild(nextModalFrame, "CurrentAxeCard") or nil
	local infoContainer = nextCurrentAxeCardFrame and findDirectChild(nextCurrentAxeCardFrame, "InfoContainer") or nil

	if
		not nextModalFrame
		or not nextOverlayFrame
		or not nextListFrame
		or not nextCurrentAxeCardFrame
		or not infoContainer
	then
		return
	end

	disconnectConnections()
	started = true
	modalFrame = nextModalFrame
	overlayFrame = nextOverlayFrame
	listFrame = nextListFrame
	listLayout = listFrame:FindFirstChild("ListLayout") or listFrame:FindFirstChildOfClass("UIListLayout")
	titleLabel = findDirectChild(modalFrame, "Title")
	currentAxeCardFrame = nextCurrentAxeCardFrame
	axeIcon = findDirectChild(currentAxeCardFrame, "AxeIcon")
	axeNameLabel = findDirectChild(infoContainer, "AxeNameLabel")
	basePowerLabel = findDirectChild(infoContainer, "BasePowerLabel")
	amberMultiplierRow = bindRow(findDirectChild(listFrame, "AmberMultiplierRow"))
	strengthWishRow = bindRow(findDirectChild(listFrame, "StrengthWishRow"))
	berserkerWishRow = bindRow(findDirectChild(listFrame, "BerserkerWishRow"))
	sharpAxePassRow = bindRow(findDirectChild(listFrame, "SharpAxePassRow"))
	vipStatusRow = bindRow(findDirectChild(listFrame, "VIPStatusRow"))
	totalDamageLabel = findDirectChild(modalFrame, "TotalDamageLabel")

	if listLayout then
		listLayoutConnection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
	end

	overlayConnection = connectGuiActivated(overlayFrame, function()
		DamageHubUI.close()
	end)

	bindPurchaseButtons()
	hideIgnoredRows()
	setVisible(modalFrame, false)
	setVisible(overlayFrame, false)
	updateCanvasSize()

	if titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text == "" then
		setText(titleLabel, "DAMAGE HUB")
	end
end

function DamageHubUI.setPurchaseHandler(callback)
	ensureGui()
	purchaseHandler = callback
	bindPurchaseButtons()
end

function DamageHubUI.renderState(state)
	ensureGui()
	hideIgnoredRows()
	renderCurrentAxe(state)
	renderMultiplierRow(amberMultiplierRow, state and state.amber or nil)
	renderPassRow(sharpAxePassRow, state and state.passes and state.passes.doubleDamage or nil)
	renderPassRow(vipStatusRow, state and state.passes and state.passes.vip or nil)
	setText(totalDamageLabel, state and state.totalDamageText or "TOTAL DAMAGE: 0 DMG")
	updateCanvasSize()
end

function DamageHubUI.open()
	ensureGui()
	setVisible(modalFrame, true)
	setVisible(overlayFrame, true)
end

function DamageHubUI.close()
	ensureGui()
	setVisible(modalFrame, false)
	setVisible(overlayFrame, false)
end

function DamageHubUI.isOpen()
	ensureGui()
	return modalFrame ~= nil and modalFrame.Visible == true
end

function DamageHubUI.showFailure(message)
	warn(typeof(message) == "string" and message or "Damage Hub request failed.")
	DamageHubUI.close()
end

return DamageHubUI
