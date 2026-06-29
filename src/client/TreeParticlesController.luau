local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local networkFolder = sharedFolder:WaitForChild("Network")
local remoteResolver = require(networkFolder:WaitForChild("RemoteResolver") :: ModuleScript)

local REMOTE_WAIT_TIMEOUT = 10
local PARTICLE_CLEANUP_DELAY_SECONDS = 1

local TreeParticlesController = {}

local started = false
local treeAudioRemote = nil

local function playLocalTreeParticles(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.effectType ~= "particles" then
		return
	end

	if typeof(payload.particleCFrame) ~= "CFrame" or typeof(payload.particleCount) ~= "number" then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Name = "TreeLocalParticleAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = payload.particleCFrame
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Name = "TreeImpactAttachment"
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "TreeImpactParticles"
	emitter.Texture = typeof(payload.particleTexture) == "string" and payload.particleTexture
		or "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 40, 180), Color3.fromRGB(255, 105, 205))
	emitter.Lifetime = NumberRange.new(0.18, 0.35)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = 0
	emitter.LockedToPart = false
	emitter.Acceleration = Vector3.new(0, -16, 0)
	emitter.Parent = attachment
	emitter:Emit(math.max(1, math.floor(payload.particleCount)))

	task.delay(PARTICLE_CLEANUP_DELAY_SECONDS, function()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)
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

function TreeParticlesController.start()
	if started then
		return
	end

	started = true

	if not resolveRemotes() then
		return
	end

	treeAudioRemote.OnClientEvent:Connect(playLocalTreeParticles)
end

return TreeParticlesController
