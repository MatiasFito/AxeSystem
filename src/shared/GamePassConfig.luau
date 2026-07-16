local GamePassConfig = {}

GamePassConfig.Benefit = {
	Gold = "Gold",
	Damage = "Damage",
	MovementSpeed = "MovementSpeed",
	SwingSpeed = "SwingSpeed",
}

GamePassConfig.Pass = {
	DoubleSwingSpeed = "DoubleSwingSpeed",
	DoubleGold = "DoubleGold",
	DoubleDamage = "DoubleDamage",
	DoubleMovementSpeed = "DoubleMovementSpeed",
	VIP = "VIP",
}

local passKeys = {
	GamePassConfig.Pass.DoubleSwingSpeed,
	GamePassConfig.Pass.DoubleGold,
	GamePassConfig.Pass.DoubleDamage,
	GamePassConfig.Pass.DoubleMovementSpeed,
	GamePassConfig.Pass.VIP,
}

local passDefinitions = {
	[GamePassConfig.Pass.DoubleSwingSpeed] = {
		Id = 1910891025,
		Benefits = {
			[GamePassConfig.Benefit.SwingSpeed] = 2,
		},
	},
	[GamePassConfig.Pass.DoubleGold] = {
		Id = 1911515053,
		Benefits = {
			[GamePassConfig.Benefit.Gold] = 2,
		},
	},
	[GamePassConfig.Pass.DoubleDamage] = {
		Id = 1913132702,
		Benefits = {
			[GamePassConfig.Benefit.Damage] = 2,
		},
	},
	[GamePassConfig.Pass.DoubleMovementSpeed] = {
		Id = 1912055020,
		Benefits = {
			[GamePassConfig.Benefit.MovementSpeed] = 2,
		},
	},
	[GamePassConfig.Pass.VIP] = {
		Id = 1912115047,
		Benefits = {
			[GamePassConfig.Benefit.Gold] = 2,
			[GamePassConfig.Benefit.Damage] = 2,
			[GamePassConfig.Benefit.MovementSpeed] = 2,
			[GamePassConfig.Benefit.SwingSpeed] = 2,
		},
	},
}

local studioOwnedPasses = {}

function GamePassConfig.getPassKeys()
	return table.clone(passKeys)
end

function GamePassConfig.getPassDefinition(passKey)
	local definition = passDefinitions[passKey]

	if not definition then
		return nil
	end

	return {
		Id = definition.Id,
		Benefits = table.clone(definition.Benefits),
	}
end

function GamePassConfig.getPassId(passKey)
	local definition = passDefinitions[passKey]
	return definition and definition.Id or nil
end

function GamePassConfig.normalizeOwnedPasses(ownedPasses)
	local normalizedOwnedPasses = {}

	for _, passKey in ipairs(passKeys) do
		normalizedOwnedPasses[passKey] = typeof(ownedPasses) == "table" and ownedPasses[passKey] == true or false
	end

	return normalizedOwnedPasses
end

function GamePassConfig.getStudioOwnedPasses()
	return GamePassConfig.normalizeOwnedPasses(studioOwnedPasses)
end

function GamePassConfig.getBenefitMultiplier(ownedPasses, benefitKey)
	if typeof(benefitKey) ~= "string" then
		return 1
	end

	local normalizedOwnedPasses = GamePassConfig.normalizeOwnedPasses(ownedPasses)
	local multiplier = 1

	for _, passKey in ipairs(passKeys) do
		local definition = passDefinitions[passKey]
		local benefitMultiplier = definition and definition.Benefits[benefitKey] or nil

		if normalizedOwnedPasses[passKey] and typeof(benefitMultiplier) == "number" and benefitMultiplier > 0 then
			multiplier *= benefitMultiplier
		end
	end

	return multiplier
end

return GamePassConfig
