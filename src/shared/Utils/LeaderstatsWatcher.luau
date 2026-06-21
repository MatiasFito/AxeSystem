--!strict

local LeaderstatsWatcher = {}

function LeaderstatsWatcher.watchIntValue(
	player: Player,
	statName: string,
	timeout: number,
	onValueChanged: (number, IntValue) -> ()
): () -> ()
	local leaderstatsConnection: RBXScriptConnection? = nil
	local valueConnection: RBXScriptConnection? = nil

	local function disconnect()
		if valueConnection then
			valueConnection:Disconnect()
			valueConnection = nil
		end

		if leaderstatsConnection then
			leaderstatsConnection:Disconnect()
			leaderstatsConnection = nil
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", timeout)

	if not leaderstats then
		return disconnect
	end

	local function attachValue(valueObject: Instance?)
		if valueConnection then
			valueConnection:Disconnect()
			valueConnection = nil
		end

		if not valueObject or not valueObject:IsA("IntValue") then
			return
		end

		onValueChanged(valueObject.Value, valueObject)
		valueConnection = valueObject:GetPropertyChangedSignal("Value"):Connect(function()
			onValueChanged(valueObject.Value, valueObject)
		end)
	end

	attachValue(leaderstats:FindFirstChild(statName) or leaderstats:WaitForChild(statName, timeout))
	leaderstatsConnection = leaderstats.ChildAdded:Connect(function(child)
		if child.Name == statName and child:IsA("IntValue") then
			attachValue(child)
		end
	end)

	return disconnect
end

return LeaderstatsWatcher
