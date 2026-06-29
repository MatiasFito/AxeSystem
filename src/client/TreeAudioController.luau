local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameFeelConfig = require(sharedFolder:WaitForChild("GameFeelConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local localSoundPlayer = require(utilsFolder:WaitForChild("LocalSoundPlayer") :: ModuleScript)
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local REMOTE_WAIT_TIMEOUT = 10
local CLEANUP_DELAY_SECONDS = 4

local TreeAudioController = {}

local started = false
local treeAudioRemote = nil

local function getCharacterRootPart()
	local character = player.Character

	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function isCharacterInsidePatch(plotCFrame, plotSize)
	local rootPart = getCharacterRootPart()

	if not rootPart or typeof(plotCFrame) ~= "CFrame" or typeof(plotSize) ~= "Vector3" then
		return false
	end

	local localPosition = plotCFrame:PointToObjectSpace(rootPart.Position)
	return math.abs(localPosition.X) <= (plotSize.X * 0.5) and math.abs(localPosition.Z) <= (plotSize.Z * 0.5)
end

local function playLocalTreeSound(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if not isCharacterInsidePatch(payload.plotCFrame, payload.plotSize) then
		return
	end

	local soundKey = if payload.kind == "death" then "TreeDeath" else "TreeHit"

	if typeof(payload.soundId) ~= "string" then
		return
	end

	localSoundPlayer.playOneShot(soundKey, payload.soundId, payload.volume, 1, CLEANUP_DELAY_SECONDS)
end

local function handleTreeAudio(payload)
	if typeof(payload) ~= "table" or payload.effectType == "particles" then
		return
	end

	playLocalTreeSound(payload)
end

local function resolveRemotes()
	local treesFolder = remoteResolver.waitForPath(ReplicatedStorage, {
		{
			Name = treeConstants.REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remotes folder was not found",
		},
		{
			Name = treeConstants.TREE_REMOTE_FOLDER_NAME,
			ErrorMessage = "Tree remote folder was not found",
		},
	}, REMOTE_WAIT_TIMEOUT)

	if not treesFolder then
		return false
	end

	local remotes = remoteResolver.waitForNamedChildren(treesFolder, {
		treeConstants.AUDIO_REMOTE_NAME,
	}, REMOTE_WAIT_TIMEOUT, "Tree remote")

	if not remotes then
		return false
	end

	treeAudioRemote = remotes[treeConstants.AUDIO_REMOTE_NAME] :: RemoteEvent
	return treeAudioRemote ~= nil
end

function TreeAudioController.start()
	if started then
		return
	end

	started = true
	localSoundPlayer.preloadOneShot("TreeHit", gameFeelConfig.TreeHitSoundId)
	localSoundPlayer.preloadOneShot("TreeDeath", gameFeelConfig.TreeDeathSoundId)

	if not resolveRemotes() then
		return
	end

	treeAudioRemote.OnClientEvent:Connect(handleTreeAudio)
end

return TreeAudioController
