local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)
local leaderstatsWatcher = require(utilsFolder:WaitForChild("LeaderstatsWatcher") :: ModuleScript)
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)
local timeSync = require(utilsFolder:WaitForChild("TimeSync") :: ModuleScript)
local TreePlotCard = require(script.Parent:WaitForChild("TreePlotCard") :: ModuleScript)

local GUI_NAME = "TreeUpgradePads"
local REMOTE_WAIT_TIMEOUT = 10
local REFRESH_RATE = 0.05
local PAD_CARD_SCALE = 1.5
local PAD_CARD_BASE_WIDTH = 188
local PAD_HORIZONTAL_PADDING = 12
local PAD_TOP_PADDING = 12
local PAD_BUTTON_GAP = 18
local PAD_BUTTON_HEIGHT = 48
local PAD_BUTTON_HORIZONTAL_PADDING = 16
local PAD_BUTTON_VERTICAL_PADDING = 4
local PAD_BOTTOM_PADDING = 14

local PANEL_COLOR = Color3.fromRGB(35, 44, 33)
local PANEL_HIGHLIGHT = Color3.fromRGB(52, 69, 48)
local PANEL_STROKE = Color3.fromRGB(210, 229, 201)
local LABEL_COLOR = Color3.fromRGB(244, 247, 237)
local GREEN_COLOR = Color3.fromRGB(101, 197, 95)
local RED_COLOR = Color3.fromRGB(196, 84, 84)
local MAX_COLOR = Color3.fromRGB(91, 102, 88)

local PAD_CARD_LAYOUT = TreePlotCard.scaleLayout(TreePlotCard.DEFAULT_LAYOUT, PAD_CARD_SCALE)
local PAD_CARD_WIDTH = math.floor(PAD_CARD_BASE_WIDTH * PAD_CARD_SCALE + 0.5)
local PAD_BUTTON_WIDTH = math.floor(PAD_CARD_WIDTH * 0.78 + 0.5)
local PAD_ROOT_WIDTH = PAD_CARD_WIDTH + (PAD_HORIZONTAL_PADDING * 2)
local PAD_ROOT_HEIGHT = PAD_TOP_PADDING
	+ PAD_CARD_LAYOUT.FrameSize.Y.Offset
	+ PAD_BUTTON_GAP
	+ PAD_BUTTON_HEIGHT
	+ PAD_BOTTOM_PADDING

PAD_CARD_LAYOUT.FrameSize = UDim2.fromOffset(PAD_CARD_WIDTH, PAD_CARD_LAYOUT.FrameSize.Y.Offset)
PAD_CARD_LAYOUT.FramePosition = UDim2.fromOffset(PAD_HORIZONTAL_PADDING, PAD_TOP_PADDING)

local TreeUpgradePadController = {}

local started = false
local rootGui = nil
local getTreeStateRemote = nil
local treeStateUpdatedRemote = nil
local requestTreeUpgradeRemote = nil

local plotSetId = nil
local goldAmount = 0
local plotStatesById = {}
local padUisByPlotId = {}
local disconnectLeaderstatsWatcher = nil
local serverTimeAtSync = 0
local localClockAtSync = 0
local lastRefreshAt = 0

local function getOwnedPlotSetFolder()
	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		return nil
	end

	local plotSetsFolder = Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)

	if not plotSetsFolder then
		return nil
	end

	return plotSetsFolder:FindFirstChild(plotSetId)
end

local function getPlotModel(plotId)
	local plotSetFolder = getOwnedPlotSetFolder()

	if not plotSetFolder or typeof(plotId) ~= "string" then
		return nil
	end

	local generatedFolder = plotSetFolder:FindFirstChild(treeConstants.TREE_PLOT_GENERATED_FOLDER_NAME)

	if generatedFolder and generatedFolder:IsA("Folder") then
		return generatedFolder:FindFirstChild(plotId)
	end

	return plotSetFolder:FindFirstChild(plotId)
end

