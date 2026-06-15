local Workspace = game:GetService("Workspace")

local blacksmithConstants = require(script.Parent:WaitForChild("BlacksmithConstants"))

local BlacksmithZoneUtils = {}

function BlacksmithZoneUtils.getBlacksmithPart()
	local part = Workspace:FindFirstChild(blacksmithConstants.BLACKSMITH_PART_NAME)

	if part and part:IsA("BasePart") then
		return part
	end

	return nil
end

function BlacksmithZoneUtils.isCharacterInZone(character, part)
	if not character then
		return false
	end

	local targetPart = part or BlacksmithZoneUtils.getBlacksmithPart()

	if not targetPart then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { character }

	return #Workspace:GetPartsInPart(targetPart, overlapParams) > 0
end

return BlacksmithZoneUtils
