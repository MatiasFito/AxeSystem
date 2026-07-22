local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local axeConfig = require(sharedFolder:WaitForChild("AxeConfig") :: ModuleScript)
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)
local lumberjackConstants = require(sharedFolder:WaitForChild("LumberjackConstants") :: ModuleScript)
local treeConfig = require(sharedFolder:WaitForChild("TreeConfig") :: ModuleScript)
local treeConstants = require(sharedFolder:WaitForChild("TreeConstants") :: ModuleScript)

local StudioAssetValidator = {}

local AXE_DEFAULTS_FOLDER_NAME = "AxeDefaults"
local AXE_OVERRIDES_FOLDER_NAME = "AxeOverrides"
local BUTTON_TEMPLATE_NAME = "ButtonTemplate"
local TOOL_CHILDREN_FOLDER_NAME = "ToolChildren"
local HANDLE_CHILDREN_FOLDER_NAME = "HandleChildren"
local DYNAMIC_HUD_NAME = "DynamicHUD"
local POPUPS_HUD_NAME = "PopupsHUD"
local STATIC_HUD_NAME = "StaticHUD"

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

local function requireDescendant(parent, name, expectedClassName, errors, context)
	local child = parent:FindFirstChild(name, true)

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

local function requireChildPath(parent, path, expectedClassName, errors, context)
	local current = parent
	local currentContext = context

	for index, name in ipairs(path) do
		local child = current:FindFirstChild(name)

		if not child then
			pushError(errors, string.format("Missing %s '%s' under %s", expectedClassName, name, currentContext))
			return nil
		end

		if index == #path then
			if not child:IsA(expectedClassName) then
				pushError(
					errors,
					string.format(
						"Expected %s '%s' under %s to be a %s, got %s",
						expectedClassName,
						name,
						currentContext,
						expectedClassName,
						child.ClassName
					)
				)
				return nil
			end

			return child
		end

		current = child
		currentContext = string.format("%s/%s", currentContext, name)
	end

	return nil
end

local function hasPrefix(value, prefix)
	return string.len(value) >= string.len(prefix) and string.sub(value, 1, string.len(prefix)) == prefix
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

local function validateTreePlotTemplate(errors)
	local template =
		requireChild(ServerStorage, treeConstants.TREE_PLOT_TEMPLATE_NAME, "Model", errors, "ServerStorage")

	if not template then
		return
	end

	local plotSign = requireDescendant(
		template,
		"PlotSign",
		"BasePart",
		errors,
		string.format("ServerStorage/%s", treeConstants.TREE_PLOT_TEMPLATE_NAME)
	)

	if not plotSign then
		return
	end

	local surfaceGui = requireChild(
		plotSign,
		"SurfaceGui",
		"SurfaceGui",
		errors,
		string.format("ServerStorage/%s/PlotSign", treeConstants.TREE_PLOT_TEMPLATE_NAME)
	)

	if not surfaceGui then
		return
	end

	local background = requireChild(
		surfaceGui,
		"Background",
		"GuiObject",
		errors,
		string.format("ServerStorage/%s/PlotSign/SurfaceGui", treeConstants.TREE_PLOT_TEMPLATE_NAME)
	)

	if not background then
		return
	end

	local mainContent = requireChild(
		background,
		"MainContent",
		"GuiObject",
		errors,
		string.format("ServerStorage/%s/PlotSign/SurfaceGui/Background", treeConstants.TREE_PLOT_TEMPLATE_NAME)
	)

	if not mainContent then
		return
	end

	requireChild(
		mainContent,
		"TreeName",
		"TextLabel",
		errors,
		string.format(
			"ServerStorage/%s/PlotSign/SurfaceGui/Background/MainContent",
			treeConstants.TREE_PLOT_TEMPLATE_NAME
		)
	)
	requireChild(
		mainContent,
		"TreeLevel",
		"TextLabel",
		errors,
		string.format(
			"ServerStorage/%s/PlotSign/SurfaceGui/Background/MainContent",
			treeConstants.TREE_PLOT_TEMPLATE_NAME
		)
	)
	requireChild(
		mainContent,
		"TreeReward",
		"TextLabel",
		errors,
		string.format(
			"ServerStorage/%s/PlotSign/SurfaceGui/Background/MainContent",
			treeConstants.TREE_PLOT_TEMPLATE_NAME
		)
	)
	requireChild(
		mainContent,
		"LumberjackLevel",
		"TextLabel",
		errors,
		string.format(
			"ServerStorage/%s/PlotSign/SurfaceGui/Background/MainContent",
			treeConstants.TREE_PLOT_TEMPLATE_NAME
		)
	)
	requireChild(
		mainContent,
		"LumberjackBonus",
		"TextLabel",
		errors,
		string.format(
			"ServerStorage/%s/PlotSign/SurfaceGui/Background/MainContent",
			treeConstants.TREE_PLOT_TEMPLATE_NAME
		)
	)
