local PlayerLeaderstats = {}

local function ensureIntValue(parent, valueName)
	local value = parent:FindFirstChild(valueName)

	if value and value:IsA("IntValue") then
		return value
	end

	if value then
		value:Destroy()
	end

	value = Instance.new("IntValue")
	value.Name = valueName
	value.Parent = parent

	return value
end

local function ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	ensureIntValue(leaderstats, "Gold")
	ensureIntValue(leaderstats, "Rebirths")

	return leaderstats
end

function PlayerLeaderstats.syncGold(player, gold)
	local leaderstats = ensureLeaderstats(player)
	local goldValue = ensureIntValue(leaderstats, "Gold")
	goldValue.Value = gold
end

function PlayerLeaderstats.syncRebirths(player, rebirths)
	local leaderstats = ensureLeaderstats(player)
	local rebirthValue = ensureIntValue(leaderstats, "Rebirths")
	rebirthValue.Value = rebirths
end

return PlayerLeaderstats
