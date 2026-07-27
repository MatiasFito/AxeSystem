local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local POPUPS_HUD_NAME = "PopupsHUD"
local WHISPERING_STUMP_MODAL_PATH = { POPUPS_HUD_NAME, "WhisperingStumpModal" }

local WhisperingStumpUI = {}

local started = false
local modalFrame = nil
local rollButton = nil
local rollHandler = nil

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

local function handleRollActivated()
	if rollHandler then
		rollHandler()
	end
end

local function ensureGui()
	if started and modalFrame and modalFrame.Parent then
		return
	end

	local playerGui = GuiLocator.getPlayerGui()
	local existingGui = playerGui:FindFirstChild(POPUPS_HUD_NAME)

	if not existingGui or not existingGui:IsA("ScreenGui") then
		return
	end

	local nextModalFrame = GuiLocator.findPath(WHISPERING_STUMP_MODAL_PATH)

	if not nextModalFrame or not nextModalFrame:IsA("GuiObject") then
		return
	end

	started = true
	modalFrame = nextModalFrame
	rollButton = modalFrame:FindFirstChild("RollButton")

	if rollButton and rollButton:IsA("GuiButton") then
		rollButton.Activated:Connect(handleRollActivated)
	end

	setVisible(modalFrame, false)
end

function WhisperingStumpUI.setRollHandler(handler)
	ensureGui()
	rollHandler = handler
end

function WhisperingStumpUI.open()
	ensureGui()
	setVisible(modalFrame, true)
end

function WhisperingStumpUI.close()
	ensureGui()
	setVisible(modalFrame, false)
end

return WhisperingStumpUI
