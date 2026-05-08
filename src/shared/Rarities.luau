--!strict
--
-- Defines the eight rarity tiers used by the RNG roll system.
--
-- `OneIn` is the nominal "1 / N" chance shown to players. Real probabilities
-- emerge from the cascading roll in RollService (rarest tier checked first).
-- `BannerColor` and `GlowColor` drive HUD presentation, while `ServerWideAnnounce`
-- toggles the server-wide announcement banner for top tiers.

export type Rarity = {
	Id: number,
	Key: string,
	Name: string,
	OneIn: number,
	Reward: number,
	BannerColor: Color3,
	GlowColor: Color3,
	ServerWideAnnounce: boolean,
}

local function tier(
	id: number,
	key: string,
	name: string,
	oneIn: number,
	reward: number,
	r: number,
	g: number,
	b: number,
	announce: boolean
): Rarity
	local color = Color3.fromRGB(r, g, b)
	return {
		Id = id,
		Key = key,
		Name = name,
		OneIn = oneIn,
		Reward = reward,
		BannerColor = color,
		GlowColor = color,
		ServerWideAnnounce = announce,
	}
end

local Rarities = {}

Rarities.Common = tier(1, "Common", "Common", 2, 1, 156, 163, 175, false)
Rarities.Uncommon = tier(2, "Uncommon", "Uncommon", 8, 2, 134, 239, 172, false)
Rarities.Rare = tier(3, "Rare", "Rare", 40, 5, 96, 165, 250, false)
Rarities.Epic = tier(4, "Epic", "Epic", 200, 15, 168, 85, 247, false)
Rarities.Legendary = tier(5, "Legendary", "Legendary", 1000, 50, 250, 204, 21, false)
Rarities.Mythic = tier(6, "Mythic", "Mythic", 10000, 200, 239, 68, 68, true)
Rarities.Divine = tier(7, "Divine", "Divine", 100000, 1000, 236, 72, 153, true)
Rarities.Celestial = tier(8, "Celestial", "Celestial", 1000000, 5000, 56, 189, 248, true)

-- Iteration order from rarest to most common. The roll routine walks this
-- list and short-circuits the first time it succeeds.
Rarities.OrderRarestFirst = {
	Rarities.Celestial,
	Rarities.Divine,
	Rarities.Mythic,
	Rarities.Legendary,
	Rarities.Epic,
	Rarities.Rare,
	Rarities.Uncommon,
	Rarities.Common,
}

-- Iteration order from common to rare for UI display.
Rarities.OrderCommonFirst = {
	Rarities.Common,
	Rarities.Uncommon,
	Rarities.Rare,
	Rarities.Epic,
	Rarities.Legendary,
	Rarities.Mythic,
	Rarities.Divine,
	Rarities.Celestial,
}

Rarities.ByKey = {} :: { [string]: Rarity }
Rarities.ById = {} :: { [number]: Rarity }
for _, t in Rarities.OrderRarestFirst do
	Rarities.ByKey[t.Key] = t
	Rarities.ById[t.Id] = t
end

return Rarities
