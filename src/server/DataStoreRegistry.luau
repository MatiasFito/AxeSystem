local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)

local DataStoreRegistry = {}

local definitions = {
	PlayerProgression = {
		DataStoreName = blacksmithConstants.DATASTORE_NAME,
		GetKeyForPlayer = function(player)
			return string.format("%s%s", blacksmithConstants.DATASTORE_KEY_PREFIX, player.UserId)
		end,
	},
}

local cachedStores = {}

function DataStoreRegistry.getDefinition(definitionName)
	return definitions[definitionName]
end

function DataStoreRegistry.getStore(definitionName)
	local definition = DataStoreRegistry.getDefinition(definitionName)

	if not definition then
		return nil
	end

	local store = cachedStores[definitionName]

	if store then
		return store
	end

	store = DataStoreService:GetDataStore(definition.DataStoreName)
	cachedStores[definitionName] = store

	return store
end

function DataStoreRegistry.getPlayerKey(definitionName, player)
	local definition = DataStoreRegistry.getDefinition(definitionName)

	if not definition then
		return nil
	end

	return definition.GetKeyForPlayer(player)
end

function DataStoreRegistry.clearPlayerData(player)
	local failures = {}

	for definitionName in definitions do
		local store = DataStoreRegistry.getStore(definitionName)
		local key = DataStoreRegistry.getPlayerKey(definitionName, player)

		if store and key then
			local success, result = pcall(function()
				store:RemoveAsync(key)
			end)

			if not success then
				failures[definitionName] = tostring(result)
			end
		end
	end

	return next(failures) == nil, failures
end

return DataStoreRegistry
