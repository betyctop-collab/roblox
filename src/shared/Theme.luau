--!strict
local Theme = {}

Theme.Colors = {
	-- Surfaces
	Background = Color3.fromRGB(11, 17, 28),
	Surface = Color3.fromRGB(20, 28, 44),
	SurfaceAlt = Color3.fromRGB(28, 38, 58),
	Border = Color3.fromRGB(54, 70, 102),

	-- Accents (Tailwind-derived)
	SkyBlue400 = Color3.fromRGB(56, 189, 248),
	Emerald400 = Color3.fromRGB(52, 211, 153),
	Red500 = Color3.fromRGB(239, 68, 68),
	Yellow400 = Color3.fromRGB(250, 204, 21),
	Purple400 = Color3.fromRGB(168, 85, 247),
	Cyan500 = Color3.fromRGB(6, 182, 212),
	Orange500 = Color3.fromRGB(249, 115, 22),
	Green500 = Color3.fromRGB(34, 197, 94),
	Pink500 = Color3.fromRGB(236, 72, 153),
	Blue400 = Color3.fromRGB(96, 165, 250),
	Gray400 = Color3.fromRGB(156, 163, 175),

	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(0, 0, 0),
	Muted = Color3.fromRGB(140, 152, 178),
}

Theme.Fonts = {
	Bold = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Regular = Enum.Font.Gotham,
}

Theme.Sizes = {
	HudPadding = 16,
	StatPanelHeight = 60,
	PanelCornerRadius = 12,
	BarHeight = 10,
	IconBox = 32,
	SideButton = 56,
	BigButton = 80,
}

Theme.RollBannerHeight = 96

return Theme
