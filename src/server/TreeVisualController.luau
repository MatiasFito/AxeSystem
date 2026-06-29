local Workspace = game:GetService("Workspace")

local TreeVisualController = {}

local randomGenerator = Random.new()

local function getTreeVisualPivot(treeInstance)
	if treeInstance:IsA("Model") then
		return treeInstance:GetPivot()
	end

	return treeInstance.CFrame
end

function TreeVisualController.create(deps)
	local constants = deps.constants

	local function beginVisualAnimation(runtimePlotState)
		runtimePlotState.AnimationToken += 1
		return runtimePlotState.AnimationToken
	end

	local function destroySpawnedTree(runtimePlotState)
		beginVisualAnimation(runtimePlotState)
		runtimePlotState.VisualState = nil
		runtimePlotState.VisualScale = 1
		runtimePlotState.FullHealth = nil
		runtimePlotState.CurrentHealth = nil

		if runtimePlotState.SpawnedTreeModel and runtimePlotState.SpawnedTreeModel.Parent then
			runtimePlotState.SpawnedTreeModel:Destroy()
		end

		runtimePlotState.SpawnedTreeModel = nil
	end

	local function getTreeEffectPart(treeInstance)
		if not treeInstance then
			return nil
		end

		if treeInstance:IsA("BasePart") then
			return treeInstance
		end

		local trunk = treeInstance:FindFirstChild("Trunk", true)

		if trunk and trunk:IsA("BasePart") then
			return trunk
		end

		for _, descendant in treeInstance:GetDescendants() do
			if descendant:IsA("BasePart") then
				return descendant
			end
		end

		return nil
	end

	local function getTreeImpactData(effectPart, sourcePosition)
		if not sourcePosition then
			return effectPart.Position, effectPart.CFrame.LookVector
		end

		local directionToSource = sourcePosition - effectPart.Position

		if directionToSource.Magnitude <= 0.001 then
			directionToSource = effectPart.CFrame.LookVector
		end

		local unitDirection = directionToSource.Unit
		local extent = deps.getPartExtentAlongDirection(effectPart, unitDirection)
		return effectPart.Position + unitDirection * (extent + constants.ImpactSurfaceOffset), unitDirection
	end

	local function createTreeImpactAttachment(effectPart, sourcePosition)
		local impactPosition, outwardDirection = getTreeImpactData(effectPart, sourcePosition)
		local upVector = Vector3.yAxis

		if math.abs(outwardDirection:Dot(upVector)) >= 0.98 then
			upVector = effectPart.CFrame.RightVector
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "TreeImpactAttachment"
		attachment.CFrame =
			effectPart.CFrame:ToObjectSpace(CFrame.lookAt(impactPosition, impactPosition + outwardDirection, upVector))
		attachment.Parent = effectPart
		return attachment
	end

	local function createDetachedEffectAnchor(name, worldCFrame)
		local anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = worldCFrame
		anchor.Parent = Workspace
		return anchor
	end

	local function emitTreeParticles(treeInstance, particleCount, sourcePosition, options)
		local effectPart = getTreeEffectPart(treeInstance)

		if not effectPart then
			return
		end

		local attachment = createTreeImpactAttachment(effectPart, sourcePosition)
		local cleanupTarget = attachment

		if typeof(options) == "table" and options.detach == true then
			local detachedAnchor = createDetachedEffectAnchor("TreeImpactEffectAnchor", attachment.WorldCFrame)
			local detachedAttachment = Instance.new("Attachment")
			detachedAttachment.Name = attachment.Name
			detachedAttachment.CFrame = CFrame.new()
			detachedAttachment.Parent = detachedAnchor
			attachment:Destroy()
			attachment = detachedAttachment
			cleanupTarget = detachedAnchor
		end

		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "TreeImpactParticles"
		emitter.Texture = constants.ImpactParticleTexture
		emitter.Color = ColorSequence.new(Color3.fromRGB(196, 164, 116), Color3.fromRGB(104, 73, 46))
		emitter.Lifetime = NumberRange.new(0.18, 0.35)
		emitter.Speed = NumberRange.new(5, 9)
		emitter.Rate = 0
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-180, 180)
		emitter.SpreadAngle = Vector2.new(55, 55)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.LightEmission = 0
		emitter.LockedToPart = false
		emitter.Acceleration = Vector3.new(0, -16, 0)
		emitter.Parent = attachment
		emitter:Emit(particleCount)

		task.delay(1, function()
			if cleanupTarget.Parent then
				cleanupTarget:Destroy()
			end
		end)
	end

	local function captureTreeVisualState(runtimePlotState, treeInstance)
		local pivot = getTreeVisualPivot(treeInstance)
		local partStates = {}

		if treeInstance:IsA("Model") then
			for _, descendant in treeInstance:GetDescendants() do
				if descendant:IsA("BasePart") then
					local relativeCFrame = pivot:ToObjectSpace(descendant.CFrame)
					table.insert(partStates, {
						Part = descendant,
						Size = descendant.Size,
						RelativePosition = relativeCFrame.Position,
						RelativeXVector = relativeCFrame.XVector,
						RelativeYVector = relativeCFrame.YVector,
						RelativeZVector = relativeCFrame.ZVector,
						Transparency = descendant.Transparency,
					})
				end
			end
		else
			local relativeCFrame = CFrame.new()
			table.insert(partStates, {
				Part = treeInstance,
				Size = treeInstance.Size,
				RelativePosition = relativeCFrame.Position,
				RelativeXVector = relativeCFrame.XVector,
				RelativeYVector = relativeCFrame.YVector,
				RelativeZVector = relativeCFrame.ZVector,
				Transparency = treeInstance.Transparency,
			})
		end

		runtimePlotState.VisualState = {
			Pivot = pivot,
			PartStates = partStates,
		}
	end

	local function applyTreeVisual(
		runtimePlotState,
		plotRecord,
		scale,
		pivotOverride,
		transparencyAlpha,
		shouldAlignBottom
	)
		local visualState = runtimePlotState.VisualState
		local treeInstance = runtimePlotState.SpawnedTreeModel

		if not visualState or not treeInstance or not treeInstance.Parent then
			return false
		end

		local clampedScale = math.max(constants.MinScale, scale)
		local pivot = pivotOverride or visualState.Pivot
		local fadeAlpha = math.clamp(transparencyAlpha or 0, 0, 1)

		for _, partState in visualState.PartStates do
			local part = partState.Part

			if part and part.Parent then
				part.Size = partState.Size * clampedScale
				part.CFrame = pivot
					* CFrame.fromMatrix(
						partState.RelativePosition * clampedScale,
						partState.RelativeXVector,
						partState.RelativeYVector,
						partState.RelativeZVector
					)
				part.Transparency = partState.Transparency + ((1 - partState.Transparency) * fadeAlpha)
			end
		end

		if shouldAlignBottom ~= false then
			deps.alignCloneBottomToPlot(treeInstance, plotRecord)
			visualState.Pivot = getTreeVisualPivot(treeInstance)
		end

		runtimePlotState.VisualScale = clampedScale
		return true
	end

	local function applyTreeScale(runtimePlotState, plotRecord, scale)
		return applyTreeVisual(runtimePlotState, plotRecord, scale, nil, 0, true)
	end

	local function applyTreeShake(runtimePlotState, plotRecord, durationSeconds, maxAngleDegrees)
		local visualState = runtimePlotState.VisualState
		local treeInstance = runtimePlotState.SpawnedTreeModel
		local duration = math.clamp(durationSeconds or 0, 0, 0.1)
		local maxAngleRadians = math.rad(math.max(0, maxAngleDegrees or 0))

		if not visualState or not treeInstance or not treeInstance.Parent then
			return false
		end

		if duration <= 0 or maxAngleRadians <= 0 then
			return false
		end

		runtimePlotState.ShakeToken = (runtimePlotState.ShakeToken or 0) + 1
		local shakeToken = runtimePlotState.ShakeToken
		local currentScale = runtimePlotState.VisualScale > 0 and runtimePlotState.VisualScale or 1
		local shakeAngle = maxAngleRadians
		local basePivot = visualState.Pivot or getTreeVisualPivot(treeInstance)

		if randomGenerator:NextNumber() < 0.5 then
			shakeAngle *= -1
		end

		local rotation = if randomGenerator:NextInteger(1, 2) == 1
			then CFrame.Angles(shakeAngle, 0, 0)
			else CFrame.Angles(0, 0, shakeAngle)

		if not applyTreeVisual(runtimePlotState, plotRecord, currentScale, basePivot * rotation, 0, true) then
			return false
		end

		task.delay(duration, function()
			if runtimePlotState.ShakeToken ~= shakeToken then
				return
			end

			applyTreeVisual(runtimePlotState, plotRecord, currentScale, basePivot, 0, true)
		end)

		return true
	end

	local function getGrowthScale(progress)
		return constants.MinScale + ((1 - constants.MinScale) * math.clamp(progress, 0, 1))
	end

	local function getHarvestScale(currentHealth, maxHealth)
		if not maxHealth or maxHealth <= 0 then
			return 1
		end

		local healthRatio = math.clamp(currentHealth / maxHealth, 0, 1)
		return constants.DeadScale + ((1 - constants.DeadScale) * healthRatio)
	end

	return {
		beginVisualAnimation = beginVisualAnimation,
		destroySpawnedTree = destroySpawnedTree,
		emitTreeParticles = emitTreeParticles,
		captureTreeVisualState = captureTreeVisualState,
		applyTreeVisual = applyTreeVisual,
		applyTreeScale = applyTreeScale,
		applyTreeShake = applyTreeShake,
		getGrowthScale = getGrowthScale,
		getHarvestScale = getHarvestScale,
	}
end

return TreeVisualController
