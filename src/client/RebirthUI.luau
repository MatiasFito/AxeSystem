local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local STATIC_HUD_NAME = "StaticHUD"
local POPUPS_HUD_NAME = "PopupsHUD"
local REBIRTH_ROOT_PATH = { STATIC_HUD_NAME, "RightContainer", "RebirthRoot" }
local REBIRTH_MODAL_PATH = { POPUPS_HUD_NAME, "RebirthModal" }
local BUTTON_READY_COLOR = Color3.fromRGB(184, 120, 46)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(92, 92, 92)

local RebirthUI = {}

local started = false
local rootFrame = nil
local modalFrame = nil
local actionButton = nil
local statusLabel = nil
local modalMessageLabel = nil
local confirmButton = nil
local cancelButton = nil
local openHandler = nil
local confirmHandler = nil
local previewState = nil
local isBusy = false

local function formatAmount(amount)
	return tostring(math.max(0, math.floor(amount or 0)))
end

local function setText(instance, text)
	if not instance then
		return
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.Text = text
	end
end

local function findDirectChild(parent, name)
	if not parent then
		return nil
	end

	return parent:FindFirstChild(name)
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
	setText(actionButton, isBusy and "Processing..." or "Rebirth")
	setText(statusLabel, buildStatusText(previewState))
end

local function closeModal()
	if modalFrame then
		modalFrame.Visible = false
	end
end

local function updateModalMessage(state)
	if not modalMessageLabel then
		return
	end

	local amberReward = typeof(state) == "table" and state.estimatedAmber or 0
	setText(modalMessageLabel, string.format("Are you sure? You will receive %s Amber.", formatAmount(amberReward)))
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
local function ensureGui()
	if started and rootFrame and rootFrame.Parent and modalFrame and modalFrame.Parent then
		return
	end
	previewState = {
		isEligible = false,
		minimumPlotOrder = 10,
		maxUnlockedPlotOrder = 0,
		estimatedAmber = 0,
	}

	local playerGui = GuiLocator.getPlayerGui()
	local staticHud = playerGui:FindFirstChild(STATIC_HUD_NAME)
	local popupsHud = playerGui:FindFirstChild(POPUPS_HUD_NAME)

	if not staticHud or not staticHud:IsA("ScreenGui") or not popupsHud or not popupsHud:IsA("ScreenGui") then
		return
	end

	local nextRootFrame = GuiLocator.findPath(REBIRTH_ROOT_PATH)
	local nextModalFrame = GuiLocator.findPath(REBIRTH_MODAL_PATH)
	local modalContentFrame = nextModalFrame and findDirectChild(nextModalFrame, "Modal") or nil

	if not nextRootFrame or not nextModalFrame or not modalContentFrame then
		return
	end

	started = true
	rootFrame = nextRootFrame
	modalFrame = nextModalFrame
	actionButton = rootFrame and findDirectChild(rootFrame, "RebirthButton") or nil
	statusLabel = rootFrame and findDirectChild(rootFrame, "StatusLabel") or nil
	modalMessageLabel = findDirectChild(modalContentFrame, "MessageLabel")
	confirmButton = findDirectChild(modalContentFrame, "ConfirmButton")
	cancelButton = findDirectChild(modalContentFrame, "CancelButton")

	if actionButton and actionButton:IsA("GuiButton") then
		actionButton.Activated:Connect(handleButtonActivated)
	end

	if confirmButton and confirmButton:IsA("GuiButton") then
		confirmButton.Activated:Connect(handleConfirmActivated)
	end

	if cancelButton and cancelButton:IsA("GuiButton") then
		cancelButton.Activated:Connect(closeModal)
	end

	if modalFrame then
		modalFrame.Visible = false
	end

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
	setText(confirmButton, isBusy and "Processing..." or "Confirm")
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
	if modalFrame then
		modalFrame.Visible = true
	end
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
