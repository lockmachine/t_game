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
	{ unlockLevel = 1, name = "ちいさい雑草", points = 10, colorName = "Bright green", shape = "blade", length = 1.0, diameter = 0.18 },
	{ unlockLevel = 2, name = "ふつうの雑草", points = 20, colorName = "Forest green", shape = "ball", diameter = 1.1 },
	{ unlockLevel = 3, name = "おおきい雑草", points = 35, colorName = "Dark green", shape = "ball", diameter = 1.7 },
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

-- Baseplateや地形の高さがどうであっても正しく置けるように、
-- 上空からレイキャストして実際の地面のY座標を調べる。
local function getGroundY(x, z)
	local rayOrigin = Vector3.new(x, 500, z)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0), raycastParams)
	if result then
		return result.Position.Y
	end
	return 0
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

local RESPAWN_DELAY = 3.5
local FIELD_RADIUS = 9
local FIELD_DEADZONE = 2.5 -- スポーン地点の近くには生やさない

-- 前方宣言。makeWeed/makeForbiddenの中(抜いた後)から呼べるようにしておく。
local spawnWeed
local spawnForbidden

local function makeWeed(tierIndex, x, z)
	local tier = WEED_TIERS[tierIndex]
	local groundY = getGroundY(x, z)
	local part = Instance.new("Part")
	part.Name = "Weed"
	part.Anchored = true
	part.CanCollide = false
	part.BrickColor = BrickColor.new(tier.colorName)
	part.Material = Enum.Material.Grass

	if tier.shape == "blade" then
		-- 細長い円柱を垂直に立てて、葉っぱのような見た目にする。
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(tier.length, tier.diameter, tier.diameter)
		part.Orientation = Vector3.new(0, 0, 90)
		part.Position = Vector3.new(x, groundY + tier.length / 2, z)
	else
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(tier.diameter, tier.diameter, tier.diameter)
		part.Position = Vector3.new(x, groundY + tier.diameter / 2, z)
	end

	part.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = tier.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
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
		task.delay(RESPAWN_DELAY, spawnWeed)
	end)
end

local function makeForbidden(x, z)
	local groundY = getGroundY(x, z)
	local stemLength = 0.8
	local headDiameter = 0.5

	-- 茎(円柱、垂直に立てる)
	local stem = Instance.new("Part")
	stem.Name = "ForbiddenStem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(stemLength, 0.06, 0.06)
	stem.Orientation = Vector3.new(0, 0, 90)
	stem.Position = Vector3.new(x, groundY + stemLength / 2, z)
	stem.BrickColor = BrickColor.new("Forest green")
	stem.Parent = Workspace

	-- 花の頭(光る球体で目立たせる)
	local head = Instance.new("Part")
	head.Name = "Forbidden"
	head.Anchored = true
	head.CanCollide = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(headDiameter, headDiameter, headDiameter)
	head.Position = Vector3.new(x, groundY + stemLength + headDiameter / 2, z)
	head.BrickColor = BrickColor.new("Bright red")
	head.Material = Enum.Material.Neon
	head.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = "おはな(ぬいちゃダメ!)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = head

	prompt.Triggered:Connect(function(player)
		showMessage:FireClient(player, "それはおはな! ぬいちゃダメだよ")
		applyPoints(player, -FORBIDDEN_PENALTY)
		stem:Destroy()
		head:Destroy()
		task.delay(RESPAWN_DELAY, spawnForbidden)
	end)
end

local function randomFieldPosition()
	for _ = 1, 10 do
		local x = (math.random() - 0.5) * 2 * FIELD_RADIUS
		local z = (math.random() - 0.5) * 2 * FIELD_RADIUS
		if math.sqrt(x * x + z * z) > FIELD_DEADZONE then
			return x, z
		end
	end
	return FIELD_RADIUS, FIELD_RADIUS
end

-- 序盤(Lv.1)でも生える雑草を多めにして、レベル2にちゃんと届くようにする。
-- ときどきロック中の大きい雑草も混ぜて、レベルが上がる楽しみを見せておく。
local function pickTierIndex()
	local roll = math.random()
	if roll < 0.6 then
		return 1
	elseif roll < 0.85 then
		return 2
	else
		return 3
	end
end

spawnWeed = function()
	local tierIndex = pickTierIndex()
	local x, z = randomFieldPosition()
	makeWeed(tierIndex, x, z)
end

spawnForbidden = function()
	local x, z = randomFieldPosition()
	makeForbidden(x, z)
end

for _ = 1, 9 do
	spawnWeed()
end
for _ = 1, 3 do
	spawnForbidden()
end
