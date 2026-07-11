local AmberShopPurchaseResolver = {}

function AmberShopPurchaseResolver.create(deps)
	local function buildFailure(player, reason)
		return deps.buildFailure(reason, deps.buildState(player))
	end

	local function handlePurchase(player, upgradeName)
		if not deps.isPlayerLoaded(player) then
			return deps.buildFailure(deps.failureReasons.DataNotLoaded)
		end

		local currentLevel = deps.getAmberUpgradeLevel(player, upgradeName)

		if currentLevel == nil then
			return buildFailure(player, deps.failureReasons.InvalidUpgrade)
		end

		local upgradeStats = deps.getUpgradeStats(upgradeName, currentLevel)

		if not upgradeStats then
			return buildFailure(player, deps.failureReasons.InvalidUpgrade)
		end

		if upgradeStats.isMaxLevel then
			return buildFailure(player, deps.failureReasons.AlreadyMaxLevel)
		end

		local amber = deps.getAmber(player) or 0
		local upgradeCost = upgradeStats.costToNextLevel

		if typeof(upgradeCost) ~= "number" then
			return buildFailure(player, deps.failureReasons.ConfigError)
		end

		if amber < upgradeCost then
			return buildFailure(player, deps.failureReasons.InsufficientAmber)
		end

		local newLevel = currentLevel + 1

		if not deps.setAmber(player, amber - upgradeCost) then
			return buildFailure(player, deps.failureReasons.SaveFailed)
		end

		if not deps.setAmberUpgradeLevel(player, upgradeName, newLevel) then
			deps.setAmber(player, amber)
			return buildFailure(player, deps.failureReasons.SaveFailed)
		end

		if not deps.savePlayer(player) then
			deps.setAmberUpgradeLevel(player, upgradeName, currentLevel)
			deps.setAmber(player, amber)
			return buildFailure(player, deps.failureReasons.SaveFailed)
		end

		if deps.applyPurchasedUpgrade then
			deps.applyPurchasedUpgrade(player, upgradeName)
		end

		local updatedState = deps.buildState(player)

		return deps.buildSuccess(updatedState, {
			purchase = {
				upgradeName = upgradeName,
				costPaid = upgradeCost,
				newLevel = newLevel,
				amberAfter = updatedState.amber,
			},
		})
	end

	return {
		handlePurchase = handlePurchase,
	}
end

return AmberShopPurchaseResolver
