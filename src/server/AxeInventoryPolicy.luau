local AxeInventoryPolicy = {}

function AxeInventoryPolicy.create(deps)
	local function removePlayerAxes(player)
		local containers = {
			player:FindFirstChildOfClass("Backpack"),
			player.Character,
		}

		for _, container in containers do
			if container then
				for _, child in container:GetChildren() do
					if deps.isAxeTool(child) then
						child:Destroy()
					end
				end
			end
		end
	end

	local function grantTool(player, tool, equipTool)
		local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)

		if not backpack then
			return false, "backpackMissing"
		end

		removePlayerAxes(player)
		tool.Parent = backpack

		if equipTool and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				humanoid:EquipTool(tool)
			end
		end

		return true, tool
	end

	return {
		removePlayerAxes = removePlayerAxes,
		grantTool = grantTool,
	}
end

return AxeInventoryPolicy