local function getPlotDirtPatch(plotId)
	local plotModel = getPlotModel(plotId)

	if not plotModel then
		return nil
	end

	local dirtPatch = plotModel:FindFirstChild(treeConstants.DIRT_PATCH_NAME)

	if dirtPatch and dirtPatch:IsA("BasePart") then
		return dirtPatch
	end

	return nil
end

local function destroyPad(plotId)
	local padUi = padUisByPlotId[plotId]

	if not padUi then
		return
	end

	if padUi.Gui then
		padUi.Gui:Destroy()
	end

	padUisByPlotId[plotId] = nil
end

local function destroyAllPads()
	for plotId in padUisByPlotId do
		destroyPad(plotId)
	end
end

local function ensureRootGui()
	if rootGui then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild(GUI_NAME)

	if existingGui and existingGui:IsA("ScreenGui") then
		existingGui:Destroy()
	end

	rootGui = Instance.new("ScreenGui")
	rootGui.Name = GUI_NAME
	rootGui.ResetOnSpawn = false
	rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	rootGui.Parent = playerGui
end

local function createPadUi(plotId, dirtPatch)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = string.format("%sPad", plotId)
	surfaceGui.Adornee = dirtPatch
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 80
	surfaceGui.PixelsPerStud = 34
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = rootGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rootFrame.Position = UDim2.fromScale(0.72, 0.5)
	rootFrame.Size = UDim2.fromOffset(PAD_ROOT_WIDTH, PAD_ROOT_HEIGHT)
	rootFrame.Rotation = -90
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BackgroundTransparency = 0.06
	rootFrame.BorderSizePixel = 0
	rootFrame.Parent = surfaceGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = rootFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = PANEL_STROKE
	stroke.Thickness = 2
	stroke.Parent = rootFrame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_HIGHLIGHT),
		ColorSequenceKeypoint.new(1, PANEL_COLOR),
	})
	gradient.Rotation = 90
	gradient.Parent = rootFrame

	local card = TreePlotCard.create(rootFrame, "InfoCard", PAD_CARD_LAYOUT)

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.AnchorPoint = Vector2.new(0.5, 0)
	upgradeButton.Position = UDim2.new(0.5, 0, 0, PAD_TOP_PADDING + PAD_CARD_LAYOUT.FrameSize.Y.Offset + PAD_BUTTON_GAP)
	upgradeButton.Size = UDim2.fromOffset(PAD_BUTTON_WIDTH, PAD_BUTTON_HEIGHT)
	upgradeButton.AutoButtonColor = false
	upgradeButton.BorderSizePixel = 0
	upgradeButton.Font = Enum.Font.GothamBlack
	upgradeButton.Text = "0 GOLD"
	upgradeButton.TextColor3 = LABEL_COLOR
	upgradeButton.TextScaled = true
	upgradeButton.Parent = rootFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 14)
	buttonCorner.Parent = upgradeButton

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = PANEL_STROKE
	buttonStroke.Thickness = 1.5
	buttonStroke.Parent = upgradeButton

	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingLeft = UDim.new(0, PAD_BUTTON_HORIZONTAL_PADDING)
	buttonPadding.PaddingRight = UDim.new(0, PAD_BUTTON_HORIZONTAL_PADDING)
	buttonPadding.PaddingTop = UDim.new(0, PAD_BUTTON_VERTICAL_PADDING)
	buttonPadding.PaddingBottom = UDim.new(0, PAD_BUTTON_VERTICAL_PADDING)
	buttonPadding.Parent = upgradeButton

	upgradeButton.Activated:Connect(function()
		local plotState = plotStatesById[plotId]

		if not plotState or plotState.isMaxLevel or plotState.upgradeCost == nil then
			return
		end

		requestTreeUpgradeRemote:FireServer(plotId)
	end)

	padUisByPlotId[plotId] = {
		Gui = surfaceGui,
		Card = card,
		UpgradeButton = upgradeButton,
	}

	return padUisByPlotId[plotId]
