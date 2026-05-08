--!strict

local Constants = {}

Constants.MaxHealth = 100
Constants.MaxEnergy = 100

Constants.AttackDamage = 25
Constants.AttackRange = 12
Constants.AttackCooldown = 0.6
Constants.AttackEnergyCost = 8

Constants.DefendDuration = 1
Constants.DefendDamageReduction = 0.5
Constants.DefendCooldown = 1.5
Constants.DefendEnergyCost = 5

Constants.EnergyRegenPerSecond = 6
Constants.HealthRegenPerSecond = 1

Constants.XpToLevel = function(level: number): number
	return 100 * level
end

Constants.XpRewardPerKill = 25
Constants.CoinsPerKill = 10
Constants.GemDropChance = 0.05
Constants.GemsPerDrop = 1

-- Wave system
Constants.FirstWaveSize = 3
Constants.WaveSizeGrowth = 2
Constants.MaxConcurrentMobs = 30
Constants.WaveBreakSeconds = 8

Constants.MobBaseHealth = 50
Constants.MobBaseSpeed = 8
Constants.MobScalingPerWave = 0.15

-- DataStore
Constants.DataStoreName = "PlayerProfileV1"

-- Spawn area for mobs (radius around origin)
Constants.MobSpawnRadius = 60
Constants.MobSpawnCenter = Vector3.new(0, 5, 0)

return Constants
