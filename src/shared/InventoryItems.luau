--!strict

export type ItemRarity = "common" | "rare" | "epic" | "legendary"

export type ItemDefinition = {
	id: number,
	name: string,
	iconKey: string,
	rarity: ItemRarity,
}

local InventoryItems: { ItemDefinition } = {
	{ id = 1, name = "Health Potion", iconKey = "HealthPotion", rarity = "common" },
	{ id = 2, name = "Diamond Sword", iconKey = "DiamondSword", rarity = "legendary" },
	{ id = 3, name = "Shield", iconKey = "ShieldItem", rarity = "rare" },
	{ id = 4, name = "Speed Boost", iconKey = "SpeedBoost", rarity = "epic" },
	{ id = 5, name = "Armor", iconKey = "Armor", rarity = "epic" },
	{ id = 6, name = "Magic Staff", iconKey = "MagicStaff", rarity = "legendary" },
}

local DefaultStartingQuantities: { [number]: number } = {
	[1] = 5,
	[2] = 1,
	[3] = 2,
	[4] = 3,
	[5] = 1,
	[6] = 1,
}

return {
	Items = InventoryItems,
	DefaultStartingQuantities = DefaultStartingQuantities,
}
