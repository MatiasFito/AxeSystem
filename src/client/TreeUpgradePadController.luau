local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local GUI_NAME = "TreeUpgradePads"
local REMOTE_WAIT_TIMEOUT = 10

local PANEL_COLOR = Color3.fromRGB(41, 49, 39)
local PANEL_STROKE = Color3.fromRGB(214, 231, 202)
local LABEL_COLOR = Color3.fromRGB(244, 247, 237)
local SUBTLE_COLOR = Color3.fromRGB(211, 223, 203)
local GREEN_COLOR = Color3.fromRGB(101, 197, 95)
local RED_COLOR = Color3.fromRGB(196, 84, 84)
local MAX_COLOR = Color3.fromRGB(91, 102, 88)

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
local goldConnection = nil
local leaderstatsChildConnection = nil

local function formatGold(amount)
	return tostring(math.max(0, math.floor(amount or 0)))
end

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

local function createLabel(parent, name, font, textColor, size, position)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.Position = position
	label.Size = size
	label.Parent = parent
	return label
end

local function createPadUi(plotId, dirtPatch)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = string.format("%sPad", plotId)
	surfaceGui.Adornee = dirtPatch
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 80
	surfaceGui.PixelsPerStud = 40
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = rootGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rootFrame.Position = UDim2.fromScale(0.75, 0.5)
	rootFrame.Size = UDim2.fromOffset(186, 104)
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

	local levelLabel = createLabel(
		rootFrame,
		"Level",
		Enum.Font.GothamBlack,
		LABEL_COLOR,
		UDim2.new(1, -20, 0, 26),
		UDim2.fromOffset(10, 8)
	)

	local costLabel = createLabel(
		rootFrame,
		"Cost",
		Enum.Font.GothamBold,
		SUBTLE_COLOR,
		UDim2.new(1, -20, 0, 24),
		UDim2.fromOffset(10, 32)
	)

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.AnchorPoint = Vector2.new(0.5, 1)
	upgradeButton.Position = UDim2.new(0.5, 0, 1, -10)
	upgradeButton.Size = UDim2.fromOffset(152, 44)
	upgradeButton.AutoButtonColor = false
	upgradeButton.BorderSizePixel = 0
	upgradeButton.Font = Enum.Font.GothamBlack
	upgradeButton.Text = "UPGRADE"
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

	upgradeButton.Activated:Connect(function()
		local plotState = plotStatesById[plotId]

		if not plotState or plotState.isMaxLevel or plotState.upgradeCost == nil then
			return
		end

		requestTreeUpgradeRemote:FireServer(plotId)
	end)

	padUisByPlotId[plotId] = {
		Gui = surfaceGui,
		LevelLabel = levelLabel,
		CostLabel = costLabel,
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

	padUi.LevelLabel.Text = string.format("LEVEL %d", plotState.level)

	if plotState.isMaxLevel or plotState.upgradeCost == nil then
		padUi.CostLabel.Text = "MAX"
		padUi.UpgradeButton.Text = "MAX"
		padUi.UpgradeButton.BackgroundColor3 = MAX_COLOR
		padUi.UpgradeButton.Active = false
		return
	end

	local canAfford = goldAmount >= plotState.upgradeCost
	padUi.CostLabel.Text = string.format("%s GOLD", formatGold(plotState.upgradeCost))
	padUi.UpgradeButton.Text = "UPGRADE"
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

local function attachGoldValue(goldValue)
	if goldConnection then
		goldConnection:Disconnect()
		goldConnection = nil
	end

	if not goldValue or not goldValue:IsA("IntValue") then
		return
	end

	goldAmount = goldValue.Value
	rerenderPads()
	goldConnection = goldValue:GetPropertyChangedSignal("Value"):Connect(function()
		goldAmount = goldValue.Value
		rerenderPads()
	end)
end

local function bindLeaderstats()
	if leaderstatsChildConnection then
		leaderstatsChildConnection:Disconnect()
		leaderstatsChildConnection = nil
	end

	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", REMOTE_WAIT_TIMEOUT)

	if not leaderstats then
		return
	end

	attachGoldValue(leaderstats:FindFirstChild("Gold") or leaderstats:WaitForChild("Gold", REMOTE_WAIT_TIMEOUT))
	leaderstatsChildConnection = leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Gold" then
			attachGoldValue(child)
		end
	end)
end

local function resolveRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild(treeConstants.REMOTE_FOLDER_NAME, REMOTE_WAIT_TIMEOUT)

	if not remotesFolder then
		warn("Tree remotes folder was not found for upgrade pads")
		return false
	end

	local treesFolder = remotesFolder:WaitForChild(treeConstants.TREE_REMOTE_FOLDER_NAME, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		warn("Tree remote folder was not found for upgrade pads")
		return false
	end

	getTreeStateRemote = treesFolder:WaitForChild(treeConstants.GET_STATE_REMOTE_NAME, REMOTE_WAIT_TIMEOUT)
	treeStateUpdatedRemote = treesFolder:WaitForChild(treeConstants.STATE_UPDATED_REMOTE_NAME, REMOTE_WAIT_TIMEOUT)
	requestTreeUpgradeRemote = treesFolder:WaitForChild(treeConstants.REQUEST_UPGRADE_REMOTE_NAME, REMOTE_WAIT_TIMEOUT)

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
	requestInitialState()
end

return TreeUpgradePadController
