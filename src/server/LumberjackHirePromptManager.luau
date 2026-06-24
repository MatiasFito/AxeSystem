local TweenService = game:GetService("TweenService")

local TREE_OFFSET_DISTANCE = 8

local LumberjackHirePromptManager = {}

function LumberjackHirePromptManager.create(deps)
	local constants = deps.constants

	local function destroyHireButton(runtimePlotState)
		runtimePlotState.HireTweenToken += 1
		runtimePlotState.IsHireAnimating = false

		if runtimePlotState.HireTouchConnection then
			runtimePlotState.HireTouchConnection:Disconnect()
			runtimePlotState.HireTouchConnection = nil
		end

		if runtimePlotState.HireButtonModel and runtimePlotState.HireButtonModel.Parent then
			runtimePlotState.HireButtonModel:Destroy()
		end

		runtimePlotState.HireButtonModel = nil
		if runtimePlotState.LastHireTouchAt == nil then
			runtimePlotState.LastHireTouchAt = 0
		end
	end

	local function createHireButtonModel(plotRecord)
		local model = Instance.new("Model")
		model.Name = string.format("%sLumberjackHireButton", plotRecord.PlotId)

		local base = Instance.new("Part")
		base.Name = "Base"
		base.Shape = Enum.PartType.Cylinder
		base.Material = Enum.Material.Plastic
		base.Anchored = true
		base.CanCollide = false
		base.CanQuery = true
		base.CanTouch = true
		base.Size = Vector3.new(0.9, 3.8, 3.8) * constants.Scale
		deps.setAllSurfacesStuds(base)
		base.Parent = model

		local button = Instance.new("Part")
		button.Name = "Button"
		button.Shape = Enum.PartType.Cylinder
		button.Material = Enum.Material.Plastic
		button.Anchored = true
		button.CanCollide = false
		button.CanQuery = true
		button.CanTouch = true
		button.Size = Vector3.new(0.75, 2.9, 2.9) * constants.Scale
		deps.setAllSurfacesStuds(button)
		button.Parent = model

		local spawnCFrame = deps.getSpawnCFrame(plotRecord.TreeSpawn)
		local leftDirection = deps.getHorizontalDirection(-plotRecord.DirtPatch.CFrame.RightVector)
		local targetPosition = spawnCFrame.Position + leftDirection * TREE_OFFSET_DISTANCE
		local pivotCFrame = CFrame.lookAt(targetPosition, targetPosition + leftDirection, Vector3.yAxis)
			* CFrame.Angles(0, 0, math.rad(90))
		base.CFrame = pivotCFrame
		button.CFrame = pivotCFrame * CFrame.new(0.2, 0, 0)

		local baseVerticalHalfExtent = base.Size.X * 0.5
		local dirtPatchTopY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y * 0.5)
		local yOffset = (dirtPatchTopY - baseVerticalHalfExtent) - base.Position.Y
		base.CFrame += Vector3.new(0, yOffset, 0)
		button.CFrame += Vector3.new(0, yOffset, 0)

		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "CostBillboard"
		billboardGui.Adornee = button
		billboardGui.AlwaysOnTop = true
		billboardGui.LightInfluence = 0
		billboardGui.Size = UDim2.fromOffset(160, 70)
		billboardGui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
		billboardGui.Parent = model

		local costLabel = Instance.new("TextLabel")
		costLabel.Name = "CostLabel"
		costLabel.BackgroundTransparency = 1
		costLabel.Size = UDim2.fromScale(1, 1)
		costLabel.Font = Enum.Font.GothamBlack
		costLabel.TextScaled = true
		costLabel.TextStrokeTransparency = 0.35
		costLabel.Text = ""
		costLabel.Parent = billboardGui

		return model, button, base
	end

	local function updateHireButtonVisuals(buttonModel, hireCost, canAfford)
		if not buttonModel then
			return
		end

		local buttonPart = buttonModel:FindFirstChild("Button")
		local basePart = buttonModel:FindFirstChild("Base")
		local billboardGui = buttonModel:FindFirstChild("CostBillboard")
		local costLabel = billboardGui and billboardGui:FindFirstChild("CostLabel")

		if not buttonPart or not basePart or not costLabel or not costLabel:IsA("TextLabel") then
			return
		end

		buttonPart.Color = canAfford and constants.ColorReady or constants.ColorLocked
		basePart.Color = canAfford and constants.BaseColorReady or constants.BaseColorLocked
		costLabel.Text = string.format("HIRE\n$ %d", hireCost)
		costLabel.TextColor3 = canAfford and constants.TextReady or constants.TextLocked
		costLabel.TextYAlignment = Enum.TextYAlignment.Center
		costLabel.TextXAlignment = Enum.TextXAlignment.Center
		costLabel.TextWrapped = true
		costLabel.TextSize = 18
		costLabel.RichText = false
	end

	local function playHireSuccessTween(runtimePlotState)
		local buttonModel = runtimePlotState.HireButtonModel

		if not buttonModel or not buttonModel.Parent then
			destroyHireButton(runtimePlotState)
			return
		end

		local buttonPart = buttonModel:FindFirstChild("Button")
		local basePart = buttonModel:FindFirstChild("Base")
		local billboardGui = buttonModel:FindFirstChild("CostBillboard")
		local costLabel = billboardGui and billboardGui:FindFirstChild("CostLabel")

		if not buttonPart or not basePart or not billboardGui or not costLabel or not costLabel:IsA("TextLabel") then
			destroyHireButton(runtimePlotState)
			return
		end

		runtimePlotState.HireTweenToken += 1
		runtimePlotState.IsHireAnimating = true

		if runtimePlotState.HireTouchConnection then
			runtimePlotState.HireTouchConnection:Disconnect()
			runtimePlotState.HireTouchConnection = nil
		end

		buttonPart.CanTouch = false
		buttonPart.CanQuery = false
		basePart.CanTouch = false
		basePart.CanQuery = false

		local sound = Instance.new("Sound")
		sound.Name = "HireButtonSound"
		sound.SoundId = constants.SoundId
		sound.Volume = 1.2
		sound.RollOffMaxDistance = 50
		sound.Parent = buttonPart
		sound:Play()

		local buttonSizeTween = TweenService:Create(
			buttonPart,
			TweenInfo.new(constants.TweenDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = Vector3.new(constants.MinThickness, buttonPart.Size.Y, buttonPart.Size.Z), Transparency = 1 }
		)
		local baseSizeTween = TweenService:Create(
			basePart,
			TweenInfo.new(constants.TweenDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Size = Vector3.new(constants.MinThickness, basePart.Size.Y, basePart.Size.Z), Transparency = 1 }
		)
		local billboardTween = TweenService:Create(
			costLabel,
			TweenInfo.new(constants.TweenDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)

		if billboardGui:IsA("BillboardGui") then
			billboardGui.Enabled = true
		end

		buttonSizeTween:Play()
		baseSizeTween:Play()
		billboardTween:Play()

		local tweenToken = runtimePlotState.HireTweenToken
		buttonSizeTween.Completed:Connect(function()
			if runtimePlotState.HireTweenToken ~= tweenToken then
				return
			end

			destroyHireButton(runtimePlotState)
		end)
	end

	local function updatePromptForPlot(player, plotId)
		local plotRecord = deps.getAssignedPlot(player, plotId)

		if not plotRecord then
			return
		end

		local plotState = deps.getTreePlot(player, plotId)
		local runtimePlotState = deps.getRuntimePlotState(player, plotId)

		if not plotState or not plotState.Unlocked or plotState.HasLumberjack == true then
			if runtimePlotState.IsHireAnimating then
				return
			end

			destroyHireButton(runtimePlotState)
			return
		end

		local hireCost = deps.getHireCostByPlotId(plotId)

		if typeof(hireCost) ~= "number" then
			destroyHireButton(runtimePlotState)
			return
		end

		local buttonModel = runtimePlotState.HireButtonModel
		local buttonPart = buttonModel and buttonModel:FindFirstChild("Button")
		local basePart = buttonModel and buttonModel:FindFirstChild("Base")

		if not buttonModel or not buttonPart or not basePart then
			destroyHireButton(runtimePlotState)
			buttonModel, buttonPart, basePart = createHireButtonModel(plotRecord)
			buttonModel.Parent = plotRecord.Model
			runtimePlotState.HireButtonModel = buttonModel
			runtimePlotState.HireTouchConnection = buttonPart.Touched:Connect(function(hit)
				local touchingPlayer = deps.getTouchingPlayer(hit)

				if touchingPlayer ~= player then
					return
				end

				local now = os.clock()

				if now - runtimePlotState.LastHireTouchAt < constants.TouchCooldown then
					return
				end

				runtimePlotState.LastHireTouchAt = now
				deps.attemptHire(player, plotId)
			end)
		end

		local canAfford = (deps.getGold(player) or 0) >= hireCost
		updateHireButtonVisuals(buttonModel, hireCost, canAfford)
	end

	local function refreshPrompts(player)
		local plotSet = deps.getAssignedPlotSet(player)

		if not plotSet then
			return
		end

		for _, ownedPlotId in plotSet.OrderedPlotIds do
			updatePromptForPlot(player, ownedPlotId)
		end
	end

	return {
		destroyHireButton = destroyHireButton,
		playHireSuccessTween = playHireSuccessTween,
		refreshPrompts = refreshPrompts,
		updatePromptForPlot = updatePromptForPlot,
	}
end

return LumberjackHirePromptManager