end

local function validatePlotUpgradeGui(errors)
	local plotUpgradeGui =
		requireChildPath(StarterGui, { POPUPS_HUD_NAME, "PlotUpgradeModal" }, "GuiObject", errors, "StarterGui")

	if not plotUpgradeGui then
		return
	end

	local mainFrame =
		requireChild(plotUpgradeGui, "MainFrame", "GuiObject", errors, "StarterGui/PopupsHUD/PlotUpgradeModal")
	requireChild(plotUpgradeGui, "Dimmer", "GuiObject", errors, "StarterGui/PopupsHUD/PlotUpgradeModal")

	if not mainFrame then
		return
	end

	local contentFrame =
		requireChild(mainFrame, "ContentFrame", "GuiObject", errors, "StarterGui/PopupsHUD/PlotUpgradeModal/MainFrame")
	local bottomButtons =
		requireChild(mainFrame, "BottomButtons", "GuiObject", errors, "StarterGui/PopupsHUD/PlotUpgradeModal/MainFrame")

	if bottomButtons then
		requireChild(
			bottomButtons,
			"UpgradeTreeButton",
			"GuiButton",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/MainFrame/BottomButtons"
		)
		requireChild(
			bottomButtons,
			"UpgradeWorkerButton",
			"GuiButton",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/MainFrame/BottomButtons"
		)
	end

	if not contentFrame then
		return
	end

	local treeStatsColumn = requireChild(
		contentFrame,
		"TreeStatsColumn",
		"GuiObject",
		errors,
		"StarterGui/PopupsHUD/PlotUpgradeModal/MainFrame/ContentFrame"
	)
	local workerColumn = requireChild(
		contentFrame,
		"WorkerColumn",
		"GuiObject",
		errors,
		"StarterGui/PopupsHUD/PlotUpgradeModal/MainFrame/ContentFrame"
	)

	if treeStatsColumn then
		requireChild(
			treeStatsColumn,
			"Header",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/TreeStatsColumn"
		)
		requireChild(
			treeStatsColumn,
			"HP",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/TreeStatsColumn"
		)
		requireChild(
			treeStatsColumn,
			"GrowTime",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/TreeStatsColumn"
		)
		requireChild(
			treeStatsColumn,
			"Reward",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/TreeStatsColumn"
		)
	end

	if not workerColumn then
		return
	end

	local hiredWorkerView = requireChild(
		workerColumn,
		"HiredWorkerView",
		"GuiObject",
		errors,
		"StarterGui/PopupsHUD/PlotUpgradeModal/WorkerColumn"
	)
	local hireWorkerView = requireChild(
		workerColumn,
		"HireWorkerView",
		"GuiObject",
		errors,
		"StarterGui/PopupsHUD/PlotUpgradeModal/WorkerColumn"
	)

	if hiredWorkerView then
		requireChild(
			hiredWorkerView,
			"Header",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/HiredWorkerView"
		)
		requireChild(
			hiredWorkerView,
			"Bonus",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/HiredWorkerView"
		)
		requireChild(
			hiredWorkerView,
			"Axe",
			"TextLabel",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/HiredWorkerView"
		)
	end

	if hireWorkerView then
		requireChild(
			hireWorkerView,
			"HireWorkerButton",
			"GuiButton",
			errors,
			"StarterGui/PopupsHUD/PlotUpgradeModal/HireWorkerView"
		)
	end
