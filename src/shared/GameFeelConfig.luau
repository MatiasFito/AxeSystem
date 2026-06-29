local GameFeelConfig = {
	AxeSwingSoundMuted = false,
	AxeSwingSoundVolume = 0.1,
	TreeHitSoundId = "rbxassetid://136507037003210",
	TreeHitSoundVolume = 3,
	TreeDeathSoundId = "rbxassetid://7214256592",
	TreeDeathSoundVolume = 0.1,
	TreePromptSuccessSoundId = "rbxassetid://138273059623491",
	TreePromptSuccessSoundVolume = 1.2,
	TreeHitParticleCount = 20,
	TreeFellParticleCount = 40,
	TreeShakeDuration = 0.08,
	TreeShakeAngleDegrees = 7,
}

function GameFeelConfig.getAxeSwingSoundVolume()
	if GameFeelConfig.AxeSwingSoundMuted then
		return 0
	end

	return math.max(0, GameFeelConfig.AxeSwingSoundVolume)
end

return GameFeelConfig
