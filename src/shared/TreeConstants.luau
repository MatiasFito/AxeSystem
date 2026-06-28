local TreeConstants = {}

TreeConstants.CURRENT_SCHEMA_VERSION = 3

TreeConstants.TREE_TEMPLATE_FOLDER_NAME = "Trees"
TreeConstants.TREE_PLOT_SETS_FOLDER_NAME = "TreePlotSets"
TreeConstants.TREE_RUNTIME_FOLDER_NAME = "TreeRuntime"
TreeConstants.TREE_PLOT_TEMPLATE_NAME = "TreePlotTemplate"
TreeConstants.TREE_PLOT_GENERATED_FOLDER_NAME = "GeneratedPlots"

TreeConstants.PLOT_MODEL_NAME = "TreePlot"
TreeConstants.PLOT_SET_ORIGIN_NAME = "PlotOrigin"
TreeConstants.DIRT_PATCH_NAME = "DirtPatch"
TreeConstants.TREE_SPAWN_NAME = "TreeSpawn"

TreeConstants.PLOT_ID_ATTRIBUTE = "PlotId"
TreeConstants.PLOT_ORDER_ATTRIBUTE = "PlotOrder"
TreeConstants.PLOT_SET_ID_ATTRIBUTE = "PlotSetId"
TreeConstants.TREE_ID_ATTRIBUTE = "TreeId"
TreeConstants.TREE_PLOT_ID_ATTRIBUTE = "TreePlotId"
TreeConstants.IS_MANAGED_TREE_ATTRIBUTE = "IsManagedTree"

TreeConstants.REMOTE_FOLDER_NAME = "Remotes"
TreeConstants.TREE_REMOTE_FOLDER_NAME = "Trees"
TreeConstants.GET_STATE_REMOTE_NAME = "GetTreeState"
TreeConstants.REQUEST_HIT_REMOTE_NAME = "RequestTreeHit"
TreeConstants.REQUEST_UPGRADE_REMOTE_NAME = "RequestTreeUpgrade"
TreeConstants.REQUEST_LUMBERJACK_UPGRADE_REMOTE_NAME = "RequestLumberjackUpgrade"
TreeConstants.STATE_UPDATED_REMOTE_NAME = "TreeStateUpdated"
TreeConstants.HIT_FEEDBACK_REMOTE_NAME = "TreeHitFeedback"
TreeConstants.HIT_DISTANCE = 16

TreeConstants.PlotState = {
	Locked = "Locked",
	Growing = "Growing",
	Grown = "Grown",
}

TreeConstants.FailureReason = {
	DataNotLoaded = "dataNotLoaded",
	PlotNotFound = "plotNotFound",
	NotOwned = "notOwned",
	NotUnlockable = "notUnlockable",
	AlreadyUnlocked = "alreadyUnlocked",
	AlreadyHired = "alreadyHired",
	AlreadyMaxed = "alreadyMaxed",
	InsufficientGold = "insufficientGold",
	NotHired = "notHired",
	NotReady = "notReady",
	InvalidHit = "invalidHit",
	NotInRange = "notInRange",
	ConfigError = "configError",
}

TreeConstants.FailureMessage = {
	[TreeConstants.FailureReason.DataNotLoaded] = "Your data is still loading. Try again in a moment.",
	[TreeConstants.FailureReason.PlotNotFound] = "That tree plot is unavailable right now.",
	[TreeConstants.FailureReason.NotOwned] = "You cannot interact with that tree plot.",
	[TreeConstants.FailureReason.NotUnlockable] = "Unlock the previous tree plot first.",
	[TreeConstants.FailureReason.AlreadyUnlocked] = "That tree plot is already unlocked.",
	[TreeConstants.FailureReason.AlreadyHired] = "That plot already has a Lumberjack.",
	[TreeConstants.FailureReason.AlreadyMaxed] = "That tree is already at the highest level.",
	[TreeConstants.FailureReason.InsufficientGold] = "You need more Gold for that tree upgrade.",
	[TreeConstants.FailureReason.NotHired] = "Hire a Lumberjack on that plot first.",
	[TreeConstants.FailureReason.NotReady] = "That tree is still growing.",
	[TreeConstants.FailureReason.InvalidHit] = "That hit did not count.",
	[TreeConstants.FailureReason.NotInRange] = "Move closer to interact with that tree.",
	[TreeConstants.FailureReason.ConfigError] = "The tree system is temporarily unavailable.",
}

function TreeConstants.getFailureMessage(reason)
	return TreeConstants.FailureMessage[reason] or "Tree action failed. Please try again."
end

return TreeConstants
