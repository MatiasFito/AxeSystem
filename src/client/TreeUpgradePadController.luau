local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local lumberjackConfig = require(sharedFolder:WaitForChild("LumberjackConfig") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local PLOT_SIGN_PART_NAME = "PlotSign"
local PLOT_UPGRADE_GUI_NAME = "PlotUpgradeGui"
local REMOTE_WAIT_TIMEOUT = 10
local REFRESH_RATE = 0.05
local GREEN_COLOR = Color3.fromRGB(101, 197, 95)
local RED_COLOR = Color3.fromRGB(196, 84, 84)

local TreeUpgradePadController = {}

local started = false
local getTreeStateRemote = nil
local treeStateUpdatedRemote = nil
local requestTreeUpgradeRemote = nil
local requestLumberjackHireRemote = nil
local requestLumberjackUpgradeRemote = nil

local plotSetId = nil
local plotStatesById = {}
local signBindingsByPlotId = {}
local modalBinding = nil
local selectedPlotId = nil
local lastRefreshAt = 0

local function formatSeconds(seconds)
	local clampedSeconds = math.max(0, seconds or 0)

	if clampedSeconds >= 10 then
		return string.format("%.0fs", clampedSeconds)
	end

	if clampedSeconds >= 1 then
		return string.format("%.1fs", clampedSeconds)
	end

	return string.format("%.2fs", clampedSeconds)
end

local function formatGoldText(amount)
	return string.format("%s Gold", currencyFormatter.formatGold(amount))
end

local function setText(instance, text)
	if not instance then
		return
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.Text = text
	end
end

local function setVisible(instance, visible)
	if not instance then
		return
	end

	if instance:IsA("ScreenGui") then
		instance.Enabled = visible
		return
	end

	if instance:IsA("GuiObject") then
		instance.Visible = visible
	end
end

local function setButtonInteractable(button, isInteractable)
	if not button or not button:IsA("GuiButton") then
		return
	end

	button.Active = isInteractable
	button.Selectable = isInteractable
	button.AutoButtonColor = isInteractable
	if button:IsA("TextButton") then
		button.TextTransparency = isInteractable and 0 or 0.35
	end
end

local function connectGuiActivated(guiObject, callback)
	if not guiObject or not callback then
		return nil
	end

	if guiObject:IsA("GuiButton") then
		return guiObject.Activated:Connect(callback)
	end

	if guiObject:IsA("GuiObject") then
		guiObject.Active = true
		return guiObject.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				callback()
			end
		end)
	end

	return nil
end

local function addConnection(connections, connection)
	if connection then
		table.insert(connections, connection)
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

local function findGuiButtonByNameToken(parent, token)
	if not parent then
		return nil
	end

	local normalizedToken = string.lower(token)

	for _, descendant in parent:GetDescendants() do
		if descendant:IsA("GuiButton") and string.find(string.lower(descendant.Name), normalizedToken, 1, true) then
			return descendant
		end
	end

	return nil
end

local function buildComparisonText(label, currentText, nextText)
	if nextText and nextText ~= "" and nextText ~= currentText then
		return string.format("%s: %s => %s", label, currentText, nextText)
	end

	return string.format("%s: %s", label, currentText)
end

local function getCurrentGoldAmount()
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		return 0
	end

	local goldValue = leaderstats:FindFirstChild("Gold")

	if goldValue and goldValue:IsA("IntValue") then
		return goldValue.Value
	end

	return 0
end

local function setButtonBackgroundColor(button, color)
	if not button or not button:IsA("GuiButton") then
		return
	end

	button.BackgroundColor3 = color
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

local function getPlotSetsFolder()
	local plotSetsFolder = Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)

	if plotSetsFolder and plotSetsFolder:IsA("Folder") then
		return plotSetsFolder
	end

	return nil
end

