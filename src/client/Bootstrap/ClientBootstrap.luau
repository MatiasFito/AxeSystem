local ClientBootstrap = {}

local controllerDefinitions = {
	"AutoSwingUI",
	"BlacksmithZoneController",
	"LumberjackUpgradePadController",
	"SwingSpeedPad",
	"TopGoldLabel",
	"TreeStatusUI",
	"TreeUpgradePadController",
}

local function loadControllers(clientRoot)
	local controllers = {}

	for _, moduleName in ipairs(controllerDefinitions) do
		controllers[moduleName] = require(clientRoot:WaitForChild(moduleName) :: ModuleScript)
	end

	return controllers
end

function ClientBootstrap.start(clientRoot)
	local controllers = loadControllers(clientRoot)

	for _, moduleName in ipairs(controllerDefinitions) do
		controllers[moduleName].start()
	end

	return controllers
end

return ClientBootstrap