end

local function validateAmberShopGui(errors)
	local amberShopGui =
		requireChildPath(StarterGui, { POPUPS_HUD_NAME, "AmberModal" }, "GuiObject", errors, "StarterGui")

	if not amberShopGui then
		return
	end

	local root = requireChild(amberShopGui, "Root", "GuiObject", errors, "StarterGui/PopupsHUD/AmberModal")

	if not root then
		return
	end

	requireChild(root, "Balance", "TextLabel", errors, "StarterGui/PopupsHUD/AmberModal/Root")
	requireChild(root, "Status", "TextLabel", errors, "StarterGui/PopupsHUD/AmberModal/Root")
	requireChild(root, "CloseButton", "GuiButton", errors, "StarterGui/PopupsHUD/AmberModal/Root")

	local scrollingFrame =
		requireChild(root, "ScrollingFrame", "ScrollingFrame", errors, "StarterGui/PopupsHUD/AmberModal/Root")

	if not scrollingFrame then
		return
	end

	if not scrollingFrame:FindFirstChildOfClass("UIListLayout") then
		pushError(errors, "Missing UIListLayout under StarterGui/PopupsHUD/AmberModal/Root/ScrollingFrame")
	end

	local cardTemplate = scrollingFrame:FindFirstChild("CardTemplate") or root:FindFirstChild("CardTemplate")

	if cardTemplate and not cardTemplate:IsA("Frame") then
		pushError(errors, "Expected StarterGui/PopupsHUD/AmberModal card template to be a Frame")
		cardTemplate = nil
	end

	if not cardTemplate then
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("Frame") and hasPrefix(child.Name, "Card_") then
				cardTemplate = child
				break
			end
		end
	end

	if not cardTemplate then
		pushError(
			errors,
			"StarterGui/PopupsHUD/AmberModal/Root/ScrollingFrame must contain CardTemplate or at least one Card_<upgradeKey> frame"
		)
		return
	end

	requireChild(cardTemplate, "Title", "TextLabel", errors, "StarterGui/PopupsHUD/AmberModal/CardTemplate")
	requireChild(cardTemplate, "Level", "TextLabel", errors, "StarterGui/PopupsHUD/AmberModal/CardTemplate")
	requireChild(cardTemplate, "Description", "TextLabel", errors, "StarterGui/PopupsHUD/AmberModal/CardTemplate")
	requireChild(cardTemplate, "Comparison", "TextLabel", errors, "StarterGui/PopupsHUD/AmberModal/CardTemplate")
	requireChild(cardTemplate, "UpgradeButton", "GuiButton", errors, "StarterGui/PopupsHUD/AmberModal/CardTemplate")
end

local function validateAutoSwingGui(errors)
	local autoSwingGui = requireChildPath(
		StarterGui,
		{ STATIC_HUD_NAME, "LeftContainer", "AutoSwingButton" },
		"GuiButton",
		errors,
		"StarterGui"
	)

	if not autoSwingGui then
		return
	end

	requireChild(autoSwingGui, "State", "TextLabel", errors, "StarterGui/StaticHUD/LeftContainer/AutoSwingButton")
end

