local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)

local AxeService = {}

local function getTemplatesFolder()
	return ServerStorage:WaitForChild(blacksmithConstants.AXE_TEMPLATE_FOLDER_NAME)
end

local function getTierAndTemplate(tierId)
	local tier = axeConfig.getTier(tierId)

	if not tier then
		return nil, nil, blacksmithConstants.FailureReason.ConfigError
	end

	local template = getTemplatesFolder():FindFirstChild(tier.ToolTemplateName)

	if not template or not template:IsA("Tool") then
		return nil, nil, blacksmithConstants.FailureReason.ConfigError
	end

	return tier, template, nil
end

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

local function configureTool(tool, tier)
	tool.Name = tier.Id
	tool:SetAttribute(blacksmithConstants.IS_AXE_TOOL_ATTRIBUTE, true)
	tool:SetAttribute(blacksmithConstants.AXE_TIER_ID_ATTRIBUTE, tier.Id)

	local stats = ensureStatsFolder(tool)
	ensureNumberValue(stats, "Power", tier.Power)
	ensureNumberValue(stats, "GoldBonus", tier.GoldMultiplier)
end

function AxeService.isAxeTool(tool)
	return axeConfig.isAxeTool(tool)
end

function AxeService.canGrantTier(tierId)
	local _, _, reason = getTierAndTemplate(tierId)
	return reason == nil, reason
end

function AxeService.removePlayerAxes(player)
	local containers = {
		player:FindFirstChildOfClass("Backpack"),
		player.Character,
	}

	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if AxeService.isAxeTool(child) then
					child:Destroy()
				end
			end
		end
	end
end

function AxeService.grantAxe(player, tierId, equipTool)
	local tier, template, reason = getTierAndTemplate(tierId)

	if not tier or not template then
		return false, reason
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)

	if not backpack then
		return false, "backpackMissing"
	end

	AxeService.removePlayerAxes(player)

	local tool = template:Clone()
	configureTool(tool, tier)
	tool.Parent = backpack

	if equipTool and player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid:EquipTool(tool)
		end
	end

	return true, tool
end

return AxeService
