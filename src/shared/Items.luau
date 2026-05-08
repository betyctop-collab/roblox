--!strict
--
-- Anime-katana item catalogue. Each item belongs to exactly one rarity tier
-- and is what RollService awards when that tier wins a roll.

local Rarities = require(script.Parent.Rarities)

export type Item = {
	Id: number,
	Name: string,
	RarityKey: string,
	Lore: string,
}

local function item(id: number, name: string, rarityKey: string, lore: string): Item
	assert(Rarities.ByKey[rarityKey], `unknown rarity {rarityKey}`)
	return {
		Id = id,
		Name = name,
		RarityKey = rarityKey,
		Lore = lore,
	}
end

local Items = {}

-- The full catalogue. Order matters for the Index UI.
Items.All = {
	-- Common (1/2)
	item(1, "Wooden Bokken", "Common", "Stiff oak. Hurts your wrist more than your foes."),
	item(2, "Bamboo Stick", "Common", "Snaps in a single duel. The dojo charges 50 yen each."),
	item(3, "Practice Sword", "Common", "Dull edge. Polished by countless apprentices."),

	-- Uncommon (1/8)
	item(
		4,
		"Steel Katana",
		"Uncommon",
		"A reliable workhorse. The smith's signature is half-rubbed."
	),
	item(5, "Iron Wakizashi", "Uncommon", "Short, fast, and unflattering."),
	item(
		6,
		"Apprentice Blade",
		"Uncommon",
		"Comes with a 'Beginner-Friendly' tag the master forgot to remove."
	),

	-- Rare (1/40)
	item(7, "Crimson Edge", "Rare", "Quenched in plum wine. Rumored to bite cleaner when angry."),
	item(
		8,
		"Forest Whisper",
		"Rare",
		"Carved from a thousand-year cedar. The wind warns its enemies."
	),
	item(9, "Azure Tide", "Rare", "Wave-shaped damascus. Rings like a temple bell."),

	-- Epic (1/200)
	item(
		10,
		"Demon Slayer",
		"Epic",
		"Sutra-etched blade. Sealed shrine ghosts dislike its proximity."
	),
	item(11, "Spirit Reaper", "Epic", "Cuts the air a moment before its swing. Whispers names."),
	item(12, "Moonlight Bringer", "Epic", "Reflects no torchlight, only the moon."),

	-- Legendary (1/1,000)
	item(
		13,
		"Dragon's Roar",
		"Legendary",
		"Forged inside a stormcloud. Distant thunder follows you."
	),
	item(14, "Phoenix Flame", "Legendary", "Ash-tempered. Re-ignites when sheathed in starlight."),
	item(15, "Thunder Strike", "Legendary", "Each cut leaves a faint ozone perfume."),

	-- Mythic (1/10,000)
	item(16, "Yoru", "Mythic", "Pitch-black sentience. Refuses lesser duels."),
	item(17, "Tenseiga", "Mythic", "A sword that does not cut. It returns what was taken."),
	item(18, "Murasame", "Mythic", "Drinks rain. Demands a drop of blood per dawn."),

	-- Divine (1/100,000)
	item(
		19,
		"Excalibur",
		"Divine",
		"Rejected by every hand but yours. The lake whispers congratulations."
	),
	item(20, "Masamune", "Divine", "Refuses to harm the innocent. The blade will know."),
	item(21, "Muramasa", "Divine", "Eager. Restless. Pretend you don't hear it humming."),

	-- Celestial (1/1,000,000)
	item(22, "Susanoo", "Celestial", "A storm given a sheath. Sea-foam runs along the edge."),
	item(23, "Amaterasu", "Celestial", "Casts no shadow at noon. The handle is warm to the touch."),
	item(
		24,
		"Tsukuyomi",
		"Celestial",
		"Steals one hour of moonlight per swing. Returns it interest-free."
	),
} :: { Item }

Items.ById = {} :: { [number]: Item }
for _, it in Items.All do
	Items.ById[it.Id] = it
end

-- Items grouped by rarity key for quick lookup when a tier rolls.
Items.ByRarity = {} :: { [string]: { Item } }
for _, it in Items.All do
	local list = Items.ByRarity[it.RarityKey]
	if not list then
		list = {}
		Items.ByRarity[it.RarityKey] = list
	end
	table.insert(list, it)
end

return Items
