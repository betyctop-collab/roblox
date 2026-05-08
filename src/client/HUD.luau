--!strict
--
-- RNG katana HUD.
--
-- Layout:
--   Top-center  : Big "Roll Banner" -- pulses + recolors per rarity on each roll.
--   Top-left    : Stats card (rolls / coins / luck / index progress / best item).
--   Top-right   : Server-wide announcement ribbon (Mythic+ drops).
--   Right side  : Four square buttons (Inventory, Index, Boosts, Settings).
--   Bottom-cntr : Big ROLL button with cooldown ring + auto-roll timer.
--
-- The HUD is fully driven by snapshots pushed from the server through
-- RemoteEvents.StateChanged. The big roll banner animates on RollResult,
-- and GlobalAnnounce drops add a row to the announcement ribbon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local IconIds = require(ReplicatedStorage.Shared.IconIds)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local Theme = require(ReplicatedStorage.Shared.Theme)

local HUD = {}
HUD.__index = HUD

type Snapshot = {
	Inventory: { [number]: number },
	TotalRolls: number,
	Coins: number,
	BestItemId: number,
	Luck: number,
	EffectiveLuck: number,
	Boosts: { { Multiplier: number, SecondsLeft: number } },
	NextRollAt: number,
	ServerNow: number,
}

local function new(parent: Instance, name: string, props: { [string]: any }?): any
	local inst = Instance.new(name)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
	inst.Parent = parent
	return inst
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Sizes.PanelCornerRadius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function padding(parent: Instance, p: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, p)
	pad.PaddingBottom = UDim.new(0, p)
	pad.PaddingLeft = UDim.new(0, p)
	pad.PaddingRight = UDim.new(0, p)
	pad.Parent = parent
	return pad
end

local function setIcon(label: ImageLabel | ImageButton, key: string, fallbackText: TextLabel?)
	local id = (IconIds :: any)[key]
	if typeof(id) == "string" and id ~= "" then
		label.Image = id
		label.ImageTransparency = 0
		if fallbackText then
			fallbackText.Visible = false
		end
	else
		label.Image = ""
		label.ImageTransparency = 1
		if fallbackText then
			fallbackText.Visible = true
			fallbackText.Text = (IconIds.Fallback :: any)[key] or "?"
		end
	end
end

local function makeIcon(
	parent: Instance,
	key: string,
	size: number,
	color: Color3
): (ImageLabel, TextLabel)
	local frame = new(parent, "Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	})
	local image = new(frame, "ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = color,
		ScaleType = Enum.ScaleType.Fit,
	}) :: ImageLabel
	local fallback = new(frame, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = color,
		Font = Theme.Fonts.Bold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}) :: TextLabel
	setIcon(image, key, fallback)
	return image, fallback
end

local function bestRarityFromInventory(inv: { [number]: number })
	local bestId = 0
	for id, count in pairs(inv) do
		if count > 0 then
			local item = Items.ById[id]
			if item then
				local r = Rarities.ByKey[item.RarityKey]
				if r and r.Id > bestId then
					bestId = r.Id
				end
			end
		end
	end
	return Rarities.ById[bestId]
end

local function indexProgress(inv: { [number]: number }): (number, number)
	local total = #Items.All
	local owned = 0
	for _, item in Items.All do
		if (inv[item.Id] or 0) > 0 then
			owned += 1
		end
	end
	return owned, total
end

local function fmtCount(n: number): string
	if n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	end
	if n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local function fmtOneIn(n: number): string
	if n >= 1000000 then
		return "1 / " .. fmtCount(n)
	end
	if n >= 1000 then
		return "1 / " .. fmtCount(n)
	end
	return "1 / " .. tostring(n)
end

-- ============================================================================
-- HUD construction
-- ============================================================================

