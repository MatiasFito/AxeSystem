local TweenService = game:GetService("TweenService")

local TreeUnlockPromptManager = {}

function TreeUnlockPromptManager.create(deps)
	local constants = deps.constants

	local function destroyUnlockButton(runtimePlotState)
		runtimePlotState.UnlockTweenToken += 1
		runtimePlotState.IsUnlockAnimating = false

		if runtimePlotState.UnlockTouchConnection then
			runtimePlotState.UnlockTouchConnection:Disconnect()
			runtimePlotState.UnlockTouchConnection = nil
		end

		if runtimePlotState.UnlockButtonModel and runtimePlotState.UnlockButtonModel.Parent then
			runtimePlotState.UnlockButtonModel:Destroy()
		end

		runtimePlotState.UnlockButtonModel = nil
		if runtimePlotState.LastUnlockTouchAt == nil then
			runtimePlotState.LastUnlockTouchAt = 0
		end
	end

	local function createUnlockButtonModel(plotRecord)
		local existingModel = plotRecord.Model:FindFirstChild(string.format("%sUnlockButton", plotRecord.PlotId))

		if existingModel and existingModel:IsA("Model") then
			existingModel:Destroy()
		end

		local model = deps.getButtonTemplate():Clone()
		model.Name = string.format("%sUnlockButton", plotRecord.PlotId)

		local base = model:FindFirstChild("Base")
		local button = model:FindFirstChild("Button")
		local billboardGui = model:FindFirstChild("CostBillboard")

		if not base or not base:IsA("BasePart") or not button or not button:IsA("BasePart") then
			error(
				"Validated Studio asset 'ServerStorage/ButtonTemplate' is missing required Base or Button parts at runtime"
			)
		end

		if not billboardGui or not billboardGui:IsA("BillboardGui") then
			error("Validated Studio asset 'ServerStorage/ButtonTemplate' is missing CostBillboard at runtime")
		end

		base.Anchored = true
		base.CanCollide = false
		base.CanQuery = true
		base.CanTouch = true
		button.Anchored = true
		button.CanCollide = false
		button.CanQuery = true
		button.CanTouch = true
		billboardGui.Adornee = button

		local forwardDirection = deps.getHorizontalDirection(plotRecord.DirtPatch.CFrame.LookVector)
		local dirtPatchExtent = deps.getPartExtentAlongDirection(plotRecord.DirtPatch, forwardDirection)
		local targetPosition = plotRecord.DirtPatch.Position
			+ forwardDirection * (dirtPatchExtent + constants.EdgeOffset)
		local pivotCFrame = CFrame.lookAt(targetPosition, targetPosition + forwardDirection, Vector3.yAxis)
			* CFrame.Angles(0, 0, math.rad(90))
		base.CFrame = pivotCFrame
		button.CFrame = pivotCFrame * CFrame.new(0.2, 0, 0)

		local baseVerticalHalfExtent = base.Size.X * 0.5
		local dirtPatchTopY = plotRecord.DirtPatch.Position.Y + (plotRecord.DirtPatch.Size.Y * 0.5)
		local yOffset = (dirtPatchTopY - baseVerticalHalfExtent) - base.Position.Y
		base.CFrame += Vector3.new(0, yOffset, 0)
		button.CFrame += Vector3.new(0, yOffset, 0)

		return model, button, base
	end

	local function updateUnlockButtonVisuals(buttonModel, tree, canAfford)
		if not buttonModel or not tree then
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
		costLabel.Text = string.format("$ %d", tree.UnlockCost)
		costLabel.TextColor3 = canAfford and constants.TextReady or constants.TextLocked
	end

	local function playUnlockButtonSuccessTween(runtimePlotState)
		local buttonModel = runtimePlotState.UnlockButtonModel

		if not buttonModel or not buttonModel.Parent then
			destroyUnlockButton(runtimePlotState)
			return
		end

		local buttonPart = buttonModel:FindFirstChild("Button")
		local basePart = buttonModel:FindFirstChild("Base")
		local billboardGui = buttonModel:FindFirstChild("CostBillboard")
		local costLabel = billboardGui and billboardGui:FindFirstChild("CostLabel")

		if not buttonPart or not basePart or not billboardGui or not costLabel or not costLabel:IsA("TextLabel") then
			destroyUnlockButton(runtimePlotState)
			return
		end

		runtimePlotState.UnlockTweenToken += 1
		runtimePlotState.IsUnlockAnimating = true

		if runtimePlotState.UnlockTouchConnection then
			runtimePlotState.UnlockTouchConnection:Disconnect()
			runtimePlotState.UnlockTouchConnection = nil
		end

		buttonPart.CanTouch = false
		buttonPart.CanQuery = false
		basePart.CanTouch = false
		basePart.CanQuery = false

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

		local tweenToken = runtimePlotState.UnlockTweenToken
		task.delay(constants.TweenDuration + 0.05, function()
			if runtimePlotState.UnlockTweenToken ~= tweenToken then
				return
			end

			if billboardGui:IsA("BillboardGui") then
				billboardGui.Enabled = false
			end

			destroyUnlockButton(runtimePlotState)
		end)

		buttonSizeTween.Completed:Connect(function()
			if runtimePlotState.UnlockTweenToken ~= tweenToken then
				return
			end

			if billboardGui:IsA("BillboardGui") then
				billboardGui.Enabled = false
			end

			destroyUnlockButton(runtimePlotState)
		end)
	end

	local function updatePromptForPlot(player, plotId)
		local plotRecord = deps.getAssignedPlot(player, plotId)

		if not plotRecord then
			return
		end

		local plotState = deps.getTreePlot(player, plotId)
		local tree = deps.getTreeByPlotId(plotId)
		local runtimePlotState = deps.getPlotRuntimeState(player, plotId)

		if not plotState or not tree then
			destroyUnlockButton(runtimePlotState)
			return
		end

		if not plotState.Unlocked then
			if not deps.isPlotUnlockable(deps.getTreePlots(player) or {}, plotId) then
				destroyUnlockButton(runtimePlotState)
				return
			end

			local buttonModel = runtimePlotState.UnlockButtonModel
			local buttonPart = buttonModel and buttonModel:FindFirstChild("Button")
			local basePart = buttonModel and buttonModel:FindFirstChild("Base")

			if not buttonModel or not buttonPart or not basePart then
				destroyUnlockButton(runtimePlotState)
				buttonModel, buttonPart, basePart = createUnlockButtonModel(plotRecord)
				buttonModel.Parent = plotRecord.Model
				runtimePlotState.UnlockButtonModel = buttonModel
				runtimePlotState.UnlockTouchConnection = buttonPart.Touched:Connect(function(hit)
					local touchingPlayer = deps.getTouchingPlayer(hit)

					if touchingPlayer ~= player then
						return
					end

					local now = os.clock()

					if now - runtimePlotState.LastUnlockTouchAt < constants.TouchCooldown then
						return
					end

					runtimePlotState.LastUnlockTouchAt = now
					deps.attemptUnlock(player, plotId)
				end)
			end

			local unlockCost = deps.getUnlockCost(player, tree)
			local canAfford = typeof(unlockCost) == "number" and (deps.getGold(player) or 0) >= unlockCost
			updateUnlockButtonVisuals(buttonModel, tree, canAfford)
			return
		end

		if runtimePlotState.IsUnlockAnimating then
			return
		end

		destroyUnlockButton(runtimePlotState)
	end

	local function refreshUnlockButtons(player)
		local plotSet = deps.getAssignedPlotSet(player)

		if not plotSet then
			return
		end

		for _, ownedPlotId in plotSet.OrderedPlotIds do
			updatePromptForPlot(player, ownedPlotId)
		end
	end

	return {
		destroyUnlockButton = destroyUnlockButton,
		playUnlockButtonSuccessTween = playUnlockButtonSuccessTween,
		refreshUnlockButtons = refreshUnlockButtons,
		updatePromptForPlot = updatePromptForPlot,
	}
end

return TreeUnlockPromptManager
