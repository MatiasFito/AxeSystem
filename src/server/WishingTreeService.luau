local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local wishingTreeBlessingConfig = require(sharedFolder:WaitForChild("WishingTreeBlessingConfig") :: ModuleScript)
local wishingTreeConstants = require(sharedFolder:WaitForChild("WishingTreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local serviceResult = require(utilsFolder:WaitForChild("ServiceResult") :: ModuleScript)
local wishingTreeRemoteHandlers = require(script.Parent:WaitForChild("WishingTreeRemoteHandlers") :: ModuleScript)
local wishingTreeRemoteRegistry = require(script.Parent:WaitForChild("WishingTreeRemoteRegistry") :: ModuleScript)

local WishingTreeService = {}

local playerData = nil
local started = false
local activeBlessingsByPlayer = {}

local function getRemainingDurationValue(entry, now)
	local resolvedNow = typeof(now) == "number" and now or os.clock()
	return math.max(0, entry.ExpiresAt - resolvedNow)
end

local function getRemainingDurationSeconds(entry, now)
	return math.max(0, math.ceil(getRemainingDurationValue(entry, now)))
end

local function buildPersistedSnapshot(player)
	local runtimeState = activeBlessingsByPlayer[player]

	if not runtimeState then
		return {}
	end

	local snapshot = {}
	local now = os.clock()

	for blessingId, entry in runtimeState do
		local remainingDurationSeconds = math.floor(getRemainingDurationValue(entry, now))

		if remainingDurationSeconds > 0 then
			table.insert(snapshot, {
				BlessingId = blessingId,
				RemainingDurationSeconds = remainingDurationSeconds,
			})
		end
	end

	table.sort(snapshot, function(left, right)
		return left.BlessingId < right.BlessingId
	end)

	return snapshot
end

local function buildPublicBlessingState(player)
	local runtimeState = activeBlessingsByPlayer[player]
	local blessingStates = {}
	local now = os.clock()

	if not runtimeState then
		return blessingStates
	end

	for blessingId, entry in runtimeState do
		local blessingDefinition = wishingTreeBlessingConfig.getBlessingById(blessingId)
		local remainingDurationSeconds = getRemainingDurationSeconds(entry, now)

		if blessingDefinition and remainingDurationSeconds > 0 then
			table.insert(blessingStates, {
				BlessingId = blessingId,
				Name = blessingDefinition.Name,
				BaseDurationSeconds = blessingDefinition.DurationSeconds,
				RemainingDurationSeconds = remainingDurationSeconds,
				EffectType = blessingDefinition.EffectType,
				EffectValue = blessingDefinition.EffectValue,
			})
		end
	end

	table.sort(blessingStates, function(left, right)
		return left.BlessingId < right.BlessingId
	end)

	return blessingStates
end

local function persistPlayerBlessings(player)
	if not playerData then
		return false
	end

	return playerData.setActiveBlessings(player, buildPersistedSnapshot(player))
end

local function cancelEntryTimer(entry)
	if entry and entry.TimerThread then
		pcall(task.cancel, entry.TimerThread)
		entry.TimerThread = nil
	end
end

local function clearPlayerRuntimeState(player)
	local runtimeState = activeBlessingsByPlayer[player]

	if not runtimeState then
		return
	end

	for _, entry in runtimeState do
		cancelEntryTimer(entry)
	end

	activeBlessingsByPlayer[player] = nil
end

local function expireBlessing(player, blessingId, serial)
	local runtimeState = activeBlessingsByPlayer[player]

	if not runtimeState then
		return
	end

	local entry = runtimeState[blessingId]

	if not entry or entry.Serial ~= serial or getRemainingDurationSeconds(entry) > 0 then
		return
	end

	cancelEntryTimer(entry)
	runtimeState[blessingId] = nil

	if next(runtimeState) == nil then
		activeBlessingsByPlayer[player] = nil
	end

	persistPlayerBlessings(player)
end

local function scheduleEntryExpiry(player, blessingId, entry)
	cancelEntryTimer(entry)
	entry.Serial += 1
	local serial = entry.Serial
	local remainingDurationSeconds = getRemainingDurationValue(entry)

	entry.TimerThread = task.delay(remainingDurationSeconds, function()
		expireBlessing(player, blessingId, serial)
	end)
end

local function upsertBlessing(player, blessingDefinition, addedDurationSeconds, shouldPersist)
	local runtimeState = activeBlessingsByPlayer[player]

	if not runtimeState then
		runtimeState = {}
		activeBlessingsByPlayer[player] = runtimeState
	end

	local blessingId = blessingDefinition.Id
	local now = os.clock()
	local maxDurationSeconds = blessingDefinition.DurationSeconds * 10
	local existingEntry = runtimeState[blessingId]
	local currentRemainingSeconds = existingEntry and getRemainingDurationValue(existingEntry, now) or 0
	local nextDurationSeconds = math.min(maxDurationSeconds, currentRemainingSeconds + addedDurationSeconds)
	local entry = existingEntry or {
		BlessingId = blessingId,
		Serial = 0,
	}

	entry.BaseDurationSeconds = blessingDefinition.DurationSeconds
	entry.DurationSeconds = nextDurationSeconds
	entry.ExpiresAt = now + nextDurationSeconds
	runtimeState[blessingId] = entry

	scheduleEntryExpiry(player, blessingId, entry)

	if shouldPersist ~= false then
		persistPlayerBlessings(player)
	end

	return buildPublicBlessingState(player), getRemainingDurationSeconds(entry, now)
end

function WishingTreeService.getActiveBlessings(player)
	return buildPublicBlessingState(player)
end

function WishingTreeService.onPlayerAdded(player)
	if not playerData or not playerData.isLoaded(player) then
		clearPlayerRuntimeState(player)
		return
	end

	clearPlayerRuntimeState(player)

	for _, blessingState in ipairs(playerData.getActiveBlessings(player) or {}) do
		local blessingDefinition = wishingTreeBlessingConfig.getBlessingById(blessingState.BlessingId)

		if blessingDefinition then
			upsertBlessing(player, blessingDefinition, blessingState.RemainingDurationSeconds, false)
		end
	end
end

function WishingTreeService.onPlayerRemoving(player)
	persistPlayerBlessings(player)
	clearPlayerRuntimeState(player)
end

function WishingTreeService.onPlayerDataReset(player)
	clearPlayerRuntimeState(player)
	return true
end

function WishingTreeService.rollBlessing(player)
	if not started or not playerData then
		return serviceResult.failure(
			wishingTreeConstants.FailureReason.ConfigError,
			wishingTreeConstants.getFailureMessage
		)
	end

	if not playerData.isLoaded(player) then
		return serviceResult.failure(
			wishingTreeConstants.FailureReason.DataNotLoaded,
			wishingTreeConstants.getFailureMessage
		)
	end

	local blessingDefinition = wishingTreeBlessingConfig.rollBlessing()

	if not blessingDefinition then
		return serviceResult.failure(
			wishingTreeConstants.FailureReason.ConfigError,
			wishingTreeConstants.getFailureMessage
		)
	end

	local activeBlessings, remainingDurationSeconds =
		upsertBlessing(player, blessingDefinition, blessingDefinition.DurationSeconds)

	return serviceResult.success(activeBlessings, {
		blessing = {
			BlessingId = blessingDefinition.Id,
			Name = blessingDefinition.Name,
			BaseDurationSeconds = blessingDefinition.DurationSeconds,
			RemainingDurationSeconds = remainingDurationSeconds,
			EffectType = blessingDefinition.EffectType,
			EffectValue = blessingDefinition.EffectValue,
		},
	})
end

function WishingTreeService.start(playerDataModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule

	local remotes = wishingTreeRemoteRegistry.getOrCreateRemotes()
	local handlers = wishingTreeRemoteHandlers.create({
		rollBlessing = WishingTreeService.rollBlessing,
	})

	wishingTreeRemoteHandlers.bind(remotes, handlers)
end

return WishingTreeService
