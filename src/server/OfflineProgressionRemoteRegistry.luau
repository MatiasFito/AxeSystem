local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local offlineProgressionConstants = require(sharedFolder:WaitForChild("OfflineProgressionConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local OfflineProgressionRemoteRegistry = {}

function OfflineProgressionRemoteRegistry.getOrCreateRemotes()
	local offlineProgressionFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = offlineProgressionConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = offlineProgressionConstants.OFFLINE_PROGRESSION_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(offlineProgressionFolder, {
		{
			Name = offlineProgressionConstants.GET_REWARD_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
		{
			Name = offlineProgressionConstants.CLAIM_REWARD_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
		{
			Name = offlineProgressionConstants.DOUBLE_PURCHASED_REMOTE_NAME,
			ClassName = "RemoteEvent",
		},
	})

	return {
		GetOfflineRewardRemote = instances[offlineProgressionConstants.GET_REWARD_REMOTE_NAME] :: RemoteFunction,
		ClaimOfflineRewardRemote = instances[offlineProgressionConstants.CLAIM_REWARD_REMOTE_NAME] :: RemoteEvent,
		DoublePurchaseProcessedRemote = instances[offlineProgressionConstants.DOUBLE_PURCHASED_REMOTE_NAME] :: RemoteEvent,
	}
end

return OfflineProgressionRemoteRegistry
