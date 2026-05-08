--!strict
--
-- Tunables for the RNG katana game. Keep design knobs here so gameplay code
-- stays declarative.

local Constants = {}

-- Auto-roll
Constants.AutoRollIntervalSeconds = 5
Constants.ClickRollCooldownSeconds = 0.25 -- minimum gap between manual rolls
Constants.MaxLuckMultiplier = 50

-- DataStore
Constants.DataStoreName = "RngKatanaProfileV1"
Constants.SaveOnLeavingDelay = 0.1

-- Server-wide announcement (in-chat + HUD ribbon)
Constants.ServerAnnounceDurationSeconds = 8

-- Boost shop
Constants.BoostShop = {
	{ Id = 1, Name = "Lucky Charm", Multiplier = 2, DurationSeconds = 60, Cost = 100 },
	{ Id = 2, Name = "Spirit Surge", Multiplier = 5, DurationSeconds = 30, Cost = 500 },
	{ Id = 3, Name = "Heaven's Gaze", Multiplier = 10, DurationSeconds = 15, Cost = 2500 },
}

-- Maximum number of recent server-wide drops kept in the announcement ribbon.
Constants.MaxRecentAnnouncements = 5

return Constants