local function resolvePlotSetId(plotSetFolder)
	if not plotSetFolder then
		return nil
	end

	local folderPlotSetId = plotSetFolder:GetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE)

	if typeof(folderPlotSetId) == "string" and folderPlotSetId ~= "" then
		return folderPlotSetId
	end

	return plotSetFolder.Name
end

local function isOwnedPlotSetFolder(plotSetFolder)
	return typeof(plotSetId) == "string" and plotSetId ~= "" and resolvePlotSetId(plotSetFolder) == plotSetId
end

local function setPlotSignVisibility(plotSign, isVisible)
	if not plotSign or not plotSign:IsA("BasePart") then
		return
	end

	plotSign.LocalTransparencyModifier = isVisible and 0 or 1

	local surfaceGui = plotSign:FindFirstChildOfClass("SurfaceGui")

	if surfaceGui then
		surfaceGui.Enabled = isVisible
	end

	for _, descendant in plotSign:GetDescendants() do
		if descendant:IsA("GuiButton") then
			setButtonInteractable(descendant, isVisible)
		end
	end
end

local function refreshPlotSetOwnershipVisibility()
	local plotSetsFolder = getPlotSetsFolder()

	if not plotSetsFolder then
		return
	end

	for _, plotSetFolder in plotSetsFolder:GetChildren() do
		if plotSetFolder:IsA("Folder") then
			local shouldShowPlotSet = isOwnedPlotSetFolder(plotSetFolder)

			for _, descendant in plotSetFolder:GetDescendants() do
				if descendant.Name == PLOT_SIGN_PART_NAME and descendant:IsA("BasePart") then
					setPlotSignVisibility(descendant, shouldShowPlotSet)
				end
			end
		end
	end
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

local function getPlotSignPart(plotId)
	local plotModel = getPlotModel(plotId)

	if not plotModel then
		return nil
	end

	local plotSign = plotModel:FindFirstChild(PLOT_SIGN_PART_NAME, true)

	if plotSign and plotSign:IsA("BasePart") then
		return plotSign
	end

	return nil
end

local function destroySignBinding(plotId)
	local signBinding = signBindingsByPlotId[plotId]

	if not signBinding then
		return
	end

	if signBinding.Connection then
		signBinding.Connection:Disconnect()
	end

	signBindingsByPlotId[plotId] = nil
end

local function destroyAllSignBindings()
	for plotId in signBindingsByPlotId do
		destroySignBinding(plotId)
	end
end

local function closeModal()
	selectedPlotId = nil

	if not modalBinding then
		return
	end

	setVisible(modalBinding.Gui, false)
	setVisible(modalBinding.MainFrame, false)
	setVisible(modalBinding.HiredWorkerView, false)
	setVisible(modalBinding.HireWorkerView, false)
	setVisible(modalBinding.UpgradeWorkerButton, false)
	setButtonInteractable(modalBinding.UpgradeTreeButton, false)
	setButtonInteractable(modalBinding.UpgradeWorkerButton, false)
	setButtonInteractable(modalBinding.HireWorkerButton, false)
	setText(modalBinding.TreeHeader, "")
	setText(modalBinding.TreeHpLabel, "")
	setText(modalBinding.TreeGrowTimeLabel, "")
	setText(modalBinding.TreeRewardLabel, "")
	setText(modalBinding.WorkerHeader, "")
	setText(modalBinding.WorkerBonus, "")
	setText(modalBinding.WorkerAxe, "")
	setText(modalBinding.UpgradeTreeButton, "")
	setText(modalBinding.UpgradeWorkerButton, "")
	setText(modalBinding.HireWorkerButton, "")
end

local function destroyModalBinding()
	if not modalBinding then
		return
	end

	for _, connection in ipairs(modalBinding.Connections) do
		connection:Disconnect()
	end

	modalBinding = nil
end

