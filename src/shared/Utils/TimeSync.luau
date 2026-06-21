--!strict

local TimeSync = {}

function TimeSync.estimateServerTime(serverTimeAtSync: number?, localClockAtSync: number?): number
	local resolvedServerTimeAtSync = serverTimeAtSync or 0

	if resolvedServerTimeAtSync <= 0 then
		return 0
	end

	return resolvedServerTimeAtSync + (os.clock() - (localClockAtSync or 0))
end

return TimeSync
