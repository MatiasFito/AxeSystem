local InfinitreeConfig = {}

InfinitreeConfig.UNLOCK_COST = 100
InfinitreeConfig.MIN_LEVEL = 1
InfinitreeConfig.GROW_TIME = 0
InfinitreeConfig.HEALTH = 1

function InfinitreeConfig.getGoldPerHit(level)
	local resolvedLevel = math.max(InfinitreeConfig.MIN_LEVEL, math.floor(level or InfinitreeConfig.MIN_LEVEL))
	local levelOffset = resolvedLevel - 1
	return math.max(1, math.floor(6 + 3 * math.sqrt(levelOffset) + 0.45 * levelOffset))
end

function InfinitreeConfig.getUpgradeCost(level)
	local resolvedLevel = math.max(InfinitreeConfig.MIN_LEVEL, math.floor(level or InfinitreeConfig.MIN_LEVEL))
	return math.max(1, math.floor(80 + 50 * resolvedLevel + 18 * (resolvedLevel ^ 1.7) + 2.5 * (resolvedLevel ^ 2)))
end

function InfinitreeConfig.getLevelData(level)
	local resolvedLevel = math.max(InfinitreeConfig.MIN_LEVEL, math.floor(level or InfinitreeConfig.MIN_LEVEL))
	return {
		Level = resolvedLevel,
		Health = InfinitreeConfig.HEALTH,
		GrowTime = InfinitreeConfig.GROW_TIME,
		Reward = InfinitreeConfig.getGoldPerHit(resolvedLevel),
		UpgradeCost = InfinitreeConfig.getUpgradeCost(resolvedLevel),
	}
end

return InfinitreeConfig