local function ensureModalBinding()
	if modalBinding and modalBinding.Gui and modalBinding.Gui.Parent then
		return modalBinding
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local plotUpgradeGui = playerGui:FindFirstChild(PLOT_UPGRADE_GUI_NAME)

	if not plotUpgradeGui or not plotUpgradeGui:IsA("ScreenGui") then
		return nil
	end

	destroyModalBinding()

	local mainFrame = findDirectChild(plotUpgradeGui, "MainFrame")
	local dimmer = findDirectChild(plotUpgradeGui, "Dimmer")
	local contentFrame = findDescendantByPath(mainFrame, { "ContentFrame" })
	local treeStatsColumn = findDescendantByPath(contentFrame, { "TreeStatsColumn" })
	local workerColumn = findDescendantByPath(contentFrame, { "WorkerColumn" })
	local hiredWorkerView = findDescendantByPath(workerColumn, { "HiredWorkerView" })
	local hireWorkerView = findDescendantByPath(workerColumn, { "HireWorkerView" })
	local bottomButtons = findDescendantByPath(mainFrame, { "BottomButtons" })

	if
		not mainFrame
		or not dimmer
		or not treeStatsColumn
		or not workerColumn
		or not hiredWorkerView
		or not hireWorkerView
	then
		return nil
	end

	local connections = {}
	local binding = {
		Gui = plotUpgradeGui,
		Dimmer = dimmer,
		MainFrame = mainFrame,
		TreeHeader = findDescendantByPath(treeStatsColumn, { "Header" }),
		TreeHpLabel = findDescendantByPath(treeStatsColumn, { "HP" }),
		TreeGrowTimeLabel = findDescendantByPath(treeStatsColumn, { "GrowTime" }),
		TreeRewardLabel = findDescendantByPath(treeStatsColumn, { "Reward" }),
		WorkerHeader = findDescendantByPath(hiredWorkerView, { "Header" }),
		WorkerBonus = findDescendantByPath(hiredWorkerView, { "Bonus" }),
		WorkerAxe = findDescendantByPath(hiredWorkerView, { "Axe" }),
		HiredWorkerView = hiredWorkerView,
		HireWorkerView = hireWorkerView,
		HireWorkerButton = findDescendantByPath(hireWorkerView, { "HireWorkerButton" }),
		UpgradeTreeButton = bottomButtons and findDescendantByPath(bottomButtons, { "UpgradeTreeButton" }) or nil,
		UpgradeWorkerButton = bottomButtons and findDescendantByPath(bottomButtons, { "UpgradeWorkerButton" }) or nil,
		Connections = connections,
	}

	addConnection(
		connections,
		connectGuiActivated(dimmer, function()
			closeModal()
		end)
	)

	if binding.UpgradeTreeButton then
		addConnection(
			connections,
			connectGuiActivated(binding.UpgradeTreeButton, function()
				local plotId = selectedPlotId
				local plotState = plotId and plotStatesById[plotId] or nil

				if not plotId or not plotState or plotState.isMaxLevel or plotState.upgradeCost == nil then
					return
				end

				requestTreeUpgradeRemote:FireServer(plotId)
			end)
		)
	end

	if binding.UpgradeWorkerButton then
		addConnection(
			connections,
			connectGuiActivated(binding.UpgradeWorkerButton, function()
				local plotId = selectedPlotId
				local plotState = plotId and plotStatesById[plotId] or nil

				if not plotId or not plotState or not plotState.canUpgradeLumberjack then
					return
				end

				requestLumberjackUpgradeRemote:FireServer(plotId)
			end)
		)
	end

	if binding.HireWorkerButton then
		addConnection(
			connections,
			connectGuiActivated(binding.HireWorkerButton, function()
				local plotId = selectedPlotId
				local plotState = plotId and plotStatesById[plotId] or nil

				if not plotId or not plotState or not plotState.canHireLumberjack then
					return
				end

				requestLumberjackHireRemote:FireServer(plotId)
			end)
		)
	end

	modalBinding = binding
	closeModal()
	return binding
end

