local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)

local GamePassService = {}

local started = false
local ownershipByPlayer = {}

local function createDefaultOwnership()
	return gamePassConfig.normalizeOwnedPasses(nil)
end

local function cloneOwnership(ownership)
	return gamePassConfig.normalizeOwnedPasses(ownership)
end

local function sanitizeMultiplier(multiplier)
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		return 1
	end

	return multiplier
end

local function resolveLiveOwnership(player)
	local resolvedOwnership = createDefaultOwnership()

	for _, passKey in ipairs(gamePassConfig.getPassKeys()) do
		local passId = gamePassConfig.getPassId(passKey)

		if typeof(passId) == "number" and passId > 0 then
			local success, ownsPass =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)

			if success then
				resolvedOwnership[passKey] = ownsPass == true
			else
				warn(
					string.format(
						"[GamePassService] Failed to check %s for %s: %s",
						passKey,
						player.Name,
						tostring(ownsPass)
					)
				)
			end
		end
	end

	return resolvedOwnership
end

local function resolveOwnership(player)
	if RunService:IsStudio() then
		return gamePassConfig.getStudioOwnedPasses()
	end

	return resolveLiveOwnership(player)
end

local function getBenefitMultiplier(player, benefitKey)
	local ownership = ownershipByPlayer[player]

	if not ownership then
		return 1
	end

	return sanitizeMultiplier(gamePassConfig.getBenefitMultiplier(ownership, benefitKey))
end

function GamePassService.start()
	if started then
		return
	end

	started = true
end

function GamePassService.onPlayerAdded(player)
	local ownership = resolveOwnership(player)
	ownershipByPlayer[player] = ownership
	return cloneOwnership(ownership)
end

function GamePassService.onPlayerRemoving(player)
	ownershipByPlayer[player] = nil
end

function GamePassService.getOwnership(player)
	return cloneOwnership(ownershipByPlayer[player])
end

function GamePassService.hasPass(player, passKey)
	local ownership = ownershipByPlayer[player]
	return ownership ~= nil and ownership[passKey] == true
end

function GamePassService.getGoldMultiplier(player)
	return getBenefitMultiplier(player, gamePassConfig.Benefit.Gold)
end

function GamePassService.getDamageMultiplier(player)
	return getBenefitMultiplier(player, gamePassConfig.Benefit.Damage)
end

function GamePassService.getMovementSpeedMultiplier(player)
	return getBenefitMultiplier(player, gamePassConfig.Benefit.MovementSpeed)
end

function GamePassService.getSwingSpeedMultiplier(player)
	return getBenefitMultiplier(player, gamePassConfig.Benefit.SwingSpeed)
end

return GamePassService
