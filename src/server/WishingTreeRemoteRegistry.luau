local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local wishingTreeConstants = require(sharedFolder:WaitForChild("WishingTreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local WishingTreeRemoteRegistry = {}

function WishingTreeRemoteRegistry.getOrCreateRemotes()
	local wishingTreeFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = wishingTreeConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = wishingTreeConstants.WISHING_TREE_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(wishingTreeFolder, {
		{
			Name = wishingTreeConstants.ROLL_BLESSING_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})

	return {
		RollBlessingRemote = instances[wishingTreeConstants.ROLL_BLESSING_REMOTE_NAME] :: RemoteFunction,
	}
end

return WishingTreeRemoteRegistry
