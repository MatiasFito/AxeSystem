local GuiLocator = require(script.Parent:WaitForChild("GuiLocator") :: ModuleScript)

local POPUPS_HUD_NAME = "PopupsHUD"
local DIALOG_PATH = { POPUPS_HUD_NAME, "OfflineRewardDialog" }

local OfflineRewardUI = {}

local started = false
local dialogFrame = nil
local titleLabel = nil
local goldEarnedLabel = nil
local collectButton = nil
local getDoubleButton = nil

local onCollectHandler = nil
local onGetDoubleHandler = nil

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

	if instance:IsA("GuiObject") then
		instance.Visible = isVisible
	end
end

local function connectButton(button, callback)
	if not button or not callback then
		return nil
	end

	if button:IsA("GuiButton") then
		return button.Activated:Connect(callback)
	end

	return nil
end

local function ensureGui()
	if started and dialogFrame and dialogFrame.Parent then
		return
	end

	local nextDialog = GuiLocator.waitForPath(DIALOG_PATH)

	if not nextDialog or not nextDialog:IsA("Frame") then
		warn(string.format("[OfflineRewardUI] %s not found after waiting", table.concat(DIALOG_PATH, "/")))
		return
	end

	started = true
	dialogFrame = nextDialog
	titleLabel = dialogFrame:FindFirstChild("TitleLabel") :: TextLabel?
	goldEarnedLabel = dialogFrame:FindFirstChild("GoldEarnedLabel") :: TextLabel?
	local buttonBar = dialogFrame:FindFirstChild("ButtonBar") :: Frame?

	if buttonBar then
		collectButton = buttonBar:FindFirstChild("CollectButton") :: TextButton?
		getDoubleButton = buttonBar:FindFirstChild("GetDoubleButton") :: TextButton?
	end

	if collectButton then
		connectButton(collectButton, function()
			if onCollectHandler then
				onCollectHandler()
			end
		end)
	end

	if getDoubleButton then
		connectButton(getDoubleButton, function()
			if onGetDoubleHandler then
				onGetDoubleHandler()
			end
		end)
	end

	setVisible(dialogFrame, false)
end

function OfflineRewardUI.setCollectHandler(callback)
	ensureGui()
	onCollectHandler = callback
end

function OfflineRewardUI.setGetDoubleHandler(callback)
	ensureGui()
	onGetDoubleHandler = callback
end

function OfflineRewardUI.open(data)
	ensureGui()

	if not dialogFrame then
		return
	end

	if data then
		setText(titleLabel, "While You Were Gone")
		setText(goldEarnedLabel, string.format("Earned %s Gold", tostring(data.offlineGoldEarned or 0)))
		setText(
			getDoubleButton,
			string.format("Get Double (%s)", tostring(data.doubleAmount or data.offlineGoldEarned * 2 or 0))
		)
	end

	setVisible(dialogFrame, true)
end

function OfflineRewardUI.close()
	ensureGui()
	setVisible(dialogFrame, false)
end

function OfflineRewardUI.isOpen()
	ensureGui()
	return dialogFrame ~= nil and dialogFrame.Visible == true
end

return OfflineRewardUI
