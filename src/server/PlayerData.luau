--!strict
--
-- Player profile management with DataStore persistence.
--
-- Profile shape (anything else is forbidden — keeps DataStore migrations sane):
--   Inventory  : { [itemId: number]: count: number }
--   TotalRolls : number
--   Coins      : number
--   BestItemId : number     (0 = none rolled yet)
--   Luck       : number     (1.0 = base; raised by boosts)
--   Boosts     : { { Multiplier, ExpiresAt } }
--   NextRollAt : number     (server clock seconds; not persisted)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
local Rarities = require(game:GetService("ReplicatedStorage").Shared.Rarities)
local RemoteEvents = require(game:GetService("ReplicatedStorage").Shared.RemoteEvents)

export type ActiveBoost = {
	Multiplier: number,
	ExpiresAt: number,
}

export type Profile = {
	Inventory: { [number]: number },
	TotalRolls: number,
	Coins: number,
	BestItemId: number,
	Luck: number,
	Boosts: { ActiveBoost },
	NextRollAt: number,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local store = DataStoreService:GetDataStore(Constants.DataStoreName)

local function defaultProfile(): Profile
	return {
		Inventory = {},
		TotalRolls = 0,
		Coins = 0,
		BestItemId = 0,
		Luck = 1,
		Boosts = {},
		NextRollAt = 0,
	}
end

local function clamp(n: number, lo: number, hi: number): number
	if n < lo then
		return lo
	end
	if n > hi then
		return hi
	end
	return n
end

local function sanitizeInventory(raw: any): { [number]: number }
	if type(raw) ~= "table" then
		return {}
	end
	local clean: { [number]: number } = {}
	for k, v in pairs(raw :: any) do
		local id = tonumber(k)
		local count = tonumber(v)
		if id and count and Items.ById[id] then
			clean[id] = clamp(math.floor(count), 0, 999999999)
		end
	end
	return clean
end

local function bestRarityIdFromInventory(inv: { [number]: number }): number
	local best = 0
	for id, count in pairs(inv) do
		if count > 0 then
			local item = Items.ById[id]
			if item then
				local rarity = Rarities.ByKey[item.RarityKey]
				if rarity and rarity.Id > best then
					best = rarity.Id
				end
			end
		end
	end
	return best
end

local function deserialize(raw: any): Profile
	local p = defaultProfile()
	if type(raw) ~= "table" then
		return p
	end
	p.Inventory = sanitizeInventory(raw.Inventory)
	p.TotalRolls = clamp(tonumber(raw.TotalRolls) or 0, 0, 1e12)
	p.Coins = clamp(tonumber(raw.Coins) or 0, 0, 1e12)
	p.BestItemId = tonumber(raw.BestItemId) or 0
	if not Items.ById[p.BestItemId] then
		p.BestItemId = 0
	end
	return p
end

local function serialize(p: Profile): any
	return {
		Inventory = p.Inventory,
		TotalRolls = p.TotalRolls,
		Coins = p.Coins,
		BestItemId = p.BestItemId,
	}
end

local function buildLeaderstats(player: Player, p: Profile)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local rolls = Instance.new("IntValue")
	rolls.Name = "Rolls"
	rolls.Value = p.TotalRolls
	rolls.Parent = folder

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = p.Coins
	coins.Parent = folder

	local best = Instance.new("StringValue")
	best.Name = "Best"
	local item = Items.ById[p.BestItemId]
	if item then
		best.Value = item.Name
	else
		best.Value = "—"
	end
	best.Parent = folder

	folder.Parent = player
end

local function refreshLeaderstats(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local rolls = ls:FindFirstChild("Rolls")
	local coins = ls:FindFirstChild("Coins")
	local best = ls:FindFirstChild("Best")
	if rolls and rolls:IsA("IntValue") then
		rolls.Value = p.TotalRolls
	end
	if coins and coins:IsA("IntValue") then
		coins.Value = p.Coins
	end
	if best and best:IsA("StringValue") then
		local item = Items.ById[p.BestItemId]
		best.Value = item and item.Name or "—"
	end
end

function PlayerData.Get(player: Player): Profile?
	return profiles[player]
end

local function activeMultiplier(p: Profile): number
	local now = os.clock()
	local mult = 1
	for _, boost in p.Boosts do
		if boost.ExpiresAt > now then
			if boost.Multiplier > mult then
				mult = boost.Multiplier
			end
		end
	end
	return clamp(mult, 1, Constants.MaxLuckMultiplier)
end

function PlayerData.GetEffectiveLuck(player: Player): number
	local p = profiles[player]
	if not p then
		return 1
	end
	return p.Luck * activeMultiplier(p)
end

function PlayerData.PushState(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	local boosts = {}
	local now = os.clock()
	for _, b in p.Boosts do
		if b.ExpiresAt > now then
			table.insert(boosts, {
				Multiplier = b.Multiplier,
				SecondsLeft = math.max(0, b.ExpiresAt - now),
			})
		end
	end
	local snapshot = {
		Inventory = p.Inventory,
		TotalRolls = p.TotalRolls,
		Coins = p.Coins,
		BestItemId = p.BestItemId,
		Luck = p.Luck,
		EffectiveLuck = activeMultiplier(p) * p.Luck,
		Boosts = boosts,
		NextRollAt = p.NextRollAt,
		ServerNow = now,
	}
	RemoteEvents.StateChanged:FireClient(player, snapshot)
end

function PlayerData.AddItem(player: Player, itemId: number)
	local p = profiles[player]
	if not p then
		return
	end
	local item = Items.ById[itemId]
	if not item then
		return
	end
	p.Inventory[itemId] = (p.Inventory[itemId] or 0) + 1

	local rarity = Rarities.ByKey[item.RarityKey]
	if rarity then
		local prevBest = Items.ById[p.BestItemId]
		local prevBestRarity = prevBest and Rarities.ByKey[prevBest.RarityKey]
		if not prevBestRarity or rarity.Id > prevBestRarity.Id then
			p.BestItemId = itemId
		end
	end
	-- BestItemId might also be due to a previously empty inventory; rebuild
	-- conservatively if needed.
	if p.BestItemId == 0 then
		p.BestItemId = bestRarityIdFromInventory(p.Inventory)
	end
end

function PlayerData.AddCoins(player: Player, amount: number)
	local p = profiles[player]
	if not p or amount <= 0 then
		return
	end
	p.Coins = clamp(p.Coins + math.floor(amount), 0, 1e12)
end

function PlayerData.IncrementRolls(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	p.TotalRolls += 1
end

function PlayerData.SetNextRollAt(player: Player, t: number)
	local p = profiles[player]
	if not p then
		return
	end
	p.NextRollAt = t
end

function PlayerData.AddBoost(player: Player, multiplier: number, durationSeconds: number)
	local p = profiles[player]
	if not p then
		return
	end
	table.insert(p.Boosts, {
		Multiplier = multiplier,
		ExpiresAt = os.clock() + durationSeconds,
	})
end

function PlayerData.SpendCoins(player: Player, cost: number): boolean
	local p = profiles[player]
	if not p or cost <= 0 then
		return false
	end
	if p.Coins < cost then
		return false
	end
	p.Coins -= cost
	return true
end

local function load(player: Player): Profile
	if not RunService:IsStudio() and player.UserId > 0 then
		local key = "u_" .. tostring(player.UserId)
		local ok, raw = pcall(function()
			return store:GetAsync(key)
		end)
		if ok and raw then
			return deserialize(raw)
		end
	end
	return defaultProfile()
end

local function save(player: Player)
	if RunService:IsStudio() then
		return
	end
	if player.UserId <= 0 then
		return
	end
	local p = profiles[player]
	if not p then
		return
	end
	local key = "u_" .. tostring(player.UserId)
	pcall(function()
		store:UpdateAsync(key, function()
			return serialize(p)
		end)
	end)
end

function PlayerData.OnPlayerAdded(player: Player)
	local p = load(player)
	profiles[player] = p
	buildLeaderstats(player, p)
	-- Push a fresh snapshot once the client is ready. The client also asks
	-- for state on connect, but this guarantees timely state.
	task.defer(PlayerData.PushState, player)
end

function PlayerData.OnPlayerRemoving(player: Player)
	save(player)
	profiles[player] = nil
end

local function janitorLoop()
	while true do
		task.wait(1)
		for player, p in pairs(profiles) do
			-- Drop expired boosts so the snapshot stays clean.
			local now = os.clock()
			local kept: { ActiveBoost } = {}
			local changed = false
			for _, b in p.Boosts do
				if b.ExpiresAt > now then
					table.insert(kept, b)
				else
					changed = true
				end
			end
			if changed then
				p.Boosts = kept
				PlayerData.PushState(player)
			end
		end
	end
end

local function autosaveLoop()
	while true do
		task.wait(60)
		for player, _ in pairs(profiles) do
			save(player)
		end
	end
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
	task.spawn(janitorLoop)
	task.spawn(autosaveLoop)
end

PlayerData.RefreshLeaderstats = refreshLeaderstats

return PlayerData
