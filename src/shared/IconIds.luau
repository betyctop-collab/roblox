--!strict
--
-- Maps each UI icon to a renderable Roblox content URL.
--
-- We upload PNGs through Open Cloud as `Decal` assets. `ImageLabel.Image`
-- does not always resolve a Decal asset id to its underlying image (the
-- known Open Cloud v1 limitation), so we wrap each asset id in an
-- `rbxthumb://` URL. Roblox renders the asset thumbnail directly for any
-- moderated asset, regardless of Decal vs Image.

local function thumb(id: number | string): string
	return string.format("rbxthumb://type=Asset&id=%s&w=150&h=150", tostring(id))
end

local IconIds = {}

IconIds.Coins = thumb(129821412159941)
IconIds.Star = thumb(78272383498199)
IconIds.Award = thumb(137168226945155)
IconIds.Swords = thumb(117853458456059)
IconIds.Backpack = thumb(130041043029819)
IconIds.Settings = thumb(132313126833268)
IconIds.X = thumb(101630352653283)
IconIds.Zap = thumb(108322398259982)
IconIds.Users = thumb(76803702792254)
IconIds.Dice = thumb(139215674289272)
IconIds.Lock = thumb(76095830145333)
IconIds.Sparkles = thumb(93854979309880)

IconIds.DiamondSword = thumb(131744572864689)

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
