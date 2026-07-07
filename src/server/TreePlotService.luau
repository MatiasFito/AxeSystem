local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local treePlotLayoutConfig = require(sharedFolder:WaitForChild("TreePlotLayoutConfig") :: ModuleScript)

local TreePlotService = {}

local started = false
local plotSetsById = {}
local orderedPlotSetIds = {}
local playerAssignments = {}
local setAssignments = {}

local function getPlotSetsFolder()
	return Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)
end

local function getPlotTemplateModel()
	return ServerStorage:FindFirstChild(treeConstants.TREE_PLOT_TEMPLATE_NAME)
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

local function resolvePlotSetId(plotSetFolder)
	local plotSetId = plotSetFolder:GetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE)

	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		plotSetId = plotSetFolder.Name
	end

	return plotSetId
end

local function resolvePlacementCFrame(instance)
	if instance:IsA("Attachment") then
		return instance.WorldCFrame
	end

	return instance.CFrame
end

local function resolvePlotSetOrigin(plotSetFolder)
	local origin = plotSetFolder:FindFirstChild(treeConstants.PLOT_SET_ORIGIN_NAME)

	if origin and (origin:IsA("BasePart") or origin:IsA("Attachment")) then
		return origin
	end

	return nil
end

local function getOrCreateGeneratedPlotsFolder(plotSetFolder)
	local generatedFolder = plotSetFolder:FindFirstChild(treeConstants.TREE_PLOT_GENERATED_FOLDER_NAME)

	if generatedFolder and generatedFolder:IsA("Folder") then
		return generatedFolder
	end

	if generatedFolder then
		generatedFolder:Destroy()
	end

	generatedFolder = Instance.new("Folder")
	generatedFolder.Name = treeConstants.TREE_PLOT_GENERATED_FOLDER_NAME
	generatedFolder.Parent = plotSetFolder
	return generatedFolder
end

local function clearFolderChildren(folder)
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
end

local function validatePlotTemplateModel(plotTemplateModel)
	if not plotTemplateModel or not plotTemplateModel:IsA("Model") then
		return nil, string.format("ServerStorage is missing a Model named '%s'", treeConstants.TREE_PLOT_TEMPLATE_NAME)
	end

	local dirtPatch = resolvePlotChild(plotTemplateModel, treeConstants.DIRT_PATCH_NAME)
	local treeSpawn = resolvePlotChild(plotTemplateModel, treeConstants.TREE_SPAWN_NAME)

	if not dirtPatch or not dirtPatch:IsA("BasePart") then
		return nil,
			string.format(
				"Plot template '%s' is missing a BasePart named '%s'",
				plotTemplateModel.Name,
				treeConstants.DIRT_PATCH_NAME
			)
	end

	if not treeSpawn or not (treeSpawn:IsA("BasePart") or treeSpawn:IsA("Attachment")) then
		return nil,
			string.format("Plot template '%s' is missing '%s'", plotTemplateModel.Name, treeConstants.TREE_SPAWN_NAME)
	end

	return {
		Model = plotTemplateModel,
		DirtPatch = dirtPatch,
		TreeSpawn = treeSpawn,
	}, nil
end

local function generatePlotClone(templateMetadata, plotId, targetDirtPatchCFrame)
	local clone = templateMetadata.Model:Clone()
	local cloneDirtPatch = resolvePlotChild(clone, treeConstants.DIRT_PATCH_NAME)
	local cloneTreeSpawn = resolvePlotChild(clone, treeConstants.TREE_SPAWN_NAME)

	if not cloneDirtPatch or not cloneDirtPatch:IsA("BasePart") then
		clone:Destroy()
		return nil, string.format("Generated plot '%s' is missing '%s'", plotId, treeConstants.DIRT_PATCH_NAME)
	end

	if not cloneTreeSpawn or not (cloneTreeSpawn:IsA("BasePart") or cloneTreeSpawn:IsA("Attachment")) then
		clone:Destroy()
		return nil, string.format("Generated plot '%s' is missing '%s'", plotId, treeConstants.TREE_SPAWN_NAME)
	end

	clone.Name = plotId
	clone:SetAttribute(treeConstants.PLOT_ID_ATTRIBUTE, plotId)
	cloneDirtPatch:SetAttribute(treeConstants.PLOT_ID_ATTRIBUTE, plotId)

	local templateToTarget = targetDirtPatchCFrame * cloneDirtPatch.CFrame:Inverse()
	clone:PivotTo(templateToTarget * clone:GetPivot())
	return clone, nil
