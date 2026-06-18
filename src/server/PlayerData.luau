local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local dataStoreRegistry = require(script.Parent:WaitForChild("DataStoreRegistry"))

local PlayerData = {}

local playerStates = {}
local dataStore = nil
local started = false
local DATASTORE_DEFINITION_NAME = "PlayerProgression"

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function normalizeGold(value)
	if not isFiniteNumber(value) then
		return 0
	end

	return math.max(0, math.floor(value))
end

local function normalizeTimestamp(value)
	if not isFiniteNumber(value) then
		return nil
	end

	return math.max(0, value)
end

local function cloneTreePlotState(plotState)
	return {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = plotState.Unlocked,
		Level = plotState.Level,
		State = plotState.State,
		GrowingUntil = plotState.GrowingUntil,
	}
end

local function cloneTreePlots(treePlots)
	local clonedTreePlots = {}

	for plotId, plotState in treePlots do
		clonedTreePlots[plotId] = cloneTreePlotState(plotState)
	end

	return clonedTreePlots
end

local function buildDefaultTreePlots()
	return treeConfig.getDefaultPlotStates()
end

local function normalizeTreePlotState(plotId, rawPlotState)
	local tree = treeConfig.getTreeByPlotId(plotId)

	if not tree then
		return nil, false
	end

	local defaultState = {
		PlotId = tree.PlotId,
		TreeId = tree.Id,
		Unlocked = false,
		Level = 0,
		State = treeConstants.PlotState.Locked,
		GrowingUntil = nil,
	}

	if typeof(rawPlotState) ~= "table" then
		return defaultState, true
	end

	local wasChanged = false
	local unlocked = rawPlotState.Unlocked == true

	if unlocked ~= rawPlotState.Unlocked then
		wasChanged = true
	end

	local normalizedLevel = 0

	if unlocked then
		local rawLevel = rawPlotState.Level

		if isFiniteNumber(rawLevel) then
			normalizedLevel = math.floor(rawLevel)
		else
			normalizedLevel = 1
			wasChanged = true
		end

		normalizedLevel = math.clamp(normalizedLevel, 1, tree.MaxLevel)

		if normalizedLevel ~= rawPlotState.Level then
			wasChanged = true
		end
	elseif rawPlotState.Level ~= 0 and rawPlotState.Level ~= nil then
		wasChanged = true
	end

	local normalizedState = treeConstants.PlotState.Locked
	local normalizedGrowingUntil = nil

	if unlocked then
		local rawState = rawPlotState.State

		if rawState == treeConstants.PlotState.Grown then
			normalizedState = treeConstants.PlotState.Grown
			if rawPlotState.GrowingUntil ~= nil then
				wasChanged = true
			end
		else
			normalizedState = treeConstants.PlotState.Growing
			normalizedGrowingUntil = normalizeTimestamp(rawPlotState.GrowingUntil)

			if normalizedGrowingUntil == nil then
				local levelData = treeConfig.getLevelData(tree.Id, normalizedLevel)
				normalizedGrowingUntil = os.time() + (levelData and levelData.GrowTime or 0)
				wasChanged = true
			elseif normalizedGrowingUntil ~= rawPlotState.GrowingUntil then
				wasChanged = true
			end

			if rawState ~= treeConstants.PlotState.Growing then
				wasChanged = true
			end
		end
	else
		if rawPlotState.State ~= nil and rawPlotState.State ~= treeConstants.PlotState.Locked then
			wasChanged = true
		end

		if rawPlotState.GrowingUntil ~= nil then
			wasChanged = true
		end
	end

	if rawPlotState.PlotId ~= nil and rawPlotState.PlotId ~= tree.PlotId then
		wasChanged = true
	end

	if rawPlotState.TreeId ~= nil and rawPlotState.TreeId ~= tree.Id then
		wasChanged = true
	end

	return {
		PlotId = tree.PlotId,
		TreeId = tree.Id,
		Unlocked = unlocked,
		Level = normalizedLevel,
		State = normalizedState,
		GrowingUntil = normalizedGrowingUntil,
	},
		wasChanged
