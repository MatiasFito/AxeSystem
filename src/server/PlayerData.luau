local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)

local PlayerData = {}

local playerStates = {}
local dataStore = nil
local started = false

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function normalizeGold(value)
	if not isFiniteNumber(value) then
		return 0
	end

	return math.max(0, math.floor(value))
end

local function buildDefaultState()
	return {
		SchemaVersion = blacksmithConstants.CURRENT_SCHEMA_VERSION,
		Gold = 0,
		AxeTierId = blacksmithConstants.DEFAULT_AXE_TIER_ID,
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
		SchemaVersion = blacksmithConstants.CURRENT_SCHEMA_VERSION,
		Gold = normalizeGold(rawGold),
		AxeTierId = ensureValidTierId(resolvedTierId),
		LastUpdatedAt = os.time(),
		IsLoaded = true,
		IsDirty = true,
	}
end

local function normalizeCurrentData(rawData)
	local normalizedGold = normalizeGold(rawData.Gold)
	local normalizedTierId = ensureValidTierId(rawData.AxeTierId)
	local lastUpdatedAt = rawData.LastUpdatedAt
	local wasChanged = false

	if normalizedGold ~= rawData.Gold then
		wasChanged = true
	end

	if normalizedTierId ~= rawData.AxeTierId then
		wasChanged = true
	end

	if not isFiniteNumber(lastUpdatedAt) then
		lastUpdatedAt = os.time()
		wasChanged = true
	end

	if rawData.SchemaVersion ~= blacksmithConstants.CURRENT_SCHEMA_VERSION then
		wasChanged = true
	end

	return {
		SchemaVersion = blacksmithConstants.CURRENT_SCHEMA_VERSION,
		Gold = normalizedGold,
		AxeTierId = normalizedTierId,
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
		SchemaVersion = blacksmithConstants.CURRENT_SCHEMA_VERSION,
		Gold = state.Gold,
		AxeTierId = state.AxeTierId,
		LastUpdatedAt = state.LastUpdatedAt,
	}
end

local function getDataStoreKey(player)
	return string.format("%s%s", blacksmithConstants.DATASTORE_KEY_PREFIX, player.UserId)
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
	dataStore = DataStoreService:GetDataStore(blacksmithConstants.DATASTORE_NAME)
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

function PlayerData.addGold(player, amount)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false, nil
	end

	state.Gold = normalizeGold(state.Gold + amount)
	state.IsDirty = true
	syncLeaderstats(player, state)
	return true, state.Gold
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