local function openModal(plotId)
	if typeof(plotId) ~= "string" then
		return
	end

	local plotState = plotStatesById[plotId]

	if not plotState or not plotState.unlocked then
		return
	end

	selectedPlotId = plotId
	lastRefreshAt = 0
end

local function ensureSignBinding(plotId, plotSign)
	local signBinding = signBindingsByPlotId[plotId]

	if
		signBinding
		and signBinding.SignPart == plotSign
		and signBinding.SurfaceGui
		and signBinding.SurfaceGui.Parent
	then
		return signBinding
	end

	destroySignBinding(plotId)

	if not plotSign then
		return nil
	end

	local surfaceGui = plotSign:FindFirstChildOfClass("SurfaceGui")

	if not surfaceGui then
		return nil
	end

	local mainContent = findDescendantByPath(surfaceGui, { "Background", "MainContent" })

	if not mainContent then
		return nil
	end

	local upgradeButton = findGuiButtonByNameToken(surfaceGui, "upgrade")

	signBinding = {
		SignPart = plotSign,
		SurfaceGui = surfaceGui,
		TreeNameLabel = findDescendantByPath(mainContent, { "TreeName" }),
		TreeLevelLabel = findDescendantByPath(mainContent, { "TreeLevel" }),
		TreeRewardLabel = findDescendantByPath(mainContent, { "TreeReward" }),
		LumberjackLevelLabel = findDescendantByPath(mainContent, { "LumberjackLevel" }),
		LumberjackBonusLabel = findDescendantByPath(mainContent, { "LumberjackBonus" }),
		UpgradeButton = upgradeButton,
		Connection = upgradeButton and connectGuiActivated(upgradeButton, function()
			openModal(plotId)
		end) or nil,
	}

	signBindingsByPlotId[plotId] = signBinding
	return signBinding
end

local function setSignVisible(signBinding, isVisible)
	if not signBinding then
		return
	end

	if signBinding.SurfaceGui then
		signBinding.SurfaceGui.Enabled = isVisible
	end

	if signBinding.SignPart and signBinding.SignPart:IsA("BasePart") then
		signBinding.SignPart.LocalTransparencyModifier = isVisible and 0 or 1
	end

	setButtonInteractable(signBinding.UpgradeButton, isVisible)
end

local function renderSign(plotId)
	local plotState = plotStatesById[plotId]

	if not plotState then
		destroySignBinding(plotId)
		return
	end

	local plotSign = getPlotSignPart(plotId)

	if not plotSign then
		destroySignBinding(plotId)
		return
	end

	local signBinding = ensureSignBinding(plotId, plotSign)

	if not signBinding then
		return
	end

	if not plotState.unlocked then
		setSignVisible(signBinding, false)
		if selectedPlotId == plotId then
			closeModal()
		end
		return
	end

	setSignVisible(signBinding, true)
	setText(signBinding.TreeNameLabel, plotState.treeName or "")
	setText(signBinding.TreeLevelLabel, string.format("Lvl %d", plotState.level or 0))
	setText(signBinding.TreeRewardLabel, formatGoldText(plotState.stats and plotState.stats.reward or 0))

	if plotState.hasLumberjack then
		setText(signBinding.LumberjackLevelLabel, string.format("Lvl %d", plotState.lumberjackLevel or 0))
		setText(
			signBinding.LumberjackBonusLabel,
			string.format("+%d%% Gold", plotState.lumberjackGoldBonusPercent or 0)
		)
	else
		setText(signBinding.LumberjackLevelLabel, "No Worker")
		setText(signBinding.LumberjackBonusLabel, "")
	end
end

