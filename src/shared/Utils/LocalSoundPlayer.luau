local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local LocalSoundPlayer = {}

local reusableSounds = {}
local oneShotTemplates = {}

local function ensureSound(store, key, soundId)
	local sound = store[key]

	if sound and sound.Parent == SoundService then
		sound.SoundId = soundId
		return sound
	end

	sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = soundId
	sound.Volume = 1
	sound.Parent = SoundService
	store[key] = sound

	pcall(function()
		ContentProvider:PreloadAsync({ sound })
	end)

	return sound
end

function LocalSoundPlayer.preloadReusable(key, soundId)
	return ensureSound(reusableSounds, key, soundId)
end

function LocalSoundPlayer.playReusable(key, soundId, volume, playbackSpeed)
	local sound = ensureSound(reusableSounds, key, soundId)
	sound.Volume = math.max(0, tonumber(volume) or 0)
	sound.PlaybackSpeed = math.max(0.05, tonumber(playbackSpeed) or 1)
	sound:Stop()
	sound.TimePosition = 0
	SoundService:PlayLocalSound(sound)
	return sound
end

function LocalSoundPlayer.stopReusable(key)
	local sound = reusableSounds[key]

	if sound and sound.Parent == SoundService then
		sound:Stop()
	end
end

function LocalSoundPlayer.preloadOneShot(key, soundId)
	return ensureSound(oneShotTemplates, key, soundId)
end

function LocalSoundPlayer.playOneShot(key, soundId, volume, playbackSpeed, cleanupDelaySeconds)
	local template = ensureSound(oneShotTemplates, key, soundId)
	local sound = template:Clone()
	sound.SoundId = soundId
	sound.Volume = math.max(0, tonumber(volume) or 0)
	sound.PlaybackSpeed = math.max(0.05, tonumber(playbackSpeed) or 1)
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)

	task.delay(cleanupDelaySeconds or 4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)

	return sound
end

return LocalSoundPlayer
