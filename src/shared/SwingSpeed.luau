local SwingSpeed = {}

SwingSpeed.DEFAULT_MULTIPLIER = 1
SwingSpeed.DEFAULT_BASE_SWING_DURATION = 0.5
SwingSpeed.MIN_EFFECTIVE_SWING_DURATION = 0.1
SwingSpeed.FINISH_BUFFER = 0.05

local function sanitizeMultiplier(multiplier)
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return SwingSpeed.DEFAULT_MULTIPLIER
	end

	return multiplier
end

function SwingSpeed.getToolSwingSpeed(tool)
	local stats = tool and tool:FindFirstChild("Stats")
	local swingSpeedValue = stats and stats:FindFirstChild("SwingSpeed")

	if swingSpeedValue and swingSpeedValue:IsA("NumberValue") then
		return sanitizeMultiplier(swingSpeedValue.Value)
	end

	return SwingSpeed.DEFAULT_MULTIPLIER
end

function SwingSpeed.getPlaybackSpeed(baseDuration, multiplier)
	local sanitizedMultiplier = sanitizeMultiplier(multiplier)
	local sanitizedBaseDuration =
		math.max(baseDuration or SwingSpeed.DEFAULT_BASE_SWING_DURATION, SwingSpeed.MIN_EFFECTIVE_SWING_DURATION)
	local maxPlaybackSpeed = sanitizedBaseDuration / SwingSpeed.MIN_EFFECTIVE_SWING_DURATION

	return math.min(sanitizedMultiplier, maxPlaybackSpeed)
end

function SwingSpeed.getEffectiveSwingDuration(baseDuration, multiplier)
	local sanitizedBaseDuration =
		math.max(baseDuration or SwingSpeed.DEFAULT_BASE_SWING_DURATION, SwingSpeed.MIN_EFFECTIVE_SWING_DURATION)
	local playbackSpeed = SwingSpeed.getPlaybackSpeed(sanitizedBaseDuration, multiplier)

	return sanitizedBaseDuration / playbackSpeed
end

function SwingSpeed.getSwingFinishDelay(baseDuration, multiplier)
	return SwingSpeed.getEffectiveSwingDuration(baseDuration, multiplier) + SwingSpeed.FINISH_BUFFER
end

function SwingSpeed.getAutoSwingInterval(tool, baseDuration)
	return SwingSpeed.getEffectiveSwingDuration(
		baseDuration or SwingSpeed.DEFAULT_BASE_SWING_DURATION,
		SwingSpeed.getToolSwingSpeed(tool)
	)
end

return SwingSpeed
