--!strict
-- Lazy folder of RemoteEvents inside ReplicatedStorage.Shared.
-- Server creates them on require, client just reads them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvents = {}

local NAMES = {
	"StateChanged", -- server -> client: full player profile snapshot
	"Action", -- client -> server: ("Attack" | "Defend" | "OpenInventory" | ...)
	"Notify", -- server -> client: ("text", color3?)
}

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local folder = sharedFolder:FindFirstChild("RemoteEvents")

if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RemoteEvents"
		folder.Parent = sharedFolder
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
else
	folder = sharedFolder:WaitForChild("RemoteEvents")
end

for _, name in ipairs(NAMES) do
	local child = folder:WaitForChild(name)
	assert(child:IsA("RemoteEvent"), `expected {name} to be RemoteEvent`)
	RemoteEvents[name] = child
end

return RemoteEvents
