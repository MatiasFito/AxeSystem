local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local PlayerDataSerializer = {}

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function PlayerDataSerializer.normalizeGold(value)
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

function PlayerDataSerializer.cloneTreePlotState(plotState)
	return {
		PlotId = plotState.PlotId,
		TreeId = plotState.TreeId,
		Unlocked = plotState.Unlocked,
		Level = plotState.Level,
		State = plotState.State,
		GrowingUntil = plotState.GrowingUntil,
	}
end

function PlayerDataSerializer.cloneTreePlots(treePlots)
	local clonedTreePlots = {}

	for plotId, plotState in treePlots do
		clonedTreePlots[plotId] = PlayerDataSerializer.cloneTreePlotState(plotState)
	end

	return clonedTreePlots
end

local function buildDefaultTreePlots()
	return treeConfig.getDefaultPlotStates()
end

function PlayerDataSerializer.normalizeTreePlotState(plotId, rawPlotState)
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

function PlayerDataSerializer.normalizeTreePlots(rawTreePlots)
	local normalizedTreePlots = {}
	local wasChanged = typeof(rawTreePlots) ~= "table"

	for plotId in treeConfig.getDefaultPlotStates() do
		local rawPlotState = nil

		if typeof(rawTreePlots) == "table" then
			rawPlotState = rawTreePlots[plotId]
		end

		local normalizedPlotState, plotWasChanged = PlayerDataSerializer.normalizeTreePlotState(plotId, rawPlotState)
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

function PlayerDataSerializer.buildDefaultState()
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

function PlayerDataSerializer.ensureValidTierId(tierId)
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
		Gold = PlayerDataSerializer.normalizeGold(rawGold),
		AxeTierId = PlayerDataSerializer.ensureValidTierId(resolvedTierId),
		TreePlots = buildDefaultTreePlots(),
		LastUpdatedAt = os.time(),
		IsLoaded = true,
		IsDirty = true,
	}
end

local function normalizeCurrentData(rawData)
	local normalizedGold = PlayerDataSerializer.normalizeGold(rawData.Gold)
	local normalizedTierId = PlayerDataSerializer.ensureValidTierId(rawData.AxeTierId)
	local normalizedTreePlots, treePlotsWereChanged = PlayerDataSerializer.normalizeTreePlots(rawData.TreePlots)
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

function PlayerDataSerializer.normalizeLoadedData(rawData)
	if rawData == nil then
		return PlayerDataSerializer.buildDefaultState()
	end

	if typeof(rawData) ~= "table" then
		return PlayerDataSerializer.buildDefaultState()
	end

	if typeof(rawData.SchemaVersion) ~= "number" then
		return migrateLegacyData(rawData)
	end

	return normalizeCurrentData(rawData)
end

function PlayerDataSerializer.serializeState(state)
	return {
		SchemaVersion = treeConstants.CURRENT_SCHEMA_VERSION,
		Gold = state.Gold,
		AxeTierId = state.AxeTierId,
		TreePlots = PlayerDataSerializer.cloneTreePlots(state.TreePlots),
		LastUpdatedAt = state.LastUpdatedAt,
	}
end

return PlayerDataSerializer
