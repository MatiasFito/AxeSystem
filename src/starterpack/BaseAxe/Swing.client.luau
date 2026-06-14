local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tool = script.Parent
local animationsFolder = tool:WaitForChild("Animations")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)

local randomGenerator = Random.new()

local animationNames = {
	"AxeSlash1",
	"AxeSlash2",
	"AxeSlash3",
	"AxeSlash4",
}

local soundName = "SwingSound"
local soundId = "rbxassetid://541909763"
local soundVolume = 2

local animator = nil
local swingSound = nil
local animationTracks = {}
local activeTrack = nil
local lastPlayedIndex = nil
local isSwinging = false

local function getCharacter()
	local parent = tool.Parent

	if parent and parent:IsA("Model") then
		return parent
	end

	return nil
end

local function ensureAnimator()
	local character = getCharacter()

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil
	end

	animator = humanoid:FindFirstChildOfClass("Animator")

	if animator then
		return animator
	end

	animator = humanoid:WaitForChild("Animator", 2)

	return animator
end

local function ensureSwingSound()
	local handle = tool:FindFirstChild("Handle")

	if not handle or not handle:IsA("BasePart") then
		return nil
	end

	local existingSound = handle:FindFirstChild(soundName)

	if existingSound and existingSound:IsA("Sound") then
		existingSound.SoundId = soundId
		existingSound.Volume = soundVolume
		swingSound = existingSound
		return swingSound
	end

	return nil
end

local function loadAnimationTracks()
	table.clear(animationTracks)

	if not animator then
		return false
	end

	for _, animationName in animationNames do
		local animation = animationsFolder:FindFirstChild(animationName)

		if animation and animation:IsA("Animation") then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			table.insert(animationTracks, track)
		else
			warn(string.format("BaseAxe missing animation '%s'", animationName))
		end
	end

	return #animationTracks > 0
end

local function stopActiveTrack()
	if activeTrack then
		activeTrack:Stop(0.05)
		activeTrack = nil
	end
end

local function chooseNextTrackIndex()
	if #animationTracks == 0 then
		return nil
	end

	if #animationTracks == 1 then
		return 1
	end

	local nextIndex = randomGenerator:NextInteger(1, #animationTracks)

	while nextIndex == lastPlayedIndex do
		nextIndex = randomGenerator:NextInteger(1, #animationTracks)
	end

	return nextIndex
end

local function releaseSwing(track)
	if activeTrack == track then
		activeTrack = nil
		isSwinging = false
	end
end

local function refreshRuntimeState()
	if not ensureAnimator() then
		return false
	end

	if not ensureSwingSound() then
		warn("BaseAxe missing SwingSound under Handle")
	end

	return loadAnimationTracks()
end

tool.Equipped:Connect(function()
	stopActiveTrack()
	isSwinging = false
	refreshRuntimeState()
end)

tool.Unequipped:Connect(function()
	if swingSound then
		swingSound:Stop()
	end

	stopActiveTrack()
	isSwinging = false
	animator = nil
	lastPlayedIndex = nil
	table.clear(animationTracks)
end)

tool.Activated:Connect(function()
	if isSwinging then
		return
	end

	if #animationTracks == 0 and not refreshRuntimeState() then
		warn("BaseAxe could not load swing animations")
		return
	end

	local nextIndex = chooseNextTrackIndex()

	if not nextIndex then
		warn("BaseAxe has no swing animations available")
		return
	end

	local nextTrack = animationTracks[nextIndex]

	if not nextTrack then
		warn("BaseAxe selected an invalid swing animation track")
		return
	end

	isSwinging = true
	activeTrack = nextTrack
	lastPlayedIndex = nextIndex

	local released = false
	local stoppedConnection

	local function finishSwing()
		if released then
			return
		end

		released = true

		if stoppedConnection then
			stoppedConnection:Disconnect()
			stoppedConnection = nil
		end

		releaseSwing(nextTrack)
	end

	stoppedConnection = nextTrack.Stopped:Connect(finishSwing)

	local baseDuration = nextTrack.Length

	if baseDuration <= 0 then
		baseDuration = swingSpeed.DEFAULT_BASE_SWING_DURATION
	end

	local desiredSwingSpeed = swingSpeed.getToolSwingSpeed(tool)
	local playbackSpeed = swingSpeed.getPlaybackSpeed(baseDuration, desiredSwingSpeed)

	nextTrack:Play(0.05, 1, playbackSpeed)

	local sound = swingSound or ensureSwingSound()

	if sound then
		sound:Stop()
		sound.TimePosition = 0
		sound.PlaybackSpeed = playbackSpeed
		sound:Play()
	end

	local fallbackDuration = swingSpeed.getSwingFinishDelay(baseDuration, desiredSwingSpeed)
	task.delay(fallbackDuration, finishSwing)
end)
