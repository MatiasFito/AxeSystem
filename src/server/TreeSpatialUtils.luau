local TreeSpatialUtils = {}

function TreeSpatialUtils.setAllSurfacesStuds(part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
end

function TreeSpatialUtils.getHorizontalDirection(vector)
	local flattened = Vector3.new(vector.X, 0, vector.Z)

	if flattened.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flattened.Unit
end

function TreeSpatialUtils.getPartExtentAlongDirection(part, direction)
	local unitDirection = direction.Unit
	local rightVector = part.CFrame.RightVector
	local upVector = part.CFrame.UpVector
	local lookVector = part.CFrame.LookVector
	local halfSize = part.Size * 0.5

	return math.abs(unitDirection:Dot(rightVector)) * halfSize.X
		+ math.abs(unitDirection:Dot(upVector)) * halfSize.Y
		+ math.abs(unitDirection:Dot(lookVector)) * halfSize.Z
end

function TreeSpatialUtils.getSpawnCFrame(spawnInstance)
	if spawnInstance:IsA("Attachment") then
		return spawnInstance.WorldCFrame
	end

	return spawnInstance.CFrame
end

function TreeSpatialUtils.alignCloneBottomToPlot(clone, plotRecord)
	local targetBottomY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y / 2)

	if clone:IsA("Model") then
		local boundingBoxCFrame, boundingBoxSize = clone:GetBoundingBox()
		local currentBottomY = boundingBoxCFrame.Position.Y - (boundingBoxSize.Y / 2)
		local offsetY = targetBottomY - currentBottomY
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, offsetY, 0))
		return
	end

	if clone:IsA("BasePart") then
		local currentBottomY = clone.Position.Y - (clone.Size.Y / 2)
		local offsetY = targetBottomY - currentBottomY
		clone.CFrame += Vector3.new(0, offsetY, 0)
	end
end

return TreeSpatialUtils
