local Workspace = game:GetService("Workspace")

local blacksmithConstants = require(script.Parent:WaitForChild("BlacksmithConstants"))

local BlacksmithZoneUtils = {}

function BlacksmithZoneUtils.getBlacksmithSectionModel()
	local model = Workspace:FindFirstChild(blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME)

	if model and model:IsA("Model") then
		return model
	end

	return nil
end

function BlacksmithZoneUtils.getBlacksmithPart()
	local model = BlacksmithZoneUtils.getBlacksmithSectionModel()

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
