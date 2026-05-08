--!strict
--
-- Maps each UI icon to a `rbxassetid://` URL.
-- Filled by `scripts/upload_assets.luau`. Until that runs, entries default to
-- empty strings and the HUD falls back to a unicode glyph.

local IconIds = {}

IconIds.Coins = ""
IconIds.Star = ""
IconIds.Award = ""
IconIds.Swords = ""
IconIds.Backpack = ""
IconIds.Settings = ""
IconIds.X = ""
IconIds.Zap = ""
IconIds.Users = ""
IconIds.Dice = ""
IconIds.Lock = ""
IconIds.Sparkles = ""

-- Item icons (each katana shares the same DiamondSword silhouette;
-- rarity is conveyed via tint and frame colour at the HUD level).
IconIds.DiamondSword = ""

IconIds.Fallback = {
	Coins = "$",
	Star = "★",
	Award = "🏆",
	Swords = "⚔",
	Backpack = "🎒",
	Settings = "⚙",
	X = "✕",
	Zap = "⚡",
	Users = "👥",
	Dice = "🎲",
	Lock = "🔒",
	Sparkles = "✨",
	DiamondSword = "🗡",
}

return IconIds
