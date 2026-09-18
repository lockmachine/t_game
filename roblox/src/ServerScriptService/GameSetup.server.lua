-- 雑草ぬきゲームの最小プロトタイプ(Roblox版)。
-- ブラウザ版と同じ核となるルール: 雑草に近づいてぬくとポイントが増え、
-- おはな(抜いてはいけないもの)をぬくとポイントが減る。
-- レベル・複数の雑草種類・見た目の作り込みは次のステップで追加していく。

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WEED_POINTS = 10
local FORBIDDEN_PENALTY = 15

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = leaderstats

	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = 0
	points.Parent = leaderstats
end)

local function addPoints(player, delta)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local points = leaderstats:FindFirstChild("Points")
	if points then
		points.Value = math.max(0, points.Value + delta)
	end
end

local function makeWeed(groundPosition)
	local part = Instance.new("Part")
	part.Name = "Weed"
	part.Size = Vector3.new(0.6, 1.2, 0.6)
	part.Position = groundPosition + Vector3.new(0, 0.6, 0)
	part.Anchored = true
	part.BrickColor = BrickColor.new("Bright green")
	part.Material = Enum.Material.Grass
	part.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = "ざっそう"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		addPoints(player, WEED_POINTS)
		part:Destroy()
	end)
end

local function makeForbidden(groundPosition)
	local part = Instance.new("Part")
	part.Name = "Forbidden"
	part.Size = Vector3.new(0.8, 1.4, 0.8)
	part.Position = groundPosition + Vector3.new(0, 0.7, 0)
	part.Anchored = true
	part.BrickColor = BrickColor.new("Bright red")
	part.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = "おはな(ぬいちゃダメ!)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		addPoints(player, -FORBIDDEN_PENALTY)
		part:Destroy()
	end)
end

makeWeed(Vector3.new(5, 0, 5))
makeWeed(Vector3.new(-4, 0, 3))
makeWeed(Vector3.new(2, 0, -6))
makeWeed(Vector3.new(-6, 0, -4))
makeForbidden(Vector3.new(0, 0, 8))
makeForbidden(Vector3.new(-2, 0, -8))
