local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local sessionTimeConfig = require(sharedFolder:WaitForChild("SessionTimeConfig") :: ModuleScript)

local SessionTimeService = {}

local started = false
local runtimeByPlayer = {}

local function getRuntimeState(player)
	return runtimeByPlayer[player]
end

local function getSessionSecondsFromState(runtimeState)
	if not runtimeState then
		return 0
	end

	return math.max(0, math.floor(os.clock() - runtimeState.ConnectedAt))
end

local function startPrintLoop(player, runtimeState)
	runtimeState.LoopToken += 1
	local loopToken = runtimeState.LoopToken

	task.spawn(function()
		while runtimeState.LoopToken == loopToken do
			if player.Parent == nil then
				break
			end

			task.wait(1)

			if runtimeState.LoopToken ~= loopToken or player.Parent == nil then
				break
			end
		end
	end)
end

function SessionTimeService.start()
	if started then
		return
	end

	started = true
end

function SessionTimeService.onPlayerAdded(player)
	local runtimeState = {
		ConnectedAt = os.clock(),
		LoopToken = 0,
	}

	runtimeByPlayer[player] = runtimeState
	startPrintLoop(player, runtimeState)
end

function SessionTimeService.onPlayerRemoving(player)
	local runtimeState = getRuntimeState(player)

	if not runtimeState then
		return
	end

	runtimeState.LoopToken += 1
	runtimeByPlayer[player] = nil
end

function SessionTimeService.getSessionSeconds(player)
	return getSessionSecondsFromState(getRuntimeState(player))
end

function SessionTimeService.getGoldMultiplier(player)
	return sessionTimeConfig.getGoldMultiplier(SessionTimeService.getSessionSeconds(player))
end

return SessionTimeService
