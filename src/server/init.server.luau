local Players = game:GetService("Players")

local axeService = require(script:WaitForChild("AxeService"))
local blacksmithService = require(script:WaitForChild("BlacksmithService"))
local orbOfRegretService = require(script:WaitForChild("OrbOfRegretService"))
local playerData = require(script:WaitForChild("PlayerData"))
local treePlotService = require(script:WaitForChild("TreePlotService"))
local treeService = require(script:WaitForChild("TreeService"))

local function syncPlayerAxe(player)
	local state = playerData.getState(player)

	if not state or not state.IsLoaded then
		return
	end

	local success, result = axeService.grantAxe(player, state.AxeTierId, false)

	if not success then
		warn(string.format("Failed to grant axe '%s' to %s: %s", state.AxeTierId, player.Name, tostring(result)))
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(syncPlayerAxe, player)
	end)

	playerData.loadPlayer(player)
	syncPlayerAxe(player)
	treeService.onPlayerAdded(player)
end

local function onPlayerRemoving(player)
	treeService.onPlayerRemoving(player)
	playerData.removePlayer(player)
end

playerData.start()
treePlotService.start()
blacksmithService.start(playerData, axeService)
treeService.start(playerData, treePlotService, axeService)
orbOfRegretService.start(playerData, axeService, treeService)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(function()
	playerData.saveAll()
end)
