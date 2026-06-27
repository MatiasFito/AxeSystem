local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)
local utilsFolder = sharedFolder:WaitForChild("Utils")
local currencyFormatter = require(utilsFolder:WaitForChild("CurrencyFormatter") :: ModuleScript)

local TreePlotCard = {}

TreePlotCard.DEFAULT_COLORS = {
	Background = Color3.fromRGB(58, 76, 53),
	Stroke = Color3.fromRGB(210, 229, 201),
	Text = Color3.fromRGB(244, 247, 237),
	SubtleText = Color3.fromRGB(206, 219, 198),
	MeterBackground = Color3.fromRGB(31, 39, 29),
	LockedAccent = Color3.fromRGB(116, 116, 116),
	GrowingAccent = Color3.fromRGB(122, 201, 118),
	ReadyAccent = Color3.fromRGB(104, 202, 255),
}

TreePlotCard.DEFAULT_LAYOUT = {
	FrameAnchorPoint = Vector2.new(0, 0),
	FramePosition = UDim2.fromOffset(0, 0),
	FrameSize = UDim2.new(1, 0, 0, 72),
	CornerRadius = UDim.new(0, 16),
	StrokeThickness = 1.5,
	TitleSize = UDim2.new(0.58, 0, 0, 24),
	TitlePosition = UDim2.fromOffset(14, 10),
	DetailSize = UDim2.new(0.58, 0, 0, 20),
	DetailPosition = UDim2.fromOffset(14, 34),
	FooterSize = UDim2.new(0.38, -16, 0, 44),
	FooterPosition = UDim2.new(0.62, 2, 0, 14),
	MeterPosition = UDim2.fromOffset(14, 58),
	MeterSize = UDim2.new(1, -28, 0, 6),
}

local function formatSeconds(seconds)
	local clampedSeconds = math.max(0, seconds or 0)

	if clampedSeconds >= 10 then
		return string.format("%.0fs", clampedSeconds)
	end

	if clampedSeconds >= 1 then
		return string.format("%.1fs", clampedSeconds)
	end

	return string.format("%.2fs", clampedSeconds)
end

local function scaleUDim(value, scale)
	return UDim.new(value.Scale, math.floor(value.Offset * scale + 0.5))
end

local function scaleUDim2(value, scale)
	return UDim2.new(
		value.X.Scale,
		math.floor(value.X.Offset * scale + 0.5),
		value.Y.Scale,
		math.floor(value.Y.Offset * scale + 0.5)
	)
end

