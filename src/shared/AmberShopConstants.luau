local AmberShopConstants = {}

AmberShopConstants.REMOTE_FOLDER_NAME = "Remotes"
AmberShopConstants.AMBER_SHOP_REMOTE_FOLDER_NAME = "AmberShop"
AmberShopConstants.GET_STATE_REMOTE_NAME = "GetAmberShopState"
AmberShopConstants.BUY_UPGRADE_REMOTE_NAME = "BuyAmberUpgrade"
AmberShopConstants.PLAYER_AMBER_ATTRIBUTE_NAME = "Amber"
AmberShopConstants.PLAYER_AMBER_GAIN_LEVEL_ATTRIBUTE_NAME = "AmberGainLevel"

AmberShopConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	InvalidUpgrade = "invalidUpgrade",
	AlreadyMaxLevel = "alreadyMaxLevel",
	InsufficientAmber = "insufficientAmber",
	SaveFailed = "saveFailed",
	ConfigError = "configError",
	RequestFailed = "requestFailed",
}

AmberShopConstants.FailureMessage = {
	[AmberShopConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[AmberShopConstants.FailureReason.InvalidUpgrade] = "That Amber upgrade is not available.",
	[AmberShopConstants.FailureReason.AlreadyMaxLevel] = "That Amber upgrade is already max level.",
	[AmberShopConstants.FailureReason.InsufficientAmber] = "You do not have enough Amber for that upgrade.",
	[AmberShopConstants.FailureReason.SaveFailed] = "Your Amber upgrade could not be saved. Please try again.",
	[AmberShopConstants.FailureReason.ConfigError] = "The Amber shop is temporarily unavailable.",
	[AmberShopConstants.FailureReason.RequestFailed] = "Amber shop request failed. Please try again.",
}

function AmberShopConstants.getFailureMessage(reason)
	return AmberShopConstants.FailureMessage[reason]
		or AmberShopConstants.FailureMessage[AmberShopConstants.FailureReason.RequestFailed]
end

return AmberShopConstants