end

local function normalizeTreePlots(rawTreePlots)
	local normalizedTreePlots = {}
	local wasChanged = typeof(rawTreePlots) ~= "table"

	for plotId in treeConfig.getDefaultPlotStates() do
		local rawPlotState = nil

		if typeof(rawTreePlots) == "table" then
			rawPlotState = rawTreePlots[plotId]
		end

		local normalizedPlotState, plotWasChanged = normalizeTreePlotState(plotId, rawPlotState)
		normalizedTreePlots[plotId] = normalizedPlotState

		if plotWasChanged then
			wasChanged = true
		end
	end

	if typeof(rawTreePlots) == "table" then
		for plotId in rawTreePlots do
			if not treeConfig.getTreeByPlotId(plotId) then
				wasChanged = true
			end
		end
	end

	return normalizedTreePlots, wasChanged
end

local function buildDefaultState()
	return {
		SchemaVersion = treeConstants.CURRENT_SCHEMA_VERSION,
		Gold = 0,
		AxeTierId = blacksmithConstants.DEFAULT_AXE_TIER_ID,
		TreePlots = buildDefaultTreePlots(),
		LastUpdatedAt = os.time(),
		IsLoaded = true,
		IsDirty = true,
	}
end

local function ensureValidTierId(tierId)
	if axeConfig.getTier(tierId) then
		return tierId
	end

	return blacksmithConstants.DEFAULT_AXE_TIER_ID
end

local function migrateLegacyData(rawData)
	local rawGold = rawData.Gold

	if typeof(rawGold) ~= "number" then
		rawGold = rawData.Money
	end

	local resolvedTierId = nil

	if typeof(rawData.AxeTierId) == "string" then
		resolvedTierId = rawData.AxeTierId
	elseif typeof(rawData.AxeTierIndex) == "number" then
		local tier = axeConfig.getTierByIndex(rawData.AxeTierIndex)

		if tier then
			resolvedTierId = tier.Id
		end
	end

	return {
		SchemaVersion = treeConstants.CURRENT_SCHEMA_VERSION,
		Gold = normalizeGold(rawGold),
		AxeTierId = ensureValidTierId(resolvedTierId),
		TreePlots = buildDefaultTreePlots(),
		LastUpdatedAt = os.time(),
		IsLoaded = true,
		IsDirty = true,
	}
end

local function normalizeCurrentData(rawData)
	local normalizedGold = normalizeGold(rawData.Gold)
	local normalizedTierId = ensureValidTierId(rawData.AxeTierId)
	local normalizedTreePlots, treePlotsWereChanged = normalizeTreePlots(rawData.TreePlots)
	local lastUpdatedAt = rawData.LastUpdatedAt
	local wasChanged = false

	if normalizedGold ~= rawData.Gold then
		wasChanged = true
	end

	if normalizedTierId ~= rawData.AxeTierId then
		wasChanged = true
	end

	if treePlotsWereChanged then
		wasChanged = true
	end

	if not isFiniteNumber(lastUpdatedAt) then
		lastUpdatedAt = os.time()
		wasChanged = true
	end

	if rawData.SchemaVersion ~= treeConstants.CURRENT_SCHEMA_VERSION then
		wasChanged = true
	end

	return {
		SchemaVersion = treeConstants.CURRENT_SCHEMA_VERSION,
		Gold = normalizedGold,
		AxeTierId = normalizedTierId,
		TreePlots = normalizedTreePlots,
		LastUpdatedAt = lastUpdatedAt,
		IsLoaded = true,
		IsDirty = wasChanged,
	}
end

local function normalizeLoadedData(rawData)
	if rawData == nil then
		return buildDefaultState()
	end

	if typeof(rawData) ~= "table" then
		return buildDefaultState()
	end

	if typeof(rawData.SchemaVersion) ~= "number" then
		return migrateLegacyData(rawData)
	end

	return normalizeCurrentData(rawData)
end

local function serializeState(state)
	return {
		SchemaVersion = treeConstants.CURRENT_SCHEMA_VERSION,
		Gold = state.Gold,
		AxeTierId = state.AxeTierId,
		TreePlots = cloneTreePlots(state.TreePlots),
		LastUpdatedAt = state.LastUpdatedAt,
	}