function HUD.new(player: Player)
	local self = setmetatable({}, HUD)

	self._player = player
	self._snapshot = nil :: Snapshot?
	self._isOpen = {} :: { [string]: boolean }
	self._modals = {} :: { [string]: ScreenGui }
	self._boostExpiresAt = {} :: { [number]: number }

	-- Root ScreenGui
	local screen = new(player:WaitForChild("PlayerGui"), "ScreenGui", {
		Name = "RngKatanaHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	self._screen = screen

	self:_buildBackground(screen)
	self:_buildStatsCard(screen)
	self:_buildAnnouncementRibbon(screen)
	self:_buildSideButtons(screen)
	self:_buildRollBanner(screen)
	self:_buildBottomBar(screen)
	self:_buildToastLayer(screen)

	-- Modals (start hidden)
	self._modals.Inventory = self:_buildInventoryModal(player)
	self._modals.Index = self:_buildIndexModal(player)
	self._modals.Boosts = self:_buildBoostShopModal(player)
	self._modals.Settings = self:_buildSettingsModal(player)

	-- Hook RemoteEvents
	RemoteEvents.StateChanged.OnClientEvent:Connect(function(snapshot)
		self:_applySnapshot(snapshot)
	end)
	RemoteEvents.RollResult.OnClientEvent:Connect(function(payload)
		self:_animateRoll(payload)
	end)
	RemoteEvents.GlobalAnnounce.OnClientEvent:Connect(function(payload)
		self:_pushAnnouncement(payload)
	end)
	RemoteEvents.Notify.OnClientEvent:Connect(function(payload)
		self:_pushToast(payload)
	end)

	-- Auto-roll timer redraw
	RunService.Heartbeat:Connect(function()
		self:_redrawTimer()
	end)

	-- Keyboard
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			self:_toggleModal("Inventory")
		elseif input.KeyCode == Enum.KeyCode.N then
			self:_toggleModal("Index")
		elseif input.KeyCode == Enum.KeyCode.B then
			self:_toggleModal("Boosts")
		elseif input.KeyCode == Enum.KeyCode.P then
			self:_toggleModal("Settings")
		elseif input.KeyCode == Enum.KeyCode.Space then
			RemoteEvents.Action:FireServer("Roll")
		end
	end)

	-- Ask the server for a fresh state in case we connected mid-frame.
	task.defer(function()
		RemoteEvents.Action:FireServer("RequestState")
	end)

	return self
end

-- ============================================================================
-- Background
-- ============================================================================

function HUD:_buildBackground(screen: ScreenGui)
	local bg = new(screen, "Frame", {
		Name = "Background",
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}) :: Frame
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(11, 17, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 14, 50)),
	})
	gradient.Rotation = 110
	gradient.Parent = bg
end

-- ============================================================================
-- Stats card (top-left)
-- ============================================================================

function HUD:_buildStatsCard(screen: ScreenGui)
	local pad = Theme.Sizes.HudPadding
	local card = new(screen, "Frame", {
		Name = "StatsCard",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.fromOffset(280, 168),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
	}) :: Frame
	corner(card)
	stroke(card, Theme.Colors.Border, 1, 0.4)
	padding(card, 12)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = card

	local function row(order: number, key: string, label: string, accent: Color3): TextLabel
		local r = new(card, "Frame", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
		}) :: Frame

		local image, _ = makeIcon(r, key, 22, accent)
		image.Parent.Position = UDim2.fromOffset(0, 3)

		local lbl = new(r, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -32, 1, 0),
			Text = label,
			TextColor3 = Theme.Colors.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Font = Theme.Fonts.Medium,
			TextSize = 16,
		}) :: TextLabel
		return lbl
	end

	self._statRolls = row(1, "Dice", "Rolls — 0", Theme.Colors.SkyBlue400)
	self._statCoins = row(2, "Coins", "Coins — 0", Theme.Colors.Yellow400)
	self._statLuck = row(3, "Sparkles", "Luck x1.00", Theme.Colors.Pink500)
	self._statIndex = row(4, "Award", "Index 0 / 24", Theme.Colors.Purple400)
	self._statBest = row(5, "Star", "Best —", Theme.Colors.Emerald400)
end

-- ============================================================================
-- Server-wide announcement ribbon (top-right)
-- ============================================================================

