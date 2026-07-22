local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local gamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig") :: ModuleScript)
local lumberjackConfig = require(sharedFolder:WaitForChild("LumberjackConfig") :: ModuleScript)
local rebirthConfig = require(sharedFolder:WaitForChild("RebirthConfig") :: ModuleScript)
local robloxSubscriptionConfig = require(sharedFolder:WaitForChild("RobloxSubscriptionConfig") :: ModuleScript)
local swingSpeed = require(sharedFolder:WaitForChild("SwingSpeed") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local axeDamageResolverModule = require(script.Parent:WaitForChild("AxeDamageResolver") :: ModuleScript)

local OfflineProgressionService = {}

local DEFAULT_CAP_SECONDS = 2 * 60 * 60
local VIP_CAP_SECONDS = 8 * 60 * 60
local GOLD_UPGRADE_KEY = "GoldMultiplier"
local REGROWTH_UPGRADE_KEY = "RegrowthTime"

local started = false
local playerData = nil
local gamePassService = nil
local axeService = nil
local axeDamageResolver = nil

local function sanitizePositiveNumber(value, fallback)
	if typeof(value) ~= "number" or value <= 0 then
		return fallback
	end

	return value
end

local function getGoldGamePassMultiplier(player)
	if not gamePassService or not gamePassService.getGoldMultiplier then
		return 1
	end

	return sanitizePositiveNumber(gamePassService.getGoldMultiplier(player), 1)
end

local function getRebirthGoldMultiplier(player)
	local rebirths = playerData and playerData.getRebirths and playerData.getRebirths(player) or 0
	return sanitizePositiveNumber(rebirthConfig.getRebirthGoldMultiplier(rebirths), 1)
end

local function getOfflineCapSeconds(player)
	if gamePassService and gamePassService.hasPass then
		if gamePassService.hasPass(player, gamePassConfig.Pass.VIP) then
			return VIP_CAP_SECONDS
		end
	end

	return DEFAULT_CAP_SECONDS
end

local function getEffectiveGrowTime(player, baseGrowTime)
	local normalizedBaseGrowTime = typeof(baseGrowTime) == "number" and math.max(0, baseGrowTime) or 0
	local regrowthLevel = playerData
			and playerData.getAmberUpgradeLevel
			and playerData.getAmberUpgradeLevel(player, REGROWTH_UPGRADE_KEY)
		or 0

	return math.max(0, normalizedBaseGrowTime * rebirthConfig.getRegrowthTimeMultiplier(regrowthLevel))
end

local function getEffectiveSwingDuration(player)
	if axeService and axeService.getPlayerSwingSpeed then
		local multiplier = sanitizePositiveNumber(axeService.getPlayerSwingSpeed(player), swingSpeed.DEFAULT_MULTIPLIER)
		return swingSpeed.getEffectiveSwingDuration(swingSpeed.DEFAULT_BASE_SWING_DURATION, multiplier)
	end

	return swingSpeed.getEffectiveSwingDuration(swingSpeed.DEFAULT_BASE_SWING_DURATION, swingSpeed.DEFAULT_MULTIPLIER)
end

local function resolvePerCycleReward(player, levelData, tier, lumberjackLevel)
	local goldUpgradeLevel = playerData.getAmberUpgradeLevel(player, GOLD_UPGRADE_KEY) or 0
	local baseReward = math.max(
		0,
		math.floor(
			levelData.Reward
				* sanitizePositiveNumber(tier.GoldMultiplier, 1)
				* lumberjackConfig.getGoldBonusMultiplier(lumberjackLevel)
		)
	)

	return math.max(
		0,
		math.floor(
			(
				baseReward
				* rebirthConfig.getGoldMultiplier(goldUpgradeLevel)
				* getRebirthGoldMultiplier(player)
				* robloxSubscriptionConfig.getGoldMultiplier(player)
				* getGoldGamePassMultiplier(player)
			) + 0.5
		)
	)
end

local function calculateWorkerGps(player, plotState, tier, swingDuration)
	if not plotState or plotState.Unlocked ~= true or plotState.HasLumberjack ~= true then
		return 0
	end

	local tree = treeConfig.getTreeByPlotId(plotState.PlotId)
	local levelData = tree and treeConfig.getLevelData(tree.Id, plotState.Level) or nil

	if not tree or not levelData then
		return 0
	end

	local power = axeDamageResolver and axeDamageResolver.resolveFinalDamageFromBasePower(player, tier.Power)
		or tier.Power
	power = sanitizePositiveNumber(power, 1)

	local hitsToFell = math.max(1, math.ceil(levelData.Health / power))
	local cycleTime = (hitsToFell * swingDuration) + getEffectiveGrowTime(player, levelData.GrowTime)

	if cycleTime <= 0 then
		return 0
	end

	local rewardPerCycle = resolvePerCycleReward(player, levelData, tier, plotState.LumberjackLevel or 0)
	return rewardPerCycle / cycleTime
end

local function calculateOfflineReward(player)
	local lastLogoutAt = playerData.getLastLogoutAt(player)
	local now = os.time()
	local offlineCapSeconds = getOfflineCapSeconds(player)
	local elapsedOfflineSeconds = typeof(lastLogoutAt) == "number" and math.max(0, now - lastLogoutAt) or 0
	local offlineSeconds = math.min(elapsedOfflineSeconds, offlineCapSeconds)
	local treePlots = playerData.getTreePlots(player) or {}
	local tier = axeConfig.getTier(playerData.getAxeTierId(player)) or axeConfig.getDefaultTier()
	local swingDuration = getEffectiveSwingDuration(player)
	local totalGps = 0

	for _, plotState in treePlots do
		totalGps += calculateWorkerGps(player, plotState, tier, swingDuration)
	end

	return {
		lastLogoutAt = lastLogoutAt,
		offlineCapSeconds = offlineCapSeconds,
		offlineSeconds = offlineSeconds,
		totalGps = totalGps,
		offlineGoldEarned = math.max(0, math.floor(totalGps * offlineSeconds)),
	}
end

function OfflineProgressionService.start(playerDataModule, gamePassServiceModule, axeServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	gamePassService = gamePassServiceModule
	axeService = axeServiceModule
	axeDamageResolver = axeDamageResolverModule.create({
		getAmberUpgradeLevel = function(player, upgradeKey)
			if not playerData or not playerData.getAmberUpgradeLevel then
				return 0
			end

			return playerData.getAmberUpgradeLevel(player, upgradeKey) or 0
		end,
		getGamePassDamageMultiplier = function(player)
			if not gamePassService or not gamePassService.getDamageMultiplier then
				return 1
			end

			return sanitizePositiveNumber(gamePassService.getDamageMultiplier(player), 1)
		end,
	})
end

function OfflineProgressionService.onPlayerAdded(player)
	if not playerData or not playerData.isLoaded or not playerData.isLoaded(player) then
		return
	end

	local result = calculateOfflineReward(player)
	local awardedGold = 0

	if result.offlineGoldEarned > 0 then
		local currentGold = playerData.getGold(player) or 0

		if playerData.setGold(player, currentGold + result.offlineGoldEarned) then
			awardedGold = result.offlineGoldEarned
		else
			warn(string.format("[OfflineProgressionService] Failed to award offline gold to %s", player.Name))
		end
	end

	if result.lastLogoutAt ~= nil then
		playerData.setLastLogoutAt(player, nil)
	end

	print(
		string.format(
			"[OfflineProgressionService] %s offlineSeconds=%d capSeconds=%d totalGPS=%.2f offlineGold=%d awardedGold=%d",
			player.Name,
			result.offlineSeconds,
			result.offlineCapSeconds,
			result.totalGps,
			result.offlineGoldEarned,
			awardedGold
		)
	)
end

function OfflineProgressionService.onPlayerRemoving(player)
	if not playerData or not playerData.isLoaded or not playerData.isLoaded(player) then
		return
	end

	playerData.setLastLogoutAt(player, os.time())
end

return OfflineProgressionService
