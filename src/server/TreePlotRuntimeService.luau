local TreePlotRuntimeService = {}

local ASSIGNMENT_WAIT_ATTEMPTS = 10

local started = false
local playerData = nil
local treePlotService = nil
local runtimeDeps = nil

local function getRuntimeDeps()
	return runtimeDeps
end

function TreePlotRuntimeService.start(playerDataModule, treePlotServiceModule)
	if started then
		return
	end

	started = true
	playerData = playerDataModule
	treePlotService = treePlotServiceModule
end

function TreePlotRuntimeService.configureRuntime(deps)
	runtimeDeps = deps
end

function TreePlotRuntimeService.getAssignedPlotSetWithRetry(player)
	for attempt = 1, ASSIGNMENT_WAIT_ATTEMPTS do
		local plotSet = treePlotService and treePlotService.getAssignedPlotSet(player)

		if plotSet then
			return plotSet
		end

		if attempt < ASSIGNMENT_WAIT_ATTEMPTS then
			task.wait()
		end
	end

	return nil
end

function TreePlotRuntimeService.onPlayerAdded(player)
	local deps = getRuntimeDeps()

	if not playerData or not playerData.isLoaded(player) or not deps then
		return false
	end

	local plotSet, errorMessage = treePlotService.assignPlayer(player)

	if not plotSet then
		player:SetAttribute(deps.plotSetIdAttribute, nil)
		warn(string.format("Failed to assign tree plot set to %s: %s", player.Name, tostring(errorMessage)))
		return false
	end

	deps.cleanupPlayerRuntime(player)
	deps.setPlotSetId(player, plotSet.Id)
	player:SetAttribute(deps.plotSetIdAttribute, plotSet.Id)
	return deps.refreshAllAssignedPlots(player)
end

function TreePlotRuntimeService.onPlayerRemoving(player)
	local deps = getRuntimeDeps()

	if not deps then
		return
	end

	deps.cleanupPlayerRuntime(player)
	treePlotService.releasePlayer(player)
	player:SetAttribute(deps.plotSetIdAttribute, nil)
end

function TreePlotRuntimeService.onPlayerDataReset(player)
	local deps = getRuntimeDeps()

	if not playerData or not playerData.isLoaded(player) or not deps then
		return false
	end

	deps.cleanupPlayerRuntime(player)
	local plotSetId = treePlotService.getAssignedPlotSetId(player)
	deps.setPlotSetId(player, plotSetId)
	player:SetAttribute(deps.plotSetIdAttribute, plotSetId)
	return deps.refreshAllAssignedPlots(player)
end

function TreePlotRuntimeService.teleportCharacterToAssignedPlotSpawn(player, character)
	local deps = getRuntimeDeps()

	if not character or character.Parent == nil or not deps then
		return false
	end

	local plotSet = TreePlotRuntimeService.getAssignedPlotSetWithRetry(player)

	if not plotSet or not plotSet.Folder then
		warn(string.format("Failed to resolve assigned plot set for %s during character spawn", player.Name))
		return false
	end

	local plotSpawn = plotSet.Folder:FindFirstChild(deps.plotSetSpawnName)

	if not plotSpawn or not plotSpawn:IsA("BasePart") then
		warn(
			string.format(
				"Assigned plot set '%s' for %s is missing a BasePart named '%s'",
				tostring(plotSet.Id),
				player.Name,
				deps.plotSetSpawnName
			)
		)
		return false
	end

	local rootPart = character:WaitForChild("HumanoidRootPart", 5)

	if not rootPart or character.Parent == nil then
		warn(string.format("Failed to resolve HumanoidRootPart for %s during character spawn", player.Name))
		return false
	end

	character:PivotTo(plotSpawn.CFrame)
	return true
end

return TreePlotRuntimeService