function HUD:_buildAnnouncementRibbon(screen: ScreenGui)
	local pad = Theme.Sizes.HudPadding
	local ribbon = new(screen, "Frame", {
		Name = "AnnouncementRibbon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -pad, 0, pad),
		Size = UDim2.fromOffset(360, 168),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}) :: Frame
	corner(ribbon)
	stroke(ribbon, Theme.Colors.Border, 1, 0.4)
	padding(ribbon, 10)

	local title = new(ribbon, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "Server-wide drops",
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Bold,
		TextSize = 12,
	})
	title.LayoutOrder = 0

	local list = new(ribbon, "Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 1, -22),
	}) :: Frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	self._announceList = list
	self._announceCount = 0

	local empty = new(list, "TextLabel", {
		Name = "EmptyState",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Text = "No drops yet — be the first to roll a Mythic+ blade.",
		TextColor3 = Theme.Colors.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Fonts.Regular,
		TextSize = 12,
		LayoutOrder = 9999,
	}) :: TextLabel
	self._announceEmpty = empty
end

function HUD:_pushAnnouncement(payload: any)
	if not self._announceList then
		return
	end
	if self._announceEmpty then
		self._announceEmpty.Visible = false
	end
	local rarity = Rarities.ByKey[payload.RarityKey] or Rarities.Mythic
	local row = new(self._announceList, "Frame", {
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = -tick(),
	}) :: Frame
	corner(row, 6)
	stroke(row, rarity.BannerColor, 1, 0.2)
	padding(row, 6)

	local text = new(row, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = string.format(
			'<font color="rgb(%d,%d,%d)">%s</font>  rolled <b>%s</b>  (%s)',
			math.floor(rarity.BannerColor.R * 255),
			math.floor(rarity.BannerColor.G * 255),
			math.floor(rarity.BannerColor.B * 255),
			payload.PlayerName or "?",
			payload.ItemName or "?",
			fmtOneIn(payload.OneIn or 1)
		),
		TextColor3 = Theme.Colors.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Theme.Fonts.Medium,
		TextSize = 12,
		RichText = true,
	})
	text.LayoutOrder = -tick()

	self._announceCount += 1
	if self._announceCount > Constants.MaxRecentAnnouncements then
		local oldest
		local oldestOrder = math.huge
		for _, child in self._announceList:GetChildren() do
			if child:IsA("Frame") then
				local lo = (child :: any).LayoutOrder
				if lo < oldestOrder then
					oldestOrder = lo
					oldest = child
				end
			end
		end
		if oldest then
			oldest:Destroy()
			self._announceCount -= 1
		end
	end
end

-- ============================================================================
-- Side buttons (right edge)
-- ============================================================================

function HUD:_buildSideButtons(screen: ScreenGui)
	local pad = Theme.Sizes.HudPadding
	local box = new(screen, "Frame", {
		Name = "SideButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -pad, 0.5, 0),
		Size = UDim2.fromOffset(64, 4 * (Theme.Sizes.SideButton + 8) - 8),
		BackgroundTransparency = 1,
	}) :: Frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = box

	local function btn(order: number, key: string, modal: string, accent: Color3)
		local button = new(box, "ImageButton", {
			LayoutOrder = order,
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(Theme.Sizes.SideButton, Theme.Sizes.SideButton),
			AutoButtonColor = false,
			Image = "",
		}) :: ImageButton
		corner(button)
		stroke(button, Theme.Colors.White, 1, 0.7)
		local _, _ = makeIcon(button, key, 28, Theme.Colors.White)
		button.MouseButton1Click:Connect(function()
			self:_toggleModal(modal)
		end)
		button.MouseEnter:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.18), { BackgroundTransparency = 0.15 })
				:Play()
		end)
	end

	btn(1, "Backpack", "Inventory", Theme.Colors.Orange500)
	btn(2, "Award", "Index", Theme.Colors.Purple400)
	btn(3, "Zap", "Boosts", Theme.Colors.Yellow400)
	btn(4, "Settings", "Settings", Theme.Colors.Gray400)
end

-- ============================================================================
-- Roll banner (top center)
-- ============================================================================

function HUD:_buildRollBanner(screen: ScreenGui)
	local banner = new(screen, "Frame", {
		Name = "RollBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.Sizes.HudPadding),
		Size = UDim2.fromOffset(420, Theme.RollBannerHeight),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
	}) :: Frame
	corner(banner)
	local outline = stroke(banner, Theme.Colors.Border, 2, 0.3)
	padding(banner, 12)
	self._bannerStroke = outline

	local rarityLabel = new(banner, "TextLabel", {
		Name = "Rarity",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Awaiting first roll…",
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 14,
	}) :: TextLabel
	self._bannerRarity = rarityLabel

	local nameLabel = new(banner, "TextLabel", {
		Name = "ItemName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "—",
		TextColor3 = Theme.Colors.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 26,
	}) :: TextLabel
	self._bannerName = nameLabel

	local loreLabel = new(banner, "TextLabel", {
		Name = "Lore",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "Press SPACE or click ROLL to begin.",
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Regular,
		TextSize = 12,
	}) :: TextLabel
	self._bannerLore = loreLabel
