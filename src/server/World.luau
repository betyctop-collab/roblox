--!strict
--
-- Builds the visual map: tiered stage, central altar, torii gate at spawn,
-- decorative blade installations, lighting, atmosphere, and ambient cherry
-- blossom particles.
--
-- All builds are idempotent — `Build()` clears any prior `RngWorld` folder
-- before re-creating, so live-syncing via Rojo doesn't pile up duplicates.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Rarities = require(game:GetService("ReplicatedStorage").Shared.Rarities)

local World = {}

local WORLD_NAME = "RngWorld"
local STAGE_RADIUS = 36
local OUTER_RADIUS = 80

local function part(name: string, parent: Instance?, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "CanCollide" then
			(p :: any)[k] = v
		end
	end
	if parent then
		p.Parent = parent
	end
	return p
end

local function buildBase(folder: Folder)
	-- Outer plate
	part("Ground", folder, {
		Size = Vector3.new(420, 2, 420),
		Position = Vector3.new(0, -1, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(22, 28, 44),
	})

	-- Mid plate (raised)
	local mid = part("Stage", folder, {
		Size = Vector3.new(STAGE_RADIUS * 2, 1, STAGE_RADIUS * 2),
		Position = Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(40, 50, 76),
		Shape = Enum.PartType.Block,
	})
	-- Bevel using a cylinder beneath the stage to suggest a circular dais.
	part("StageDisc", folder, {
		Size = Vector3.new(STAGE_RADIUS * 2 + 4, 1, STAGE_RADIUS * 2 + 4),
		Position = Vector3.new(0, 0.0, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(28, 36, 60),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
	})

	-- Glowing seam ring around the dais
	for i = 0, 47 do
		local angle = (i / 48) * math.pi * 2
		local x = math.cos(angle) * (STAGE_RADIUS - 1)
		local z = math.sin(angle) * (STAGE_RADIUS - 1)
		part("Seam" .. i, folder, {
			Size = Vector3.new(2, 0.3, 0.6),
			Position = Vector3.new(x, 1.05, z),
			Orientation = Vector3.new(0, math.deg(-angle), 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(56, 189, 248),
			CanCollide = false,
		})
	end

	-- Decorative ground tiles outside the dais (sparse)
	for i = 1, 24 do
		local angle = math.random() * math.pi * 2
		local r = STAGE_RADIUS + 8 + math.random() * (OUTER_RADIUS - STAGE_RADIUS - 12)
		local x = math.cos(angle) * r
		local z = math.sin(angle) * r
		local size = 5 + math.random() * 6
		part("Tile" .. i, folder, {
			Size = Vector3.new(size, 0.4, size),
			Position = Vector3.new(x, 0.2, z),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(20, 26, 42),
			Orientation = Vector3.new(0, math.random(0, 360), 0),
			CanCollide = false,
		})
	end
	mid:GetMass()
end

local function buildAltar(folder: Folder)
	-- Three concentric platforms forming a stepped altar at center.
	local altar = Instance.new("Folder")
	altar.Name = "Altar"
	altar.Parent = folder

	part("AltarStep1", altar, {
		Size = Vector3.new(20, 0.6, 20),
		Position = Vector3.new(0, 1.3, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(50, 62, 90),
	})
	part("AltarStep2", altar, {
		Size = Vector3.new(14, 0.6, 14),
		Position = Vector3.new(0, 1.9, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(60, 72, 104),
	})
	part("AltarTop", altar, {
		Size = Vector3.new(10, 0.4, 10),
		Position = Vector3.new(0, 2.3, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(168, 85, 247),
	})

	-- Center beacon (slim glowing column reaching up)
	local beacon = part("Beacon", altar, {
		Size = Vector3.new(0.8, 80, 0.8),
		Position = Vector3.new(0, 42.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(236, 72, 153),
		Transparency = 0.2,
		CanCollide = false,
		CastShadow = false,
	})

	-- Floating glow ring above the altar
	for i = 0, 11 do
		local angle = (i / 12) * math.pi * 2
		local x = math.cos(angle) * 4
		local z = math.sin(angle) * 4
		part("Glyph" .. i, altar, {
			Size = Vector3.new(0.4, 0.4, 0.8),
			Position = Vector3.new(x, 5.5, z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(56, 189, 248),
			CanCollide = false,
			Orientation = Vector3.new(0, math.deg(-angle), 0),
		})
	end
	beacon:GetMass()
end

local function buildRarityPillars(folder: Folder)
	-- One pillar per rarity, arranged in a circle around the altar at the
	-- edge of the dais. Order is rare→common clockwise so the brightest
	-- (Celestial) is the first one a player sees on spawn.
	local pillars = Instance.new("Folder")
	pillars.Name = "RarityPillars"
	pillars.Parent = folder

	local order = Rarities.OrderRarestFirst
	for i, tier in order do
		local angle = (i - 1) / #order * math.pi * 2 - math.pi / 2
		local x = math.cos(angle) * (STAGE_RADIUS - 5)
		local z = math.sin(angle) * (STAGE_RADIUS - 5)

		-- Base
		part("Base_" .. tier.Key, pillars, {
			Size = Vector3.new(4, 1.2, 4),
			Position = Vector3.new(x, 1.6, z),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(36, 46, 70),
		})
		-- Shaft
		part("Shaft_" .. tier.Key, pillars, {
			Size = Vector3.new(2.4, 8, 2.4),
			Position = Vector3.new(x, 6.2, z),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(44, 56, 86),
		})
		-- Glowing cap
		local cap = part("Cap_" .. tier.Key, pillars, {
			Size = Vector3.new(3, 1.6, 3),
			Position = Vector3.new(x, 11, z),
			Material = Enum.Material.Neon,
			Color = tier.BannerColor,
		})
		-- Floating gem above cap
		part("Gem_" .. tier.Key, pillars, {
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = Vector3.new(x, 13.5, z),
			Orientation = Vector3.new(45, 45, 0),
			Material = Enum.Material.Neon,
			Color = tier.BannerColor,
			Transparency = 0.1,
			CanCollide = false,
			CastShadow = false,
		})
		-- PointLight on the cap
		local light = Instance.new("PointLight")
		light.Brightness = 2.5
		light.Range = 18
		light.Color = tier.BannerColor
		light.Parent = cap

		-- Label above the gem
		local labelPart = part("Label_" .. tier.Key, pillars, {
			Size = Vector3.new(6, 1.4, 0.05),
			Position = Vector3.new(x, 15.2, z),
			Transparency = 1,
			CanCollide = false,
			CastShadow = false,
		})
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 80
		sg.Parent = labelPart
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = string.upper(tier.Name)
		label.TextColor3 = tier.BannerColor
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = sg
	end
end

local function buildToriiGate(folder: Folder)
	-- Classic torii: two thick uprights, a top crossbeam ("kasagi"), and a
	-- secondary beam ("nuki") below it.
	local gate = Instance.new("Folder")
	gate.Name = "ToriiGate"
	gate.Parent = folder

	local CX, CZ = 0, OUTER_RADIUS - 6
	local UPRIGHT_HEIGHT = 18
	local SPAN = 16
	local BEAM_THICK = 1.6
	local UPRIGHT_THICK = 1.6

	local function torii(offsetX: number)
		part("Upright_" .. offsetX, gate, {
			Size = Vector3.new(UPRIGHT_THICK, UPRIGHT_HEIGHT, UPRIGHT_THICK),
			Position = Vector3.new(CX + offsetX, UPRIGHT_HEIGHT / 2 + 0.5, CZ),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(176, 35, 35),
		})
	end

	torii(-SPAN / 2)
	torii(SPAN / 2)

	-- Nuki (lower crossbeam)
	part("Nuki", gate, {
		Size = Vector3.new(SPAN + 2, BEAM_THICK, UPRIGHT_THICK + 0.2),
		Position = Vector3.new(CX, UPRIGHT_HEIGHT - 4, CZ),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(40, 28, 28),
	})

	-- Kasagi (curved-ish top crossbeam)
	part("Kasagi", gate, {
		Size = Vector3.new(SPAN + 6, BEAM_THICK + 0.6, UPRIGHT_THICK + 0.6),
		Position = Vector3.new(CX, UPRIGHT_HEIGHT + 0.5, CZ),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(176, 35, 35),
	})

	-- Top accent strip
	part("KasagiAccent", gate, {
		Size = Vector3.new(SPAN + 7, 0.4, UPRIGHT_THICK + 0.8),
		Position = Vector3.new(CX, UPRIGHT_HEIGHT + 1.5, CZ),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(250, 204, 21),
		CastShadow = false,
	})

	-- Subtle hanging lanterns on the uprights
	for _, side in { -1, 1 } :: { number } do
		local hang = part("Lantern_" .. side, gate, {
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = Vector3.new(CX + side * SPAN / 2, UPRIGHT_HEIGHT - 5.4, CZ),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(250, 204, 21),
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 16
		light.Color = Color3.fromRGB(255, 220, 130)
		light.Parent = hang
	end
end

local function buildDecorativeBlades(folder: Folder)
	-- Two giant blades stuck in the ground, framing the torii gate.
	local blades = Instance.new("Folder")
	blades.Name = "Blades"
	blades.Parent = folder

	local function blade(x: number, z: number, tilt: number, accent: Color3)
		-- Hilt
		part("Hilt", blades, {
			Size = Vector3.new(1.2, 4, 1.2),
			Position = Vector3.new(x, 13, z),
			Orientation = Vector3.new(tilt, 0, 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(48, 28, 22),
		})
		-- Crossguard
		part("Guard", blades, {
			Size = Vector3.new(2.4, 0.4, 0.6),
			Position = Vector3.new(x, 11, z),
			Orientation = Vector3.new(tilt, 0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(180, 168, 90),
		})
		-- Blade
		part("Blade", blades, {
			Size = Vector3.new(0.5, 16, 1.4),
			Position = Vector3.new(x, 4.5, z),
			Orientation = Vector3.new(tilt, 0, 0),
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.05,
			CanCollide = false,
		})
		-- Glow base
		local glowPart = part("BladeGlow", blades, {
			Size = Vector3.new(2.4, 0.6, 2.4),
			Position = Vector3.new(x, 0.7, z),
			Material = Enum.Material.Neon,
			Color = accent,
			CanCollide = false,
			CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 3
		light.Range = 14
		light.Color = accent
		light.Parent = glowPart
	end

	blade(-30, OUTER_RADIUS - 14, 12, Color3.fromRGB(56, 189, 248))
	blade(30, OUTER_RADIUS - 14, 12, Color3.fromRGB(236, 72, 153))
end

local function buildPetals(folder: Folder)
	-- A single hidden anchor part that emits cherry blossom petals ambient
	-- across the stage. ParticleEmitter "rains" them.
	local emitter = part("PetalEmitter", folder, {
		Size = Vector3.new(STAGE_RADIUS * 2, 1, STAGE_RADIUS * 2),
		Position = Vector3.new(0, 60, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	local p = Instance.new("ParticleEmitter")
	p.Name = "Petals"
	-- Use a small built-in soft-circle decal as a stand-in petal sprite.
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 192, 203)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 153, 184)),
	})
	p.Size = NumberSequence.new(0.4, 0.6)
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Lifetime = NumberRange.new(6, 10)
	p.Rate = 28
	p.Speed = NumberRange.new(2, 4)
	p.SpreadAngle = Vector2.new(20, 20)
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-90, 90)
	p.Acceleration = Vector3.new(0, -2, 0)
	p.LightEmission = 0.2
	p.Parent = emitter
end

local function buildSpawn(folder: Folder)
	-- Spawn pad nestled just inside the torii gate.
	local existing = Workspace:FindFirstChild("SpawnLocation")
	if existing then
		existing:Destroy()
	end
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "SpawnLocation"
	spawnPart.Size = Vector3.new(8, 1, 8)
	spawnPart.Position = Vector3.new(0, 1.2, OUTER_RADIUS - 14)
	spawnPart.Anchored = true
	spawnPart.Material = Enum.Material.Neon
	spawnPart.Color = Color3.fromRGB(56, 189, 248)
	spawnPart.Transparency = 0.15
	spawnPart.TopSurface = Enum.SurfaceType.Smooth
	spawnPart.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 12
	light.Color = Color3.fromRGB(56, 189, 248)
	light.Parent = spawnPart
	folder:GetMass()
end

local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(80, 86, 116)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 140)
	Lighting.Brightness = 1.6
	Lighting.ColorShift_Bottom = Color3.fromRGB(20, 22, 42)
	Lighting.ColorShift_Top = Color3.fromRGB(70, 60, 110)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 17.7
	Lighting.GeographicLatitude = 32
	Lighting.FogColor = Color3.fromRGB(78, 102, 130)
	Lighting.FogStart = 80
	Lighting.FogEnd = 360

	-- Atmosphere
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.32
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(180, 188, 220)
	atmo.Decay = Color3.fromRGB(106, 90, 156)
	atmo.Glare = 0.3
	atmo.Haze = 1.6

	-- Sky
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
	sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
	sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
	sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
	sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
	sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
	sky.SunAngularSize = 6
	sky.MoonAngularSize = 5
	sky.StarCount = 1500

	-- Bloom for that "magical sunset" feel
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.5
	bloom.Size = 18
	bloom.Threshold = 0.95

	-- Mild colour grading toward warm magenta/teal
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
	end
	cc.Saturation = 0.1
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(240, 230, 250)

	-- Sun rays
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Parent = Lighting
	end
	rays.Intensity = 0.18
	rays.Spread = 0.6
end

function World.Build()
	-- Wipe any leftover wave-based content (Mob, EnemySpawn, etc.) and our
	-- own previous attempt.
	for _, name in { "Baseplate", "RngStage", WORLD_NAME, "Mob", "EnemySpawn" } :: { string } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = WORLD_NAME
	folder.Parent = Workspace

	buildBase(folder)
	buildAltar(folder)
	buildRarityPillars(folder)
	buildToriiGate(folder)
	buildDecorativeBlades(folder)
	buildPetals(folder)
	buildSpawn(folder)
	configureLighting()
end

return World