end

local function renderPad(plotId)
	local plotState = plotStatesById[plotId]

	if not plotState or not plotState.unlocked then
		destroyPad(plotId)
		return
	end

	local dirtPatch = getPlotDirtPatch(plotId)

	if not dirtPatch then
		destroyPad(plotId)
		return
	end

	local padUi = padUisByPlotId[plotId]

	if not padUi or not padUi.Gui or padUi.Gui.Adornee ~= dirtPatch then
		destroyPad(plotId)
		padUi = createPadUi(plotId, dirtPatch)
	end

	TreePlotCard.render(padUi.Card, plotState, {
		estimatedServerTime = timeSync.estimateServerTime(serverTimeAtSync, localClockAtSync),
	})

	if plotState.isMaxLevel or plotState.upgradeCost == nil then
		padUi.UpgradeButton.Text = "MAX"
		padUi.UpgradeButton.BackgroundColor3 = MAX_COLOR
		padUi.UpgradeButton.Active = false
		return
	end

	local canAfford = goldAmount >= plotState.upgradeCost
	padUi.UpgradeButton.Text = string.format("%s GOLD", currencyFormatter.formatGold(plotState.upgradeCost))
	padUi.UpgradeButton.BackgroundColor3 = canAfford and GREEN_COLOR or RED_COLOR
	padUi.UpgradeButton.Active = true
end

local function rerenderPads()
	for plotId in plotStatesById do
		renderPad(plotId)
	end

	for plotId in padUisByPlotId do
		if not plotStatesById[plotId] or not plotStatesById[plotId].unlocked then
			destroyPad(plotId)
		end
	end

	lastRefreshAt = os.clock()
end

local function applyState(state)
	if typeof(state) ~= "table" then
		return
	end

	serverTimeAtSync = tonumber(state.serverTime) or serverTimeAtSync
	localClockAtSync = os.clock()

	if typeof(state.plotSetId) == "string" and state.plotSetId ~= plotSetId then
		plotSetId = state.plotSetId
		destroyAllPads()
	end

	for _, plotState in state.plots or {} do
		plotStatesById[plotState.plotId] = plotState
	end

	rerenderPads()
end

local function bindLeaderstats()
	if disconnectLeaderstatsWatcher then
		disconnectLeaderstatsWatcher()
		disconnectLeaderstatsWatcher = nil
	end

	disconnectLeaderstatsWatcher = leaderstatsWatcher.watchIntValue(player, "Gold", REMOTE_WAIT_TIMEOUT, function(value)
		goldAmount = value
		rerenderPads()
	end)
end

local function resolveRemotes()
	local treesFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remotes folder was not found for upgrade pads",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found for upgrade pads",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(treesFolder, {
		treeConstants.GET_STATE_REMOTE_NAME,
		treeConstants.STATE_UPDATED_REMOTE_NAME,
		treeConstants.REQUEST_UPGRADE_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Tree remote")

	if not remotes then
		return false
	end

	getTreeStateRemote = remotes[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	treeStateUpdatedRemote = remotes[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent
	requestTreeUpgradeRemote = remotes[treeConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteEvent

	return getTreeStateRemote ~= nil and treeStateUpdatedRemote ~= nil and requestTreeUpgradeRemote ~= nil
end

local function requestInitialState()
	if not getTreeStateRemote then
		return
	end

	local success, payload = pcall(function()
		return getTreeStateRemote:InvokeServer()
	end)

	if success and payload and payload.success then
		applyState(payload.state)
	end
end

function TreeUpgradePadController.start()
	if started then
		return
	end

	started = true
	ensureRootGui()

	if not resolveRemotes() then
		return
	end

	bindLeaderstats()
	treeStateUpdatedRemote.OnClientEvent:Connect(applyState)
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastRefreshAt >= REFRESH_RATE then
			rerenderPads()
		end
	end)
	requestInitialState()
end

return TreeUpgradePadController
