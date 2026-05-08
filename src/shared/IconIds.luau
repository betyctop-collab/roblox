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

IconIds.Heart = "rbxassetid://100050331024442"
IconIds.Zap = "rbxassetid://83260526994918"
IconIds.Award = "rbxassetid://106257585162158"
IconIds.Coins = "rbxassetid://119925823047107"
IconIds.Star = "rbxassetid://131001814361490"
IconIds.Swords = "rbxassetid://85866097063189"
IconIds.Shield = "rbxassetid://103180364659837"
IconIds.Backpack = "rbxassetid://111881241745536"
IconIds.Map = "rbxassetid://78428377303513"
IconIds.Users = "rbxassetid://110376501888217"
IconIds.Settings = "rbxassetid://101099430344718"
IconIds.X = "rbxassetid://124066249057535"

-- Inventory item icons
IconIds.HealthPotion = "rbxassetid://83372162956829"
IconIds.DiamondSword = "rbxassetid://122658320298929"
IconIds.ShieldItem = "rbxassetid://107563413419058"
IconIds.SpeedBoost = "rbxassetid://92629595264558"
IconIds.Armor = "rbxassetid://87109257902884"
IconIds.MagicStaff = "rbxassetid://77413335266651"

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
