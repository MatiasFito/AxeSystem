local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local networkFolder = sharedFolder:WaitForChild("Network")
local rebirthConstants = require(sharedFolder:WaitForChild("RebirthConstants") :: ModuleScript)
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local RebirthRemoteRegistry = {}

function RebirthRemoteRegistry.getOrCreateRemotes()
	local rebirthFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = rebirthConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = rebirthConstants.REBIRTH_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(rebirthFolder, {
		{
			Name = rebirthConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
		{
			Name = rebirthConstants.REQUEST_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})

	return {
		GetRebirthStateRemote = instances[rebirthConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction,
		RequestRebirthRemote = instances[rebirthConstants.REQUEST_REMOTE_NAME] :: RemoteFunction,
	}
end

return RebirthRemoteRegistry