end

function HUD:_animateRoll(payload: any)
	local rarity = Rarities.ByKey[payload.RarityKey] or Rarities.Common
	local color = rarity.BannerColor

	if self._bannerRarity then
		self._bannerRarity.Text =
			string.format("%s  •  %s", string.upper(rarity.Name), fmtOneIn(payload.OneIn or 1))
		self._bannerRarity.TextColor3 = color
	end
	if self._bannerName then
		self._bannerName.Text = payload.ItemName or "?"
		self._bannerName.TextColor3 = Theme.Colors.White
	end
	if self._bannerLore then
		self._bannerLore.Text = payload.Lore or ""
	end
	if self._bannerStroke then
		self._bannerStroke.Color = color
	end

	-- Scale pulse for impact tier 4+ (Epic+).
	if rarity.Id >= 4 then
		local banner = self._bannerName and self._bannerName.Parent
		if banner and banner:IsA("GuiObject") then
			banner.Size = UDim2.fromOffset(420, Theme.RollBannerHeight + 4)
			TweenService:Create(
				banner,
				TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(420, Theme.RollBannerHeight) }
			):Play()
		end
	end
end

-- ============================================================================
-- Bottom bar: ROLL button + auto-roll timer
-- ============================================================================

function HUD:_buildBottomBar(screen: ScreenGui)
	local container = new(screen, "Frame", {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Sizes.HudPadding),
		Size = UDim2.fromOffset(360, 110),
		BackgroundTransparency = 1,
	}) :: Frame

	local rollBtn = new(container, "ImageButton", {
		Name = "RollButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(220, 70),
		BackgroundColor3 = Theme.Colors.Pink500,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Image = "",
	}) :: ImageButton
	corner(rollBtn, 14)
	stroke(rollBtn, Theme.Colors.White, 1, 0.6)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.Pink500),
		ColorSequenceKeypoint.new(1, Theme.Colors.Purple400),
	})
	gradient.Rotation = 90
	gradient.Parent = rollBtn

	local label = new(rollBtn, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "ROLL",
		TextColor3 = Theme.Colors.White,
		Font = Theme.Fonts.Bold,
		TextSize = 28,
	})
	rollBtn.MouseButton1Click:Connect(function()
		RemoteEvents.Action:FireServer("Roll")
		-- Quick squish for tactile feedback.
		rollBtn.Size = UDim2.fromOffset(214, 67)
		TweenService:Create(
			rollBtn,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(220, 70) }
		):Play()
	end)
	rollBtn.MouseEnter:Connect(function()
		TweenService:Create(rollBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.1 }):Play()
	end)
	rollBtn.MouseLeave:Connect(function()
		TweenService:Create(rollBtn, TweenInfo.new(0.18), { BackgroundTransparency = 0 }):Play()
	end)
	self._rollBtn = rollBtn
	self._rollLabel = label

	local timer = new(container, "TextLabel", {
		Name = "AutoTimer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(280, 24),
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Muted,
		Text = "Auto-roll in 5.0s — press SPACE to skip",
		Font = Theme.Fonts.Medium,
		TextSize = 14,
	}) :: TextLabel
	self._timerLabel = timer

	local hint = new(container, "TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromOffset(360, 14),
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Muted,
		Text = "[I] inventory  [N] index  [B] boosts  [P] settings",
		Font = Theme.Fonts.Regular,
		TextSize = 11,
	})
	hint.TextTransparency = 0.3

	-- Active boost banner (shows while a temporary luck multiplier is live).
	local pad = Theme.Sizes.HudPadding
	local boostBanner = new(screen, "Frame", {
		Name = "BoostBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(110 + pad + 12)),
		Size = UDim2.fromOffset(280, 36),
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
	}) :: Frame
	corner(boostBanner, 10)
	stroke(boostBanner, Theme.Colors.Yellow400, 1, 0.2)
	padding(boostBanner, 8)

	local boostIcon, _ = makeIcon(boostBanner, "Zap", 18, Theme.Colors.Yellow400)
	boostIcon.Parent.Position = UDim2.fromOffset(0, 1)

	local boostText = new(boostBanner, "TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -26, 1, 0),
		Text = "",
		TextColor3 = Theme.Colors.White,
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}) :: TextLabel
	self._boostBanner = boostBanner
	self._boostText = boostText
