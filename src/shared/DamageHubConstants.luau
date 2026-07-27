local DamageHubConstants = {}

DamageHubConstants.REMOTE_FOLDER_NAME = "Remotes"
DamageHubConstants.DAMAGE_HUB_REMOTE_FOLDER_NAME = "DamageHub"
DamageHubConstants.GET_STATE_REMOTE_NAME = "GetDamageHubState"

DamageHubConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	ConfigError = "configError",
	RequestFailed = "requestFailed",
}

DamageHubConstants.FailureMessage = {
	[DamageHubConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[DamageHubConstants.FailureReason.ConfigError] = "The Damage Hub is temporarily unavailable.",
	[DamageHubConstants.FailureReason.RequestFailed] = "Damage Hub request failed. Please try again.",
}

function DamageHubConstants.getFailureMessage(reason)
	return DamageHubConstants.FailureMessage[reason]
		or DamageHubConstants.FailureMessage[DamageHubConstants.FailureReason.RequestFailed]
end

return DamageHubConstants
