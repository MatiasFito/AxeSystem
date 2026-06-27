local TreePlotLayoutConfig = {
	Rows = 6,
	Columns = 5,
	ColumnSpacing = 2,
	RowSpacing = 2,
}

function TreePlotLayoutConfig.getMaxPlotCount()
	return TreePlotLayoutConfig.Rows * TreePlotLayoutConfig.Columns
end

function TreePlotLayoutConfig.getSlotOffset(index, plotSize)
	local zeroBasedIndex = math.max(0, math.floor(index) - 1)
	local column = zeroBasedIndex % TreePlotLayoutConfig.Columns
	local row = math.floor(zeroBasedIndex / TreePlotLayoutConfig.Columns)
	local width = plotSize.X + TreePlotLayoutConfig.ColumnSpacing
	local depth = plotSize.Z + TreePlotLayoutConfig.RowSpacing

	return Vector3.new(column * width, 0, row * depth)
end

return TreePlotLayoutConfig
