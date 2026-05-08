--!strict
--
-- Per-player profile + DataStore persistence + leaderstats mirroring.
-- Fires `RemoteEvents.StateChanged` whenever something changes so the HUD
-- reflects the new values on the client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local InventoryItems = require(Shared:WaitForChild("InventoryItems"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

export type Profile = {
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

	-- Transient combat state, not persisted.
	LastAttackTick: number,
	LastDefendTick: number,
	DefendingUntil: number,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local store = DataStoreService:GetDataStore(Constants.DataStoreName)

local function defaultInventory(): { [number]: number }
	return table.clone(InventoryItems.DefaultStartingQuantities)
end

local function defaultProfile(): Profile
	return {
		Health = Constants.MaxHealth,
		MaxHealth = Constants.MaxHealth,
		Energy = Constants.MaxEnergy,
		MaxEnergy = Constants.MaxEnergy,
		Level = 1,
		XP = 0,
		XPToNext = Constants.XpToLevel(1),
		Coins = 0,
		Gems = 0,
		Inventory = defaultInventory(),
		LastAttackTick = 0,
		LastDefendTick = 0,
		DefendingUntil = 0,
	}
end

local function applyLoaded(profile: Profile, raw: any)
	if typeof(raw) ~= "table" then
		return
	end
	if typeof(raw.Level) == "number" then
		profile.Level = math.max(1, math.floor(raw.Level))
	end
	if typeof(raw.XP) == "number" then
		profile.XP = math.max(0, raw.XP)
	end
	if typeof(raw.Coins) == "number" then
		profile.Coins = math.max(0, math.floor(raw.Coins))
	end
	if typeof(raw.Gems) == "number" then
		profile.Gems = math.max(0, math.floor(raw.Gems))
	end
	if typeof(raw.Inventory) == "table" then
		profile.Inventory = {}
		for k, v in pairs(raw.Inventory) do
			local id = tonumber(k)
			if id and typeof(v) == "number" and v > 0 then
				profile.Inventory[id] = math.floor(v)
			end
		end
	end
	profile.XPToNext = Constants.XpToLevel(profile.Level)
end

local function ensureLeaderstats(player: Player)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local function num(name: string): IntValue
		local v = Instance.new("IntValue")
		v.Name = name
		v.Value = 0
		v.Parent = folder
		return v
	end
	num("Coins")
	num("Gems")
	num("Level")

	return folder
end

local function syncLeaderstats(player: Player, profile: Profile)
	local folder = ensureLeaderstats(player)
	local function set(name: string, value: number)
		local stat = folder:FindFirstChild(name)
		if stat and stat:IsA("IntValue") then
			stat.Value = math.floor(value)
		end
	end
	set("Coins", profile.Coins)
	set("Gems", profile.Gems)
	set("Level", profile.Level)
end

local function pushState(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	syncLeaderstats(player, profile)
	RemoteEvents.StateChanged:FireClient(player, {
		Health = profile.Health,
		MaxHealth = profile.MaxHealth,
		Energy = profile.Energy,
		MaxEnergy = profile.MaxEnergy,
		Level = profile.Level,
		XP = profile.XP,
		XPToNext = profile.XPToNext,
		Coins = profile.Coins,
		Gems = profile.Gems,
		Inventory = profile.Inventory,
	})
end

local function load(player: Player)
	local profile = defaultProfile()
	profiles[player] = profile

	if not RunService:IsStudio() then
		local ok, raw = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if ok then
			applyLoaded(profile, raw)
		else
			warn(string.format("[PlayerData] failed to load %d: %s", player.UserId, tostring(raw)))
		end
	end

	pushState(player)
end

local function serialize(profile: Profile): { [string]: any }
	local invCopy: { [string]: number } = {}
	for id, qty in pairs(profile.Inventory) do
		invCopy[tostring(id)] = qty
	end
	return {
		Level = profile.Level,
		XP = profile.XP,
		Coins = profile.Coins,
		Gems = profile.Gems,
		Inventory = invCopy,
	}
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if RunService:IsStudio() then
		return
	end
	local data = serialize(profile)
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn(string.format("[PlayerData] failed to save %d: %s", player.UserId, tostring(err)))
	end
end

function PlayerData.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.AddCurrency(player: Player, coins: number, gems: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	if coins ~= 0 then
		profile.Coins = math.max(0, profile.Coins + coins)
	end
	if gems ~= 0 then
		profile.Gems = math.max(0, profile.Gems + gems)
	end
	pushState(player)
end

function PlayerData.AddXP(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.XP = math.max(0, profile.XP + amount)
	while profile.XP >= profile.XPToNext do
		profile.XP -= profile.XPToNext
		profile.Level += 1
		profile.XPToNext = Constants.XpToLevel(profile.Level)
		profile.MaxHealth = Constants.MaxHealth + (profile.Level - 1) * 5
		profile.MaxEnergy = Constants.MaxEnergy + (profile.Level - 1) * 2
		profile.Health = profile.MaxHealth
		profile.Energy = profile.MaxEnergy
		RemoteEvents.Notify:FireClient(
			player,
			string.format("LEVEL UP! Now level %d", profile.Level),
			Color3.fromRGB(168, 85, 247)
		)
	end
	pushState(player)
end

function PlayerData.SetHealth(player: Player, value: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Health = math.clamp(value, 0, profile.MaxHealth)
	pushState(player)
end

function PlayerData.SetEnergy(player: Player, value: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Energy = math.clamp(value, 0, profile.MaxEnergy)
	pushState(player)
end

function PlayerData.PushState(player: Player)
	pushState(player)
end

function PlayerData.OnPlayerAdded(player: Player)
	ensureLeaderstats(player)
	load(player)
end

function PlayerData.OnPlayerRemoving(player: Player)
	save(player)
	profiles[player] = nil
end

function PlayerData.Init()
	for _, player in Players:GetPlayers() do
		PlayerData.OnPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(PlayerData.OnPlayerAdded)
	Players.PlayerRemoving:Connect(PlayerData.OnPlayerRemoving)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	-- Idle regen: tick every second.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in pairs(profiles) do
				local changed = false
				if profile.Energy < profile.MaxEnergy then
					profile.Energy =
						math.min(profile.MaxEnergy, profile.Energy + Constants.EnergyRegenPerSecond)
					changed = true
				end
				if profile.Health < profile.MaxHealth then
					profile.Health =
						math.min(profile.MaxHealth, profile.Health + Constants.HealthRegenPerSecond)
					changed = true
				end
				if changed then
					pushState(player)
				end
			end
		end
	end)
end

return PlayerData
