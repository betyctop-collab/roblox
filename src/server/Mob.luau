--!strict
--
-- Lightweight mob: a colored part with a Humanoid for built-in damage handling
-- and a billboard health bar. Spawns somewhere on a ring around `MobSpawnCenter`.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

export type Mob = {
	Model: Model,
	Humanoid: Humanoid,
	Root: Part,
	Damage: number,
	XP: number,
	Coins: number,
	GemChance: number,
	Destroyed: boolean,
}

local Mob = {}

local function buildHealthBar(model: Model, humanoid: Humanoid)
	local bbg = Instance.new("BillboardGui")
	bbg.Name = "Healthbar"
	bbg.Size = UDim2.fromOffset(80, 14)
	bbg.StudsOffset = Vector3.new(0, 3.5, 0)
	bbg.AlwaysOnTop = true
	bbg.LightInfluence = 0
	bbg.Adornee = model.PrimaryPart
	bbg.Parent = model

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	bg.Parent = bbg
	local cBg = Instance.new("UICorner")
	cBg.CornerRadius = UDim.new(0, 6)
	cBg.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local cFill = Instance.new("UICorner")
	cFill.CornerRadius = UDim.new(0, 6)
	cFill.Parent = fill

	humanoid.HealthChanged:Connect(function(h)
		fill.Size = UDim2.fromScale(math.clamp(h / humanoid.MaxHealth, 0, 1), 1)
	end)
end

local function spawnPosition(): Vector3
	local angle = math.random() * math.pi * 2
	local r = Constants.MobSpawnRadius * (0.6 + math.random() * 0.4)
	return Constants.MobSpawnCenter + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

function Mob.new(wave: number): Mob
	local scaling = 1 + (wave - 1) * Constants.MobScalingPerWave
	local maxHp = math.floor(Constants.MobBaseHealth * scaling)
	local damage = math.floor(8 * scaling)

	local model = Instance.new("Model")
	model.Name = "Mob"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4, 2)
	root.Position = spawnPosition() + Vector3.new(0, 2, 0)
	root.Anchored = false
	root.Material = Enum.Material.SmoothPlastic
	root.Color = Color3.fromRGB(168, 85, 247)
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = maxHp
	humanoid.Health = maxHp
	humanoid.WalkSpeed = Constants.MobBaseSpeed
	humanoid.AutoRotate = true
	humanoid.RequiresNeck = false
	humanoid.HipHeight = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	-- Attach a name above the mob so players see who they're fighting.
	local nameTag = Instance.new("BillboardGui")
	nameTag.Size = UDim2.fromOffset(120, 18)
	nameTag.StudsOffset = Vector3.new(0, 4.8, 0)
	nameTag.AlwaysOnTop = true
	nameTag.Adornee = root
	nameTag.Parent = model
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = string.format("MOB Lv%d", wave)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextSize = 14
	nameLabel.Parent = nameTag

	buildHealthBar(model, humanoid)

	model.Parent = workspace

	local mob: Mob = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Damage = damage,
		XP = Constants.XpRewardPerKill,
		Coins = Constants.CoinsPerKill,
		GemChance = Constants.GemDropChance,
		Destroyed = false,
	}

	-- Simple AI: every second, walk toward the nearest player.
	task.spawn(function()
		while not mob.Destroyed and humanoid.Parent and humanoid.Health > 0 do
			task.wait(0.7)
			local nearest: Vector3? = nil
			local nearestDist = math.huge
			for _, plr in Players:GetPlayers() do
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local d = (hrp.Position - root.Position).Magnitude
					if d < nearestDist then
						nearestDist = d
						nearest = hrp.Position
					end
				end
			end
			if nearest then
				humanoid:MoveTo(nearest)
			end
		end
	end)

	return mob
end

function Mob.Destroy(mob: Mob)
	if mob.Destroyed then
		return
	end
	mob.Destroyed = true
	if mob.Model and mob.Model.Parent then
		mob.Model:Destroy()
	end
end

-- Suppress unused-import warning for PathfindingService — kept for future use.
local _ = PathfindingService

return Mob
