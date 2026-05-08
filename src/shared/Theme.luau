--!strict
-- Color palette + spacing constants matching the Figma design.
-- All colors are taken from Tailwind's default palette so we keep parity with
-- `RobloxGameUI.tsx` (the original Figma Make export).

local Theme = {}

-- Tailwind-equivalent colors (RGB 0-255).
Theme.Colors = {
	-- Backgrounds
	SkyBlue400 = Color3.fromRGB(56, 189, 248),
	Emerald400 = Color3.fromRGB(52, 211, 153),

	-- Status icon backgrounds
	Red500 = Color3.fromRGB(239, 68, 68),
	Red600 = Color3.fromRGB(220, 38, 38),
	Red700 = Color3.fromRGB(185, 28, 28),
	Red900 = Color3.fromRGB(127, 29, 29),

	Yellow400 = Color3.fromRGB(250, 204, 21),
	Yellow500 = Color3.fromRGB(234, 179, 8),
	Yellow900 = Color3.fromRGB(113, 63, 18),

	Purple400 = Color3.fromRGB(192, 132, 252),
	Purple500 = Color3.fromRGB(168, 85, 247),
	Purple600 = Color3.fromRGB(147, 51, 234),
	Purple700 = Color3.fromRGB(126, 34, 206),
	Purple900 = Color3.fromRGB(88, 28, 135),

	Cyan500 = Color3.fromRGB(6, 182, 212),

	Orange500 = Color3.fromRGB(249, 115, 22),
	Orange600 = Color3.fromRGB(234, 88, 12),
	Orange700 = Color3.fromRGB(194, 65, 12),

	Green500 = Color3.fromRGB(34, 197, 94),
	Green600 = Color3.fromRGB(22, 163, 74),
	Green700 = Color3.fromRGB(21, 128, 61),

	Blue400 = Color3.fromRGB(96, 165, 250),
	Blue500 = Color3.fromRGB(59, 130, 246),
	Blue600 = Color3.fromRGB(37, 99, 235),
	Blue700 = Color3.fromRGB(29, 78, 216),

	Gray400 = Color3.fromRGB(156, 163, 175),
	Gray500 = Color3.fromRGB(107, 114, 128),
	Gray600 = Color3.fromRGB(75, 85, 99),
	Gray700 = Color3.fromRGB(55, 65, 81),
	Gray800 = Color3.fromRGB(31, 41, 55),
	Gray900 = Color3.fromRGB(17, 24, 39),

	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),
}

Theme.Rarity = {
	common = {
		text = Theme.Colors.Gray400,
		border = Theme.Colors.Gray400,
		fill = Theme.Colors.Gray500,
	},
	rare = {
		text = Theme.Colors.Blue400,
		border = Theme.Colors.Blue400,
		fill = Theme.Colors.Blue500,
	},
	epic = {
		text = Theme.Colors.Purple400,
		border = Theme.Colors.Purple400,
		fill = Theme.Colors.Purple500,
	},
	legendary = {
		text = Theme.Colors.Yellow400,
		border = Theme.Colors.Yellow400,
		fill = Theme.Colors.Yellow500,
	},
}

Theme.Fonts = {
	Bold = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Regular = Enum.Font.Gotham,
}

Theme.Sizes = {
	HudPadding = 16,
	PanelHeight = 60,
	PanelCornerRadius = 12,
	BarHeight = 12,
	IconBox = 32,
	SideButton = 56,
	BigButton = 70,
}

return Theme
