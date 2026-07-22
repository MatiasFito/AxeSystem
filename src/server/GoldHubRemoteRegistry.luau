local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local goldHubConstants = require(sharedFolder:WaitForChild("GoldHubConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local GoldHubRemoteRegistry = {}

function GoldHubRemoteRegistry.getOrCreateRemotes()
	local goldHubFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = goldHubConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = goldHubConstants.GOLD_HUB_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(goldHubFolder, {
		{
			Name = goldHubConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})

	return {
		GetGoldHubStateRemote = instances[goldHubConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction,
	}
end

return GoldHubRemoteRegistry