local function createLabel(parent, name, font, textColor, size, position, xAlignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = ""
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	label.Position = position
	label.Size = size
	label.Parent = parent
	return label
end

local function getAccent(plot, colors)
	if not plot.unlocked then
		return colors.LockedAccent, 0
	end

	if plot.state == treeConstants.PlotState.Growing then
		return colors.GrowingAccent, 0.2
	end

	return colors.ReadyAccent, 1
end

function TreePlotCard.scaleLayout(layout, scale)
	local sourceLayout = layout or TreePlotCard.DEFAULT_LAYOUT

	return {
		FrameAnchorPoint = sourceLayout.FrameAnchorPoint,
		FramePosition = scaleUDim2(sourceLayout.FramePosition, scale),
		FrameSize = scaleUDim2(sourceLayout.FrameSize, scale),
		CornerRadius = scaleUDim(sourceLayout.CornerRadius, scale),
		StrokeThickness = sourceLayout.StrokeThickness * scale,
		TitleSize = scaleUDim2(sourceLayout.TitleSize, scale),
		TitlePosition = scaleUDim2(sourceLayout.TitlePosition, scale),
		DetailSize = scaleUDim2(sourceLayout.DetailSize, scale),
		DetailPosition = scaleUDim2(sourceLayout.DetailPosition, scale),
		FooterSize = scaleUDim2(sourceLayout.FooterSize, scale),
		FooterPosition = scaleUDim2(sourceLayout.FooterPosition, scale),
		MeterPosition = scaleUDim2(sourceLayout.MeterPosition, scale),
		MeterSize = scaleUDim2(sourceLayout.MeterSize, scale),
	}
end

function TreePlotCard.create(parent, name, layout, colors)
	local resolvedLayout = layout or TreePlotCard.DEFAULT_LAYOUT
	local resolvedColors = colors or TreePlotCard.DEFAULT_COLORS

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = resolvedLayout.FrameAnchorPoint
	frame.Position = resolvedLayout.FramePosition
	frame.Size = resolvedLayout.FrameSize
	frame.BackgroundColor3 = resolvedColors.Background
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = resolvedLayout.CornerRadius
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = resolvedColors.Stroke
	stroke.Thickness = resolvedLayout.StrokeThickness
	stroke.Parent = frame

	local titleLabel = createLabel(
		frame,
		"Title",
		Enum.Font.GothamBlack,
		resolvedColors.Text,
		resolvedLayout.TitleSize,
		resolvedLayout.TitlePosition,
		Enum.TextXAlignment.Left
	)
	local detailLabel = createLabel(
		frame,
		"Detail",
		Enum.Font.GothamBold,
		resolvedColors.SubtleText,
		resolvedLayout.DetailSize,
		resolvedLayout.DetailPosition,
		Enum.TextXAlignment.Left
	)
	local footerLabel = createLabel(
		frame,
		"Footer",
		Enum.Font.Gotham,
		resolvedColors.SubtleText,
		resolvedLayout.FooterSize,
		resolvedLayout.FooterPosition,
		Enum.TextXAlignment.Right
	)

	local meterBackground = Instance.new("Frame")
	meterBackground.Name = "MeterBackground"
	meterBackground.BackgroundColor3 = resolvedColors.MeterBackground
	meterBackground.BorderSizePixel = 0
	meterBackground.Position = resolvedLayout.MeterPosition
	meterBackground.Size = resolvedLayout.MeterSize
	meterBackground.Parent = frame

	local meterCorner = Instance.new("UICorner")
	meterCorner.CornerRadius = UDim.new(1, 0)
	meterCorner.Parent = meterBackground

	local meterFill = Instance.new("Frame")
	meterFill.Name = "MeterFill"
	meterFill.BackgroundColor3 = resolvedColors.ReadyAccent
	meterFill.BorderSizePixel = 0
	meterFill.Size = UDim2.fromScale(0, 1)
	meterFill.Parent = meterBackground

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = meterFill

	return {
		Root = frame,
		Stroke = stroke,
		TitleLabel = titleLabel,
		DetailLabel = detailLabel,
		FooterLabel = footerLabel,
		MeterFill = meterFill,
	}
end

function TreePlotCard.render(card, plot, options)
	local resolvedOptions = options or {}
	local resolvedColors = resolvedOptions.colors or TreePlotCard.DEFAULT_COLORS
	local estimatedServerTime = resolvedOptions.estimatedServerTime or 0
	local accentColor, baseProgress = getAccent(plot, resolvedColors)
	local titleSuffix = plot.unlocked and string.format("Lv.%d", plot.level) or "Locked"
	local levelStats = plot.stats or {}
	local hasLumberjack = plot.hasLumberjack == true
	local lumberjackBonusPercent = plot.lumberjackGoldBonusPercent or 0
	local lumberjackLevel = plot.lumberjackLevel or 0
	local lumberjackHireCost = plot.lumberjackHireCost or 0

	card.Root.LayoutOrder = plot.plotOrder or card.Root.LayoutOrder
	card.TitleLabel.Text = string.format("%s  %s", plot.treeName, titleSuffix)
	card.MeterFill.BackgroundColor3 = accentColor

	if not plot.unlocked then
		card.DetailLabel.Text = plot.isUnlockable and "Ready to unlock" or "Unlock previous plot first"
		card.FooterLabel.Text = string.format("Cost %s Gold", currencyFormatter.formatGold(plot.unlockCost))
		card.MeterFill.Size = UDim2.fromScale(baseProgress, 1)
		return
	end

	if plot.isInfiniteTree then
		card.FooterLabel.Text = string.format("Gold/Hit %s", currencyFormatter.formatGold(plot.goldPerHit or 0))

		if plot.state == treeConstants.PlotState.Growing then
			local maxGrowTime = math.max(0.01, levelStats.growTime or 0.01)
			local remaining = math.max(0, (plot.growingUntil or 0) - estimatedServerTime)
			local progress = math.clamp(1 - (remaining / maxGrowTime), 0, 1)
			card.DetailLabel.Text = string.format("Preparing  %s", formatSeconds(remaining))
			card.MeterFill.Size = UDim2.fromScale(progress, 1)
			return
		end

		card.DetailLabel.Text = "Ready to farm"
		card.MeterFill.Size = UDim2.fromScale(baseProgress, 1)
		return
	end

	card.FooterLabel.Text = string.format(
		"HP %s  Reward %s%s",
		currencyFormatter.formatGold(levelStats.health),
		currencyFormatter.formatGold(levelStats.reward),
		hasLumberjack and string.format("  Auto +%d%%", lumberjackBonusPercent) or ""
	)

	if plot.state == treeConstants.PlotState.Growing then
		local maxGrowTime = math.max(0.01, levelStats.growTime or 0.01)
		local remaining = math.max(0, (plot.growingUntil or 0) - estimatedServerTime)
		local progress = math.clamp(1 - (remaining / maxGrowTime), 0, 1)
		if hasLumberjack then
			card.DetailLabel.Text =
				string.format("Growing  %s  Lumberjack Lv.%d", formatSeconds(remaining), lumberjackLevel)
		else
			card.DetailLabel.Text = string.format(
				"Growing  %s  Hire Lumberjack for %s Gold",
				formatSeconds(remaining),
				currencyFormatter.formatGold(lumberjackHireCost)
			)
		end
		card.MeterFill.Size = UDim2.fromScale(progress, 1)
		return
	end

	if hasLumberjack then
		card.DetailLabel.Text = string.format("Ready to chop  Lumberjack Lv.%d active", lumberjackLevel)
	else
		card.DetailLabel.Text = string.format(
			"Ready to chop  Hire Lumberjack for %s Gold",
			currencyFormatter.formatGold(lumberjackHireCost)
		)
	end
	card.MeterFill.Size = UDim2.fromScale(baseProgress, 1)
end

return TreePlotCard
