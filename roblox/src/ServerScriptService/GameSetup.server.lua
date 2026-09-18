-- 雑草ぬきゲーム(Roblox版)。ブラウザ版と同じルールを再現している:
-- ポイントを貯めるとレベルが上がり、レベルが足りない雑草は抜けない。
-- おはな(抜いてはいけないもの)を抜くとポイントが減り、レベルが下がることもある。

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local showMessage = Instance.new("RemoteEvent")
showMessage.Name = "ShowMessage"
showMessage.Parent = ReplicatedStorage

local WEED_TIERS = {
	{ unlockLevel = 1, name = "ちいさい雑草", points = 10, colorName = "Bright green", size = Vector3.new(0.6, 1.2, 0.6) },
	{ unlockLevel = 2, name = "ふつうの雑草", points = 20, colorName = "Forest green", size = Vector3.new(0.9, 1.8, 0.9) },
	{ unlockLevel = 3, name = "おおきい雑草", points = 35, colorName = "Dark green", size = Vector3.new(1.3, 2.6, 1.3) },
}

local FORBIDDEN_PENALTY = 15

local LEVELS = {
	{ level = 1, needPoints = 0 },
	{ level = 2, needPoints = 50 },
	{ level = 3, needPoints = 130 },
}

local function computeLevel(points)
	local level = 1
	for _, entry in ipairs(LEVELS) do
		if points >= entry.needPoints then
			level = entry.level
		end
	end
	return level
end

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

local function applyPoints(player, delta)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local pointsValue = leaderstats:FindFirstChild("Points")
	local levelValue = leaderstats:FindFirstChild("Level")
	if not pointsValue or not levelValue then
		return
	end

	local beforeLevel = levelValue.Value
	pointsValue.Value = math.max(0, pointsValue.Value + delta)
	local newLevel = computeLevel(pointsValue.Value)
	levelValue.Value = newLevel

	if newLevel > beforeLevel then
		showMessage:FireClient(player, "レベルアップ! Lv." .. newLevel .. " になった!")
	elseif newLevel < beforeLevel then
		showMessage:FireClient(player, "ポイントが へって Lv." .. newLevel .. " に もどっちゃった…")
	end
end

local function makeWeed(tierIndex, groundPosition)
	local tier = WEED_TIERS[tierIndex]
	local part = Instance.new("Part")
	part.Name = "Weed"
	part.Size = tier.size
	part.Position = groundPosition + Vector3.new(0, tier.size.Y / 2, 0)
	part.Anchored = true
	part.BrickColor = BrickColor.new(tier.colorName)
	part.Material = Enum.Material.Grass
	part.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = tier.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
		if not levelValue then
			return
		end

		if levelValue.Value < tier.unlockLevel then
			showMessage:FireClient(player, "まだ Lv." .. tier.unlockLevel .. " にならないと ぬけないよ")
			return
		end

		applyPoints(player, tier.points)
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
		showMessage:FireClient(player, "それはおはな! ぬいちゃダメだよ")
		applyPoints(player, -FORBIDDEN_PENALTY)
		part:Destroy()
	end)
end

makeWeed(1, Vector3.new(5, 0, 5))
makeWeed(1, Vector3.new(-4, 0, 3))
makeWeed(1, Vector3.new(3, 0, -3))
makeWeed(2, Vector3.new(2, 0, -6))
makeWeed(2, Vector3.new(-6, 0, -4))
makeWeed(3, Vector3.new(6, 0, -7))
makeForbidden(Vector3.new(0, 0, 8))
makeForbidden(Vector3.new(-2, 0, -8))