end

function HUD:_redrawTimer()
	local snap = self._snapshot
	if not snap then
		return
	end
	-- The server clock and our clock are not synchronized; we received
	-- ServerNow alongside NextRollAt and use the diff plus our local elapsed
	-- time to estimate remaining seconds.
	local localElapsed = os.clock() - (self._snapshotLocalT or os.clock())

	if self._timerLabel then
		local delta = math.max(0, snap.NextRollAt - snap.ServerNow)
		local remaining = math.max(0, delta - localElapsed)
		self._timerLabel.Text =
			string.format("Auto-roll in %.1fs — press SPACE to skip", remaining)
		self._timerLabel.TextColor3 = remaining < 0.6 and Theme.Colors.Yellow400
			or Theme.Colors.Muted
	end

	if self._boostBanner and self._boostText then
		local active = nil
		local soonestExpiry = math.huge
		for _, b in snap.Boosts or {} do
			local remaining = math.max(0, (b.SecondsLeft or 0) - localElapsed)
			if remaining > 0 and remaining < soonestExpiry then
				active = b
				soonestExpiry = remaining
			end
		end
		if active then
			self._boostBanner.Visible = true
			self._boostText.Text = string.format(
				"Luck boost x%d — %.1fs remaining",
				active.Multiplier or 1,
				soonestExpiry
			)
		else
			self._boostBanner.Visible = false
		end
	end
end

-- ============================================================================
-- Toast layer (bottom-right)
-- ============================================================================

function HUD:_buildToastLayer(screen: ScreenGui)
	local pad = Theme.Sizes.HudPadding
	local layer = new(screen, "Frame", {
		Name = "ToastLayer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -pad, 1, -160),
		Size = UDim2.fromOffset(280, 0),
		BackgroundTransparency = 1,
	}) :: Frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 6)
	layout.Parent = layer
	self._toastLayer = layer
end

function HUD:_pushToast(payload: any)
	if not self._toastLayer then
		return
	end
	local color = payload.Color or Theme.Colors.SkyBlue400
	local toast = new(self._toastLayer, "Frame", {
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = -math.floor(tick() * 1000),
	}) :: Frame
	corner(toast, 8)
	stroke(toast, color, 1, 0.2)
	padding(toast, 6)

	new(toast, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = payload.Text or "",
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Theme.Fonts.Medium,
		TextSize = 14,
	})

	task.delay(3.6, function()
		toast:Destroy()
	end)
end

-- ============================================================================
-- Modal scaffolding
-- ============================================================================

function HUD:_buildModalShell(
	player: Player,
	name: string,
	title: string,
	width: number,
	height: number
): (ScreenGui, Frame)
	local screen = new(player:WaitForChild("PlayerGui"), "ScreenGui", {
		Name = "RngModal_" .. name,
		Enabled = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	local backdrop = new(screen, "Frame", {
		BackgroundColor3 = Theme.Colors.Black,
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}) :: Frame
	local backdropBtn = new(backdrop, "TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}) :: TextButton
	backdropBtn.MouseButton1Click:Connect(function()
		self:_toggleModal(name)
	end)

	local panel = new(screen, "Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.Colors.Surface,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
	}) :: Frame
	corner(panel, 16)
	stroke(panel, Theme.Colors.Border, 1, 0.4)
	padding(panel, 16)

	local header = new(panel, "Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	}) :: Frame
	new(header, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.85, 1),
		Text = title,
		TextColor3 = Theme.Colors.White,
		Font = Theme.Fonts.Bold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local closeBtn = new(header, "TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = Theme.Colors.White,
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		AutoButtonColor = true,
	}) :: TextButton
	corner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function()
		self:_toggleModal(name)
	end)

	local body = new(panel, "Frame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
	}) :: Frame

	return screen, body
end

