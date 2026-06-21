local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local BlacksmithRemoteRegistry = {}

function BlacksmithRemoteRegistry.getOrCreateRemotes()
	local blacksmithFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = blacksmithConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = blacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(blacksmithFolder, {
		{
			Name = blacksmithConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
		{
			Name = blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})

	return {
		GetStateRemote = instances[blacksmithConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction,
		RequestUpgradeRemote = instances[blacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteFunction,
	}
end

return BlacksmithRemoteRegistry
