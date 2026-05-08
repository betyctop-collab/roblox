--!strict
--
-- Lazy-built `RemoteEvent` folder under ReplicatedStorage. Both server and
-- client `require` this module to obtain typed handles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RngKatanaRemotes"

local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function ensureRemote(name: string): RemoteEvent
	local folder = ensureFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local RemoteEvents = {
	-- Server -> client: full profile snapshot
	StateChanged = ensureRemote("StateChanged"),
	-- Server -> client: a roll just resolved for *this* client
	RollResult = ensureRemote("RollResult"),
	-- Server -> all clients: someone rolled a Mythic+
	GlobalAnnounce = ensureRemote("GlobalAnnounce"),
	-- Client -> server: actions (Roll, BuyBoost, etc.)
	Action = ensureRemote("Action"),
	-- Server -> client: ad-hoc toast notification
	Notify = ensureRemote("Notify"),
}

return RemoteEvents
