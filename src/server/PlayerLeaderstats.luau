local PlayerLeaderstats = {}

local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local goldValue = leaderstats:FindFirstChild("Gold")

	if goldValue and goldValue:IsA("IntValue") then
		return goldValue
	end

	if goldValue then
		goldValue:Destroy()
	end

	goldValue = Instance.new("IntValue")
	goldValue.Name = "Gold"
	goldValue.Parent = leaderstats

	return goldValue
end

function PlayerLeaderstats.syncGold(player, gold)
	local goldValue = ensureLeaderstats(player)
	goldValue.Value = gold
end

return PlayerLeaderstats
