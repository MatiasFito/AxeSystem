local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteRegistry = require(networkFolder:WaitForChild("RemoteRegistry") :: ModuleScript)

local TreeNetworkBridge = {}

function TreeNetworkBridge.create(deps)
	local remotes = nil

	local function getOrCreateRemotes()
		if remotes then
			return remotes
		end

		local treesFolder = remoteRegistry.getOrCreatePath(ReplicatedStorage, {
			{
				Name = treeConstants.REMOTE_FOLDER_NAME,
				ClassName = "Folder",
			},
			{
				Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
				ClassName = "Folder",
			},
		})
		local instances = remoteRegistry.getOrCreateNamedChildren(treesFolder, {
			{
				Name = treeConstants.GET_STATE_REMOTE_NAME,
				ClassName = "RemoteFunction",
			},
			{
				Name = treeConstants.REQUEST_HIT_REMOTE_NAME,
				ClassName = "RemoteEvent",
			},
			{
				Name = treeConstants.REQUEST_UPGRADE_REMOTE_NAME,
				ClassName = "RemoteEvent",
			},
			{
				Name = treeConstants.STATE_UPDATED_REMOTE_NAME,
				ClassName = "RemoteEvent",
			},
			{
				Name = treeConstants.HIT_FEEDBACK_REMOTE_NAME,
				ClassName = "RemoteEvent",
			},
			{
				Name = treeConstants.AUDIO_REMOTE_NAME,
				ClassName = "RemoteEvent",
			},
		})

		remotes = {
			GetTreeStateRemote = instances[treeConstants.GET_STATE_REMOTE_NAME] :: RemoteFunction,
			RequestTreeHitRemote = instances[treeConstants.REQUEST_HIT_REMOTE_NAME] :: RemoteEvent,
			RequestTreeUpgradeRemote = instances[treeConstants.REQUEST_UPGRADE_REMOTE_NAME] :: RemoteEvent,
			StateUpdatedRemote = instances[treeConstants.STATE_UPDATED_REMOTE_NAME] :: RemoteEvent,
			HitFeedbackRemote = instances[treeConstants.HIT_FEEDBACK_REMOTE_NAME] :: RemoteEvent,
			AudioRemote = instances[treeConstants.AUDIO_REMOTE_NAME] :: RemoteEvent,
		}

		return remotes
	end

	local function buildStatePayload(player, changedPlotIds)
		return deps.buildStatePayload(player, changedPlotIds)
	end

	local function pushStateUpdate(player, changedPlotIds)
		local payload = buildStatePayload(player, changedPlotIds)

		if payload.success then
			getOrCreateRemotes().StateUpdatedRemote:FireClient(player, payload.state)
		end
	end

	local function pushHitFeedback(player, payload)
		getOrCreateRemotes().HitFeedbackRemote:FireClient(player, payload)
	end

	local function pushAudioEvent(player, payload)
		getOrCreateRemotes().AudioRemote:FireClient(player, payload)
	end

	return {
		getOrCreateRemotes = getOrCreateRemotes,
		buildStatePayload = buildStatePayload,
		pushStateUpdate = pushStateUpdate,
		pushHitFeedback = pushHitFeedback,
		pushAudioEvent = pushAudioEvent,
	}
end

return TreeNetworkBridge
