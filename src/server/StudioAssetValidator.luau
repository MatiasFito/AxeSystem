local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local StudioAssetValidator = {}

local AXE_DEFAULTS_FOLDER_NAME = "AxeDefaults"
local AXE_OVERRIDES_FOLDER_NAME = "AxeOverrides"
local TOOL_CHILDREN_FOLDER_NAME = "ToolChildren"
local HANDLE_CHILDREN_FOLDER_NAME = "HandleChildren"

local function pushError(errors, message)
	table.insert(errors, message)
end

local function requireFolder(parent, name, errors, context)
	local child = parent:FindFirstChild(name)

	if not child then
		pushError(errors, string.format("Missing %s folder '%s'", context, name))
		return nil
	end

	if not child:IsA("Folder") then
		pushError(errors, string.format("Expected %s '%s' to be a Folder, got %s", context, name, child.ClassName))
		return nil
	end

	return child
end

local function requireChild(parent, name, expectedClassName, errors, context)
	local child = parent:FindFirstChild(name)

	if not child then
		pushError(errors, string.format("Missing %s '%s' under %s", expectedClassName, name, context))
		return nil
	end

	if not child:IsA(expectedClassName) then
		pushError(
			errors,
			string.format(
				"Expected %s '%s' under %s to be a %s, got %s",
				expectedClassName,
				name,
				context,
				expectedClassName,
				child.ClassName
			)
		)
		return nil
	end

	return child
end

local function validateAxeTemplates(errors)
	local templatesFolder =
		requireFolder(ServerStorage, blacksmithConstants.AXE_TEMPLATE_FOLDER_NAME, errors, "ServerStorage")

	if not templatesFolder then
		return
	end

	for _, tierId in axeConfig.Order do
		local tier = axeConfig.getTier(tierId)

		if tier then
			local template = requireChild(
				templatesFolder,
				tier.ToolTemplateName,
				"Tool",
				errors,
				string.format("ServerStorage/%s", blacksmithConstants.AXE_TEMPLATE_FOLDER_NAME)
			)

			if template then
				requireChild(
					template,
					"Handle",
					"BasePart",
					errors,
					string.format(
						"ServerStorage/%s/%s",
						blacksmithConstants.AXE_TEMPLATE_FOLDER_NAME,
						tier.ToolTemplateName
					)
				)
			end
		end
	end
end

local function validateAxeDefaults(errors)
	local defaultsFolder = requireFolder(ServerStorage, AXE_DEFAULTS_FOLDER_NAME, errors, "ServerStorage")

	if not defaultsFolder then
		return
	end

	requireFolder(
		defaultsFolder,
		TOOL_CHILDREN_FOLDER_NAME,
		errors,
		string.format("ServerStorage/%s", AXE_DEFAULTS_FOLDER_NAME)
	)
	requireFolder(
		defaultsFolder,
		HANDLE_CHILDREN_FOLDER_NAME,
		errors,
		string.format("ServerStorage/%s", AXE_DEFAULTS_FOLDER_NAME)
	)
end

