local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)

local TreeInteractionUtils = {}

function TreeInteractionUtils.getCharacterRootPart(player)
	local character = player.Character

	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

function TreeInteractionUtils.getEquippedAxeTool(player)
	local character = player.Character

	if not character then
		return nil
	end

	for _, child in character:GetChildren() do
		if axeConfig.isAxeTool(child) then
			return child
		end
	end

	return nil
end

function TreeInteractionUtils.getToolStatValue(tool, statName, fallbackValue)
	if not tool or not tool:IsA("Tool") then
		return fallbackValue
	end

	local statsFolder = tool:FindFirstChild("Stats")

	if not statsFolder then
		return fallbackValue
	end

	local statValue = statsFolder:FindFirstChild(statName)

	if statValue and statValue:IsA("NumberValue") then
		return statValue.Value
	end

	return fallbackValue
end

function TreeInteractionUtils.getTouchingPlayer(hit)
	if not hit then
		return nil
	end

	local character = hit.Parent

	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

return TreeInteractionUtils
