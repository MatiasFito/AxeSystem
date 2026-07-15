local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)

local OrbOfRegretService = {}

local started = false
local playerData = nil
local axeService = nil
local treePlotRuntimeService = nil
local lumberjackService = nil

local ORB_NAME = "OrbOfRegret"
local ORB_POSITION = Vector3.new(-30, 3.5, 0)
local ORB_SIZE = Vector3.new(4, 4, 4)
local ORB_COLOR = Color3.fromRGB(255, 94, 214)

local function ensureOrb()
	local existingOrb = Workspace:FindFirstChild(ORB_NAME)
	local orb = existingOrb

	if orb and not orb:IsA("BasePart") then
		orb:Destroy()
		orb = nil
	end

	if not orb then
		orb = Instance.new("Part")
		orb.Name = ORB_NAME
		orb.Parent = Workspace
	end

	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = ORB_COLOR
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = true
	orb.Size = ORB_SIZE
	orb.Position = ORB_POSITION

	local prompt = orb:FindFirstChildOfClass("ProximityPrompt")

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = orb
	end

	prompt.ActionText = "Reset My Data"
	prompt.ObjectText = ORB_NAME
	prompt.HoldDuration = 1.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false

	return orb, prompt
end

local function handleTriggered(player)
	if not playerData.isLoaded(player) then
		warn(string.format("OrbOfRegret reset skipped for %s because data is not loaded", player.Name))
		return
	end

	local success, result = playerData.resetPlayerData(player)

	if not success then
		warn(
			string.format(
				"OrbOfRegret failed to clear data for %s: %s",
				player.Name,
				game:GetService("HttpService"):JSONEncode(result)
			)
		)
		return
	end

	local axeSuccess, axeResult = axeService.grantAxe(player, blacksmithConstants.DEFAULT_AXE_TIER_ID, true)

	if not axeSuccess then
		warn(string.format("OrbOfRegret failed to regrant default axe to %s: %s", player.Name, tostring(axeResult)))
	end

	if treePlotRuntimeService and not treePlotRuntimeService.onPlayerDataReset(player) then
		warn(string.format("OrbOfRegret failed to refresh tree state for %s", player.Name))
	end

	if lumberjackService and not lumberjackService.onPlayerDataReset(player) then
		warn(string.format("OrbOfRegret failed to refresh lumberjack state for %s", player.Name))
	end
end

function OrbOfRegretService.start(
	playerDataModule,
	axeServiceModule,
	treePlotRuntimeServiceModule,
	lumberjackServiceModule
)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	axeService = axeServiceModule
	treePlotRuntimeService = treePlotRuntimeServiceModule
	lumberjackService = lumberjackServiceModule

	local _, prompt = ensureOrb()
	prompt.Triggered:Connect(handleTriggered)
end

return OrbOfRegretService