end

local function generatePlotsForSet(plotSetFolder, orderedPlotIds, templateMetadata)
	if not plotSetFolder:IsA("Folder") then
		return false, "Plot set entry is not a Folder"
	end

	if #orderedPlotIds > treePlotLayoutConfig.getMaxPlotCount() then
		return false,
			string.format(
				"Configured %d plots but layout supports only %d",
				#orderedPlotIds,
				treePlotLayoutConfig.getMaxPlotCount()
			)
	end

	local origin = resolvePlotSetOrigin(plotSetFolder)

	if not origin then
		return false, string.format("Plot set is missing '%s'", treeConstants.PLOT_SET_ORIGIN_NAME)
	end

	local generatedFolder = getOrCreateGeneratedPlotsFolder(plotSetFolder)
	clearFolderChildren(generatedFolder)

	local originCFrame = resolvePlacementCFrame(origin)
	local plotSize = templateMetadata.DirtPatch.Size

	for order, plotId in orderedPlotIds do
		local slotOffset = treePlotLayoutConfig.getSlotOffset(order, plotSize)
		local targetDirtPatchCFrame = originCFrame * CFrame.new(slotOffset)
		local clone, errorMessage = generatePlotClone(templateMetadata, plotId, targetDirtPatchCFrame)

		if not clone then
			clearFolderChildren(generatedFolder)
			return false, errorMessage
		end

		clone.Parent = generatedFolder
	end

	return true, nil
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

	if not dirtPatch or not dirtPatch:IsA("BasePart") then
		return nil, string.format("Plot '%s' is missing a BasePart named '%s'", plotId, treeConstants.DIRT_PATCH_NAME)
	end

	if not treeSpawn or not (treeSpawn:IsA("BasePart") or treeSpawn:IsA("Attachment")) then
		return nil, string.format("Plot '%s' is missing '%s'", plotId, treeConstants.TREE_SPAWN_NAME)
	end

	return {
		PlotSetId = plotSetId,
		PlotId = tree.PlotId,
		PlotOrder = tree.PlotOrder,
		Model = plotModel,
		DirtPatch = dirtPatch,
		TreeSpawn = treeSpawn,
	},
		nil
end

local function registerPlotSet(plotSetFolder)
	if not plotSetFolder:IsA("Folder") then
		warn(string.format("Ignoring non-folder tree plot set '%s'", plotSetFolder.Name))
		return
	end

	local plotSetId = resolvePlotSetId(plotSetFolder)
	local generatedFolder = plotSetFolder:FindFirstChild(treeConstants.TREE_PLOT_GENERATED_FOLDER_NAME)

	if not generatedFolder or not generatedFolder:IsA("Folder") then
		warn(string.format("Tree plot set '%s' is missing generated plots", plotSetId))
		return
	end

	local plotSetRecord = {
		Id = plotSetId,
		Folder = plotSetFolder,
		PlotsById = {},
		OrderedPlotIds = {},
	}

	for _, child in generatedFolder:GetChildren() do
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
	local plotTemplateModel = getPlotTemplateModel()

	if not plotSetsFolder then
		warn(string.format("Workspace is missing '%s'", treeConstants.TREE_PLOT_SETS_FOLDER_NAME))
		return
	end

	local templateMetadata, templateError = validatePlotTemplateModel(plotTemplateModel)

	if not templateMetadata then
		warn(templateError)
		return
	end

	local orderedPlotIds = getOrderedPlotIds()

	for _, child in plotSetsFolder:GetChildren() do
		local generated, generationError = generatePlotsForSet(child, orderedPlotIds, templateMetadata)

		if not generated then
			warn(string.format("Tree plot set '%s' failed generation: %s", child.Name, generationError))
			continue
		end

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

function TreePlotService.getPlotSet(plotSetId)
	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		return nil
	end

	return plotSetsById[plotSetId]
end

function TreePlotService.getPlotSets()
	local plotSets = {}

	for _, plotSetId in orderedPlotSetIds do
		local plotSet = plotSetsById[plotSetId]

		if plotSet then
			table.insert(plotSets, plotSet)
		end
	end

	return plotSets
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
