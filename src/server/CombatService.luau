--!strict
--
-- Translates `Action` RemoteEvent invocations into combat outcomes.
-- ATTACK: spends energy, damages mobs in front of the player. On kill, awards
-- XP and currency via PlayerData.
-- DEFEND: spends energy, applies a damage-reduction window via the Profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local CombatService = {}

type Mob = {
	Model: Model,
	Humanoid: Humanoid,
	Root: Part,
	Damage: number,
	XP: number,
	Coins: number,
	GemChance: number,
	Destroyed: boolean,
}

type Profile = {
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
	LastAttackTick: number,
	LastDefendTick: number,
	DefendingUntil: number,
}

type WaveSpawnerLike = {
	GetMobs: (self: any) -> { Mob },
	OnMobKilled: (self: any, mob: Mob, killer: Player?) -> (),
}

type PlayerDataLike = {
	Get: (player: Player) -> Profile?,
	AddCurrency: (player: Player, coins: number, gems: number) -> (),
	AddXP: (player: Player, amount: number) -> (),
	SetHealth: (player: Player, value: number) -> (),
	SetEnergy: (player: Player, value: number) -> (),
	PushState: (player: Player) -> (),
}

local PlayerData: PlayerDataLike
local WaveSpawner: WaveSpawnerLike?

function CombatService.SetDeps(playerData: PlayerDataLike, waveSpawner: WaveSpawnerLike)
	PlayerData = playerData
	WaveSpawner = waveSpawner
end

local function nearestMobInFront(player: Player): Mob?
	local char = player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	if not WaveSpawner then
		return nil
	end

	local origin = hrp.Position
	local forward = hrp.CFrame.LookVector
	local best: Mob? = nil
	local bestScore = -math.huge
	for _, mob in WaveSpawner:GetMobs() do
		if mob.Destroyed or not mob.Humanoid or mob.Humanoid.Health <= 0 then
			continue
		end
		local toMob = (mob.Root.Position - origin)
		local dist = toMob.Magnitude
		if dist > Constants.AttackRange then
			continue
		end
		local dir = if dist > 0 then toMob.Unit else forward
		local dot = dir:Dot(forward)
		if dot < 0.3 then
			continue
		end
		local score = dot * 5 - dist
		if score > bestScore then
			bestScore = score
			best = mob
		end
	end
	return best
end

local function handleAttack(player: Player)
	if not PlayerData then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local now = os.clock()
	if now - profile.LastAttackTick < Constants.AttackCooldown then
		return
	end
	if profile.Energy < Constants.AttackEnergyCost then
		RemoteEvents.Notify:FireClient(player, "Not enough energy!", Color3.fromRGB(239, 68, 68))
		return
	end
	profile.LastAttackTick = now
	PlayerData.SetEnergy(player, profile.Energy - Constants.AttackEnergyCost)

	local mob = nearestMobInFront(player)
	if not mob then
		return
	end
	mob.Humanoid:TakeDamage(Constants.AttackDamage)
	if mob.Humanoid.Health <= 0 and not mob.Destroyed then
		mob.Destroyed = true
		PlayerData.AddXP(player, mob.XP)
		local gems = (math.random() < mob.GemChance) and Constants.GemsPerDrop or 0
		PlayerData.AddCurrency(player, mob.Coins, gems)
		if WaveSpawner then
			WaveSpawner:OnMobKilled(mob, player)
		end
	end
end

local function handleDefend(player: Player)
	if not PlayerData then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local now = os.clock()
	if now - profile.LastDefendTick < Constants.DefendCooldown then
		return
	end
	if profile.Energy < Constants.DefendEnergyCost then
		RemoteEvents.Notify:FireClient(player, "Not enough energy!", Color3.fromRGB(239, 68, 68))
		return
	end
	profile.LastDefendTick = now
	profile.DefendingUntil = now + Constants.DefendDuration
	PlayerData.SetEnergy(player, profile.Energy - Constants.DefendEnergyCost)
	RemoteEvents.Notify:FireClient(player, "Defending!", Color3.fromRGB(59, 130, 246))
end

function CombatService.ApplyMobDamageToNearestPlayer(mob: Mob)
	if not PlayerData then
		return
	end
	if mob.Destroyed or mob.Humanoid.Health <= 0 then
		return
	end
	local origin = mob.Root.Position
	local closestPlayer: Player? = nil
	local closestDist = math.huge
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - origin).Magnitude < 4 then
			local d = (hrp.Position - origin).Magnitude
			if d < closestDist then
				closestDist = d
				closestPlayer = plr
			end
		end
	end
	if not closestPlayer then
		return
	end
	local profile = PlayerData.Get(closestPlayer)
	if not profile then
		return
	end
	local damage = mob.Damage
	if os.clock() < profile.DefendingUntil then
		damage = math.floor(damage * (1 - Constants.DefendDamageReduction))
	end
	PlayerData.SetHealth(closestPlayer, profile.Health - damage)
end

function CombatService.Init()
	RemoteEvents.Action.OnServerEvent:Connect(function(player: Player, action: string)
		if typeof(action) ~= "string" then
			return
		end
		if action == "Attack" then
			handleAttack(player)
		elseif action == "Defend" then
			handleDefend(player)
		end
	end)
end

return CombatService
