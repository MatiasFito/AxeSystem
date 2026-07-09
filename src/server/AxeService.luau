local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)
local axeToolBuilder = require(script.Parent:WaitForChild("AxeToolBuilder") :: ModuleScript)
local axeInventoryPolicyModule = require(script.Parent:WaitForChild("AxeInventoryPolicy") :: ModuleScript)

local AxeService = {}
local axeInventoryPolicy = axeInventoryPolicyModule.create({
	isAxeTool = axeConfig.isAxeTool,
})

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

local function getPlayerSwingSpeed(player)
	return sanitizeSwingSpeed(player and player:GetAttribute(swingSpeed.PLAYER_ATTRIBUTE_NAME) or nil)
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
	local sanitizedMultiplier = sanitizeSwingSpeed(multiplier)

	if player then
		player:SetAttribute(swingSpeed.PLAYER_ATTRIBUTE_NAME, sanitizedMultiplier)
	end

	local containers = {
		player and player:FindFirstChildOfClass("Backpack") or nil,
		player and player.Character or nil,
	}

	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				setToolSwingSpeed(child, sanitizedMultiplier)
			end
		end
	end

	return sanitizedMultiplier
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
	return getPlayerSwingSpeed(player)
end

function AxeService.setPlayerSwingSpeed(player, multiplier)
	return applyPlayerSwingSpeed(player, multiplier)
end

function AxeService.grantAxe(player, tierId, equipTool)
	local buildSuccess, toolOrReason = axeToolBuilder.createToolForTier(tierId)

	if not buildSuccess then
		return false, toolOrReason
	end

	local tool = toolOrReason
	setToolSwingSpeed(tool, getPlayerSwingSpeed(player))
	return axeInventoryPolicy.grantTool(player, tool, equipTool)
end

return AxeService
