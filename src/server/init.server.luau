--!strict
--
-- Server bootstrap. Builds a tiny world (baseplate + spawn ring), then wires
-- up PlayerData and RollService.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local PlayerData = require(script.PlayerData)
local RollService = require(script.RollService)

local function buildWorld()
	-- Baseplate
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if not baseplate then
		baseplate = Instance.new("Part")
		baseplate.Name = "Baseplate"
		baseplate.Size = Vector3.new(512, 1, 512)
		baseplate.Position = Vector3.new(0, 0, 0)
		baseplate.Anchored = true
		baseplate.Material = Enum.Material.Slate
		baseplate.Color = Color3.fromRGB(28, 36, 56)
		baseplate.TopSurface = Enum.SurfaceType.Smooth
		baseplate.BottomSurface = Enum.SurfaceType.Smooth
		baseplate.Parent = Workspace
	end

	-- Subtle decorative ring (raised glowing tiles)
	if not Workspace:FindFirstChild("RngStage") then
		local stage = Instance.new("Folder")
		stage.Name = "RngStage"
		stage.Parent = Workspace
		for i = 0, 17 do
			local angle = (i / 18) * math.pi * 2
			local x = math.cos(angle) * 28
			local z = math.sin(angle) * 28
			local pillar = Instance.new("Part")
			pillar.Name = "Pillar" .. i
			pillar.Size = Vector3.new(3, 6, 3)
			pillar.Position = Vector3.new(x, 3.5, z)
			pillar.Anchored = true
			pillar.Material = Enum.Material.Neon
			pillar.Color = Color3.fromRGB(96, 165, 250)
			pillar.Parent = stage
		end
	end

	-- Spawn
	local spawnPart = Workspace:FindFirstChild("SpawnLocation")
	if not spawnPart then
		spawnPart = Instance.new("SpawnLocation")
		spawnPart.Name = "SpawnLocation"
		spawnPart.Size = Vector3.new(8, 1, 8)
		spawnPart.Position = Vector3.new(0, 1.5, 0)
		spawnPart.Anchored = true
		spawnPart.Material = Enum.Material.Neon
		spawnPart.Color = Color3.fromRGB(56, 189, 248)
		spawnPart.TopSurface = Enum.SurfaceType.Smooth
		spawnPart.Parent = Workspace
	end

	-- Lighting tweaks (already set in default.project.json, but keep idempotent)
	Lighting.GlobalShadows = true
	Lighting.Brightness = 1.5
end

buildWorld()
PlayerData.Init()
RollService.Init()
