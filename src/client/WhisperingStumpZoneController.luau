local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local whisperingStumpUI = require(script.Parent:WaitForChild("WhisperingStumpUI"))

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local wishingTreeZoneUtils = require(sharedFolder:WaitForChild("WishingTreeZoneUtils") :: ModuleScript)

local POLL_INTERVAL = 0.15
local MISS_THRESHOLD = 3

local WhisperingStumpZoneController = {}

local started = false
local timeSincePoll = 0
local insideZone = false
local missCount = 0

local function closeModal()
	insideZone = false
	missCount = 0
	whisperingStumpUI.close()
end

local function _dismissModalWhileInside()
	whisperingStumpUI.close()
end

local function updateZoneState()
	local part = wishingTreeZoneUtils.getTouchAreaPart()
	local isInZone = part ~= nil and wishingTreeZoneUtils.isCharacterInZone(player.Character, part)

	if isInZone then
		missCount = 0

		if not insideZone then
			insideZone = true
			whisperingStumpUI.open()
		end

		return
	end

	if not insideZone then
		return
	end

	missCount += 1

	if missCount >= MISS_THRESHOLD then
		closeModal()
	end
end

function WhisperingStumpZoneController.start()
	if started then
		return
	end

	started = true

	player.CharacterAdded:Connect(function()
		closeModal()
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		timeSincePoll += deltaTime

		if timeSincePoll < POLL_INTERVAL then
			return
		end

		timeSincePoll = 0
		updateZoneState()
	end)
end

return WhisperingStumpZoneController
