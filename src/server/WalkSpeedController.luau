local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)

local WalkSpeedController = {}

local BASE_WALK_SPEED = 16
local WALK_SPEED_UPGRADE_KEY = "WalkSpeed"

local function resolveWalkSpeed(playerData, player)
	local walkSpeedLevel = playerData.getAmberUpgradeLevel(player, WALK_SPEED_UPGRADE_KEY) or 0
	local walkSpeedMultiplier = rebirthConfig.getWalkSpeedMultiplier(walkSpeedLevel)

	return BASE_WALK_SPEED * walkSpeedMultiplier
end

function WalkSpeedController.applyToCharacter(playerData, player, character)
	if not playerData or not player or not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)

	if not humanoid then
		return false
	end

	humanoid.WalkSpeed = resolveWalkSpeed(playerData, player)
	return true
end

function WalkSpeedController.applyToCurrentCharacter(playerData, player)
	if not playerData or not player then
		return false
	end

	local character = player.Character

	if not character then
		return false
	end

	return WalkSpeedController.applyToCharacter(playerData, player, character)
end

return WalkSpeedController
