local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)
local leaderstatsWatcher = require(utilsFolder:WaitForChild("LeaderstatsWatcher") :: ModuleScript)
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local LumberjackUpgradePadController = {}

local GUI_NAME = "LumberjackUpgradePads"
local REMOTE_WAIT_TIMEOUT = 10
local REFRESH_RATE = 0.05

local PANEL_COLOR = Color3.fromRGB(58, 44, 34)
local PANEL_HIGHLIGHT = Color3.fromRGB(92, 68, 48)
local PANEL_STROKE = Color3.fromRGB(233, 220, 194)
local LABEL_COLOR = Color3.fromRGB(246, 241, 232)
local SUBTLE_COLOR = Color3.fromRGB(214, 201, 182)
local GREEN_COLOR = Color3.fromRGB(101, 197, 95)
local RED_COLOR = Color3.fromRGB(196, 84, 84)
local MAX_COLOR = Color3.fromRGB(91, 102, 88)

local started = false
local rootGui = nil
local getTreeStateRemote = nil
local treeStateUpdatedRemote = nil
local requestLumberjackUpgradeRemote = nil

local plotSetId = nil
local goldAmount = 0
local plotStatesById = {}
local padUisByPlotId = {}
local disconnectLeaderstatsWatcher = nil
local lastRefreshAt = 0

local function getOwnedRuntimeFolder()
	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		return nil
	end

	local runtimeFolder = Workspace:FindFirstChild(lumberjackConstants.RUNTIME_FOLDER_NAME)

	if not runtimeFolder then
		return nil
	end

	return runtimeFolder:FindFirstChild(plotSetId)
end

local function getUpgradePadPart(plotId)
	local runtimeFolder = getOwnedRuntimeFolder()

	if not runtimeFolder or typeof(plotId) ~= "string" then
		return nil
	end

	local modelName = string.format("%s%s", plotId, lumberjackConstants.MODEL_NAME_SUFFIX)
	local lumberjackModel = runtimeFolder:FindFirstChild(modelName)

	if not lumberjackModel then
		for _, child in runtimeFolder:GetChildren() do
			if child:GetAttribute(treeConstants.TREE_PLOT_ID_ATTRIBUTE) == plotId then
				lumberjackModel = child
				break
			end
		end
	end

	if not lumberjackModel then
		return nil
	end

	local padPart = lumberjackModel:FindFirstChild(lumberjackConstants.UPGRADE_PAD_PART_NAME)

	if padPart and padPart:IsA("BasePart") then
		return padPart
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

local function createPadUi(plotId, padPart)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = string.format("%sLumberjackPad", plotId)
	surfaceGui.Adornee = padPart
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 80
	surfaceGui.PixelsPerStud = 34
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = rootGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rootFrame.Position = UDim2.fromScale(0.5, 0.5)
	rootFrame.Size = UDim2.fromOffset(250, 148)
	rootFrame.BackgroundColor3 = PANEL_COLOR
	rootFrame.BackgroundTransparency = 0.05
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

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(14, 10)
	titleLabel.Size = UDim2.new(1, -28, 0, 28)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextColor3 = LABEL_COLOR
	titleLabel.TextScaled = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = rootFrame

	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Name = "Bonus"
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Position = UDim2.fromOffset(14, 44)
	bonusLabel.Size = UDim2.new(1, -28, 0, 24)
	bonusLabel.Font = Enum.Font.GothamBold
	bonusLabel.TextColor3 = LABEL_COLOR
	bonusLabel.TextScaled = true
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.Parent = rootFrame

	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.BackgroundTransparency = 1
	detailLabel.Position = UDim2.fromOffset(14, 72)
	detailLabel.Size = UDim2.new(1, -28, 0, 22)
	detailLabel.Font = Enum.Font.Gotham
	detailLabel.TextColor3 = SUBTLE_COLOR
	detailLabel.TextScaled = true
	detailLabel.TextWrapped = true
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.Parent = rootFrame

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.AnchorPoint = Vector2.new(0.5, 1)
	upgradeButton.Position = UDim2.new(0.5, 0, 1, -14)
	upgradeButton.Size = UDim2.fromOffset(196, 42)
	upgradeButton.AutoButtonColor = false
	upgradeButton.BorderSizePixel = 0
	upgradeButton.Font = Enum.Font.GothamBlack
	upgradeButton.Text = "0 GOLD"
	upgradeButton.TextColor3 = LABEL_COLOR
	upgradeButton.TextScaled = true
	upgradeButton.Parent = rootFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = upgradeButton

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = PANEL_STROKE
	buttonStroke.Thickness = 1.5
	buttonStroke.Parent = upgradeButton

	upgradeButton.Activated:Connect(function()
		local plotState = plotStatesById[plotId]

		if not plotState or not plotState.canUpgradeLumberjack or plotState.lumberjackUpgradeCost == nil then
			return
		end

		requestLumberjackUpgradeRemote:FireServer(plotId)
	end)

	padUisByPlotId[plotId] = {
		Gui = surfaceGui,
		TitleLabel = titleLabel,
		BonusLabel = bonusLabel,
		DetailLabel = detailLabel,
		UpgradeButton = upgradeButton,
	}

	return padUisByPlotId[plotId]
