local GoldHubConstants = {}

GoldHubConstants.REMOTE_FOLDER_NAME = "Remotes"
GoldHubConstants.GOLD_HUB_REMOTE_FOLDER_NAME = "GoldHub"
GoldHubConstants.GET_STATE_REMOTE_NAME = "GetGoldHubState"

GoldHubConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	ConfigError = "configError",
	RequestFailed = "requestFailed",
}

GoldHubConstants.FailureMessage = {
	[GoldHubConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[GoldHubConstants.FailureReason.ConfigError] = "The Gold Hub is temporarily unavailable.",
	[GoldHubConstants.FailureReason.RequestFailed] = "Gold Hub request failed. Please try again.",
}

function GoldHubConstants.getFailureMessage(reason)
	return GoldHubConstants.FailureMessage[reason]
		or GoldHubConstants.FailureMessage[GoldHubConstants.FailureReason.RequestFailed]
end

return GoldHubConstants
