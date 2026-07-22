local RobloxSubscriptionConfig = {}

RobloxSubscriptionConfig.GOLD_MULTIPLIER = 1.5

local function isPlayerInstance(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

function RobloxSubscriptionConfig.hasSubscription(player: Player)
	if not isPlayerInstance(player) then
		return false
	end

	return player.HasRobloxSubscription == true or player.MembershipType == Enum.MembershipType.Premium
end

function RobloxSubscriptionConfig.getGoldMultiplier(player: Player)
	if RobloxSubscriptionConfig.hasSubscription(player) then
		return RobloxSubscriptionConfig.GOLD_MULTIPLIER
	end

	return 1
end

return RobloxSubscriptionConfig