local function validateRebirthGui(errors)
	local root = requireChildPath(
		StarterGui,
		{ STATIC_HUD_NAME, "RightContainer", "RebirthRoot" },
		"GuiObject",
		errors,
		"StarterGui"
	)
	local rebirthGui =
		requireChildPath(StarterGui, { POPUPS_HUD_NAME, "RebirthModal" }, "GuiObject", errors, "StarterGui")

	if root then
		requireChild(root, "RebirthButton", "GuiButton", errors, "StarterGui/StaticHUD/RightContainer/RebirthRoot")
		requireChild(root, "StatusLabel", "TextLabel", errors, "StarterGui/StaticHUD/RightContainer/RebirthRoot")
	end

	if not rebirthGui then
		return
	end

	local modal = requireChild(rebirthGui, "Modal", "GuiObject", errors, "StarterGui/PopupsHUD/RebirthModal")

	if modal then
		requireChild(modal, "MessageLabel", "TextLabel", errors, "StarterGui/PopupsHUD/RebirthModal/Modal")
		requireChild(modal, "ConfirmButton", "GuiButton", errors, "StarterGui/PopupsHUD/RebirthModal/Modal")
		requireChild(modal, "CancelButton", "GuiButton", errors, "StarterGui/PopupsHUD/RebirthModal/Modal")
	end
end

local function validateTopGoldLabelGui(errors)
	local goldRoot = requireChildPath(
		StarterGui,
		{ DYNAMIC_HUD_NAME, "TopContainer", "GoldRoot" },
		"GuiObject",
		errors,
		"StarterGui"
	)
	local amberRoot = requireChildPath(
		StarterGui,
		{ DYNAMIC_HUD_NAME, "TopContainer", "AmberRoot" },
		"GuiObject",
		errors,
		"StarterGui"
	)

	if goldRoot then
		requireChild(goldRoot, "Amount", "TextLabel", errors, "StarterGui/DynamicHUD/TopContainer/GoldRoot")
	end

	if amberRoot then
		requireChild(amberRoot, "Amount", "TextLabel", errors, "StarterGui/DynamicHUD/TopContainer/AmberRoot")
		requireChild(amberRoot, "Button", "GuiButton", errors, "StarterGui/DynamicHUD/TopContainer/AmberRoot")
	end
end

local function isAllowedPlotSetName(name)
	for index = 1, 6 do
		if name == string.format("PlotSet%02d", index) then
			return true
		end
	end

	return false
end

local function validateTreePlotSets(errors)
	local plotSetsFolder = requireFolder(Workspace, treeConstants.TREE_PLOT_SETS_FOLDER_NAME, errors, "Workspace")

	if not plotSetsFolder then
		return
	end

	local validPlotSetCount = 0

	for _, child in plotSetsFolder:GetChildren() do
		local childPath = string.format("Workspace/%s/%s", treeConstants.TREE_PLOT_SETS_FOLDER_NAME, child.Name)

		if not child:IsA("Folder") then
			pushError(errors, string.format("Expected %s to be a Folder, got %s", childPath, child.ClassName))
		elseif not isAllowedPlotSetName(child.Name) then
			pushError(
				errors,
				string.format("Unexpected plot set folder '%s'; expected PlotSet01 through PlotSet06", childPath)
			)
		else
			validPlotSetCount += 1
			requireChild(child, treeConstants.PLOT_SET_ORIGIN_NAME, "Part", errors, childPath)
			requireChild(child, treeConstants.PLOT_SET_SPAWN_NAME, "Part", errors, childPath)
		end
	end

	if validPlotSetCount == 0 then
		pushError(
			errors,
			string.format(
				"Expected Workspace/%s to contain at least one plot set folder named PlotSet01 through PlotSet06",
				treeConstants.TREE_PLOT_SETS_FOLDER_NAME
			)
		)
	elseif validPlotSetCount > 6 then
		pushError(
			errors,
			string.format(
				"Expected Workspace/%s to contain at most 6 plot set folders, found %d",
				treeConstants.TREE_PLOT_SETS_FOLDER_NAME,
				validPlotSetCount
			)
		)
	end
end

local function validateBlacksmithSection(errors)
	local template =
		requireChild(Workspace, blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME, "Model", errors, "Workspace")

	if not template then
		return
	end

	requireDescendant(
		template,
		blacksmithConstants.BLACKSMITH_PART_NAME,
		"BasePart",
		errors,
		string.format("Workspace/%s", blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME)
	)
	requireDescendant(
		template,
		blacksmithConstants.BLACKSMITH_FLOOR_NAME,
		"BasePart",
		errors,
		string.format("Workspace/%s", blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME)
	)
	requireDescendant(
		template,
		blacksmithConstants.BLACKSMITH_NPC_NAME,
		"Model",
		errors,
		string.format("Workspace/%s", blacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME)
	)
