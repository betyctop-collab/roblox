--!strict
--
-- Client bootstrap. Builds the HUD and keeps it in sync with server state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

local script = script :: Script
local HUD = require(script:WaitForChild("HUD"))

local player = Players.LocalPlayer :: Player
local hud = HUD.new(player)

RemoteEvents.StateChanged.OnClientEvent:Connect(function(state)
	hud:SetState(state)
end)

RemoteEvents.Notify.OnClientEvent:Connect(function(text: string, color: Color3?)
	-- Quick-and-dirty notification: a green/red toast at the top of the screen.
	local screen = player:WaitForChild("PlayerGui"):FindFirstChild("GameHUD") :: ScreenGui?
	if not screen then
		return
	end
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 12)
	toast.Size = UDim2.fromOffset(360, 36)
	toast.BackgroundColor3 = color or Color3.fromRGB(34, 197, 94)
	toast.BackgroundTransparency = 0.1
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.Text = text
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.TextSize = 16
	toast.ZIndex = 200
	toast.Parent = screen
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = toast
	task.delay(2.5, function()
		toast:Destroy()
	end)
end)