local function validateAxeOverrides(errors)
	local overridesFolder = ServerStorage:FindFirstChild(AXE_OVERRIDES_FOLDER_NAME)

	if not overridesFolder then
		return
	end

	if not overridesFolder:IsA("Folder") then
		pushError(
			errors,
			string.format(
				"Expected ServerStorage/%s to be a Folder, got %s",
				AXE_OVERRIDES_FOLDER_NAME,
				overridesFolder.ClassName
			)
		)
		return
	end

	local knownTierIds = {}

	for _, tierId in axeConfig.Order do
		knownTierIds[tierId] = true
		local tierOverride = overridesFolder:FindFirstChild(tierId)

		if tierOverride then
			if not tierOverride:IsA("Folder") then
				pushError(
					errors,
					string.format(
						"Expected ServerStorage/%s/%s to be a Folder, got %s",
						AXE_OVERRIDES_FOLDER_NAME,
						tierId,
						tierOverride.ClassName
					)
				)
			else
				local toolChildren = tierOverride:FindFirstChild(TOOL_CHILDREN_FOLDER_NAME)

				if toolChildren and not toolChildren:IsA("Folder") then
					pushError(
						errors,
						string.format(
							"Expected ServerStorage/%s/%s/%s to be a Folder, got %s",
							AXE_OVERRIDES_FOLDER_NAME,
							tierId,
							TOOL_CHILDREN_FOLDER_NAME,
							toolChildren.ClassName
						)
					)
				end

				local handleChildren = tierOverride:FindFirstChild(HANDLE_CHILDREN_FOLDER_NAME)

				if handleChildren and not handleChildren:IsA("Folder") then
					pushError(
						errors,
						string.format(
							"Expected ServerStorage/%s/%s/%s to be a Folder, got %s",
							AXE_OVERRIDES_FOLDER_NAME,
							tierId,
							HANDLE_CHILDREN_FOLDER_NAME,
							handleChildren.ClassName
						)
					)
				end
			end
		end
	end

	for _, child in overridesFolder:GetChildren() do
		if not knownTierIds[child.Name] then
			pushError(
				errors,
				string.format(
					"Unexpected override folder 'ServerStorage/%s/%s'; expected one of the configured axe tier ids",
					AXE_OVERRIDES_FOLDER_NAME,
					child.Name
				)
			)
		end
	end
end

local function validateTrees(errors)
	local treesFolder = requireFolder(ServerStorage, treeConstants.TREE_TEMPLATE_FOLDER_NAME, errors, "ServerStorage")

	if not treesFolder then
		return
	end

	for _, treeId in treeConfig.Order do
		local treeDefinition = treeConfig.getTree(treeId)

		if treeDefinition then
			local template = treesFolder:FindFirstChild(treeDefinition.TemplateName)

			if not template then
				pushError(
					errors,
					string.format(
						"Missing tree template '%s' under ServerStorage/%s",
						treeDefinition.TemplateName,
						treeConstants.TREE_TEMPLATE_FOLDER_NAME
					)
				)
			elseif not template:IsA("Model") and not template:IsA("BasePart") then
				pushError(
					errors,
					string.format(
						"Expected tree template 'ServerStorage/%s/%s' to be a Model or BasePart, got %s",
						treeConstants.TREE_TEMPLATE_FOLDER_NAME,
						treeDefinition.TemplateName,
						template.ClassName
					)
				)
			end
		end
	end
end

local function validateNpcTemplates(errors)
	local npcFolder =
		requireFolder(ServerStorage, lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME, errors, "ServerStorage")

	if not npcFolder then
		return
	end

	local template = requireChild(
		npcFolder,
		lumberjackConstants.NPC_TEMPLATE_NAME,
		"Model",
		errors,
		string.format("ServerStorage/%s", lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME)
	)

	if not template then
		return
	end

	requireChild(
		template,
		"RightHand",
		"BasePart",
		errors,
		string.format(
			"ServerStorage/%s/%s",
			lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME,
			lumberjackConstants.NPC_TEMPLATE_NAME
		)
	)
	requireChild(
		template,
		"HumanoidRootPart",
		"BasePart",
		errors,
		string.format(
			"ServerStorage/%s/%s",
			lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME,
			lumberjackConstants.NPC_TEMPLATE_NAME
		)
	)

	local humanoid = template:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		pushError(
			errors,
			string.format(
				"Missing Humanoid under ServerStorage/%s/%s",
				lumberjackConstants.NPC_TEMPLATE_FOLDER_NAME,
				lumberjackConstants.NPC_TEMPLATE_NAME
			)
		)
	end
end

function StudioAssetValidator.validateOrThrow()
	local errors = {}

	validateAxeTemplates(errors)
	validateAxeDefaults(errors)
	validateAxeOverrides(errors)
	validateTrees(errors)
	validateNpcTemplates(errors)

	if #errors > 0 then
		error("Studio asset validation failed:\n- " .. table.concat(errors, "\n- "))
	end

	return true
end

return StudioAssetValidator