end

local function validateBlacksmithGui(errors)
	local blacksmithGui =
		requireChildPath(StarterGui, { POPUPS_HUD_NAME, "BlacksmithModal" }, "GuiObject", errors, "StarterGui")

	if not blacksmithGui then
		return
	end

	local root = requireChild(blacksmithGui, "Root", "GuiObject", errors, "StarterGui/PopupsHUD/BlacksmithModal")

	if not root then
		return
	end

	requireChild(root, "CloseButton", "GuiButton", errors, "StarterGui/PopupsHUD/BlacksmithModal/Root")
	requireChild(root, "UpgradeButton", "GuiButton", errors, "StarterGui/PopupsHUD/BlacksmithModal/Root")
	requireChild(root, "UpgradeArrow", "GuiObject", errors, "StarterGui/PopupsHUD/BlacksmithModal/Root")

	for _, cardName in ipairs({ "CurrentAxe", "NextAxe" }) do
		local card = requireChild(root, cardName, "GuiObject", errors, "StarterGui/PopupsHUD/BlacksmithModal/Root")

		if card then
			requireChild(
				card,
				"AxeImage",
				"ImageLabel",
				errors,
				string.format("StarterGui/PopupsHUD/BlacksmithModal/Root/%s", cardName)
			)
			requireChild(
				card,
				"AxeName",
				"TextLabel",
				errors,
				string.format("StarterGui/PopupsHUD/BlacksmithModal/Root/%s", cardName)
			)
			requireChild(
				card,
				"BaseDamage",
				"TextLabel",
				errors,
				string.format("StarterGui/PopupsHUD/BlacksmithModal/Root/%s", cardName)
			)
			requireChild(
				card,
				"YourDamage",
				"TextLabel",
				errors,
				string.format("StarterGui/PopupsHUD/BlacksmithModal/Root/%s", cardName)
			)
			requireChild(
				card,
				"GoldBonus",
				"TextLabel",
				errors,
				string.format("StarterGui/PopupsHUD/BlacksmithModal/Root/%s", cardName)
			)
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

local function validateButtonTemplate(errors)
	local template = requireChild(ServerStorage, BUTTON_TEMPLATE_NAME, "Model", errors, "ServerStorage")

	if not template then
		return
	end

	requireChild(template, "Base", "BasePart", errors, string.format("ServerStorage/%s", BUTTON_TEMPLATE_NAME))
	requireChild(template, "Button", "BasePart", errors, string.format("ServerStorage/%s", BUTTON_TEMPLATE_NAME))

	local billboardGui = requireChild(
		template,
		"CostBillboard",
		"BillboardGui",
		errors,
		string.format("ServerStorage/%s", BUTTON_TEMPLATE_NAME)
	)

	if not billboardGui then
		return
	end

	requireChild(
		billboardGui,
		"CostLabel",
		"TextLabel",
		errors,
		string.format("ServerStorage/%s/CostBillboard", BUTTON_TEMPLATE_NAME)
	)
end

function StudioAssetValidator.validateOrThrow()
	local errors = {}

	validateAxeTemplates(errors)
	validateAxeDefaults(errors)
	validateAxeOverrides(errors)
	validateAmberShopGui(errors)
	validateAutoSwingGui(errors)
	validateBlacksmithGui(errors)
	validateBlacksmithSection(errors)
	validateRebirthGui(errors)
	validateTopGoldLabelGui(errors)
	validateTrees(errors)
	validateTreePlotSets(errors)
	validateTreePlotTemplate(errors)
	validateButtonTemplate(errors)
	validatePlotUpgradeGui(errors)
	validateNpcTemplates(errors)

	if #errors > 0 then
		error("Studio asset validation failed:\n- " .. table.concat(errors, "\n- "))
	end

	return true
end

return StudioAssetValidator
