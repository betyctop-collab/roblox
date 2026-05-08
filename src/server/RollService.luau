--!strict
--
-- Drives the RNG roll loop.
--
-- Each player has a `NextRollAt` timestamp on their profile. The auto-roll
-- loop ticks every 0.25s and rolls for any player whose timer has elapsed.
-- Manual rolls (Action "Roll" remote) are subject to a separate cooldown
-- (`Constants.ClickRollCooldownSeconds`) and reset the auto-roll timer so the
-- player doesn't double-spend.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Items)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local PlayerData = require(script.Parent.PlayerData)

local RollService = {}

local rng = Random.new()

-- Rolls a rarity by walking from rarest to most common and returning on the
-- first hit. The `Common` tier is the catch-all so it never misses.
local function rollRarity(luck: number)
	luck = math.max(1, luck)
	for _, tier in Rarities.OrderRarestFirst do
		if tier.Key == "Common" then
			return tier
		end
		local chance = (1 / tier.OneIn) * luck
		if chance >= 1 then
			return tier
		end
		if rng:NextNumber() < chance then
			return tier
		end
	end
	return Rarities.Common
end

local function pickItem(rarityKey: string)
	local pool = Items.ByRarity[rarityKey]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local lastManualRollAt: { [Player]: number } = {}

local function performRoll(player: Player, manual: boolean)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local luck = PlayerData.GetEffectiveLuck(player)
	local rarity = rollRarity(luck)
	local item = pickItem(rarity.Key)
	if not item then
		return
	end

	PlayerData.AddItem(player, item.Id)
	PlayerData.AddCoins(player, rarity.Reward)
	PlayerData.IncrementRolls(player)
	PlayerData.SetNextRollAt(player, os.clock() + Constants.AutoRollIntervalSeconds)
	PlayerData.RefreshLeaderstats(player)

	RemoteEvents.RollResult:FireClient(player, {
		ItemId = item.Id,
		ItemName = item.Name,
		Lore = item.Lore,
		RarityKey = rarity.Key,
		RarityName = rarity.Name,
		OneIn = rarity.OneIn,
		Reward = rarity.Reward,
		Manual = manual,
	})
	PlayerData.PushState(player)

	if rarity.ServerWideAnnounce then
		local payload = {
			PlayerName = player.DisplayName ~= "" and player.DisplayName or player.Name,
			ItemName = item.Name,
			RarityKey = rarity.Key,
			RarityName = rarity.Name,
			OneIn = rarity.OneIn,
			At = os.time(),
		}
		RemoteEvents.GlobalAnnounce:FireAllClients(payload)
	end
end

local function tryManualRoll(player: Player)
	local now = os.clock()
	local last = lastManualRollAt[player] or 0
	if now - last < Constants.ClickRollCooldownSeconds then
		return
	end
	lastManualRollAt[player] = now
	performRoll(player, true)
end

local function tryBuyBoost(player: Player, boostId: number)
	local entry
	for _, e in Constants.BoostShop do
		if e.Id == boostId then
			entry = e
			break
		end
	end
	if not entry then
		return
	end
	if not PlayerData.SpendCoins(player, entry.Cost) then
		RemoteEvents.Notify:FireClient(player, {
			Text = "Not enough coins for " .. entry.Name,
			Color = Color3.fromRGB(239, 68, 68),
		})
		return
	end
	PlayerData.AddBoost(player, entry.Multiplier, entry.DurationSeconds)
	RemoteEvents.Notify:FireClient(player, {
		Text = string.format(
			"%s active: x%d luck for %ds",
			entry.Name,
			entry.Multiplier,
			entry.DurationSeconds
		),
		Color = Color3.fromRGB(250, 204, 21),
	})
	PlayerData.PushState(player)
end

local function autoRollLoop()
	while true do
		task.wait(0.25)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local profile = PlayerData.Get(player)
			if profile and profile.NextRollAt <= now then
				performRoll(player, false)
			end
		end
	end
end

function RollService.Init()
	RemoteEvents.Action.OnServerEvent:Connect(function(player: Player, action: string, payload: any)
		if typeof(action) ~= "string" then
			return
		end
		if action == "Roll" then
			tryManualRoll(player)
		elseif action == "RequestState" then
			PlayerData.PushState(player)
		elseif action == "BuyBoost" then
			if typeof(payload) == "number" then
				tryBuyBoost(player, payload)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastManualRollAt[player] = nil
	end)
	task.spawn(autoRollLoop)
end

return RollService
