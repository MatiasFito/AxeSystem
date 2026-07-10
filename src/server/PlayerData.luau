local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local amberShopConstants = require(sharedFolder:WaitForChild("AmberShopConstants") :: ModuleScript)
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
	playerLeaderstats.syncRebirths(player, state.Rebirths or 0)
	player:SetAttribute(amberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME, state.Amber or 0)
	player:SetAttribute(
		amberShopConstants.PLAYER_AMBER_GAIN_LEVEL_ATTRIBUTE_NAME,
		(state.AmberUpgrades and state.AmberUpgrades.AmberGain) or 0
	)
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

function PlayerData.getRebirths(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return state.Rebirths
end

function PlayerData.getAmber(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return state.Amber
end

function PlayerData.getAmberUpgrades(player)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return playerDataSerializer.cloneAmberUpgrades(state.AmberUpgrades)
end

function PlayerData.getAmberUpgradeLevel(player, upgradeKey)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return nil
	end

	return playerDataSerializer.cloneAmberUpgrades(state.AmberUpgrades)[upgradeKey]
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

function PlayerData.setAmber(player, amber)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.Amber = playerDataSerializer.normalizeAmber(amber)
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

function PlayerData.setAmberUpgrades(player, amberUpgrades)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	state.AmberUpgrades = playerDataSerializer.cloneAmberUpgrades(amberUpgrades)
	state.IsDirty = true
	return true
end

function PlayerData.setAmberUpgradeLevel(player, upgradeKey, level)
	local state = playerStates[player]

	if not state or not state.IsLoaded or typeof(upgradeKey) ~= "string" then
		return false
	end

	local amberUpgrades = playerDataSerializer.cloneAmberUpgrades(state.AmberUpgrades)

	if amberUpgrades[upgradeKey] == nil then
		return false
	end

	amberUpgrades[upgradeKey] = math.max(0, math.floor(tonumber(level) or 0))
	state.AmberUpgrades = playerDataSerializer.cloneAmberUpgrades(amberUpgrades)
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

function PlayerData.applyRebirth(player, awardedAmber)
	local state = playerStates[player]

	if not state or not state.IsLoaded then
		return false
	end

	local previousState = playerDataSerializer.cloneState(state)
	local rebirthState = playerDataSerializer.buildRebirthResetState(state, awardedAmber)
	playerStates[player] = rebirthState
	syncLeaderstats(player, rebirthState)

	local saveSuccess = PlayerData.savePlayer(player)

	if not saveSuccess then
		playerStates[player] = previousState
		syncLeaderstats(player, previousState)
		return false
	end

	return true, playerDataSerializer.cloneState(playerStates[player])
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
	player:SetAttribute(amberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME, nil)
	player:SetAttribute(amberShopConstants.PLAYER_AMBER_GAIN_LEVEL_ATTRIBUTE_NAME, nil)
	playerStates[player] = nil
end

function PlayerData.saveAll()
	for player in playerStates do
		PlayerData.savePlayer(player)
	end
end

return PlayerData
