local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local OwnedPromptVisibilityController = {}

local PROMPT_MODEL_SUFFIXES = {
	"UnlockButton",
	"LumberjackHireButton",
}

local started = false
local plotSetId = nil
local billboardMaxDistanceByGui = setmetatable({}, { __mode = "k" })

local function getPlotSetsFolder()
	local plotSetsFolder = Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)

	if plotSetsFolder and plotSetsFolder:IsA("Folder") then
		return plotSetsFolder
	end

	return nil
end

local function hasSuffix(value, suffix)
	return string.len(value) >= string.len(suffix) and string.sub(value, -string.len(suffix)) == suffix
end

local function isPromptModel(instance)
	if not instance or not instance:IsA("Model") then
		return false
	end

	for _, suffix in PROMPT_MODEL_SUFFIXES do
		if hasSuffix(instance.Name, suffix) then
			return true
		end
	end

	return false
end

local function getPromptModel(instance)
	local current = instance

	while current do
		if isPromptModel(current) then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function syncPlotSetId()
	local assignedPlotSetId = player:GetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE)

	if typeof(assignedPlotSetId) == "string" and assignedPlotSetId ~= "" then
		plotSetId = assignedPlotSetId
		return
	end

	plotSetId = nil
end

local function getPlotSetFolder(instance)
	local plotSetsFolder = getPlotSetsFolder()
	local current = instance

	if not plotSetsFolder then
		return nil
	end

	while current and current ~= plotSetsFolder do
		if current.Parent == plotSetsFolder and current:IsA("Folder") then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function isOwnedPlotSetFolder(plotSetFolder)
	if not plotSetFolder or typeof(plotSetId) ~= "string" or plotSetId == "" then
		return false
	end

	local folderPlotSetId = plotSetFolder:GetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE)

	if typeof(folderPlotSetId) == "string" and folderPlotSetId ~= "" then
		return folderPlotSetId == plotSetId
	end

	return plotSetFolder.Name == plotSetId
end

local function applyPromptVisibility(promptModel)
	if not promptModel then
		return
	end

	local isVisible = isOwnedPlotSetFolder(getPlotSetFolder(promptModel))

	for _, descendant in promptModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = isVisible and 0 or 1
		elseif descendant:IsA("BillboardGui") then
			local originalMaxDistance = billboardMaxDistanceByGui[descendant]

			if originalMaxDistance == nil then
				originalMaxDistance = descendant.MaxDistance
				billboardMaxDistanceByGui[descendant] = originalMaxDistance
			end

			descendant.MaxDistance = isVisible and originalMaxDistance or 0
		end
	end
end

local function refreshAllPromptVisibility()
	local plotSetsFolder = getPlotSetsFolder()

	if not plotSetsFolder then
		return
	end

	for _, descendant in plotSetsFolder:GetDescendants() do
		if isPromptModel(descendant) then
			applyPromptVisibility(descendant)
		end
	end
end

function OwnedPromptVisibilityController.start()
	if started then
		return
	end

	started = true
	syncPlotSetId()
	refreshAllPromptVisibility()

	player:GetAttributeChangedSignal(treeConstants.PLOT_SET_ID_ATTRIBUTE):Connect(function()
		syncPlotSetId()
		refreshAllPromptVisibility()
	end)

	Workspace.ChildAdded:Connect(function(child)
		if child.Name ~= treeConstants.TREE_PLOT_SETS_FOLDER_NAME then
			return
		end

		refreshAllPromptVisibility()

		child.DescendantAdded:Connect(function(descendant)
			local promptModel = getPromptModel(descendant)

			if promptModel then
				applyPromptVisibility(promptModel)
			end
		end)
	end)

	local plotSetsFolder = getPlotSetsFolder()

	if plotSetsFolder then
		plotSetsFolder.DescendantAdded:Connect(function(descendant)
			local promptModel = getPromptModel(descendant)

			if promptModel then
				applyPromptVisibility(promptModel)
			end
		end)
	end
end

return OwnedPromptVisibilityController
