local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)
local axeToolBuilder = require(script.Parent:WaitForChild("AxeToolBuilder") :: ModuleScript)
local axeInventoryPolicyModule = require(script.Parent:WaitForChild("AxeInventoryPolicy") :: ModuleScript)

local AxeService = {}
local axeInventoryPolicy = axeInventoryPolicyModule.create({
	isAxeTool = axeConfig.isAxeTool,
})
local playerData = nil
local gamePassService = nil
local wishingTreeService = nil
local SWING_SPEED_UPGRADE_KEY = "SwingSpeed"

local function ensureStatsFolder(tool)
	local stats = tool:FindFirstChild("Stats")

	if stats and stats:IsA("Configuration") then
		return stats
	end

	if stats then
		stats:Destroy()
	end

	stats = Instance.new("Configuration")
	stats.Name = "Stats"
	stats.Parent = tool

	return stats
end

local function ensureNumberValue(parent, name, value)
	local numberValue = parent:FindFirstChild(name)

	if numberValue and numberValue:IsA("NumberValue") then
		numberValue.Value = value
		return numberValue
	end

	if numberValue then
		numberValue:Destroy()
	end

	numberValue = Instance.new("NumberValue")
	numberValue.Name = name
	numberValue.Value = value
	numberValue.Parent = parent

	return numberValue
end

local function sanitizeSwingSpeed(multiplier)
	return swingSpeed.sanitizeSelectedMultiplier(multiplier)
end

local function getSelectedPlayerSwingSpeed(player)
	return sanitizeSwingSpeed(player and player:GetAttribute(swingSpeed.PLAYER_ATTRIBUTE_NAME) or nil)
end

local function getAmberSwingSpeedMultiplier(player)
	if not playerData or not player then
		return 1
	end

	local swingSpeedLevel = playerData.getAmberUpgradeLevel(player, SWING_SPEED_UPGRADE_KEY) or 0
	return rebirthConfig.getSwingSpeedMultiplier(swingSpeedLevel)
end

local function getGamePassSwingSpeedMultiplier(player)
	if not gamePassService or not gamePassService.getSwingSpeedMultiplier or not player then
		return 1
	end

	local multiplier = gamePassService.getSwingSpeedMultiplier(player)

	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function getBlessingSwingSpeedMultiplier(player)
	if not wishingTreeService or not wishingTreeService.getAttackSpeedMultiplier or not player then
		return 1
	end

	local multiplier = wishingTreeService.getAttackSpeedMultiplier(player)

	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function getEffectivePlayerSwingSpeed(player, selectedMultiplier)
	local resolvedSelectedMultiplier = selectedMultiplier

	if typeof(resolvedSelectedMultiplier) ~= "number" then
		resolvedSelectedMultiplier = getSelectedPlayerSwingSpeed(player)
	end

	return resolvedSelectedMultiplier
		* getAmberSwingSpeedMultiplier(player)
		* getGamePassSwingSpeedMultiplier(player)
		* getBlessingSwingSpeedMultiplier(player)
end

local function setToolSwingSpeed(tool, multiplier)
	if not axeConfig.isAxeTool(tool) then
		return false
	end

	local stats = ensureStatsFolder(tool)
	ensureNumberValue(stats, "SwingSpeed", sanitizeSwingSpeed(multiplier))
	return true
end

local function applyPlayerSwingSpeed(player, multiplier)
	local selectedMultiplier = multiplier

	if typeof(selectedMultiplier) == "number" then
		selectedMultiplier = sanitizeSwingSpeed(selectedMultiplier)
	elseif player then
		selectedMultiplier = getSelectedPlayerSwingSpeed(player)
	else
		selectedMultiplier = swingSpeed.DEFAULT_MULTIPLIER
	end

	local effectiveMultiplier = getEffectivePlayerSwingSpeed(player, selectedMultiplier)

	if player then
		player:SetAttribute(swingSpeed.PLAYER_ATTRIBUTE_NAME, selectedMultiplier)
		player:SetAttribute(swingSpeed.EFFECTIVE_PLAYER_ATTRIBUTE_NAME, effectiveMultiplier)
	end

	local containers = {
		player and player:FindFirstChildOfClass("Backpack") or nil,
		player and player.Character or nil,
	}

	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				setToolSwingSpeed(child, effectiveMultiplier)
			end
		end
	end

	return effectiveMultiplier
end

function AxeService.start(playerDataModule, gamePassServiceModule, wishingTreeServiceModule)
	playerData = playerDataModule
	gamePassService = gamePassServiceModule
	wishingTreeService = wishingTreeServiceModule
end

function AxeService.isAxeTool(tool)
	return axeConfig.isAxeTool(tool)
end

function AxeService.canGrantTier(tierId)
	return axeToolBuilder.canBuildTier(tierId)
end

function AxeService.removePlayerAxes(player)
	return axeInventoryPolicy.removePlayerAxes(player)
end

function AxeService.getPlayerSwingSpeed(player)
	return getEffectivePlayerSwingSpeed(player)
end

function AxeService.setPlayerSwingSpeed(player, multiplier)
	return applyPlayerSwingSpeed(player, multiplier)
end

function AxeService.applyToPlayer(player)
	return applyPlayerSwingSpeed(player)
end

function AxeService.grantAxe(player, tierId, equipTool)
	local buildSuccess, toolOrReason = axeToolBuilder.createToolForTier(tierId)

	if not buildSuccess then
		return false, toolOrReason
	end

	local tool = toolOrReason
	setToolSwingSpeed(tool, getEffectivePlayerSwingSpeed(player))
	return axeInventoryPolicy.grantTool(player, tool, equipTool)
end

return AxeService
