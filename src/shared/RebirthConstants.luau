local RebirthConstants = {}

RebirthConstants.REMOTE_FOLDER_NAME = "Remotes"
RebirthConstants.REBIRTH_REMOTE_FOLDER_NAME = "Rebirth"
RebirthConstants.GET_STATE_REMOTE_NAME = "GetRebirthState"
RebirthConstants.REQUEST_REMOTE_NAME = "RebirthRequest"

RebirthConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	InsufficientProgress = "insufficientProgress",
	SaveFailed = "saveFailed",
	ConfigError = "configError",
	RequestFailed = "requestFailed",
}

RebirthConstants.FailureMessage = {
	[RebirthConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[RebirthConstants.FailureReason.InsufficientProgress] = "Reach Plot 10 before rebirthing.",
	[RebirthConstants.FailureReason.SaveFailed] = "Your rebirth could not be saved. Please try again.",
	[RebirthConstants.FailureReason.ConfigError] = "The rebirth system is temporarily unavailable.",
	[RebirthConstants.FailureReason.RequestFailed] = "Rebirth failed. Please try again.",
}

function RebirthConstants.getFailureMessage(reason)
	return RebirthConstants.FailureMessage[reason]
		or RebirthConstants.FailureMessage[RebirthConstants.FailureReason.RequestFailed]
end

return RebirthConstants
