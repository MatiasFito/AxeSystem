local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local axeToolBuilder = require(script.Parent:WaitForChild("AxeToolBuilder") :: ModuleScript)

local AxeService = {}

function AxeService.isAxeTool(tool)
	return axeConfig.isAxeTool(tool)
end

function AxeService.canGrantTier(tierId)
	return axeToolBuilder.canBuildTier(tierId)
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
	local buildSuccess, toolOrReason = axeToolBuilder.createToolForTier(tierId)

	if not buildSuccess then
		return false, toolOrReason
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)

	if not backpack then
		return false, "backpackMissing"
	end

	AxeService.removePlayerAxes(player)

	local tool = toolOrReason
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