end

local function getDataStoreKey(player)
	return dataStoreRegistry.getPlayerKey(DATASTORE_DEFINITION_NAME, player)
end

local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local goldValue = leaderstats:FindFirstChild("Gold")

	if goldValue and goldValue:IsA("IntValue") then
		return goldValue
	end

	if goldValue then
		goldValue:Destroy()
	end

	goldValue = Instance.new("IntValue")
	goldValue.Name = "Gold"
	goldValue.Parent = leaderstats

	return goldValue
end

local function syncLeaderstats(player, state)
	if not state or not state.IsLoaded then
		return
	end

	local goldValue = ensureLeaderstats(player)
	goldValue.Value = state.Gold
end

function PlayerData.start()
	if started then
		return
	end

	started = true
	dataStore = dataStoreRegistry.getStore(DATASTORE_DEFINITION_NAME)
end

function PlayerData.isLoaded(player)
	local state = playerStates[player]
	return state ~= nil and state.IsLoaded == true
end

function PlayerData.getState(player)
	return playerStates[player]
end

function PlayerData.getGold(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return state.Gold
end

function PlayerData.getAxeTierId(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return state.AxeTierId
end

function PlayerData.getTreePlots(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return cloneTreePlots(state.TreePlots)
end

function PlayerData.getTreePlot(player, plotId)
	local state = playerStates[player]

	if not state or not state.IsLoaded or typeof(plotId) ~= "string" then
		return nil
	end

	local plotState = state.TreePlots[plotId]

	if not plotState then
		return nil
	end

	return cloneTreePlotState(plotState)
end

function PlayerData.setGold(player, gold)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.Gold = normalizeGold(gold)
	state.IsDirty = true
	syncLeaderstats(player, state)
	return true
end

function PlayerData.setAxeTierId(player, tierId)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.AxeTierId = ensureValidTierId(tierId)
	state.IsDirty = true
	return true
end

function PlayerData.setTreePlot(player, plotId, plotState)
	local state = playerStates[player]

	if not state or not state.IsLoaded or typeof(plotId) ~= "string" then
		return false
	end

	local normalizedPlotState = normalizeTreePlotState(plotId, plotState)

	if not normalizedPlotState then
		return false
	end

	state.TreePlots[plotId] = normalizedPlotState
	state.IsDirty = true
	return true
end

function PlayerData.setTreePlots(player, treePlots)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.TreePlots = normalizeTreePlots(treePlots)
	state.IsDirty = true
	return true
end

function PlayerData.resetPlayerData(player)
	local success, failures = dataStoreRegistry.clearPlayerData(player)

	if not success then
		return false, failures
	end

	local state = buildDefaultState()
	state.IsDirty = false
	playerStates[player] = state
	syncLeaderstats(player, state)

	return true, state
end

function PlayerData.loadPlayer(player)
	local success, result = pcall(function()
		return dataStore:GetAsync(getDataStoreKey(player))
	end)

	if not success then
		warn(string.format("Failed to load data for %s: %s", player.Name, tostring(result)))
		playerStates[player] = {
			IsLoaded = false,
			IsDirty = false,
		}
		return false
	end

	local state = normalizeLoadedData(result)
	playerStates[player] = state
	syncLeaderstats(player, state)
	return true
end

function PlayerData.savePlayer(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded or not state.IsDirty then
		return true
	end

	state.LastUpdatedAt = os.time()

	local success, result = pcall(function()
		dataStore:SetAsync(getDataStoreKey(player), serializeState(state))
	end)

	if not success then
		warn(string.format("Failed to save data for %s: %s", player.Name, tostring(result)))
		return false
	end

	state.IsDirty = false
	return true
end

function PlayerData.removePlayer(player)
	PlayerData.savePlayer(player)
	playerStates[player] = nil
end

function PlayerData.saveAll()
	for player in playerStates do
		PlayerData.savePlayer(player)
	end
end

return PlayerData