local function renderModal()
	local binding = ensureModalBinding()

	if not binding or not selectedPlotId then
		if modalBinding then
			closeModal()
		end
		return
	end

	local plotState = plotStatesById[selectedPlotId]

	if not plotState or not plotState.unlocked then
		closeModal()
		return
	end

	local currentLevel = math.max(1, plotState.level or 1)
	local currentStats = plotState.stats or treeConfig.getLevelData(plotState.treeId, currentLevel)
	local nextLevel = treeConfig.getUpgradeLevel(plotState.treeId, currentLevel)
	local nextStats = nextLevel and treeConfig.getLevelData(plotState.treeId, nextLevel) or nil
	local currentReward = currentStats and currentStats.Reward or currentStats and currentStats.reward or 0
	local currentHealth = currentStats and currentStats.Health or currentStats and currentStats.health or 0
	local currentGrowTime = currentStats and currentStats.GrowTime or currentStats and currentStats.growTime or 0
	local nextReward = nextStats and nextStats.Reward or nextStats and nextStats.reward or nil
	local nextHealth = nextStats and nextStats.Health or nextStats and nextStats.health or nil
	local nextGrowTime = nextStats and nextStats.GrowTime or nextStats and nextStats.growTime or nil
	local currentGold = getCurrentGoldAmount()

	setVisible(binding.Gui, true)
	setVisible(binding.MainFrame, true)
	setText(binding.TreeHeader, string.format("%s - Lvl %d", plotState.treeName or "Plot", currentLevel))
	setText(
		binding.TreeHpLabel,
		buildComparisonText(
			"HP",
			string.format("%s HP", currencyFormatter.formatGold(currentHealth)),
			nextHealth and string.format("%s HP", currencyFormatter.formatGold(nextHealth)) or nil
		)
	)
	setText(
		binding.TreeGrowTimeLabel,
		buildComparisonText("Grow", formatSeconds(currentGrowTime), nextGrowTime and formatSeconds(nextGrowTime) or nil)
	)
	setText(
		binding.TreeRewardLabel,
		buildComparisonText(
			"Reward",
			currencyFormatter.formatGold(currentReward),
			nextReward and currencyFormatter.formatGold(nextReward) or nil
		)
	)

	if plotState.isMaxLevel or plotState.upgradeCost == nil then
		setText(binding.UpgradeTreeButton, "MAX TREE LEVEL")
		setButtonInteractable(binding.UpgradeTreeButton, false)
	else
		setText(
			binding.UpgradeTreeButton,
			string.format("UPGRADE TREE: %s G", currencyFormatter.formatGold(plotState.upgradeCost))
		)
		setButtonInteractable(binding.UpgradeTreeButton, true)
	end

	local workerSupported = plotState.hasLumberjack
		or plotState.canHireLumberjack
		or plotState.lumberjackHireCost ~= nil

	if plotState.hasLumberjack then
		setVisible(binding.HiredWorkerView, true)
		setVisible(binding.HireWorkerView, false)
		setVisible(binding.UpgradeWorkerButton, true)
		setText(binding.WorkerHeader, string.format("Worker - Lvl %d", plotState.lumberjackLevel or 0))

		local currentBonus = plotState.lumberjackGoldBonusPercent or 0
		local nextBonus = nil

		if not plotState.lumberjackIsMaxLevel then
			nextBonus = lumberjackConfig.getGoldBonusPercent((plotState.lumberjackLevel or 0) + 1)
		end

		setText(
			binding.WorkerBonus,
			buildComparisonText(
				"Bonus",
				string.format("+%d%% Gold", currentBonus),
				nextBonus and string.format("+%d%% Gold", nextBonus) or nil
			)
		)
		setText(binding.WorkerAxe, string.format("Using: %s", plotState.lumberjackAxeName or "Unknown Axe"))

		if plotState.lumberjackIsMaxLevel or not plotState.canUpgradeLumberjack then
			setText(binding.UpgradeWorkerButton, "MAX WORKER LEVEL")
			setButtonInteractable(binding.UpgradeWorkerButton, false)
		else
			setText(
				binding.UpgradeWorkerButton,
				string.format(
					"UPGRADE WORKER: %s G",
					currencyFormatter.formatGold(plotState.lumberjackUpgradeCost or 0)
				)
			)
			setButtonInteractable(binding.UpgradeWorkerButton, true)
		end

		setButtonInteractable(binding.HireWorkerButton, false)
	elseif workerSupported and plotState.canHireLumberjack then
		setVisible(binding.HiredWorkerView, false)
		setVisible(binding.HireWorkerView, true)
		setVisible(binding.UpgradeWorkerButton, false)
		setText(
			binding.HireWorkerButton,
			string.format("HIRE LUMBERJACK: %s G", currencyFormatter.formatGold(plotState.lumberjackHireCost or 0))
		)
		setButtonBackgroundColor(
			binding.HireWorkerButton,
			currentGold >= (plotState.lumberjackHireCost or math.huge) and GREEN_COLOR or RED_COLOR
		)
		setButtonInteractable(binding.HireWorkerButton, true)
	else
		setVisible(binding.HiredWorkerView, true)
		setVisible(binding.HireWorkerView, false)
		setVisible(binding.UpgradeWorkerButton, false)
		setText(binding.WorkerHeader, "Worker Unavailable")
		setText(binding.WorkerBonus, "This plot does not support a worker")
		setText(binding.WorkerAxe, "")
		setButtonBackgroundColor(binding.HireWorkerButton, RED_COLOR)
		setButtonInteractable(binding.HireWorkerButton, false)
	end
