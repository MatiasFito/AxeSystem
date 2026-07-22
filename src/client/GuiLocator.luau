local Players = game:GetService("Players")

local player = Players.LocalPlayer

local GuiLocator = {}

local function findChildPath(parent, path)
	local current = parent

	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)

		if not current then
			return nil
		end
	end

	return current
end

function GuiLocator.getPlayerGui()
	return player:WaitForChild("PlayerGui")
end

function GuiLocator.findPath(path)
	return findChildPath(GuiLocator.getPlayerGui(), path)
end

function GuiLocator.findInScreenGui(screenGuiName, path)
	local playerGui = GuiLocator.getPlayerGui()
	local screenGui = playerGui:FindFirstChild(screenGuiName)

	if not screenGui or not screenGui:IsA("ScreenGui") then
		return nil
	end

	if not path or #path == 0 then
		return screenGui
	end

	return findChildPath(screenGui, path)
end

return GuiLocator
