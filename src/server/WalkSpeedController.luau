local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)

local WalkSpeedController = {}

local BASE_WALK_SPEED = 16
local WALK_SPEED_UPGRADE_KEY = "WalkSpeed"

local function getBlessingMovementSpeedMultiplier(wishingTreeService, player)
	if not wishingTreeService or not wishingTreeService.getMovementSpeedMultiplier or not player then
		return 1
	end

	local multiplier = wishingTreeService.getMovementSpeedMultiplier(player)

	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function getGamePassMovementSpeedMultiplier(gamePassService, player)
	if not gamePassService or not gamePassService.getMovementSpeedMultiplier or not player then
		return 1
	end

	local multiplier = gamePassService.getMovementSpeedMultiplier(player)

	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function resolveWalkSpeed(playerData, gamePassService, wishingTreeService, player)
	local walkSpeedLevel = playerData.getAmberUpgradeLevel(player, WALK_SPEED_UPGRADE_KEY) or 0
	local walkSpeedMultiplier = rebirthConfig.getWalkSpeedMultiplier(walkSpeedLevel)

	return BASE_WALK_SPEED
		* walkSpeedMultiplier
		* getGamePassMovementSpeedMultiplier(gamePassService, player)
		* getBlessingMovementSpeedMultiplier(wishingTreeService, player)
end

function WalkSpeedController.applyToCharacter(playerData, gamePassService, wishingTreeService, player, character)
	if not playerData or not player or not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)

	if not humanoid then
		return false
	end

	humanoid.WalkSpeed = resolveWalkSpeed(playerData, gamePassService, wishingTreeService, player)
	return true
end

function WalkSpeedController.applyToCurrentCharacter(playerData, gamePassService, wishingTreeService, player)
	if not playerData or not player then
		return false
	end

	local character = player.Character

	if not character then
		return false
	end

	return WalkSpeedController.applyToCharacter(playerData, gamePassService, wishingTreeService, player, character)
end

return WalkSpeedController
