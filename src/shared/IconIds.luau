--!strict
--
-- Maps each UI icon to a `rbxassetid://` URL.
-- These default to the empty string (which renders nothing) until they are
-- replaced by `scripts/upload_assets.luau`. Once you've run that script,
-- the file is patched in-place with the real Open Cloud asset IDs.
--
-- The HUD code falls back to a unicode glyph (see `IconIds.Fallback`) when an
-- entry is empty so the UI is still readable in Studio before assets are uploaded.

local IconIds = {}

IconIds.Heart = ""
IconIds.Zap = ""
IconIds.Award = ""
IconIds.Coins = ""
IconIds.Star = ""
IconIds.Swords = ""
IconIds.Shield = ""
IconIds.Backpack = ""
IconIds.Map = ""
IconIds.Users = ""
IconIds.Settings = ""
IconIds.X = ""

-- Inventory item icons
IconIds.HealthPotion = ""
IconIds.DiamondSword = ""
IconIds.ShieldItem = ""
IconIds.SpeedBoost = ""
IconIds.Armor = ""
IconIds.MagicStaff = ""

-- Unicode fallbacks rendered in a TextLabel when the corresponding image is empty.
IconIds.Fallback = {
	Heart = "♥",
	Zap = "⚡",
	Award = "★",
	Coins = "$",
	Star = "✦",
	Swords = "⚔",
	Shield = "🛡",
	Backpack = "🎒",
	Map = "🗺",
	Users = "👥",
	Settings = "⚙",
	X = "✕",
	HealthPotion = "🧪",
	DiamondSword = "⚔",
	ShieldItem = "🛡",
	SpeedBoost = "⚡",
	Armor = "🥋",
	MagicStaff = "🪄",
}

return IconIds
