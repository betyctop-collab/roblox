--!strict
--
-- Client bootstrap. Builds the HUD once the local player has a PlayerGui.
-- The HUD module also sets up the modal `ScreenGui` instances, RemoteEvent
-- listeners, and keyboard shortcuts.

local Players = game:GetService("Players")

local HUD = require(script.HUD)

local player = Players.LocalPlayer
if not player then
	-- Wait for the local player on cold-start (rare on PlayerScripts).
	repeat
		player = Players.LocalPlayer
		task.wait()
	until player
end

HUD.new(player)
