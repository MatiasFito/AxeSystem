local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local axeToolBuilder = require(script.Parent:WaitForChild("AxeToolBuilder") :: ModuleScript)
local axeInventoryPolicyModule = require(script.Parent:WaitForChild("AxeInventoryPolicy") :: ModuleScript)

local AxeService = {}
local axeInventoryPolicy = axeInventoryPolicyModule.create({
	isAxeTool = axeConfig.isAxeTool,
})

function AxeService.isAxeTool(tool)
	return axeConfig.isAxeTool(tool)
end

function AxeService.canGrantTier(tierId)
	return axeToolBuilder.canBuildTier(tierId)
end

function AxeService.removePlayerAxes(player)
	return axeInventoryPolicy.removePlayerAxes(player)
end

function AxeService.grantAxe(player, tierId, equipTool)
	local buildSuccess, toolOrReason = axeToolBuilder.createToolForTier(tierId)

	if not buildSuccess then
		return false, toolOrReason
	end

	local tool = toolOrReason
	return axeInventoryPolicy.grantTool(player, tool, equipTool)
end

return AxeService
