local BlacksmithConstants = {}

BlacksmithConstants.CURRENT_SCHEMA_VERSION = 1
BlacksmithConstants.DATASTORE_NAME = "PlayerProgressionV1"
BlacksmithConstants.DATASTORE_KEY_PREFIX = "player:"

BlacksmithConstants.DEFAULT_AXE_TIER_ID = "WoodAxe"
BlacksmithConstants.AXE_TEMPLATE_FOLDER_NAME = "AxeTemplates"
BlacksmithConstants.BLACKSMITH_SECTION_TEMPLATE_NAME = "BlacksmithSection"
BlacksmithConstants.BLACKSMITH_SECTION_MODEL_NAME = "BlacksmithSection"
BlacksmithConstants.BLACKSMITH_PART_NAME = "AxeUpgrades"
BlacksmithConstants.BLACKSMITH_FLOOR_NAME = "BlacksmithFloor"
BlacksmithConstants.BLACKSMITH_NPC_NAME = "Blacksmith"
BlacksmithConstants.BLACKSMITH_TARGET_PLOT_ID = "Plot03"
BlacksmithConstants.BLACKSMITH_FORWARD_OFFSET = 15
BlacksmithConstants.IS_AXE_TOOL_ATTRIBUTE = "IsAxeTool"
BlacksmithConstants.AXE_TIER_ID_ATTRIBUTE = "AxeTierId"
BlacksmithConstants.SWING_SPEED_ATTRIBUTE_NAME = "SelectedSwingSpeed"
BlacksmithConstants.DEFAULT_SWING_SPEED = 1
BlacksmithConstants.MIN_SWING_SPEED = 1
BlacksmithConstants.MAX_SWING_SPEED = 5

BlacksmithConstants.REMOTE_FOLDER_NAME = "Remotes"
BlacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME = "Blacksmith"
BlacksmithConstants.GET_STATE_REMOTE_NAME = "GetBlacksmithState"
BlacksmithConstants.REQUEST_UPGRADE_REMOTE_NAME = "RequestAxeUpgrade"
BlacksmithConstants.REQUEST_SWING_SPEED_REMOTE_NAME = "RequestSwingSpeed"

BlacksmithConstants.FailureReason = {
	NotInRange = "notInRange",
	InsufficientGold = "insufficientGold",
	InvalidTier = "invalidTier",
	AlreadyMaxed = "alreadyMaxed",
	DataNotLoaded = "dataNotLoaded",
	ConfigError = "configError",
	ShopUnavailable = "shopUnavailable",
}

BlacksmithConstants.FailureMessage = {
	[BlacksmithConstants.FailureReason.NotInRange] = "Stand on the blacksmith platform to upgrade your axe.",
	[BlacksmithConstants.FailureReason.InsufficientGold] = "You need more Gold to buy this axe.",
	[BlacksmithConstants.FailureReason.InvalidTier] = "That upgrade is not available right now.",
	[BlacksmithConstants.FailureReason.AlreadyMaxed] = "You already own the best available axe.",
	[BlacksmithConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[BlacksmithConstants.FailureReason.ConfigError] = "The shop is temporarily unavailable. Please try again soon.",
	[BlacksmithConstants.FailureReason.ShopUnavailable] = "The blacksmith is unavailable right now.",
}

function BlacksmithConstants.getFailureMessage(reason)
	return BlacksmithConstants.FailureMessage[reason] or "Upgrade failed. Please try again."
end

return BlacksmithConstants