end

local function renderPad(plotId)
	local plotState = plotStatesById[plotId]

	if not plotState or not plotState.showLumberjackUpgradePad then
		destroyPad(plotId)
		return
	end

	local padPart = getUpgradePadPart(plotId)

	if not padPart then
		destroyPad(plotId)
		return
	end

	local padUi = padUisByPlotId[plotId]

	if not padUi or not padUi.Gui or padUi.Gui.Adornee ~= padPart then
		destroyPad(plotId)
		padUi = createPadUi(plotId, padPart)
	end

	padUi.TitleLabel.Text = string.format("%s Lumberjack  Lv.%d", plotState.treeName, plotState.lumberjackLevel or 0)
	padUi.BonusLabel.Text = string.format("Auto Bonus  +%d%%", plotState.lumberjackGoldBonusPercent or 0)
	padUi.DetailLabel.Text = "Uses your current axe power and gold bonus"

	if plotState.lumberjackIsMaxLevel or plotState.lumberjackUpgradeCost == nil then
		padUi.DetailLabel.Text = string.format(
			"Max level reached  Lv.%d / %d",
			plotState.lumberjackLevel or 0,
			lumberjackConstants.MAX_LEVEL
		)
		padUi.UpgradeButton.Text = "MAX"
		padUi.UpgradeButton.BackgroundColor3 = MAX_COLOR
		padUi.UpgradeButton.Active = false
		return
	end

	local canAfford = goldAmount >= (plotState.lumberjackUpgradeCost or math.huge)
	padUi.UpgradeButton.Text =
		string.format("%s GOLD", currencyFormatter.formatGold(plotState.lumberjackUpgradeCost or 0))
	padUi.UpgradeButton.BackgroundColor3 = canAfford and GREEN_COLOR or RED_COLOR
	padUi.UpgradeButton.Active = plotState.canUpgradeLumberjack == true
end

local function rerenderPads()
	for plotId in plotStatesById do
		renderPad(plotId)
	end

	for plotId in padUisByPlotId do
		if not plotStatesById[plotId] or not plotStatesById[plotId].showLumberjackUpgradePad then
			destroyPad(plotId)
		end
	end

	lastRefreshAt = os.clock()
end

local function applyState(state)
	if typeof(state) ~= "table" then
		return
	end

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
			ErrorMessage = "Tree remotes folder was not found for lumberjack upgrade pads",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found for lumberjack upgrade pads",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(treesFolder, {
		treeConstants.GET_STATE_REMOTE_NAME,
		treeConstants.STATE_UPDATED_REMOTE_NAME,
		treeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Tree remote")

	if not remotes then
		return false
	end

	getTreeStateRemote = remotes[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	treeStateUpdatedRemote = remotes[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent
	requestLumberjackUpgradeRemote = remotes[treeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME] :: RemoteEvent

	return getTreeStateRemote ~= nil and treeStateUpdatedRemote ~= nil and requestLumberjackUpgradeRemote ~= nil
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

function LumberjackUpgradePadController.start()
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

return LumberjackUpgradePadController