function HUD:_toggleModal(name: string)
	local modal = self._modals[name]
	if not modal then
		return
	end
	-- Close all other modals so only one is active.
	for k, m in pairs(self._modals) do
		if k ~= name then
			m.Enabled = false
		end
	end
	modal.Enabled = not modal.Enabled
end

-- ============================================================================
-- Inventory modal
-- ============================================================================

function HUD:_buildInventoryModal(player: Player): ScreenGui
	local screen, body = self:_buildModalShell(player, "Inventory", "Inventory", 540, 460)

	local scroll = new(body, "ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
	}) :: ScrollingFrame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(160, 80)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	self._inventoryGrid = scroll
	return screen
end

function HUD:_renderInventory(snap: Snapshot)
	if not self._inventoryGrid then
		return
	end
	for _, child in self._inventoryGrid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local owned = {}
	for _, item in Items.All do
		local count = snap.Inventory[item.Id] or 0
		if count > 0 then
			table.insert(owned, { Item = item, Count = count })
		end
	end
	if #owned == 0 then
		new(self._inventoryGrid, "TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(500, 60),
			Text = "Inventory is empty — start rolling.",
			TextColor3 = Theme.Colors.Muted,
			Font = Theme.Fonts.Medium,
			TextSize = 16,
		})
		return
	end
	-- Sort owned items by rarity (rarest first), then by id.
	table.sort(owned, function(a, b)
		local ra = Rarities.ByKey[a.Item.RarityKey].Id
		local rb = Rarities.ByKey[b.Item.RarityKey].Id
		if ra ~= rb then
			return ra > rb
		end
		return a.Item.Id < b.Item.Id
	end)

	for index, entry in owned do
		local rarity = Rarities.ByKey[entry.Item.RarityKey]
		local cell = new(self._inventoryGrid, "Frame", {
			LayoutOrder = index,
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(160, 80),
		}) :: Frame
		corner(cell, 8)
		stroke(cell, rarity.BannerColor, 1, 0.2)
		padding(cell, 8)

		new(cell, "TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Text = entry.Item.Name,
			TextColor3 = Theme.Colors.White,
			Font = Theme.Fonts.Bold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		new(cell, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 14),
			Text = rarity.Name .. "  •  " .. fmtOneIn(rarity.OneIn),
			TextColor3 = rarity.BannerColor,
			Font = Theme.Fonts.Medium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		new(cell, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 28),
			Text = "x" .. tostring(entry.Count),
			TextColor3 = Theme.Colors.White,
			Font = Theme.Fonts.Bold,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

-- ============================================================================
-- Index modal
-- ============================================================================

function HUD:_buildIndexModal(player: Player): ScreenGui
	local screen, body = self:_buildModalShell(player, "Index", "Index", 600, 480)

	local progressLabel = new(body, "TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "0 / 24 collected",
		TextColor3 = Theme.Colors.Muted,
		Font = Theme.Fonts.Medium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	self._indexProgress = progressLabel

	local scroll = new(body, "ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
	}) :: ScrollingFrame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(180, 64)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	self._indexGrid = scroll
	return screen
end

function HUD:_renderIndex(snap: Snapshot)
	if not self._indexGrid then
		return
	end
	for _, child in self._indexGrid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local owned, total = indexProgress(snap.Inventory)
	if self._indexProgress then
		self._indexProgress.Text = string.format("%d / %d collected", owned, total)
	end

	for i, item in Items.All do
		local rarity = Rarities.ByKey[item.RarityKey]
		local discovered = (snap.Inventory[item.Id] or 0) > 0
		local cell = new(self._indexGrid, "Frame", {
			LayoutOrder = i,
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BackgroundTransparency = discovered and 0.05 or 0.5,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(180, 64),
		}) :: Frame
		corner(cell, 8)
		stroke(cell, rarity.BannerColor, 1, discovered and 0.2 or 0.6)
		padding(cell, 8)

		local nameText = discovered and item.Name or "???"
		local nameColor = discovered and Theme.Colors.White or Theme.Colors.Muted
		new(cell, "TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Text = nameText,
			TextColor3 = nameColor,
			Font = Theme.Fonts.Bold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		new(cell, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 14),
			Text = rarity.Name .. "  •  " .. fmtOneIn(rarity.OneIn),
			TextColor3 = rarity.BannerColor,
			Font = Theme.Fonts.Medium,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		new(cell, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 22),
			Text = discovered and "x" .. tostring(snap.Inventory[item.Id]) or "Locked",
			TextColor3 = discovered and Theme.Colors.White or Theme.Colors.Muted,
			Font = Theme.Fonts.Medium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

-- ============================================================================
-- Boost shop modal
-- ============================================================================

function HUD:_buildBoostShopModal(player: Player): ScreenGui
	local screen, body = self:_buildModalShell(player, "Boosts", "Luck Boosts", 460, 320)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = body

	for index, entry in Constants.BoostShop do
		local row = new(body, "Frame", {
			LayoutOrder = index,
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 64),
		}) :: Frame
		corner(row, 8)
		stroke(row, Theme.Colors.Yellow400, 1, 0.3)
		padding(row, 10)

		new(row, "TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.6, 0, 0, 22),
			Text = entry.Name,
			TextColor3 = Theme.Colors.White,
			Font = Theme.Fonts.Bold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		new(row, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(0.6, 0, 0, 18),
			Text = string.format("x%d luck for %ds", entry.Multiplier, entry.DurationSeconds),
			TextColor3 = Theme.Colors.Muted,
			Font = Theme.Fonts.Medium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local buy = new(row, "TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(120, 36),
			BackgroundColor3 = Theme.Colors.Yellow400,
			BorderSizePixel = 0,
			Text = string.format("Buy — %d", entry.Cost),
			TextColor3 = Theme.Colors.Black,
			Font = Theme.Fonts.Bold,
			TextSize = 14,
			AutoButtonColor = true,
		}) :: TextButton
		corner(buy, 8)
		buy.MouseButton1Click:Connect(function()
			RemoteEvents.Action:FireServer("BuyBoost", entry.Id)
		end)
	end

	return screen
end

-- ============================================================================
-- Settings modal
-- ============================================================================

function HUD:_buildSettingsModal(player: Player): ScreenGui
	local screen, body = self:_buildModalShell(player, "Settings", "Settings", 420, 280)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = body

	local function row(order: number, label: string, helper: string)
		local r = new(body, "Frame", {
			LayoutOrder = order,
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 56),
		}) :: Frame
		corner(r, 8)
		padding(r, 10)
		new(r, "TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Text = label,
			TextColor3 = Theme.Colors.White,
			Font = Theme.Fonts.Bold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		new(r, "TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 18),
			Text = helper,
			TextColor3 = Theme.Colors.Muted,
			Font = Theme.Fonts.Medium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	row(
		1,
		"Auto-roll interval",
		string.format("Every %d seconds. Press SPACE to skip.", Constants.AutoRollIntervalSeconds)
	)
	row(
		2,
		"Server-wide announcements",
		"Mythic / Divine / Celestial drops are announced to everyone."
	)
	row(3, "Persistence", "Your inventory and best item are saved between sessions.")

	return screen
end

-- ============================================================================
-- Snapshot apply
-- ============================================================================

function HUD:_applySnapshot(snap: Snapshot)
	self._snapshot = snap
	self._snapshotLocalT = os.clock()

	if self._statRolls then
		self._statRolls.Text = "Rolls — " .. fmtCount(snap.TotalRolls)
	end
	if self._statCoins then
		self._statCoins.Text = "Coins — " .. fmtCount(snap.Coins)
	end
	if self._statLuck then
		self._statLuck.Text = string.format("Luck x%.2f", snap.EffectiveLuck or 1)
	end
	if self._statIndex then
		local owned, total = indexProgress(snap.Inventory)
		self._statIndex.Text = string.format("Index %d / %d", owned, total)
	end
	if self._statBest then
		local rarity = bestRarityFromInventory(snap.Inventory)
		local item = Items.ById[snap.BestItemId]
		if rarity and item then
			self._statBest.Text = string.format("Best — %s", item.Name)
			self._statBest.TextColor3 = rarity.BannerColor
		else
			self._statBest.Text = "Best — none yet"
			self._statBest.TextColor3 = Theme.Colors.Muted
		end
	end

	if self._modals.Inventory and self._modals.Inventory.Enabled then
		self:_renderInventory(snap)
	end
	if self._modals.Index and self._modals.Index.Enabled then
		self:_renderIndex(snap)
	end
end

return HUD
