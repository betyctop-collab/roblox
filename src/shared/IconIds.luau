--!strict
--
-- Maps each UI icon to a `rbxassetid://` URL.
-- Filled by `scripts/upload_assets.luau`. Until that runs, entries default to
-- empty strings and the HUD falls back to a unicode glyph.

local IconIds = {}

IconIds.Coins = "rbxassetid://129821412159941"
IconIds.Star = "rbxassetid://78272383498199"
IconIds.Award = "rbxassetid://137168226945155"
IconIds.Swords = "rbxassetid://117853458456059"
IconIds.Backpack = "rbxassetid://130041043029819"
IconIds.Settings = "rbxassetid://132313126833268"
IconIds.X = "rbxassetid://101630352653283"
IconIds.Zap = "rbxassetid://108322398259982"
IconIds.Users = "rbxassetid://76803702792254"
IconIds.Dice = "rbxassetid://139215674289272"
IconIds.Lock = "rbxassetid://76095830145333"
IconIds.Sparkles = "rbxassetid://93854979309880"

-- Item icons (each katana shares the same DiamondSword silhouette;
-- rarity is conveyed via tint and frame colour at the HUD level).
IconIds.DiamondSword = "rbxassetid://131744572864689"

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
