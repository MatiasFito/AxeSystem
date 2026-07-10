local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local amberShopConstants = require(sharedFolder:WaitForChild("AmberShopConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local AmberShopRemoteRegistry = {}

function AmberShopRemoteRegistry.getOrCreateRemotes()
	local amberShopFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
		{
			Name = amberShopConstants.REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
		{
			Name = amberShopConstants.AMBER_SHOP_REMOTE_FOLDER_NAME,
			ClassName = "Folder",
		},
	})
	local instances = remoteRegistry.getOrCreateNamedChildren(amberShopFolder, {
		{
			Name = amberShopConstants.GET_STATE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
		{
			Name = amberShopConstants.BUY_UPGRADE_REMOTE_NAME,
			ClassName = "RemoteFunction",
		},
	})

	return {
		GetAmberShopStateRemote = instances[amberShopConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction,
		BuyAmberUpgradeRemote = instances[amberShopConstants.BUY_UPGRADE_REMOTE_NAME] :: RemoteFunction,
	}
end

return AmberShopRemoteRegistry
