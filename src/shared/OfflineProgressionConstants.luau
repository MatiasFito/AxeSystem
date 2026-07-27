local OfflineProgressionConstants = {}

OfflineProgressionConstants.REMOTE_FOLDER_NAME = "Remotes"
OfflineProgressionConstants.OFFLINE_PROGRESSION_REMOTE_FOLDER_NAME = "OfflineProgression"
OfflineProgressionConstants.GET_REWARD_REMOTE_NAME = "GetOfflineReward"
OfflineProgressionConstants.CLAIM_REWARD_REMOTE_NAME = "ClaimOfflineReward"
OfflineProgressionConstants.DOUBLE_PURCHASED_REMOTE_NAME = "DoublePurchaseProcessed"

OfflineProgressionConstants.DEVELOPER_PRODUCT_ID = 3610068577

OfflineProgressionConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	ConfigError = "configError",
	RequestFailed = "requestFailed",
	NoPendingReward = "noPendingReward",
}

OfflineProgressionConstants.FailureMessage = {
	[OfflineProgressionConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[OfflineProgressionConstants.FailureReason.ConfigError] = "Offline rewards are temporarily unavailable.",
	[OfflineProgressionConstants.FailureReason.RequestFailed] = "Offline reward request failed. Please try again.",
	[OfflineProgressionConstants.FailureReason.NoPendingReward] = "No pending offline reward found.",
}

function OfflineProgressionConstants.getFailureMessage(reason)
	return OfflineProgressionConstants.FailureMessage[reason]
		or OfflineProgressionConstants.FailureMessage[OfflineProgressionConstants.FailureReason.RequestFailed]
end

return OfflineProgressionConstants