end

local function rerenderPads()
	refreshPlotSetOwnershipVisibility()

	for plotId in plotStatesById do
		renderSign(plotId)
	end

	for plotId in signBindingsByPlotId do
		if not plotStatesById[plotId] then
			destroySignBinding(plotId)
		end
	end

	renderModal()

	lastRefreshAt = os.clock()
end

local function applyState(state)
	if typeof(state) ~= "table" then
		return
	end

	if typeof(state.plotSetId) == "string" and state.plotSetId ~= plotSetId then
		plotSetId = state.plotSetId
		destroyAllSignBindings()
		closeModal()
	end

	for _, plotState in state.plots or {} do
		plotStatesById[plotState.plotId] = plotState
	end

	rerenderPads()
end

local function resolveRemotes()
	local treesFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remotes folder was not found for plot upgrades",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found for plot upgrades",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(treesFolder, {
		treeConstants.GET_STATE_REMOTE_NAME,
		treeConstants.STATE_UPDATED_REMOTE_NAME,
		treeConstants.REQUEST_UPGRADE_REMOTE_NAME,
		treeConstants.REQUEST_LUMBERJACK_HIRE_REMOTE_NAME,
		treeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Tree remote")

	if not remotes then
		return false
	end

	getTreeStateRemote = remotes[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction
	treeStateUpdatedRemote = remotes[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent
	requestTreeUpgradeRemote = remotes[treeConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteEvent
	requestLumberjackHireRemote = remotes[treeConstants.REQUEST_LUMBERJACK_HIRE_REMOTE_NAME] :: RemoteEvent
	requestLumberjackUpgradeRemote = remotes[treeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME] :: RemoteEvent

	return getTreeStateRemote ~= nil
		and treeStateUpdatedRemote ~= nil
		and requestTreeUpgradeRemote ~= nil
		and requestLumberjackHireRemote ~= nil
		and requestLumberjackUpgradeRemote ~= nil
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

	if not resolveRemotes() then
		return
	end

	refreshPlotSetOwnershipVisibility()
	ensureModalBinding()
	treeStateUpdatedRemote.OnClientEvent:Connect(applyState)

	local plotSetsFolder = getPlotSetsFolder()

	if plotSetsFolder then
		plotSetsFolder.DescendantAdded:Connect(function(descendant)
			if descendant.Name == PLOT_SIGN_PART_NAME and descendant:IsA("BasePart") then
				refreshPlotSetOwnershipVisibility()
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		if os.clock() - lastRefreshAt >= REFRESH_RATE then
			rerenderPads()
		end
	end)
	requestInitialState()
end

return TreeUpgradePadController
