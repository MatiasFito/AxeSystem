local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local damageHubConstants = require(sharedFolder:WaitForChild("DamageHubConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local DamageHubRemoteRegistry = {}

function DamageHubRemoteRegistry.getOrCreateRemotes()
	local damageHubFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = damageHubConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = damageHubConstants.DAMAGE_HUB_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(damageHubFolder, {
		{
			Name = damageHubConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})

	return {
		GetDamageHubStateRemote = instances[damageHubConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction,
	}
end

return DamageHubRemoteRegistry
