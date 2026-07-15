local Players = game:GetService("Players")

local ServerBootstrap = {}

local studioAssetValidatorModuleName = "StudioAssetValidator"
local walkSpeedControllerModuleName = "WalkSpeedController"

local serviceDefinitions = {
	{
		name = "AxeService",
		moduleName = "AxeService",
	},
	{
		name = "AmberShopService",
		moduleName = "AmberShopService",
	},
	{
		name = "BlacksmithService",
		moduleName = "BlacksmithService",
	},
	{
		name = "LumberjackService",
		moduleName = "LumberjackService",
	},
	{
		name = "RebirthService",
		moduleName = "RebirthService",
	},
	{
		name = "OrbOfRegretService",
		moduleName = "OrbOfRegretService",
	},
	{
		name = "PlayerData",
		moduleName = "PlayerData",
	},
	{
		name = "SessionTimeService",
		moduleName = "SessionTimeService",
	},
	{
		name = "TreePlotService",
		moduleName = "TreePlotService",
	},
	{
		name = "TreeService",
		moduleName = "TreeService",
	},
}

local serviceStartOrder = {
	{
		name = "PlayerData",
		start = function(services)
			services.PlayerData.start()
		end,
	},
	{
		name = "AxeService",
		start = function(services)
			services.AxeService.start(services.PlayerData)
		end,
	},
	{
		name = "SessionTimeService",
		start = function(services)
			services.SessionTimeService.start()
		end,
	},
	{
		name = "TreePlotService",
		start = function(services)
			services.TreePlotService.start()
		end,
	},
	{
		name = "AmberShopService",
		start = function(services)
			services.AmberShopService.start(services.PlayerData, services.AxeService)
		end,
	},
	{
		name = "BlacksmithService",
		start = function(services)
			services.BlacksmithService.start(services.PlayerData, services.AxeService)
		end,
	},
	{
		name = "TreeService",
		start = function(services)
			services.TreeService.start(
				services.PlayerData,
				services.TreePlotService,
				services.AxeService,
				services.SessionTimeService
			)
		end,
	},
	{
		name = "LumberjackService",
		start = function(services)
			services.LumberjackService.start(services.PlayerData, services.TreePlotService, services.TreeService)
		end,
	},
	{
		name = "RebirthService",
		start = function(services)
			services.RebirthService.start(services.PlayerData, services.TreeService, services.LumberjackService)
		end,
	},
	{
		name = "OrbOfRegretService",
		start = function(services)
			services.OrbOfRegretService.start(
				services.PlayerData,
				services.AxeService,
				services.TreeService,
				services.LumberjackService
			)
		end,
	},
}

local function loadServices(serverRoot)
	local services = {}

	for _, definition in ipairs(serviceDefinitions) do
		services[definition.name] = require(serverRoot:WaitForChild(definition.moduleName) :: ModuleScript)
	end

	return services
end

local function startServices(services)
	for _, definition in ipairs(serviceStartOrder) do
		definition.start(services)
	end
end

local function syncPlayerAxe(services, player)
	local state = services.PlayerData.getState(player)

	if not state or not state.IsLoaded then
		return
	end

	local success, result = services.AxeService.grantAxe(player, state.AxeTierId, false)

	if not success then
		warn(string.format("Failed to grant axe '%s' to %s: %s", state.AxeTierId, player.Name, tostring(result)))
	end
end

local function syncPlayerSwingSpeed(services, player)
	services.AxeService.applyToPlayer(player)
end

local function syncPlayerWalkSpeed(services, player, character)
	services.WalkSpeedController.applyToCharacter(services.PlayerData, player, character)
end

local function syncPlayerPlotSpawn(services, player, character)
	services.TreeService.teleportCharacterToAssignedPlotSpawn(player, character)
end

local function onPlayerAdded(services, player)
	player.CharacterAdded:Connect(function(character)
		task.defer(syncPlayerPlotSpawn, services, player, character)
		task.defer(syncPlayerWalkSpeed, services, player, character)
		task.defer(syncPlayerAxe, services, player)
		task.defer(syncPlayerSwingSpeed, services, player)
	end)

	services.PlayerData.loadPlayer(player)
	services.WalkSpeedController.applyToCurrentCharacter(services.PlayerData, player)
	syncPlayerAxe(services, player)
	syncPlayerSwingSpeed(services, player)
	services.SessionTimeService.onPlayerAdded(player)
	services.TreeService.onPlayerAdded(player)
	services.LumberjackService.onPlayerAdded(player)
end

local function onPlayerRemoving(services, player)
	services.SessionTimeService.onPlayerRemoving(player)
	services.LumberjackService.onPlayerRemoving(player)
	services.TreeService.onPlayerRemoving(player)
	services.PlayerData.removePlayer(player)
end

function ServerBootstrap.start(serverRoot)
	local services = loadServices(serverRoot)
	local studioAssetValidator = require(serverRoot:WaitForChild(studioAssetValidatorModuleName) :: ModuleScript)
	services.WalkSpeedController = require(serverRoot:WaitForChild(walkSpeedControllerModuleName) :: ModuleScript)

	studioAssetValidator.validateOrThrow()

	startServices(services)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, services, player)
	end

	Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(services, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		onPlayerRemoving(services, player)
	end)

	game:BindToClose(function()
		services.PlayerData.saveAll()
	end)

	return services
end

return ServerBootstrap
