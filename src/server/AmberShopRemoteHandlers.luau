local AmberShopRemoteHandlers = {}

function AmberShopRemoteHandlers.create(deps)
	local function handleGetState(player)
		return deps.getState(player)
	end

	local function handleBuyUpgrade(player, upgradeName)
		return deps.buyUpgrade(player, upgradeName)
	end

	return {
		handleGetState = handleGetState,
		handleBuyUpgrade = handleBuyUpgrade,
	}
end

function AmberShopRemoteHandlers.bind(remotes, handlers)
	remotes.GetAmberShopStateRemote.OnServerInvoke = handlers.handleGetState
	remotes.BuyAmberUpgradeRemote.OnServerInvoke = handlers.handleBuyUpgrade
end

return AmberShopRemoteHandlers
