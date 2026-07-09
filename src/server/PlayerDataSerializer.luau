local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
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

function PlayerDataSerializer.normalizeAmber(value)
	if not isFiniteNumber(value) then
		return 0
	end

	return math.max(0, math.floor(value))
end

function PlayerDataSerializer.normalizeRebirths(value)
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
		HasLumberjack = plotState.HasLumberjack,
		LumberjackLevel = plotState.LumberjackLevel,
	}
end

function PlayerDataSerializer.cloneTreePlots(treePlots)
	local clonedTreePlots = {}

	for plotId, plotState in treePlots do
		clonedTreePlots[plotId] = PlayerDataSerializer.cloneTreePlotState(plotState)
	end

	return clonedTreePlots
end

function PlayerDataSerializer.cloneAmberUpgrades(amberUpgrades)
	return rebirthConfig.cloneAmberUpgrades(amberUpgrades)
end

function PlayerDataSerializer.cloneState(state)
	return {
		SchemaVersion = state.SchemaVersion,
		Gold = state.Gold,
		AxeTierId = state.AxeTierId,
		TreePlots = PlayerDataSerializer.cloneTreePlots(state.TreePlots),
		Rebirths = state.Rebirths,
		Amber = state.Amber,
		AmberUpgrades = PlayerDataSerializer.cloneAmberUpgrades(state.AmberUpgrades),
		LastUpdatedAt = state.LastUpdatedAt,
		IsLoaded = state.IsLoaded,
		IsDirty = state.IsDirty,
	}
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
		HasLumberjack = false,
		LumberjackLevel = 0,
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

	local supportsLumberjack = tree.SupportsLumberjack ~= false
	local hasLumberjack = supportsLumberjack and rawPlotState.HasLumberjack == true

	if hasLumberjack ~= rawPlotState.HasLumberjack then
		wasChanged = true
	end

	local lumberjackLevel = 0

	if hasLumberjack then
		if isFiniteNumber(rawPlotState.LumberjackLevel) then
			lumberjackLevel = math.max(0, math.floor(rawPlotState.LumberjackLevel))

			if lumberjackLevel ~= rawPlotState.LumberjackLevel then
				wasChanged = true
			end
		else
			lumberjackLevel = 1
			wasChanged = true
		end
	elseif rawPlotState.LumberjackLevel ~= nil and rawPlotState.LumberjackLevel ~= 0 then
		wasChanged = true
	end

	if hasLumberjack and lumberjackLevel < 1 then
		lumberjackLevel = 1
		wasChanged = true
	end

	if not supportsLumberjack and lumberjackLevel ~= 0 then
		lumberjackLevel = 0
		wasChanged = true
	end

	return {
		PlotId = tree.PlotId,
		TreeId = tree.Id,
		Unlocked = unlocked,
		Level = normalizedLevel,
		State = normalizedState,
		GrowingUntil = normalizedGrowingUntil,
		HasLumberjack = hasLumberjack,
		LumberjackLevel = lumberjackLevel,
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
		Rebirths = 0,
		Amber = 0,
		AmberUpgrades = rebirthConfig.createDefaultAmberUpgrades(),
		LastUpdatedAt = os.time(),
		IsLoaded = true,
		IsDirty = true,
	}
end

function PlayerDataSerializer.buildRebirthResetState(previousState, awardedAmber)
	local normalizedPreviousState = typeof(previousState) == "table" and previousState
		or PlayerDataSerializer.buildDefaultState()

	return {
		SchemaVersion = treeConstants.CURRENT_SCHEMA_VERSION,
		Gold = 0,
		AxeTierId = PlayerDataSerializer.ensureValidTierId(normalizedPreviousState.AxeTierId),
		TreePlots = buildDefaultTreePlots(),
		Rebirths = PlayerDataSerializer.normalizeRebirths(normalizedPreviousState.Rebirths) + 1,
		Amber = PlayerDataSerializer.normalizeAmber(normalizedPreviousState.Amber)
			+ PlayerDataSerializer.normalizeAmber(awardedAmber),
		AmberUpgrades = PlayerDataSerializer.cloneAmberUpgrades(normalizedPreviousState.AmberUpgrades),
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
		Rebirths = 0,
		Amber = 0,
		AmberUpgrades = rebirthConfig.createDefaultAmberUpgrades(),
		LastUpdatedAt = os.time(),
		IsLoaded = true,
		IsDirty = true,
	}
end

local function normalizeCurrentData(rawData)
	local normalizedGold = PlayerDataSerializer.normalizeGold(rawData.Gold)
	local normalizedTierId = PlayerDataSerializer.ensureValidTierId(rawData.AxeTierId)
	local normalizedTreePlots, treePlotsWereChanged = PlayerDataSerializer.normalizeTreePlots(rawData.TreePlots)
	local normalizedRebirths = PlayerDataSerializer.normalizeRebirths(rawData.Rebirths)
	local normalizedAmber = PlayerDataSerializer.normalizeAmber(rawData.Amber)
	local normalizedAmberUpgrades = PlayerDataSerializer.cloneAmberUpgrades(rawData.AmberUpgrades)
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

	if normalizedRebirths ~= rawData.Rebirths then
		wasChanged = true
	end

	if normalizedAmber ~= rawData.Amber then
		wasChanged = true
	end

	if typeof(rawData.AmberUpgrades) ~= "table" then
		wasChanged = true
	else
		for _, key in ipairs(rebirthConfig.getUpgradeKeys()) do
			if normalizedAmberUpgrades[key] ~= rawData.AmberUpgrades[key] then
				wasChanged = true
				break
			end
		end
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
		Rebirths = normalizedRebirths,
		Amber = normalizedAmber,
		AmberUpgrades = normalizedAmberUpgrades,
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
		Rebirths = PlayerDataSerializer.normalizeRebirths(state.Rebirths),
		Amber = PlayerDataSerializer.normalizeAmber(state.Amber),
		AmberUpgrades = PlayerDataSerializer.cloneAmberUpgrades(state.AmberUpgrades),
		LastUpdatedAt = state.LastUpdatedAt,
	}
end

return PlayerDataSerializer
