--!strict
--
-- Builds the visual map: tiered stage, central altar, torii gate at spawn,
-- decorative blade installations, lighting, atmosphere, and ambient cherry
-- blossom particles.
--
-- The build is split into a guaranteed `bareMinimum()` phase that always
-- runs first (so the player has *something* to spawn onto, even if anything
-- else later throws), followed by a series of `pcall`-guarded steps for the
-- decorative additions. Each step's failure is logged via `warn()` and the
-- rest still runs.
--
-- `Build()` is idempotent — it deletes any prior `RngWorld` folder before
-- re-creating, so live-syncing via Rojo doesn't pile up duplicates.

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
	if props.CanCollide == nil then
		p.CanCollide = true
	else
		p.CanCollide = props.CanCollide
	end
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

local function bareMinimum(folder: Folder)
	-- The two parts that must exist for the place to be playable: a ground
	-- plane the player can stand on, and a SpawnLocation. Anything else is
	-- decoration that we tolerate failing.
	part("Ground", folder, {
		Size = Vector3.new(420, 2, 420),
		Position = Vector3.new(0, -1, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(118, 128, 158),
	})

	-- Wipe any pre-existing SpawnLocation so we own the position.
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
end

local function buildStage(folder: Folder)
	-- Mid plate (raised marble platform)
	part("Stage", folder, {
		Size = Vector3.new(STAGE_RADIUS * 2, 1, STAGE_RADIUS * 2),
		Position = Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(170, 180, 210),
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

	-- Sparse decorative tiles outside the dais
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
			Color = Color3.fromRGB(140, 150, 178),
			Orientation = Vector3.new(0, math.random(0, 360), 0),
			CanCollide = false,
		})
	end
end

local function buildAltar(folder: Folder)
	local altar = Instance.new("Folder")
	altar.Name = "Altar"
	altar.Parent = folder

	part("AltarStep1", altar, {
		Size = Vector3.new(20, 0.6, 20),
		Position = Vector3.new(0, 1.3, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(196, 200, 220),
	})
	part("AltarStep2", altar, {
		Size = Vector3.new(14, 0.6, 14),
		Position = Vector3.new(0, 1.9, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(214, 218, 232),
	})
	part("AltarTop", altar, {
		Size = Vector3.new(10, 0.4, 10),
		Position = Vector3.new(0, 2.3, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(168, 85, 247),
	})

	part("Beacon", altar, {
		Size = Vector3.new(0.8, 80, 0.8),
		Position = Vector3.new(0, 42.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(236, 72, 153),
		Transparency = 0.2,
		CanCollide = false,
	})

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
end

local function buildRarityPillars(folder: Folder)
	local pillars = Instance.new("Folder")
	pillars.Name = "RarityPillars"
	pillars.Parent = folder

	local order = Rarities.OrderRarestFirst
	for i, tier in order do
		local angle = (i - 1) / #order * math.pi * 2 - math.pi / 2
		local x = math.cos(angle) * (STAGE_RADIUS - 5)
		local z = math.sin(angle) * (STAGE_RADIUS - 5)

		part("Base_" .. tier.Key, pillars, {
			Size = Vector3.new(4, 1.2, 4),
			Position = Vector3.new(x, 1.6, z),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(180, 184, 204),
		})
		part("Shaft_" .. tier.Key, pillars, {
			Size = Vector3.new(2.4, 8, 2.4),
			Position = Vector3.new(x, 6.2, z),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(212, 216, 232),
		})
		local cap = part("Cap_" .. tier.Key, pillars, {
			Size = Vector3.new(3, 1.6, 3),
			Position = Vector3.new(x, 11, z),
			Material = Enum.Material.Neon,
			Color = tier.BannerColor,
		})
		part("Gem_" .. tier.Key, pillars, {
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = Vector3.new(x, 13.5, z),
			Orientation = Vector3.new(45, 45, 0),
			Material = Enum.Material.Neon,
			Color = tier.BannerColor,
			Transparency = 0.1,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 2.5
		light.Range = 18
		light.Color = tier.BannerColor
		light.Parent = cap

		local labelAnchor = part("Label_" .. tier.Key, pillars, {
			Size = Vector3.new(0.4, 0.4, 0.4),
			Position = Vector3.new(x, 15.6, z),
			Transparency = 1,
			CanCollide = false,
		})
		local bg = Instance.new("BillboardGui")
		bg.Adornee = labelAnchor
		bg.Size = UDim2.fromOffset(160, 36)
		bg.AlwaysOnTop = false
		bg.LightInfluence = 0
		bg.Parent = labelAnchor
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = string.upper(tier.Name)
		label.TextColor3 = tier.BannerColor
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = bg
	end
end

local function buildToriiGate(folder: Folder)
	local gate = Instance.new("Folder")
	gate.Name = "ToriiGate"
	gate.Parent = folder

	local CX, CZ = 0, OUTER_RADIUS - 6
	local UPRIGHT_HEIGHT = 18
	local SPAN = 16
	local BEAM_THICK = 1.6
	local UPRIGHT_THICK = 1.6

	for _, offset in { -SPAN / 2, SPAN / 2 } do
		part("Upright_" .. tostring(offset), gate, {
			Size = Vector3.new(UPRIGHT_THICK, UPRIGHT_HEIGHT, UPRIGHT_THICK),
			Position = Vector3.new(CX + offset, UPRIGHT_HEIGHT / 2 + 0.5, CZ),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(176, 35, 35),
		})
	end

	part("Nuki", gate, {
		Size = Vector3.new(SPAN + 2, BEAM_THICK, UPRIGHT_THICK + 0.2),
		Position = Vector3.new(CX, UPRIGHT_HEIGHT - 4, CZ),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(40, 28, 28),
	})

	part("Kasagi", gate, {
		Size = Vector3.new(SPAN + 6, BEAM_THICK + 0.6, UPRIGHT_THICK + 0.6),
		Position = Vector3.new(CX, UPRIGHT_HEIGHT + 0.5, CZ),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(176, 35, 35),
	})

	part("KasagiAccent", gate, {
		Size = Vector3.new(SPAN + 7, 0.4, UPRIGHT_THICK + 0.8),
		Position = Vector3.new(CX, UPRIGHT_HEIGHT + 1.5, CZ),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(250, 204, 21),
	})

	for _, side in { -1, 1 } do
		local hang = part("Lantern_" .. tostring(side), gate, {
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
	local blades = Instance.new("Folder")
	blades.Name = "Blades"
	blades.Parent = folder

	local function blade(x: number, z: number, tilt: number, accent: Color3)
		part("Hilt", blades, {
			Size = Vector3.new(1.2, 4, 1.2),
			Position = Vector3.new(x, 13, z),
			Orientation = Vector3.new(tilt, 0, 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(48, 28, 22),
		})
		part("Guard", blades, {
			Size = Vector3.new(2.4, 0.4, 0.6),
			Position = Vector3.new(x, 11, z),
			Orientation = Vector3.new(tilt, 0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(180, 168, 90),
		})
		part("Blade", blades, {
			Size = Vector3.new(0.5, 16, 1.4),
			Position = Vector3.new(x, 4.5, z),
			Orientation = Vector3.new(tilt, 0, 0),
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.05,
			CanCollide = false,
		})
		local glowPart = part("BladeGlow", blades, {
			Size = Vector3.new(2.4, 0.6, 2.4),
			Position = Vector3.new(x, 0.7, z),
			Material = Enum.Material.Neon,
			Color = accent,
			CanCollide = false,
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
	local emitter = part("PetalEmitter", folder, {
		Size = Vector3.new(STAGE_RADIUS * 2, 1, STAGE_RADIUS * 2),
		Position = Vector3.new(0, 60, 0),
		Transparency = 1,
		CanCollide = false,
	})
	local p = Instance.new("ParticleEmitter")
	p.Name = "Petals"
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

local function configureLighting()
	-- Bright daytime so the dojo and pillars are clearly readable. The previous
	-- pass set ClockTime ~17.7 (sunset) + heavy fog + dark ColorShift_Bottom,
	-- which combined with dark stone colours made the whole map render black
	-- from the player's POV (only emissive neon parts were visible).
	Lighting.Ambient = Color3.fromRGB(140, 144, 156)
	Lighting.OutdoorAmbient = Color3.fromRGB(180, 186, 200)
	Lighting.Brightness = 2
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 32
	Lighting.FogColor = Color3.fromRGB(180, 200, 220)
	Lighting.FogStart = 320
	Lighting.FogEnd = 1200

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	if atmo then
		atmo.Density = 0.18
		atmo.Offset = 0.05
		atmo.Color = Color3.fromRGB(199, 199, 199)
		atmo.Decay = Color3.fromRGB(106, 112, 125)
		atmo.Glare = 0
		atmo.Haze = 0.6
	end

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	if bloom then
		bloom.Intensity = 0.4
		bloom.Size = 18
		bloom.Threshold = 0.95
	end

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Parent = Lighting
	end
	if rays then
		rays.Intensity = 0.1
		rays.Spread = 0.4
	end

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Parent = Lighting
	end
	if cc then
		cc.Saturation = 0
		cc.Contrast = 0
		cc.TintColor = Color3.fromRGB(255, 255, 255)
	end

	-- Make sure a Sky exists. If a previous publish left a darker / custom one,
	-- reuse it so we don't fight over the place's Lighting tree, but reset its
	-- properties to a clean default so the horizon renders blue, not black.
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	if sky then
		sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
		sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
		sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
		sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
		sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
		sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
		sky.CelestialBodiesShown = true
		sky.StarCount = 3000
	end
end

local function safeStep(name: string, fn: (Folder) -> (), folder: Folder)
	local ok, err = pcall(fn, folder)
	if not ok then
		warn(string.format("[RngWorld] %s failed: %s", name, tostring(err)))
	end
end

function World.Build()
	-- Clean up any prior build (and leftovers from PR #1's wave-based code).
	for _, name in { "Baseplate", "RngStage", WORLD_NAME, "Mob", "EnemySpawn" } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = WORLD_NAME
	folder.Parent = Workspace

	-- Bare minimum (ground + spawn) is unguarded. If this fails the place is
	-- broken regardless and a thrown error helps surface the bug fast.
	bareMinimum(folder)

	-- Decorative steps are independent and tolerated to fail individually.
	safeStep("Stage", buildStage, folder)
	safeStep("Altar", buildAltar, folder)
	safeStep("RarityPillars", buildRarityPillars, folder)
	safeStep("ToriiGate", buildToriiGate, folder)
	safeStep("DecorativeBlades", buildDecorativeBlades, folder)
	safeStep("Petals", buildPetals, folder)

	local ok, err = pcall(configureLighting)
	if not ok then
		warn(string.format("[RngWorld] Lighting config failed: %s", tostring(err)))
	end
end

return World
