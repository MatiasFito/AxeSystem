local ReplicatedStorage = game:GetService("ReplicatedStorage")

local whisperingStumpUI = require(script.Parent:WaitForChild("WhisperingStumpUI") :: ModuleScript)

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local wishingTreeConstants = require(sharedFolder:WaitForChild("WishingTreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local WishingTreeController = {}

local REMOTE_WAIT_TIMEOUT = 10

local started = false
local rollBlessingRemote = nil

local function resolveRemotes()
	local wishingTreeFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = wishingTreeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Wishing Tree remotes folder was not found",
		},
		{
			Name = wishingTreeConstants.WISHING_TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Wishing Tree remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not wishingTreeFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(
		wishingTreeFolder,
		{ wishingTreeConstants.ROLL_BLESSING_REMOTE_NAME },
		REMOTE_WAIT_TIMEOUT,
		"Wishing Tree remote"
	)

	if not remotes then
		return false
	end

	rollBlessingRemote = remotes[wishingTreeConstants.ROLL_BLESSING_REMOTE_NAME] :: RemoteFunction
	return rollBlessingRemote ~= nil
end

local function handleRollRequested()
	if not rollBlessingRemote then
		warn(wishingTreeConstants.getFailureMessage(wishingTreeConstants.FailureReason.ConfigError))
		return
	end

	local success, payload = pcall(function()
		return rollBlessingRemote:InvokeServer()
	end)

	if not success or not payload then
		warn(wishingTreeConstants.getFailureMessage(wishingTreeConstants.FailureReason.RequestFailed))
		return
	end

	if not payload.success then
		warn(payload.message or wishingTreeConstants.getFailureMessage(payload.reason))
		return
	end

	if payload.blessing then
		print(
			string.format(
				"Rolled blessing: %s (%ds remaining)",
				tostring(payload.blessing.Name or payload.blessing.BlessingId),
				tonumber(payload.blessing.RemainingDurationSeconds) or 0
			)
		)
	else
		print("Rolled blessing successfully.")
	end
end

function WishingTreeController.start()
	if started then
		return
	end

	started = true
	whisperingStumpUI.setRollHandler(handleRollRequested)

	if not resolveRemotes() then
		warn(wishingTreeConstants.getFailureMessage(wishingTreeConstants.FailureReason.ConfigError))
	end
end

return WishingTreeController
