local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local treeSpatialUtils = require(script.Parent:WaitForChild("TreeSpatialUtils") :: ModuleScript)

local BlacksmithSectionMaterializer = {}

local function getTemplateModel()
	local template = ServerStorage:FindFirstChild(blacksmithConstants.BLACKSMITH_SECTION_TEMPLATE_NAME)

	if template and template:IsA("Model") then
		return template
	end

	error(
		string.format(
			"Validated Studio asset 'ServerStorage/%s' is missing or invalid at runtime",
			blacksmithConstants.BLACKSMITH_SECTION_TEMPLATE_NAME
		)
	)
end

local function getSectionAnchorPart(model)
	local anchorPart = model:FindFirstChild(blacksmithConstants.BLACKSMITH_PART_NAME, true)

	if anchorPart and anchorPart:IsA("BasePart") then
		return anchorPart
	end

	error(
		string.format(
			"Validated blacksmith section '%s' is missing '%s' at runtime",
			model.Name,
			blacksmithConstants.BLACKSMITH_PART_NAME
		)
	)
end

local function getFloorPart(model)
	local floorPart = model:FindFirstChild(blacksmithConstants.BLACKSMITH_FLOOR_NAME, true)

	if floorPart and floorPart:IsA("BasePart") then
		return floorPart
	end

	return getSectionAnchorPart(model)
end

local function clearExistingSection(plotSetFolder)
	local existingSection = plotSetFolder:FindFirstChild(blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME)

	if existingSection then
		existingSection:Destroy()
	end
end

local function getTargetAnchorCFrame(plotRecord, anchorPart)
	local forwardDirection = treeSpatialUtils.getHorizontalDirection(plotRecord.DirtPatch.CFrame.LookVector)
	local plotFrontExtent = treeSpatialUtils.getPartExtentAlongDirection(plotRecord.DirtPatch, forwardDirection)
	local sectionAnchorExtent = treeSpatialUtils.getPartExtentAlongDirection(anchorPart, forwardDirection)
	local anchorDistance = plotFrontExtent + blacksmithConstants.BLACKSMITH_FORWARD_OFFSET + sectionAnchorExtent
	local targetPosition = plotRecord.DirtPatch.Position + forwardDirection * anchorDistance

	return CFrame.lookAt(targetPosition, targetPosition + forwardDirection, Vector3.yAxis)
end

local function pivotModelToAnchor(model, anchorPart, targetAnchorCFrame)
	local anchorToWorld = targetAnchorCFrame * anchorPart.CFrame:Inverse()
	model:PivotTo(anchorToWorld * model:GetPivot())
end

local function alignModelToGround(model, supportPart, plotRecord)
	local targetBottomY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y * 0.5)
	local currentBottomY = supportPart.Position.Y - (supportPart.Size.Y * 0.5)
	local offsetY = targetBottomY - currentBottomY

	if math.abs(offsetY) > 0.001 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, offsetY, 0))
	end
end

function BlacksmithSectionMaterializer.create(deps)
	local function materializeForPlotSet(plotSetRecord)
		local plotSetFolder = plotSetRecord and plotSetRecord.Folder
		local plotRecord = plotSetRecord and plotSetRecord.PlotsById[blacksmithConstants.BLACKSMITH_TARGET_PLOT_ID]

		if not plotSetFolder or not plotRecord then
			return false
		end

		clearExistingSection(plotSetFolder)

		local clone = getTemplateModel():Clone()
		clone.Name = blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME
		clone:SetAttribute(treeConstants.PLOT_SET_ID_ATTRIBUTE, plotSetRecord.Id)

		local anchorPart = getSectionAnchorPart(clone)
		local targetAnchorCFrame = getTargetAnchorCFrame(plotRecord, anchorPart)
		pivotModelToAnchor(clone, anchorPart, targetAnchorCFrame)
		alignModelToGround(clone, getFloorPart(clone), plotRecord)

		clone.Parent = plotSetFolder
		return true
	end

	local function materializeAll()
		for _, plotSetRecord in deps.getPlotSets() do
			materializeForPlotSet(plotSetRecord)
		end
	end

	return {
		materializeAll = materializeAll,
		materializeForPlotSet = materializeForPlotSet,
	}
end

return BlacksmithSectionMaterializer
