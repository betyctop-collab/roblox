--!strict
--
-- Server bootstrap. Builds the visual map, then wires up player profiles
-- and the roll service.

local PlayerData = require(script.PlayerData)
local RollService = require(script.RollService)
local World = require(script.World)

World.Build()
PlayerData.Init()
RollService.Init()
