local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local utilsFolder = sharedFolder:WaitForChild("Utils")
local leaderstatsWatcher = require(utilsFolder:WaitForChild("LeaderstatsWatcher") :: ModuleScript)
local TopGoldLabelView = require(script.Parent:WaitForChild("TopGoldLabelView") :: ModuleScript)

local REMOTE_WAIT_TIMEOUT = 10

local TopGoldLabel = {}

local started = false

function TopGoldLabel.start()
	if started then
		return
	end

	started = true
	TopGoldLabelView.mount(player)
	leaderstatsWatcher.watchIntValue(player, "Gold", REMOTE_WAIT_TIMEOUT, function(value)
		TopGoldLabelView.setGold(value)
	end)
end

return TopGoldLabel
