--!strict
--
-- Wave-based mob spawner. Maintains a list of live mobs, spawns the next wave
-- when all mobs are dead, scales difficulty per wave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local serverScripts = script.Parent :: Instance
local Mob = require(serverScripts:WaitForChild("Mob"))

type MobInstance = Mob.Mob

local WaveSpawner = {}
WaveSpawner.__index = WaveSpawner

local instance: any = nil

function WaveSpawner.new()
	local self = setmetatable({
		Wave = 0,
		Mobs = {} :: { MobInstance },
		_running = false,
	}, WaveSpawner)
	return self
end

function WaveSpawner:GetMobs(): { MobInstance }
	local out = {}
	for _, mob in self.Mobs do
		if not mob.Destroyed then
			table.insert(out, mob)
		end
	end
	return out
end

function WaveSpawner:OnMobKilled(_mob: MobInstance, killer: Player?)
	if killer then
		RemoteEvents.Notify:FireClient(killer, "+25 XP / +10 Coins", Color3.fromRGB(34, 197, 94))
	end
end

local function announceAll(text: string, color: Color3)
	for _, plr in Players:GetPlayers() do
		RemoteEvents.Notify:FireClient(plr, text, color)
	end
end

function WaveSpawner:_cleanup()
	local kept = {}
	for _, mob in self.Mobs do
		if mob.Destroyed or not mob.Humanoid or mob.Humanoid.Health <= 0 then
			Mob.Destroy(mob)
		else
			table.insert(kept, mob)
		end
	end
	self.Mobs = kept
end

function WaveSpawner:_spawnWave()
	self.Wave += 1
	local size = Constants.FirstWaveSize + (self.Wave - 1) * Constants.WaveSizeGrowth
	announceAll(
		string.format("Wave %d incoming! (%d mobs)", self.Wave, size),
		Color3.fromRGB(168, 85, 247)
	)
	for _ = 1, size do
		if #self.Mobs >= Constants.MaxConcurrentMobs then
			break
		end
		local mob = Mob.new(self.Wave)
		table.insert(self.Mobs, mob)
		task.wait(0.3)
	end
end

function WaveSpawner:Start()
	if self._running then
		return
	end
	self._running = true
	task.spawn(function()
		while self._running do
			-- Wait for any human players to be in the server before spawning.
			while #Players:GetPlayers() == 0 do
				task.wait(2)
			end
			self:_spawnWave()
			-- Wait until all mobs are dead.
			while true do
				task.wait(0.5)
				self:_cleanup()
				if #self.Mobs == 0 then
					break
				end
			end
			announceAll(
				string.format(
					"Wave %d cleared! Next wave in %ds",
					self.Wave,
					Constants.WaveBreakSeconds
				),
				Color3.fromRGB(34, 197, 94)
			)
			task.wait(Constants.WaveBreakSeconds)
		end
	end)
end

function WaveSpawner.Get(): any
	if not instance then
		instance = WaveSpawner.new()
	end
	return instance
end

return WaveSpawner
