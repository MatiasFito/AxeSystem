local Workspace = game:GetService("Workspace")

local wishingTreeConstants = require(script.Parent:WaitForChild("WishingTreeConstants"))

local WishingTreeZoneUtils = {}

function WishingTreeZoneUtils.getWishingTreeSectionModel()
	local model = Workspace:FindFirstChild(wishingTreeConstants.WISHING_TREE_SECTION_MODEL_NAME)

	if model and model:IsA("Model") then
		return model
	end

	return nil
end

function WishingTreeZoneUtils.getTouchAreaPart()
	local model = WishingTreeZoneUtils.getWishingTreeSectionModel()

	if not model then
		return nil
	end

	local part = model:FindFirstChild(wishingTreeConstants.WISHING_TREE_TOUCH_AREA_NAME, true)

	if part and part:IsA("BasePart") then
		return part
	end

	return nil
end

function WishingTreeZoneUtils.isCharacterInZone(character, part)
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

return WishingTreeZoneUtils
