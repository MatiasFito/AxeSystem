local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local tool = script.Parent
local animationsFolder = tool:WaitForChild("Animations")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gameFeelConfig = require(sharedFolder:WaitForChild("GameFeelConfig") :: ModuleScript)
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local localSoundPlayer = require(utilsFolder:WaitForChild("LocalSoundPlayer") :: ModuleScript)

local randomGenerator = Random.new()

local animationNames = {
	"AxeSlash1",
	"AxeSlash2",
	"AxeSlash3",
	"AxeSlash4",
}

local autoSwingAttributeName = "AutoSwingHeld"
local soundId = "rbxassetid://541909763"
local soundKey = "AxeSwingLocal"
local swingTimingPollInterval = 0.01
local treeHitRange = treeConstants.HIT_DISTANCE
local treeHitRemote = nil

local animator = nil
local animationTracks = {}
local activeTrack = nil
local lastPlayedIndex = nil
local manualHoldActive = false
local autoHoldActive = tool:GetAttribute(autoSwingAttributeName) == true
local repeatLoopId = 0
local repeatLoopRunning = false
local lastRepeatDelay = swingSpeed.DEFAULT_BASE_SWING_DURATION
local nextSwingAt = 0

local function getCharacter()
	local parent = tool.Parent

	if parent and parent:IsA("Model") then
		return parent
	end

	return nil
end

local function getRootPart()
	local character = getCharacter()

	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function resolveTreeHitRemote()
	if treeHitRemote and treeHitRemote.Parent then
		return treeHitRemote
	end

	local remotesFolder = ReplicatedStorage:FindFirstChild(treeConstants.REMOTE_FOLDER_NAME)
	local treesFolder = remotesFolder and remotesFolder:FindFirstChild(treeConstants.TREE_REMOTE_FOLDER_NAME)
	local remote = treesFolder and treesFolder:FindFirstChild(treeConstants.REQUEST_HIT_REMOTE_NAME)

	if remote and remote:IsA("RemoteEvent") then
		treeHitRemote = remote
		return treeHitRemote
	end

	return nil
end

local function findTreePlotIdCandidate()
	local rootPart = getRootPart()

	if not rootPart then
		return nil
	end

	local nearestPlotId = nil
	local nearestDistance = treeHitRange

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(treeConstants.IS_MANAGED_TREE_ATTRIBUTE) == true then
			local plotId = descendant:GetAttribute(treeConstants.TREE_PLOT_ID_ATTRIBUTE)

			if typeof(plotId) == "string" then
				local distance = (descendant.Position - rootPart.Position).Magnitude

				if distance <= nearestDistance then
					nearestDistance = distance
					nearestPlotId = plotId
				end
			end
		end
	end

	return nearestPlotId
end

local function reportTreeHit()
	local remote = resolveTreeHitRemote()

	if not remote then
		return
	end

	local plotId = findTreePlotIdCandidate()

	if plotId then
		remote:FireServer(plotId)
	end
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
	return localSoundPlayer.preloadReusable(soundKey, soundId)
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

local function stopActiveTrack(fadeTime)
	if activeTrack then
		local track = activeTrack
		activeTrack = nil
		track:Stop(fadeTime or 0.05)
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
	end
end

local function shouldKeepSwinging()
	return manualHoldActive or autoHoldActive
end

local function stopRepeatLoop()
	repeatLoopId += 1
	repeatLoopRunning = false
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

local function attemptSwing()
	local now = os.clock()

	if now < nextSwingAt then
		return false, nextSwingAt - now
	end

	if #animationTracks == 0 and not refreshRuntimeState() then
		nextSwingAt = now + lastRepeatDelay
		warn("BaseAxe could not load swing animations")
		return false, lastRepeatDelay
	end

	local nextIndex = chooseNextTrackIndex()

	if not nextIndex then
		nextSwingAt = now + lastRepeatDelay
		warn("BaseAxe has no swing animations available")
		return false, lastRepeatDelay
	end

	local nextTrack = animationTracks[nextIndex]

	if not nextTrack then
		nextSwingAt = now + lastRepeatDelay
		warn("BaseAxe selected an invalid swing animation track")
		return false, lastRepeatDelay
	end

	stopActiveTrack(0)

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
	local effectiveDuration = swingSpeed.getEffectiveSwingDuration(baseDuration, desiredSwingSpeed)

	lastRepeatDelay = effectiveDuration
	nextSwingAt = now + effectiveDuration
	nextTrack:Play(0.05, 1, playbackSpeed)
	task.delay(math.max(0.03, math.min(0.12, effectiveDuration * 0.35)), reportTreeHit)

	if ensureSwingSound() then
		localSoundPlayer.playReusable(soundKey, soundId, gameFeelConfig.getAxeSwingSoundVolume(), playbackSpeed)
	end

	local fallbackDuration = swingSpeed.getSwingFinishDelay(baseDuration, desiredSwingSpeed)
	task.delay(fallbackDuration, finishSwing)

	return true, effectiveDuration
end

local function runRepeatLoop(currentLoopId)
	while repeatLoopId == currentLoopId and shouldKeepSwinging() and getCharacter() do
		local waitDuration = math.max(0, nextSwingAt - os.clock())

		if waitDuration > 0 then
			task.wait(math.min(swingTimingPollInterval, waitDuration))
		else
			attemptSwing()
		end

		if repeatLoopId ~= currentLoopId or not shouldKeepSwinging() or not getCharacter() then
			break
		end
	end

	if repeatLoopId == currentLoopId then
		repeatLoopRunning = false
	end
end

local function startRepeatLoop()
	if repeatLoopRunning or not shouldKeepSwinging() or not getCharacter() then
		return
	end

	repeatLoopId += 1
	repeatLoopRunning = true
	local currentLoopId = repeatLoopId

	task.spawn(runRepeatLoop, currentLoopId)
end

local function syncAutoHoldState()
	autoHoldActive = tool:GetAttribute(autoSwingAttributeName) == true

	if autoHoldActive then
		attemptSwing()
		startRepeatLoop()
	elseif not manualHoldActive then
		stopRepeatLoop()
	end
end

tool.Equipped:Connect(function()
	stopActiveTrack()
	lastRepeatDelay = swingSpeed.DEFAULT_BASE_SWING_DURATION
	nextSwingAt = 0
	refreshRuntimeState()
	syncAutoHoldState()
end)

tool.Unequipped:Connect(function()
	localSoundPlayer.stopReusable(soundKey)

	manualHoldActive = false
	autoHoldActive = false
	stopRepeatLoop()
	stopActiveTrack()
	animator = nil
	lastPlayedIndex = nil
	lastRepeatDelay = swingSpeed.DEFAULT_BASE_SWING_DURATION
	nextSwingAt = 0
	table.clear(animationTracks)
end)

tool.Activated:Connect(function()
	manualHoldActive = true
	attemptSwing()
	startRepeatLoop()
end)

tool.Deactivated:Connect(function()
	manualHoldActive = false

	if not autoHoldActive then
		stopRepeatLoop()
	end
end)

tool:GetAttributeChangedSignal(autoSwingAttributeName):Connect(syncAutoHoldState)
