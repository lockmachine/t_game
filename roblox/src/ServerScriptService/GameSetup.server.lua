-- 雑草ぬきゲーム(Roblox版)。
-- ポイントを貯めるとレベルが上がり、レベルが足りない雑草・道具は使えない。
-- おはな(抜いてはいけないもの)を抜くとポイントが減り、レベルが下がることもある。
-- 中身(雑草・抜いてはいけないもの・道具の一覧)はReplicatedStorage/GameConfig.luaにまとめてある。

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local InsertService = game:GetService("InsertService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- 進捗の保存。Studioでテストする場合は、ゲーム設定の「セキュリティ」タブで
-- 「Studio内でのAPIサービスへのアクセスを有効にする」をONにしないと保存/読込が失敗する。
local progressStore = DataStoreService:GetDataStore("ZassouProgress_v1")

local function loadPoints(player)
	local key = "player_" .. player.UserId
	local success, data = pcall(function()
		return progressStore:GetAsync(key)
	end)
	if success and data then
		return data.points or 0
	end
	return 0
end

local function saveProgress(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local points = leaderstats:FindFirstChild("Points")
	if not points then
		return
	end
	local key = "player_" .. player.UserId
	local success, err = pcall(function()
		progressStore:SetAsync(key, { points = points.Value })
	end)
	if not success then
		warn("進捗の保存に失敗しました: " .. tostring(err))
	end
end

local showMessage = Instance.new("RemoteEvent")
showMessage.Name = "ShowMessage"
showMessage.Parent = ReplicatedStorage

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

-- ---------- Creator Store(トイボックス)アセットの読み込み・安全確認 ----------
-- 無料モデルにScript/LocalScript/ModuleScriptが仕込まれているケース(バックドア等)への
-- 対策として、読み込んだ直後にそれらを機械的にすべて削除する。1回読み込んだら
-- サニタイズ済みのテンプレートとして使い回す(毎回読み込み直さない)。
local ASSET_TEMPLATES = {}

local function loadSanitizedAsset(assetId)
	local success, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not success then
		warn("[アセット] " .. tostring(assetId) .. " の読み込みに失敗しました: " .. tostring(result))
		return nil
	end

	local removed = 0
	for _, descendant in ipairs(result:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			warn("[セキュリティ] アセット " .. tostring(assetId) .. " 内のスクリプトを検出・削除しました: " .. descendant:GetFullName())
			descendant:Destroy()
			removed += 1
		end
	end
	if removed == 0 then
		print("[アセット] " .. tostring(assetId) .. " を読み込みました。スクリプトは見つかりませんでした。")
	else
		warn("[セキュリティ] アセット " .. tostring(assetId) .. " から合計 " .. removed .. " 個のスクリプトを削除しました。見た目に問題がないか確認してください。")
	end
	return result
end

local function preloadAssetsFromTierList(list)
	for _, entry in ipairs(list) do
		if entry.assetId and not ASSET_TEMPLATES[entry.assetId] then
			ASSET_TEMPLATES[entry.assetId] = loadSanitizedAsset(entry.assetId)
		end
	end
end

preloadAssetsFromTierList(GameConfig.WEED_TIERS)

-- アセットモデルを置き、当たり判定(ProximityPrompt置き場)として
-- モデル全体を包む透明な箱を別に用意する。モデルの中身がどんな構造でも
-- (パーツが1個でも複数でも、名前が何でも)確実に反応するようにするため。
local function placeAssetModel(template, x, z, groundY)
	local model = template:Clone()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	model.Parent = Workspace
	model:MoveTo(Vector3.new(x, groundY, z))

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(math.max(boundsSize.X, 1), math.max(boundsSize.Y, 1), math.max(boundsSize.Z, 1))
	hitbox.CFrame = boundsCFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.Anchored = true
	hitbox.Parent = model

	return model, hitbox
end

-- ---------- 道具の自動装着 ----------
local function attachTool(character, tool)
	local old = character:FindFirstChild("EquippedTool")
	if old then
		old:Destroy()
	end

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end

	local part = Instance.new("Part")
	part.Name = "EquippedTool"
	part.Size = tool.size
	part.Color = tool.color
	part.Material = Enum.Material.Plastic
	part.CanCollide = false
	part.Massless = true
	part.CFrame = hand.CFrame * CFrame.new(0, -(hand.Size.Y / 2 + tool.size.Y / 2), 0)
	part.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
end

local function updateEquippedTool(player)
	local character = player.Character
	if not character then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if not levelValue then
		return
	end
	local tool = GameConfig.toolForLevel(levelValue.Value)
	attachTool(character, tool)
end

Players.PlayerAdded:Connect(function(player)
	local savedPoints = loadPoints(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = GameConfig.computeLevel(savedPoints)
	level.Parent = leaderstats

	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = savedPoints
	points.Parent = leaderstats

	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- キャラクターの各パーツが揃うのを少し待つ
		updateEquippedTool(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveProgress(player)
end)

-- 予期しない切断やStudioの再生停止に備えて、定期的にも保存しておく。
task.spawn(function()
	while true do
		task.wait(90)
		for _, player in ipairs(Players:GetPlayers()) do
			saveProgress(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveProgress(player)
	end
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
	local newLevel = GameConfig.computeLevel(pointsValue.Value)
	levelValue.Value = newLevel

	if newLevel > beforeLevel then
		showMessage:FireClient(player, "レベルアップ! Lv." .. newLevel .. " になった!")
		updateEquippedTool(player)
	elseif newLevel < beforeLevel then
		showMessage:FireClient(player, "ポイントが へって Lv." .. newLevel .. " に もどっちゃった…")
		updateEquippedTool(player)
	end
end

local RESPAWN_DELAY = 3.5
local FIELD_RADIUS = 14
local FIELD_DEADZONE = 2.5 -- スポーン地点の近くには生やさない

-- 前方宣言。makeWeed/makeForbiddenの中(抜いた後)から呼べるようにしておく。
local spawnWeed
local spawnForbidden

local function highestOnlineLevel()
	local highest = 1
	for _, player in ipairs(Players:GetPlayers()) do
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
		if levelValue and levelValue.Value > highest then
			highest = levelValue.Value
		end
	end
	return highest
end

local function makeWeed(tierIndex, x, z)
	local tier = GameConfig.WEED_TIERS[tierIndex]
	local groundY = getGroundY(x, z)
	local instanceRoot
	local promptAnchor

	local template = tier.assetId and ASSET_TEMPLATES[tier.assetId]
	if template then
		instanceRoot, promptAnchor = placeAssetModel(template, x, z, groundY)
	end

	if not instanceRoot then
		-- アセットが無い/読み込めなかった場合は、これまで通り図形で代用する。
		local part = Instance.new("Part")
		part.Name = "Weed"
		part.Anchored = true
		part.CanCollide = false
		part.Color = tier.color

		if tier.shape == "blade" then
			-- 細長い円柱を垂直に立てて、葉っぱや柱のような見た目にする。
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(tier.length, tier.diameter, tier.diameter)
			part.Orientation = Vector3.new(0, 0, 90)
			part.Position = Vector3.new(x, groundY + tier.length / 2, z)
		elseif tier.shape == "ball" then
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(tier.diameter, tier.diameter, tier.diameter)
			part.Position = Vector3.new(x, groundY + tier.diameter / 2, z)
		else -- "block"
			part.Size = tier.size
			part.Position = Vector3.new(x, groundY + tier.size.Y / 2, z)
		end

		part.Parent = Workspace
		instanceRoot = part
		promptAnchor = part
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = tier.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

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
		instanceRoot:Destroy()
		task.delay(RESPAWN_DELAY, spawnWeed)
	end)
end

-- 「抜いてはいけないもの」は柱+上に乗るパーツ(pole)、または単一パーツ(single)で表現する。
local function makeForbidden(typeIndex, x, z)
	local spec = GameConfig.FORBIDDEN_TYPES[typeIndex]
	local groundY = getGroundY(x, z)
	local parts = {}

	if spec.kind == "pole" then
		local pole = Instance.new("Part")
		pole.Name = "ForbiddenPole"
		pole.Anchored = true
		pole.CanCollide = false
		pole.Shape = Enum.PartType.Cylinder
		pole.Size = Vector3.new(spec.poleHeight, spec.poleDiameter, spec.poleDiameter)
		pole.Orientation = Vector3.new(0, 0, 90)
		pole.Position = Vector3.new(x, groundY + spec.poleHeight / 2, z)
		pole.Color = spec.poleColor
		pole.Parent = Workspace
		table.insert(parts, pole)

		local topper = Instance.new("Part")
		topper.Name = "Forbidden"
		topper.Anchored = true
		topper.CanCollide = false
		if spec.topperShape == "ball" then
			topper.Shape = Enum.PartType.Ball
		end
		topper.Size = spec.topperSize
		topper.Position = Vector3.new(x, groundY + spec.poleHeight + spec.topperSize.Y / 2, z)
		topper.Color = spec.topperColor
		if spec.glow then
			topper.Material = Enum.Material.Neon
		end
		topper.Parent = Workspace
		table.insert(parts, topper)
	else -- "single"
		local single = Instance.new("Part")
		single.Name = "Forbidden"
		single.Anchored = true
		single.CanCollide = false
		if spec.shape == "ball" then
			single.Shape = Enum.PartType.Ball
		end
		single.Size = spec.size
		single.Position = Vector3.new(x, groundY + spec.size.Y / 2, z)
		single.Color = spec.color
		single.Parent = Workspace
		table.insert(parts, single)
	end

	local promptPart = parts[#parts]
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ぬく"
	prompt.ObjectText = spec.name .. "(ぬいちゃダメ!)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	prompt.Triggered:Connect(function(player)
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Level")

		if levelValue and levelValue.Value < spec.unlockLevel then
			showMessage:FireClient(player, "まだ Lv." .. spec.unlockLevel .. " にならないと、これは反応しないみたい")
			return
		end

		showMessage:FireClient(player, "それは" .. spec.name .. "! ぬいちゃダメだよ")
		applyPoints(player, -spec.penalty)
		for _, p in ipairs(parts) do
			p:Destroy()
		end
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

-- 序盤でも生える雑草を多めにして、レベルアップがちゃんと体感できるようにする。
-- 今いるプレイヤーの最高レベルを基準に、ときどき1段上のものも混ぜて見せておく。
local function pickTierIndex(level)
	local maxUnlocked = 1
	for i, tier in ipairs(GameConfig.WEED_TIERS) do
		if tier.unlockLevel <= level then
			maxUnlocked = i
		end
	end
	local upper = math.min(maxUnlocked + 1, #GameConfig.WEED_TIERS)
	local roll = math.random()
	if roll < 0.18 and upper > maxUnlocked then
		return upper
	end
	return math.random(1, maxUnlocked)
end

local function pickForbiddenTypeIndex(level)
	local maxUnlocked = 1
	for i, spec in ipairs(GameConfig.FORBIDDEN_TYPES) do
		if spec.unlockLevel <= level then
			maxUnlocked = i
		end
	end
	local upper = math.min(maxUnlocked + 1, #GameConfig.FORBIDDEN_TYPES)
	local roll = math.random()
	if roll < 0.2 and upper > maxUnlocked then
		return upper
	end
	return math.random(1, maxUnlocked)
end

spawnWeed = function()
	local level = highestOnlineLevel()
	local tierIndex = pickTierIndex(level)
	local x, z = randomFieldPosition()
	makeWeed(tierIndex, x, z)
end

spawnForbidden = function()
	local level = highestOnlineLevel()
	local typeIndex = pickForbiddenTypeIndex(level)
	local x, z = randomFieldPosition()
	makeForbidden(typeIndex, x, z)
end

for _ = 1, 14 do
	spawnWeed()
end
for _ = 1, 4 do
	spawnForbidden()
end
