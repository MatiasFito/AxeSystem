local playerDataSerializer = require(script.Parent:WaitForChild("PlayerDataSerializer") :: ModuleScript)
local playerLeaderstats = require(script.Parent:WaitForChild("PlayerLeaderstats") :: ModuleScript)
local dataStoreRegistry = require(script.Parent:WaitForChild("DataStoreRegistry"))

local PlayerData = {}

local playerStates = {}
local dataStore = nil
local started = false
local DATASTORE_DEFINITION_NAME = "PlayerProgression"

local function getDataStoreKey(player)
	return dataStoreRegistry.getPlayerKey(DATASTORE_DEFINITION_NAME, player)
end

local function syncLeaderstats(player, state)
	if not state or not state.IsLoaded then
		return
	end

	playerLeaderstats.syncGold(player, state.Gold)
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

	return playerDataSerializer.cloneTreePlots(state.TreePlots)
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

	return playerDataSerializer.cloneTreePlotState(plotState)
end

function PlayerData.setGold(player, gold)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.Gold = playerDataSerializer.normalizeGold(gold)
	state.IsDirty = true
	syncLeaderstats(player, state)
	return true
end

function PlayerData.setAxeTierId(player, tierId)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.AxeTierId = playerDataSerializer.ensureValidTierId(tierId)
	state.IsDirty = true
	return true
end

function PlayerData.setTreePlot(player, plotId, plotState)
	local state = playerStates[player]

	if not state or not state.IsLoaded or typeof(plotId) ~= "string" then
		return false
	end

	local normalizedPlotState = playerDataSerializer.normalizeTreePlotState(plotId, plotState)

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

	state.TreePlots = playerDataSerializer.normalizeTreePlots(treePlots)
	state.IsDirty = true
	return true
end

function PlayerData.resetPlayerData(player)
	local success, failures = dataStoreRegistry.clearPlayerData(player)

	if not success then
		return false, failures
	end

	local state = playerDataSerializer.buildDefaultState()
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

	local state = playerDataSerializer.normalizeLoadedData(result)
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
		dataStore:SetAsync(getDataStoreKey(player), playerDataSerializer.serializeState(state))
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
