--!strict
--
-- Server bootstrap. Builds the world, wires services, starts the wave spawner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure RemoteEvents are created before clients ask for them.
local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared:WaitForChild("RemoteEvents"))

local script = script :: Script
local PlayerData = require(script:WaitForChild("PlayerData"))
local CombatService = require(script:WaitForChild("CombatService"))
local WaveSpawner = require(script:WaitForChild("WaveSpawner"))

-- ---------------------------------------------------------------- world setup --

local function ensureBaseplate()
	local existing = workspace:FindFirstChild("Baseplate")
	if existing then
		return
	end
	local baseplate = Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Size = Vector3.new(512, 1, 512)
	baseplate.Position = Vector3.new(0, 0, 0)
	baseplate.Anchored = true
	baseplate.Locked = true
	baseplate.Material = Enum.Material.Grass
	baseplate.Color = Color3.fromRGB(86, 165, 86)
	baseplate.TopSurface = Enum.SurfaceType.Smooth
	baseplate.BottomSurface = Enum.SurfaceType.Smooth
	baseplate.Parent = workspace
end

local function ensureSpawn()
	local existing = workspace:FindFirstChildOfClass("SpawnLocation")
	if existing then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 0)
	spawn.Anchored = true
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(56, 189, 248)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = workspace
end

local function ensureArenaWalls()
	local arena = workspace:FindFirstChild("ArenaWalls")
	if arena then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "ArenaWalls"
	folder.Parent = workspace

	local function wall(name: string, size: Vector3, position: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = size
		part.Position = position
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(31, 41, 55)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
	end
	-- 4 walls forming a 200x200 arena around origin.
	wall("North", Vector3.new(200, 12, 4), Vector3.new(0, 6, 100))
	wall("South", Vector3.new(200, 12, 4), Vector3.new(0, 6, -100))
	wall("East", Vector3.new(4, 12, 200), Vector3.new(100, 6, 0))
	wall("West", Vector3.new(4, 12, 200), Vector3.new(-100, 6, 0))
end

ensureBaseplate()
ensureSpawn()
ensureArenaWalls()

-- ----------------------------------------------------------------- services --

PlayerData.Init()
CombatService.SetDeps(PlayerData, WaveSpawner.Get())
CombatService.Init()
WaveSpawner.Get():Start()

-- Mob "auto-attack": when a mob is close to a player, deal damage every 1.2s.
task.spawn(function()
	while true do
		task.wait(1.2)
		local spawner = WaveSpawner.Get()
		for _, mob in spawner:GetMobs() do
			CombatService.ApplyMobDamageToNearestPlayer(mob)
		end
	end
end)

-- Respawn the player's character when it dies, keeping their profile health
-- in sync with the actual humanoid.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local profile = PlayerData.Get(player)
		if not profile then
			return
		end
		local hum = char:WaitForChild("Humanoid", 5)
		if hum and hum:IsA("Humanoid") then
			hum.MaxHealth = profile.MaxHealth
			hum.Health = profile.Health
			hum.HealthChanged:Connect(function(h)
				PlayerData.SetHealth(player, h)
			end)
		end
	end)
end)
