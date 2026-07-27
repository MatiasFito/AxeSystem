local WishingTreeConstants = {}

WishingTreeConstants.WISHING_TREE_SECTION_MODEL_NAME = "WishingTreeSection"
WishingTreeConstants.WISHING_TREE_TOUCH_AREA_NAME = "TouchArea"
WishingTreeConstants.REMOTE_FOLDER_NAME = "Remotes"
WishingTreeConstants.WISHING_TREE_REMOTE_FOLDER_NAME = "WishingTree"
WishingTreeConstants.ROLL_BLESSING_REMOTE_NAME = "RollBlessing"

WishingTreeConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	ConfigError = "configError",
	RequestFailed = "requestFailed",
}

WishingTreeConstants.FailureMessage = {
	[WishingTreeConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[WishingTreeConstants.FailureReason.ConfigError] = "The Wishing Tree is temporarily unavailable.",
	[WishingTreeConstants.FailureReason.RequestFailed] = "Wishing Tree request failed. Please try again.",
}

function WishingTreeConstants.getFailureMessage(reason)
	return WishingTreeConstants.FailureMessage[reason]
		or WishingTreeConstants.FailureMessage[WishingTreeConstants.FailureReason.RequestFailed]
end

return WishingTreeConstants
