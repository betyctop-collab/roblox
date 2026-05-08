--!strict
--
-- Builds the in-game HUD ScreenGui to match the Figma "Roblox Game UI" design.
-- All visual constants live in `Theme.luau`. All icon asset IDs live in
-- `IconIds.luau`. State is driven by the `RemoteEvents.StateChanged` event
-- pushed from the server, plus a few client-only flags (modal visibility).
--
-- The module returns a single `HUD.new(player)` constructor that returns an
-- object with `:SetState(state)` to push new server data into the UI and
-- `:Destroy()` to tear it down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local IconIds = require(Shared:WaitForChild("IconIds"))
local InventoryItems = require(Shared:WaitForChild("InventoryItems"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

export type PlayerState = {
	Health: number,
	MaxHealth: number,
	Energy: number,
	MaxEnergy: number,
	Level: number,
	XP: number,
	XPToNext: number,
	Coins: number,
	Gems: number,
	Inventory: { [number]: number },
}

local HUD = {}
HUD.__index = HUD

-- ------------------------------------------------------------------ helpers --

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent: Instance, all: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
	return p
end

local function listLayout(
	parent: Instance,
	direction: Enum.FillDirection,
	spacing: number,
	align: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = UDim.new(0, spacing)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = valign or Enum.VerticalAlignment.Top
	l.Parent = parent
	return l
end

local function gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- An ImageLabel that falls back to a TextLabel glyph when the asset id is empty.
local function iconImage(parent: Instance, key: string, size: number, color: Color3): GuiObject
	local assetId = IconIds[key]
	if typeof(assetId) == "string" and assetId ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = key
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(size, size)
		img.Image = assetId
		img.ImageColor3 = color
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = parent
		return img
	end
	local label = Instance.new("TextLabel")
	label.Name = key
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(size, size)
	label.Text = IconIds.Fallback[key] or "?"
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Theme.Fonts.Bold
	label.RichText = false
	label.Parent = parent
	return label
end

-- A tinted square containing a centered icon.
local function iconBadge(parent: Instance, key: string, bg: Color3, boxSize: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(boxSize, boxSize)
	f.BackgroundColor3 = bg
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, 8)
	local pad = math.floor(boxSize * 0.18)
	local inner = iconImage(f, key, boxSize - pad * 2, Theme.Colors.White)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	return f
end

local function tweenTo(obj: Instance, time: number, props: { [string]: any })
	local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(obj, info, props):Play()
end

-- A status bar (background frame + fill frame). Returns the fill so the caller
-- can resize it as the value changes.
local function progressBar(
	parent: Instance,
	fillColor: Color3,
	bgColor: Color3,
	height: number
): (Frame, Frame)
	local bg = Instance.new("Frame")
	bg.Name = "Bar"
	bg.BackgroundColor3 = bgColor
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	bg.Size = UDim2.new(1, 0, 0, height)
	bg.Parent = parent
	corner(bg, math.floor(height / 2))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg
	corner(fill, math.floor(height / 2))

	return bg, fill
end

-- "Status" panel: a horizontal pill with an icon badge + label + value + progress bar.
type StatusPanel = {
	Frame: Frame,
	Label: TextLabel,
	Value: TextLabel,
	Fill: Frame,
}

local function statusPanel(
	parent: Instance,
	iconKey: string,
	iconBg: Color3,
	barColor: Color3,
	barBg: Color3,
	labelText: string
): StatusPanel
	local panel = Instance.new("Frame")
	panel.Name = labelText .. "Panel"
	panel.Size = UDim2.fromOffset(320, 64)
	panel.BackgroundColor3 = Theme.Colors.Black
	panel.BackgroundTransparency = 0.4
	panel.BorderSizePixel = 0
	panel.Parent = parent
	corner(panel, Theme.Sizes.PanelCornerRadius)
	stroke(panel, Theme.Colors.White, 2).Transparency = 0.8

	local pad = padding(panel, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = panel
	listLayout(
		row,
		Enum.FillDirection.Horizontal,
		10,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)

	local badge = iconBadge(row, iconKey, iconBg, 36)
	badge.LayoutOrder = 1

	local right = Instance.new("Frame")
	right.LayoutOrder = 2
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(1, -46, 1, 0)
	right.Parent = row

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0.5, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Bold
	label.Text = labelText
	label.TextColor3 = Theme.Colors.White
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = right

	local value = Instance.new("TextLabel")
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, 0, 0, 0)
	value.Size = UDim2.new(0.5, 0, 0, 18)
	value.BackgroundTransparency = 1
	value.Font = Theme.Fonts.Bold
	value.Text = "0/0"
	value.TextColor3 = Theme.Colors.White
	value.TextSize = 14
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextYAlignment = Enum.TextYAlignment.Center
	value.Parent = right

	local barHolder = Instance.new("Frame")
	barHolder.Position = UDim2.new(0, 0, 0, 24)
	barHolder.Size = UDim2.new(1, 0, 0, 12)
	barHolder.BackgroundTransparency = 1
	barHolder.Parent = right
	local _, fill = progressBar(barHolder, barColor, barBg, 12)

	return {
		Frame = panel,
		Label = label,
		Value = value,
		Fill = fill,
	}
end

-- "Currency" panel: black/60 with a coloured icon badge and a label/value on the right.
type CurrencyPanel = {
	Frame: Frame,
	Value: TextLabel,
}

local function currencyPanel(
	parent: Instance,
	iconKey: string,
	iconBg: Color3,
	labelText: string
): CurrencyPanel
	local panel = Instance.new("Frame")
	panel.Name = labelText .. "Panel"
	panel.Size = UDim2.fromOffset(220, 60)
	panel.BackgroundColor3 = Theme.Colors.Black
	panel.BackgroundTransparency = 0.4
	panel.BorderSizePixel = 0
	panel.Parent = parent
	corner(panel, Theme.Sizes.PanelCornerRadius)
	stroke(panel, Theme.Colors.White, 2).Transparency = 0.8

	local pad = padding(panel, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = panel
	local layout = listLayout(
		row,
		Enum.FillDirection.Horizontal,
		10,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local badge = iconBadge(row, iconKey, iconBg, 40)
	badge.LayoutOrder = 1

	local right = Instance.new("Frame")
	right.LayoutOrder = 2
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(1, -50, 1, 0)
	right.Parent = row

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, 0, 0, 4)
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Medium
	label.Text = labelText
	label.TextColor3 = Theme.Colors.White
	label.TextTransparency = 0.2
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Parent = right

	local value = Instance.new("TextLabel")
	value.AnchorPoint = Vector2.new(1, 1)
	value.Position = UDim2.new(1, 0, 1, -4)
	value.Size = UDim2.new(1, 0, 0, 22)
	value.BackgroundTransparency = 1
	value.Font = Theme.Fonts.Bold
	value.Text = "0"
	value.TextColor3 = Theme.Colors.White
	value.TextSize = 20
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = right

	return {
		Frame = panel,
		Value = value,
	}
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	-- Insert commas for thousand separators (matching the Figma's `toLocaleString()`).
	local formatted, count = s, 0
	repeat
		formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return formatted
end

-- ------------------------------------------------------------ side buttons --

local function sideButton(
	parent: Instance,
	iconKey: string,
	gradTop: Color3,
	gradBottom: Color3,
	borderColor: Color3,
	onClick: (() -> ())?
): TextButton
	local button = Instance.new("TextButton")
	button.Name = iconKey .. "Button"
	button.Size = UDim2.fromOffset(56, 56)
	button.BackgroundColor3 = gradTop
	button.AutoButtonColor = false
	button.Text = ""
	button.BorderSizePixel = 0
	button.Parent = parent
	corner(button, 12)
	gradient(button, gradTop, gradBottom)
	stroke(button, borderColor, 4)

	local icon = iconImage(button, iconKey, 28, Theme.Colors.White)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)

	button.MouseEnter:Connect(function()
		tweenTo(button, 0.12, { Size = UDim2.fromOffset(62, 62) })
	end)
	button.MouseLeave:Connect(function()
		tweenTo(button, 0.12, { Size = UDim2.fromOffset(56, 56) })
	end)
	if onClick then
		button.MouseButton1Click:Connect(onClick)
	end

	return button
end

local function bigButton(
	parent: Instance,
	text: string,
	iconKey: string,
	gradTop: Color3,
	gradBottom: Color3,
	borderColor: Color3,
	layoutOrder: number,
	onClick: (() -> ())?
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = text .. "Button"
	btn.LayoutOrder = layoutOrder
	btn.Size = UDim2.fromOffset(170, 64)
	btn.BackgroundColor3 = gradTop
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.BorderSizePixel = 0
	btn.Parent = parent
	corner(btn, 12)
	gradient(btn, gradTop, gradBottom)
	stroke(btn, borderColor, 4)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = btn
	local layout = listLayout(
		row,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local icon = iconImage(row, iconKey, 26, Theme.Colors.White)
	icon.LayoutOrder = 1

	local label = Instance.new("TextLabel")
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 28)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Bold
	label.Text = text
	label.TextColor3 = Theme.Colors.White
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = row

	btn.MouseEnter:Connect(function()
		tweenTo(btn, 0.12, { Size = UDim2.fromOffset(178, 66) })
	end)
	btn.MouseLeave:Connect(function()
		tweenTo(btn, 0.12, { Size = UDim2.fromOffset(170, 64) })
	end)
	if onClick then
		btn.MouseButton1Click:Connect(onClick)
	end

	return btn
end

-- ----------------------------------------------------------------- modals --

local function modalShell(parent: Instance, width: number, height: number): (Frame, Frame)
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Colors.Black
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Visible = false
	backdrop.ZIndex = 50
	backdrop.Parent = parent

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(width, height)
	panel.BackgroundColor3 = Theme.Colors.Gray800
	panel.BorderSizePixel = 0
	panel.Parent = backdrop
	corner(panel, 16)
	gradient(panel, Theme.Colors.Gray800, Theme.Colors.Gray900)
	stroke(panel, Theme.Colors.Gray700, 4)
	padding(panel, 24)

	return backdrop, panel
end

local function modalHeader(
	parent: Instance,
	iconKey: string,
	iconBg: Color3,
	titleText: string,
	onClose: () -> ()
): Frame
	local header = Instance.new("Frame")
	header.LayoutOrder = 1
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 56)
	header.Parent = parent

	local left = Instance.new("Frame")
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.new(0, 0, 0.5, 0)
	left.Size = UDim2.new(1, -56, 1, 0)
	left.BackgroundTransparency = 1
	left.Parent = header
	listLayout(
		left,
		Enum.FillDirection.Horizontal,
		12,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)

	iconBadge(left, iconKey, iconBg, 44).LayoutOrder = 1

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 2
	title.Size = UDim2.fromOffset(400, 36)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Bold
	title.Text = titleText
	title.TextColor3 = Theme.Colors.White
	title.TextSize = 30
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = left

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Theme.Colors.Red500
	close.AutoButtonColor = true
	close.Text = ""
	close.BorderSizePixel = 0
	close.Parent = header
	corner(close, 8)

	local x = iconImage(close, "X", 22, Theme.Colors.White)
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.fromScale(0.5, 0.5)

	close.MouseButton1Click:Connect(onClose)

	return header
end

local function buildInventoryGrid(parent: Instance, inventory: { [number]: number })
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(160, 160)
	grid.CellPadding = UDim2.fromOffset(16, 16)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = parent

	for index, def in ipairs(InventoryItems.Items) do
		local cell = Instance.new("Frame")
		cell.LayoutOrder = index
		cell.BackgroundColor3 = Theme.Colors.Gray700
		cell.BorderSizePixel = 0
		cell.Parent = parent
		corner(cell, 12)
		gradient(cell, Theme.Colors.Gray700, Theme.Colors.Gray800)
		local rarity = Theme.Rarity[def.rarity]
		stroke(cell, rarity.border, 3)

		local tint = Instance.new("Frame")
		tint.BackgroundColor3 = rarity.fill
		tint.BackgroundTransparency = 0.85
		tint.BorderSizePixel = 0
		tint.Size = UDim2.fromScale(1, 1)
		tint.Parent = cell
		corner(tint, 12)

		local icon = iconImage(cell, def.iconKey, 64, Theme.Colors.White)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 16)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 0)
		nameLabel.Position = UDim2.new(0.5, 0, 0, 88)
		nameLabel.Size = UDim2.new(1, -8, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Theme.Fonts.Bold
		nameLabel.Text = def.name
		nameLabel.TextColor3 = Theme.Colors.White
		nameLabel.TextSize = 14
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Parent = cell

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.AnchorPoint = Vector2.new(0.5, 1)
		rarityLabel.Position = UDim2.new(0.5, 0, 1, -8)
		rarityLabel.Size = UDim2.new(1, -8, 0, 16)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Font = Theme.Fonts.Bold
		rarityLabel.Text = string.upper(def.rarity)
		rarityLabel.TextColor3 = rarity.text
		rarityLabel.TextSize = 12
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
		rarityLabel.Parent = cell

		local qty = inventory[def.id] or 0
		local qtyHolder = Instance.new("Frame")
		qtyHolder.AnchorPoint = Vector2.new(1, 0)
		qtyHolder.Position = UDim2.new(1, -6, 0, 6)
		qtyHolder.Size = UDim2.fromOffset(36, 22)
		qtyHolder.BackgroundColor3 = Theme.Colors.Black
		qtyHolder.BackgroundTransparency = 0.3
		qtyHolder.BorderSizePixel = 0
		qtyHolder.Parent = cell
		corner(qtyHolder, 11)

		local qtyLabel = Instance.new("TextLabel")
		qtyLabel.Size = UDim2.fromScale(1, 1)
		qtyLabel.BackgroundTransparency = 1
		qtyLabel.Font = Theme.Fonts.Bold
		qtyLabel.Text = "x" .. tostring(qty)
		qtyLabel.TextColor3 = Theme.Colors.White
		qtyLabel.TextSize = 13
		qtyLabel.TextXAlignment = Enum.TextXAlignment.Center
		qtyLabel.Parent = qtyHolder
	end
end

local function buildSettingsBody(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	listLayout(parent, Enum.FillDirection.Vertical, 16)

	local function settingsCard(layoutOrder: number, name: string)
		local card = Instance.new("Frame")
		card.LayoutOrder = layoutOrder
		card.Size = UDim2.new(1, 0, 0, 76)
		card.BackgroundColor3 = Theme.Colors.Gray700
		card.BackgroundTransparency = 0.5
		card.BorderSizePixel = 0
		card.Parent = parent
		corner(card, 8)
		padding(card, 16)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.Font = Theme.Fonts.Bold
		label.Text = name
		label.TextColor3 = Theme.Colors.White
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = card
		return card
	end

	local sound = settingsCard(1, "Sound Effects")
	local soundBar = Instance.new("Frame")
	soundBar.AnchorPoint = Vector2.new(0, 1)
	soundBar.Position = UDim2.new(0, 0, 1, 0)
	soundBar.Size = UDim2.new(1, 0, 0, 12)
	soundBar.BackgroundTransparency = 1
	soundBar.Parent = sound
	progressBar(soundBar, Theme.Colors.White, Theme.Colors.Gray600, 12)
	local _, soundFill = progressBar(soundBar, Theme.Colors.White, Theme.Colors.Gray600, 12)
	soundFill.Size = UDim2.fromScale(0.8, 1)

	local music = settingsCard(2, "Music Volume")
	local musicBar = Instance.new("Frame")
	musicBar.AnchorPoint = Vector2.new(0, 1)
	musicBar.Position = UDim2.new(0, 0, 1, 0)
	musicBar.Size = UDim2.new(1, 0, 0, 12)
	musicBar.BackgroundTransparency = 1
	musicBar.Parent = music
	local _, musicFill = progressBar(musicBar, Theme.Colors.White, Theme.Colors.Gray600, 12)
	musicFill.Size = UDim2.fromScale(0.6, 1)

	local quality = settingsCard(3, "Graphics Quality")
	quality.Size = UDim2.new(1, 0, 0, 90)
	local btnRow = Instance.new("Frame")
	btnRow.AnchorPoint = Vector2.new(0, 1)
	btnRow.Position = UDim2.new(0, 0, 1, 0)
	btnRow.Size = UDim2.new(1, 0, 0, 36)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = quality
	local row = listLayout(btnRow, Enum.FillDirection.Horizontal, 8)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Left
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local function qBtn(order: number, text: string, color: Color3)
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(0.333, -6, 0, 32)
		b.BackgroundColor3 = color
		b.AutoButtonColor = true
		b.Font = Theme.Fonts.Bold
		b.Text = text
		b.TextColor3 = Theme.Colors.White
		b.TextSize = 14
		b.BorderSizePixel = 0
		b.Parent = btnRow
		corner(b, 6)
	end
	qBtn(1, "High", Theme.Colors.Green600)
	qBtn(2, "Medium", Theme.Colors.Gray600)
	qBtn(3, "Low", Theme.Colors.Gray600)
end

-- --------------------------------------------------------------- HUD class --

function HUD.new(player: Player)
	local self = setmetatable({}, HUD)

	local playerGui = player:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "GameHUD"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	-- Background gradient + grid overlay (only visible behind 3D world if camera
	-- happens to render an empty scene; in real gameplay the world fills it).
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.Colors.SkyBlue400
	bg.BorderSizePixel = 0
	bg.ZIndex = 0
	bg.Parent = screen
	gradient(bg, Theme.Colors.SkyBlue400, Theme.Colors.Emerald400)

	-- Faint center label "GAME WORLD".
	local center = Instance.new("TextLabel")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(800, 120)
	center.BackgroundTransparency = 1
	center.Font = Theme.Fonts.Bold
	center.Text = "GAME WORLD"
	center.TextColor3 = Theme.Colors.White
	center.TextTransparency = 0.8
	center.TextSize = 60
	center.TextStrokeTransparency = 0.7
	center.ZIndex = 1
	center.Parent = bg

	-- Top left status panels.
	local topLeft = Instance.new("Frame")
	topLeft.Name = "TopLeft"
	topLeft.AnchorPoint = Vector2.new(0, 0)
	topLeft.Position = UDim2.fromOffset(16, 16)
	topLeft.Size = UDim2.fromOffset(320, 240)
	topLeft.BackgroundTransparency = 1
	topLeft.ZIndex = 5
	topLeft.Parent = screen
	listLayout(topLeft, Enum.FillDirection.Vertical, 12)

	local healthPanel = statusPanel(
		topLeft,
		"Heart",
		Theme.Colors.Red500,
		Theme.Colors.Red500,
		Theme.Colors.Red900,
		"HEALTH"
	)
	healthPanel.Frame.LayoutOrder = 1
	local energyPanel = statusPanel(
		topLeft,
		"Zap",
		Theme.Colors.Yellow500,
		Theme.Colors.Yellow400,
		Theme.Colors.Yellow900,
		"ENERGY"
	)
	energyPanel.Frame.LayoutOrder = 2
	local levelPanel = statusPanel(
		topLeft,
		"Award",
		Theme.Colors.Purple500,
		Theme.Colors.Purple500,
		Theme.Colors.Purple900,
		"LEVEL 1"
	)
	levelPanel.Frame.LayoutOrder = 3

	-- Top right currency panels.
	local topRight = Instance.new("Frame")
	topRight.Name = "TopRight"
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.Position = UDim2.new(1, -16, 0, 16)
	topRight.Size = UDim2.fromOffset(220, 140)
	topRight.BackgroundTransparency = 1
	topRight.ZIndex = 5
	topRight.Parent = screen
	local trLayout = listLayout(topRight, Enum.FillDirection.Vertical, 12)
	trLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local coinsPanel = currencyPanel(topRight, "Coins", Theme.Colors.Yellow500, "Coins")
	coinsPanel.Frame.LayoutOrder = 1
	local gemsPanel = currencyPanel(topRight, "Star", Theme.Colors.Cyan500, "Gems")
	gemsPanel.Frame.LayoutOrder = 2

	-- Right side quick actions.
	local rightSide = Instance.new("Frame")
	rightSide.Name = "RightSide"
	rightSide.AnchorPoint = Vector2.new(1, 0.5)
	rightSide.Position = UDim2.new(1, -16, 0.5, 0)
	rightSide.Size = UDim2.fromOffset(56, 248)
	rightSide.BackgroundTransparency = 1
	rightSide.ZIndex = 5
	rightSide.Parent = screen
	local sideLayout = listLayout(rightSide, Enum.FillDirection.Vertical, 12)
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	-- Bottom center action buttons.
	local bottomCenter = Instance.new("Frame")
	bottomCenter.Name = "BottomCenter"
	bottomCenter.AnchorPoint = Vector2.new(0.5, 1)
	bottomCenter.Position = UDim2.new(0.5, 0, 1, -32)
	bottomCenter.Size = UDim2.fromOffset(360, 64)
	bottomCenter.BackgroundTransparency = 1
	bottomCenter.ZIndex = 5
	bottomCenter.Parent = screen
	local bcLayout = listLayout(bottomCenter, Enum.FillDirection.Horizontal, 12)
	bcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bcLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	-- Modals
	local inventoryBackdrop, inventoryPanel = modalShell(screen, 640, 540)
	local settingsBackdrop, settingsPanel = modalShell(screen, 520, 440)

	listLayout(inventoryPanel, Enum.FillDirection.Vertical, 16)
	listLayout(settingsPanel, Enum.FillDirection.Vertical, 16)

	local function setInventoryVisible(visible: boolean)
		inventoryBackdrop.Visible = visible
	end
	local function setSettingsVisible(visible: boolean)
		settingsBackdrop.Visible = visible
	end

	modalHeader(inventoryPanel, "Backpack", Theme.Colors.Orange500, "INVENTORY", function()
		setInventoryVisible(false)
	end)
	local invBody = Instance.new("Frame")
	invBody.LayoutOrder = 2
	invBody.BackgroundTransparency = 1
	invBody.Size = UDim2.new(1, 0, 1, -72)
	invBody.Parent = inventoryPanel

	modalHeader(settingsPanel, "Settings", Theme.Colors.Gray500, "SETTINGS", function()
		setSettingsVisible(false)
	end)
	local settingsBody = Instance.new("Frame")
	settingsBody.LayoutOrder = 2
	settingsBody.BackgroundTransparency = 1
	settingsBody.Size = UDim2.new(1, 0, 1, -72)
	settingsBody.Parent = settingsPanel
	buildSettingsBody(settingsBody)

	-- Side buttons (after modals exist so we can wire toggles).
	sideButton(
		rightSide,
		"Backpack",
		Theme.Colors.Orange500,
		Theme.Colors.Orange600,
		Theme.Colors.Orange700,
		function()
			setInventoryVisible(not inventoryBackdrop.Visible)
		end
	).LayoutOrder =
		1
	sideButton(
		rightSide,
		"Map",
		Theme.Colors.Green500,
		Theme.Colors.Green600,
		Theme.Colors.Green700
	).LayoutOrder =
		2
	sideButton(
		rightSide,
		"Users",
		Theme.Colors.Purple500,
		Theme.Colors.Purple600,
		Theme.Colors.Purple700
	).LayoutOrder =
		3
	sideButton(
		rightSide,
		"Settings",
		Theme.Colors.Gray500,
		Theme.Colors.Gray600,
		Theme.Colors.Gray700,
		function()
			setSettingsVisible(not settingsBackdrop.Visible)
		end
	).LayoutOrder =
		4

	-- Bottom buttons
	bigButton(
		bottomCenter,
		"ATTACK",
		"Swords",
		Theme.Colors.Red500,
		Theme.Colors.Red600,
		Theme.Colors.Red700,
		1,
		function()
			RemoteEvents.Action:FireServer("Attack")
		end
	)
	bigButton(
		bottomCenter,
		"DEFEND",
		"Shield",
		Theme.Colors.Blue500,
		Theme.Colors.Blue600,
		Theme.Colors.Blue700,
		2,
		function()
			RemoteEvents.Action:FireServer("Defend")
		end
	)

	-- Default empty state.
	healthPanel.Value.Text = "0/100"
	energyPanel.Value.Text = "0/100"
	levelPanel.Value.Text = "0%"
	coinsPanel.Value.Text = "0"
	gemsPanel.Value.Text = "0"
	healthPanel.Fill.Size = UDim2.fromScale(0, 1)
	energyPanel.Fill.Size = UDim2.fromScale(0, 1)
	levelPanel.Fill.Size = UDim2.fromScale(0, 1)

	buildInventoryGrid(invBody, {})

	-- Keyboard shortcuts: I = inventory, P = settings, M = map (no-op), F = friends.
	local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			setInventoryVisible(not inventoryBackdrop.Visible)
		elseif input.KeyCode == Enum.KeyCode.P then
			setSettingsVisible(not settingsBackdrop.Visible)
		end
	end)

	self.Screen = screen
	self.HealthPanel = healthPanel
	self.EnergyPanel = energyPanel
	self.LevelPanel = levelPanel
	self.CoinsPanel = coinsPanel
	self.GemsPanel = gemsPanel
	self.InventoryBody = invBody
	self.InputConnection = inputConn

	return self
end

function HUD:SetState(state: PlayerState)
	local hp = math.clamp(state.Health / math.max(state.MaxHealth, 1), 0, 1)
	local en = math.clamp(state.Energy / math.max(state.MaxEnergy, 1), 0, 1)
	local xpFrac = math.clamp(state.XP / math.max(state.XPToNext, 1), 0, 1)

	self.HealthPanel.Value.Text =
		string.format("%d/%d", math.floor(state.Health), math.floor(state.MaxHealth))
	self.EnergyPanel.Value.Text =
		string.format("%d/%d", math.floor(state.Energy), math.floor(state.MaxEnergy))
	self.LevelPanel.Label.Text = "LEVEL " .. tostring(state.Level)
	self.LevelPanel.Value.Text = string.format("%d%%", math.floor(xpFrac * 100))
	self.CoinsPanel.Value.Text = formatNumber(state.Coins)
	self.GemsPanel.Value.Text = formatNumber(state.Gems)

	tweenTo(self.HealthPanel.Fill, 0.25, { Size = UDim2.new(hp, 0, 1, 0) })
	tweenTo(self.EnergyPanel.Fill, 0.25, { Size = UDim2.new(en, 0, 1, 0) })
	tweenTo(self.LevelPanel.Fill, 0.25, { Size = UDim2.new(xpFrac, 0, 1, 0) })

	buildInventoryGrid(self.InventoryBody, state.Inventory)
end

function HUD:Destroy()
	if self.InputConnection then
		self.InputConnection:Disconnect()
		self.InputConnection = nil
	end
	if self.Screen then
		self.Screen:Destroy()
		self.Screen = nil
	end
end

return HUD
