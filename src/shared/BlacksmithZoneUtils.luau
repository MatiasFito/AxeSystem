local Workspace = game:GetService("Workspace")

local blacksmithConstants = require(script.Parent:WaitForChild("BlacksmithConstants"))
local treeConstants = require(script.Parent:WaitForChild("TreeConstants"))

local BlacksmithZoneUtils = {}

local function getPlotSetsFolder()
	return Workspace:FindFirstChild(treeConstants.TREE_PLOT_SETS_FOLDER_NAME)
end

function BlacksmithZoneUtils.getPlotSetFolder(plotSetId)
	if typeof(plotSetId) ~= "string" or plotSetId == "" then
		return nil
	end

	local plotSetsFolder = getPlotSetsFolder()

	if not plotSetsFolder then
		return nil
	end

	local directFolder = plotSetsFolder:FindFirstChild(plotSetId)

	if directFolder and directFolder:IsA("Folder") then
		return directFolder
	end

	for _, child in plotSetsFolder:GetChildren() do
		if child:IsA("Folder") and child:GetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE) == plotSetId then
			return child
		end
	end

	return nil
end

function BlacksmithZoneUtils.getBlacksmithSectionModel(plotSetId)
	local plotSetFolder = BlacksmithZoneUtils.getPlotSetFolder(plotSetId)

	if not plotSetFolder then
		return nil
	end

	local model = plotSetFolder:FindFirstChild(blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME)

	if model and model:IsA("Model") then
		return model
	end

	return nil
end

function BlacksmithZoneUtils.getBlacksmithPartForPlotSet(plotSetId)
	local model = BlacksmithZoneUtils.getBlacksmithSectionModel(plotSetId)

	if not model then
		return nil
	end

	local part = model:FindFirstChild(blacksmithConstants.BLACKSMITH_PART_NAME, true)

	if part and part:IsA("BasePart") then
		return part
	end

	return nil
end

function BlacksmithZoneUtils.isCharacterInZone(character, part)
	if not character then
		return false
	end

	if not part then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { character }

	return #Workspace:GetPartsInPart(part, overlapParams) > 0
end

return BlacksmithZoneUtils
