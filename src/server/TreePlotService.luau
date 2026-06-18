local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local TreePlotService = {}

local started = false
local plotSetsById = {}
local orderedPlotSetIds = {}
local playerAssignments = {}
local setAssignments = {}

local function getPlotSetsFolder()
	return Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)
end

local function getOrderedPlotIds()
	local plotIds = {}

	for order, treeId in treeConfig.Order do
		local tree = treeConfig.ById[treeId]
		plotIds[order] = tree.PlotId
	end

	return plotIds
end

local function resolvePlotChild(plotModel, childName)
	local child = plotModel:FindFirstChild(childName)

	if child then
		return child
	end

	return nil
end

local function buildPlotRecord(plotSetId, plotModel)
	if not plotModel:IsA("Model") then
		return nil, "Plot entry is not a Model"
	end

	local plotId = plotModel:GetAttribute(treeConstants.PLOT_ID_ATTRIBUTE)

	if typeof(plotId) ~= "string" or plotId == "" then
		plotId = plotModel.Name
	end

	local tree = treeConfig.getTreeByPlotId(plotId)

	if not tree then
		return nil, string.format("Unknown plot id '%s'", tostring(plotId))
	end

	local dirtPatch = resolvePlotChild(plotModel, treeConstants.DIRT_PATCH_NAME)
	local treeSpawn = resolvePlotChild(plotModel, treeConstants.TREE_SPAWN_NAME)
	local promptHost = resolvePlotChild(plotModel, treeConstants.PROMPT_HOST_NAME) or dirtPatch

	if not dirtPatch or not dirtPatch:IsA("BasePart") then
		return nil, string.format("Plot '%s' is missing a BasePart named '%s'", plotId, treeConstants.DIRT_PATCH_NAME)
	end

	if not treeSpawn or not (treeSpawn:IsA("BasePart") or treeSpawn:IsA("Attachment")) then
		return nil, string.format("Plot '%s' is missing '%s'", plotId, treeConstants.TREE_SPAWN_NAME)
	end

	if not promptHost or not (promptHost:IsA("BasePart") or promptHost:IsA("Attachment")) then
		return nil, string.format("Plot '%s' is missing a valid prompt host", plotId)
	end

	return {
		PlotSetId = plotSetId,
		PlotId = tree.PlotId,
		PlotOrder = tree.PlotOrder,
		Model = plotModel,
		DirtPatch = dirtPatch,
		TreeSpawn = treeSpawn,
		PromptHost = promptHost,
	},
		nil
end

local function registerPlotSet(plotSetFolder)
	if not plotSetFolder:IsA("Folder") then
		warn(string.format("Ignoring non-folder tree plot set '%s'", plotSetFolder.Name))
		return
	end

	local plotSetId = plotSetFolder:GetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE)

	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		plotSetId = plotSetFolder.Name
	end

	local plotSetRecord = {
		Id = plotSetId,
		Folder = plotSetFolder,
		PlotsById = {},
		OrderedPlotIds = {},
	}

	for _, child in plotSetFolder:GetChildren() do
		local plotRecord, errorMessage = buildPlotRecord(plotSetId, child)

		if plotRecord then
			plotSetRecord.PlotsById[plotRecord.PlotId] = plotRecord
			plotSetRecord.OrderedPlotIds[plotRecord.PlotOrder] = plotRecord.PlotId
		else
			warn(string.format("Tree plot set '%s' skipped child '%s': %s", plotSetId, child.Name, errorMessage))
		end
	end

	for order, expectedPlotId in getOrderedPlotIds() do
		if plotSetRecord.OrderedPlotIds[order] ~= expectedPlotId then
			warn(
				string.format(
					"Tree plot set '%s' is missing expected plot '%s' at order %d",
					plotSetId,
					expectedPlotId,
					order
				)
			)
			return
		end
	end

	plotSetsById[plotSetId] = plotSetRecord
	table.insert(orderedPlotSetIds, plotSetId)
end

local function scanPlotSets()
	table.clear(plotSetsById)
	table.clear(orderedPlotSetIds)

	local plotSetsFolder = getPlotSetsFolder()

	if not plotSetsFolder then
		warn(string.format("Workspace is missing '%s'", treeConstants.TREE_PLOT_SETS_FOLDER_NAME))
		return
	end

	for _, child in plotSetsFolder:GetChildren() do
		registerPlotSet(child)
	end

	table.sort(orderedPlotSetIds)
end

function TreePlotService.start()
	if started then
		return
	end

	started = true
	scanPlotSets()
end

function TreePlotService.assignPlayer(player)
	local existingPlotSetId = playerAssignments[player]

	if existingPlotSetId then
		return plotSetsById[existingPlotSetId]
	end

	for _, plotSetId in orderedPlotSetIds do
		if not setAssignments[plotSetId] then
			playerAssignments[player] = plotSetId
			setAssignments[plotSetId] = player
			return plotSetsById[plotSetId]
		end
	end

	return nil, "No free tree plot sets available"
end

function TreePlotService.releasePlayer(player)
	local plotSetId = playerAssignments[player]

	if not plotSetId then
		return
	end

	playerAssignments[player] = nil

	if setAssignments[plotSetId] == player then
		setAssignments[plotSetId] = nil
	end
end

function TreePlotService.getAssignedPlotSet(player)
	local plotSetId = playerAssignments[player]

	if not plotSetId then
		return nil
	end

	return plotSetsById[plotSetId]
end

function TreePlotService.getAssignedPlotSetId(player)
	return playerAssignments[player]
end

function TreePlotService.getAssignedPlot(player, plotId)
	local plotSet = TreePlotService.getAssignedPlotSet(player)

	if not plotSet or typeof(plotId) ~= "string" then
		return nil
	end

	return plotSet.PlotsById[plotId]
end

function TreePlotService.isOwnedPlot(player, plotId)
	return TreePlotService.getAssignedPlot(player, plotId) ~= nil
end

return TreePlotService
