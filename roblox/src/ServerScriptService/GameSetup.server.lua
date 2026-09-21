-- 雑草ぬきゲーム(Roblox版)。
-- ポイントを貯めるとレベルが上がり、レベルが足りない雑草・道具は使えない。
-- おはな(抜いてはいけないもの)を抜くとポイントが減り、レベルが下がることもある。
-- 中身(雑草・抜いてはいけないもの・道具の一覧)はReplicatedStorage/GameConfig.luaにまとめてある。
--
-- 順番についての注意: Players.PlayerAdded の接続は、通信を伴う処理(DataStore・
-- アセット読み込みなど)より必ず先に済ませること。先に時間のかかる処理を書くと、
-- その待ち時間の間にプレイヤーが参加してしまい、参加イベントを取りこぼして
-- leaderstatsが一生作られない、という不具合が起きる(実際に一度起きた)。

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- 進捗の保存。Studio上のテスト再生ではDataStoreへのアクセスが許可されておらず、
-- 毎回エラーになってしまうため、Studio上では保存処理そのものをスキップする
-- (0ポイントから始まり、保存もされない=テスト用の割り切り)。
-- 本当に保存されるかどうかはRobloxに公開した本番環境で確認すること。
local IS_STUDIO = RunService:IsStudio()
local progressStore = DataStoreService:GetDataStore("ZassouProgress_v1")

local function loadPoints(player)
	if IS_STUDIO then
		return 0
	end
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
	if IS_STUDIO then
		return
	end
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

local attackRequest = Instance.new("RemoteEvent")
attackRequest.Name = "AttackRequest"
attackRequest.Parent = ReplicatedStorage

-- ---------- サウンド ----------
-- 実際のアセットIDはGameConfig.lua側(BGM_ASSET_ID / DEFAULT_PULL_SFX_ID)で
-- 指定する。0や未設定の場合は静かにスキップする(エラーにはしない)。
local function setupBgm()
	local bgmId = GameConfig.BGM_ASSET_ID
	if not bgmId or bgmId == 0 then
		print("[サウンド] BGMのアセットID(GameConfig.BGM_ASSET_ID)が未設定なので再生をスキップします。")
		return
	end
	local bgm = Instance.new("Sound")
	bgm.Name = "Bgm"
	bgm.SoundId = "rbxassetid://" .. bgmId
	bgm.Looped = true
	bgm.Volume = 0.35
	bgm.Parent = Workspace
	bgm:Play()
end
setupBgm()

-- 雑草を抜いた瞬間に、プレイヤーのすぐそばで短い効果音を鳴らす。
-- 抜いた雑草(instanceRoot)はこの直後に消えてしまうので、音は消えない
-- プレイヤーのキャラクターに付けて再生し、鳴らし終わったら自動で片付ける。
local function playPullSfx(character, sfxId)
	sfxId = sfxId or GameConfig.DEFAULT_PULL_SFX_ID
	if not sfxId or sfxId == 0 then
		return
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sfx = Instance.new("Sound")
	sfx.Name = "PullSfx"
	sfx.SoundId = "rbxassetid://" .. sfxId
	sfx.Volume = 0.6
	sfx.Parent = root
	sfx:Play()
	Debris:AddItem(sfx, 3)
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

-- ---------- 花束(摘んだ花を手に持っていく) ----------
-- 摘んだ雑草はどんどん花束として蓄積していく。見た目のパーツ数はMAX_VISIBLE_FLOWERSで
-- 頭打ちにするが、実際の本数(BouquetCount属性)は上限なく増え続け、攻撃のダメージ
-- 計算に使う。道具は右手に装着するので、花束は左手側に持たせる。
local MAX_VISIBLE_FLOWERS = 10
local BOUQUET_FLOWER_COLORS = {
	Color3.fromRGB(255, 205, 210),
	Color3.fromRGB(255, 236, 179),
	Color3.fromRGB(220, 237, 200),
	Color3.fromRGB(197, 225, 245),
	Color3.fromRGB(225, 190, 231),
}

local function updateBouquetVisual(player)
	local character = player.Character
	if not character then
		return
	end
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if not hand then
		return
	end

	local holder = character:FindFirstChild("Bouquet")
	if not holder then
		holder = Instance.new("Model")
		holder.Name = "Bouquet"
		holder.Parent = character
	end

	local count = player:GetAttribute("BouquetCount") or 0
	local visibleTarget = math.min(count, MAX_VISIBLE_FLOWERS)

	for i = #holder:GetChildren() + 1, visibleTarget do
		local flower = Instance.new("Part")
		flower.Name = "Flower" .. i
		flower.Shape = Enum.PartType.Ball
		flower.Size = Vector3.new(0.26, 0.26, 0.26)
		flower.Color = BOUQUET_FLOWER_COLORS[(i - 1) % #BOUQUET_FLOWER_COLORS + 1]
		flower.CanCollide = false
		flower.Massless = true
		flower.CFrame = hand.CFrame
			* CFrame.new(math.random(-12, 12) / 100, -(hand.Size.Y / 2) - 0.1 - i * 0.04, math.random(-12, 12) / 100)
		flower.Parent = holder

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = flower
		weld.Parent = flower
	end
end

local function addToBouquet(player, amount)
	local newCount = (player:GetAttribute("BouquetCount") or 0) + amount
	player:SetAttribute("BouquetCount", newCount)
	updateBouquetVisual(player)
end

-- ---------- プレイヤー参加・退出(通信を伴う処理より先に接続する) ----------
local function onPlayerAdded(player)
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

	player:SetAttribute("BouquetCount", 0)

	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- キャラクターの各パーツが揃うのを少し待つ
		updateEquippedTool(player)
		updateBouquetVisual(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- このスクリプトが動き出すより前にすでに参加していたプレイヤー(Studioのテスト再生等)
-- を取りこぼさないための保険。
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

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

-- ---------- 花束での攻撃 ----------
-- 手に持っている花の本数(BouquetCount)が多いほど、叩いたときのダメージが大きくなる。
-- ただし本数には上限を付けずに際限なく貯められるようにしたいので、ダメージ計算だけ
-- ATTACK_DAMAGE_FLOWER_CAPで頭打ちにして、一撃で倒しきれてしまわないようにしている。
local ATTACK_COOLDOWN = 0.6
local ATTACK_RANGE = 6
local ATTACK_BASE_DAMAGE = 5
local ATTACK_DAMAGE_PER_FLOWER = 1
local ATTACK_DAMAGE_FLOWER_CAP = 40
local lastAttackAt = {}

Players.PlayerRemoving:Connect(function(player)
	lastAttackAt[player] = nil
end)

attackRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastAttackAt[player] and now - lastAttackAt[player] < ATTACK_COOLDOWN then
		return
	end
	lastAttackAt[player] = now

	local bouquetCount = player:GetAttribute("BouquetCount") or 0
	if bouquetCount <= 0 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local damage = ATTACK_BASE_DAMAGE + math.min(bouquetCount, ATTACK_DAMAGE_FLOWER_CAP) * ATTACK_DAMAGE_PER_FLOWER

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildWhichIsA("Humanoid")
			if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
				if (otherRoot.Position - root.Position).Magnitude <= ATTACK_RANGE then
					otherHumanoid:TakeDamage(damage)
					showMessage:FireClient(other, player.Name .. " の花束(" .. bouquetCount .. "本)に たたかれた! (-" .. damage .. ")")
					showMessage:FireClient(player, other.Name .. " を たたいた! (" .. damage .. "ダメージ)")
				end
			end
		end
	end
end)

-- ---------- Creator Store(トイボックス)アセットの読み込み・安全確認 ----------
-- 無料モデルにScript/LocalScript/ModuleScriptが仕込まれているケース(バックドア等)への
-- 対策として、読み込んだ直後にそれらを機械的にすべて削除する。1回読み込んだら
-- サニタイズ済みのテンプレートとして使い回す(毎回読み込み直さない)。
-- ここでの通信待ちがPlayerAddedの接続を遅らせないよう、上のプレイヤー参加処理より
-- 後ろに書いてあることに注意(このスクリプト内での順番が重要)。
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
	local hasVisiblePart = false
	for _, descendant in ipairs(result:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			warn("[セキュリティ] アセット " .. tostring(assetId) .. " 内のスクリプトを検出・削除しました: " .. descendant:GetFullName())
			descendant:Destroy()
			removed += 1
		elseif descendant:IsA("BasePart") then
			hasVisiblePart = true
		end
	end

	-- 読み込みはできても、中に表示できるパーツが1つも無い(アセットIDが違う種類の
	-- アセットだった、モデルが壊れている等)場合は使い物にならないので、ここで
	-- 弾いておく。そうしないと当たり判定(GetBoundingBox)の計算でエラーになり、
	-- その雑草だけ画面に何も表示されないまま残ってしまう。
	if not hasVisiblePart then
		warn("[アセット] " .. tostring(assetId) .. " は読み込めましたが、表示できるパーツが見つかりませんでした。アセットIDが正しいか(Modelとして公開されたアセットか)確認してください。図形の見た目で代用します。")
		result:Destroy()
		return nil
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

-- ここでの読み込み待ち(通信)は、PlayerAddedの接続が既に済んだ後なので安全。
-- あえて同期的に待ってから雑草を生やし始める(そうしないと、読み込みが終わる前に
-- 生成された雑草だけ図形のフォールバック見た目のまま固定されてしまう)。
preloadAssetsFromTierList(GameConfig.WEED_TIERS)

-- モデル全体を包む透明な箱(当たり判定/Touched置き場)を追加する。モデルの中身が
-- どんな構造でも(パーツが1個でも複数でも、名前が何でも)確実に反応するようにするため。
-- GetBoundingBoxはパーツが無い(不完全な)モデルだとエラーになることがあるため、
-- 失敗しても他の雑草の生成が止まらないようpcallで守る。
local function attachHitbox(model)
	local boundsSuccess, boundsCFrame, boundsSize = pcall(function()
		return model:GetBoundingBox()
	end)
	if not boundsSuccess then
		warn("[見た目] モデルの当たり判定の計算に失敗しました: " .. tostring(boundsCFrame))
		return nil
	end

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(math.max(boundsSize.X, 1), math.max(boundsSize.Y, 1), math.max(boundsSize.Z, 1))
	hitbox.CFrame = boundsCFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.Anchored = true
	hitbox.Parent = model

	return hitbox
end

-- アセットモデルを置く(Creator Storeのモデルを使う雑草のみ)。
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

	local hitbox = attachHitbox(model)
	if not hitbox then
		warn("[アセット] 当たり判定の計算に失敗したため、図形の見た目で代用します。")
		model:Destroy()
		return nil
	end

	return model, hitbox
end

-- ---------- Creator Storeのアセットを使わず、複数パーツを組み合わせて
-- それっぽい見た目を作る(「アセットが面倒」なので、まずは花から工夫する版)。
-- shape == "ball" は花・茂み、"blade" は草の束、"block" は建物っぽい形にする。
local function buildFlower(tier, x, z, groundY)
	local model = Instance.new("Model")
	model.Name = "Weed"

	local stemHeight = math.max(tier.diameter or 0.5, 0.3) * 1.4
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(stemHeight, 0.07, 0.07)
	stem.Orientation = Vector3.new(0, 0, 90)
	stem.Color = Color3.fromRGB(80, 150, 70)
	stem.Anchored = true
	stem.CanCollide = false
	stem.Position = Vector3.new(x, groundY + stemHeight / 2, z)
	stem.Parent = model

	local headY = groundY + stemHeight
	local headRadius = math.max(tier.diameter or 0.5, 0.3) * 0.55

	local center = Instance.new("Part")
	center.Name = "Center"
	center.Shape = Enum.PartType.Ball
	center.Size = Vector3.new(headRadius * 0.7, headRadius * 0.7, headRadius * 0.7)
	center.Color = tier.color
	center.Anchored = true
	center.CanCollide = false
	center.Position = Vector3.new(x, headY, z)
	center.Parent = model

	local petalColor = tier.color:Lerp(Color3.new(1, 1, 1), 0.3)
	local petalCount = 6
	for i = 1, petalCount do
		local angle = (i / petalCount) * math.pi * 2
		local petal = Instance.new("Part")
		petal.Name = "Petal" .. i
		petal.Shape = Enum.PartType.Ball
		petal.Size = Vector3.new(headRadius * 0.55, headRadius * 0.3, headRadius * 0.55)
		petal.Color = petalColor
		petal.Anchored = true
		petal.CanCollide = false
		petal.CFrame = CFrame.new(x, headY, z) * CFrame.Angles(0, angle, 0) * CFrame.new(headRadius * 0.55, 0, 0)
		petal.Parent = model
	end

	model.Parent = Workspace
	local hitbox = attachHitbox(model)
	return model, hitbox or stem
end

local function buildGrassTuft(tier, x, z, groundY)
	local model = Instance.new("Model")
	model.Name = "Weed"

	local bladeCount = 3
	for i = 1, bladeCount do
		local blade = Instance.new("Part")
		blade.Name = "Blade" .. i
		blade.Shape = Enum.PartType.Cylinder
		local length = tier.length * (0.75 + math.random() * 0.5)
		blade.Size = Vector3.new(length, tier.diameter * 0.6, tier.diameter * 0.6)
		blade.Color = tier.color
		blade.Anchored = true
		blade.CanCollide = false
		local lean = math.rad((math.random() - 0.5) * 26)
		local offsetAngle = (i / bladeCount) * math.pi * 2
		local offsetX = math.cos(offsetAngle) * tier.diameter * 0.5
		local offsetZ = math.sin(offsetAngle) * tier.diameter * 0.5
		blade.CFrame = CFrame.new(x + offsetX, groundY + (length / 2) * math.cos(lean), z + offsetZ)
			* CFrame.Angles(0, 0, math.rad(90) + lean)
		blade.Parent = model
	end

	model.Parent = Workspace
	local hitbox = attachHitbox(model)
	return model, hitbox or model:FindFirstChildWhichIsA("BasePart")
end

local function buildBuildingShape(tier, x, z, groundY)
	local model = Instance.new("Model")
	model.Name = "Weed"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = tier.size
	body.Color = tier.color
	body.Anchored = true
	body.CanCollide = false
	body.Position = Vector3.new(x, groundY + tier.size.Y / 2, z)
	body.Parent = model

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(tier.size.X * 1.05, math.max(tier.size.Y * 0.08, 0.15), tier.size.Z * 1.05)
	roof.Color = tier.color:Lerp(Color3.new(0, 0, 0), 0.3)
	roof.Anchored = true
	roof.CanCollide = false
	roof.Position = Vector3.new(x, groundY + tier.size.Y + roof.Size.Y / 2, z)
	roof.Parent = model

	model.Parent = Workspace
	local hitbox = attachHitbox(model)
	return model, hitbox or body
end

local RESPAWN_DELAY = 3.5
-- 「今の100倍くらいの面積」の要望に合わせて、半径を約10倍(面積は約10^2=100倍)に。
local FIELD_RADIUS = 450
local FIELD_DEADZONE = 4 -- スポーン地点の近くには生やさない
local MIN_ITEM_SPACING = 4 -- 他の雑草・おはなとこれ以上近くには生やさない(判定の重なり防止)

-- 街をフィールドの外側にはみ出す形まで行き渡らせる(距離ではなく格子状に)。
local TOWN_MARGIN = 60
local TOWN_EXTENT = FIELD_RADIUS + TOWN_MARGIN
local ROAD_SPACING = 90 -- 道路(碁盤の目)の間隔
local SPAWN_CLEARING = 20 -- スポーン地点(原点)付近には建物を置かない

-- 注意: Workspace.StreamingEnabled はスクリプトから書き込もうとすると
-- 「lacking capability Plugin」というエラーで止まってしまう(Studio側の設定でしか
-- 変更できない)。しかもこれがスクリプトの先頭の方にあると、それより下の処理
-- (地面・街・雑草の生成)が丸ごと実行されなくなってしまう(実際に一度起きた)。
-- 有効にしたい場合は、Studio上部の「ゲーム設定」→「ワールド」タブから
-- 手動でオンにすること。

-- ---------- 地面を芝生にする ----------
-- Baseplateなど元々置いてある地面の高さを1回だけ調べ、その上に緑の芝生パーツを敷く。
-- 以後、フィールド内の高さはすべてこの結果(FIELD_GROUND_Y)を使い回す。毎回
-- Raycastし直すと、生成したばかりの地面をまだ拾えず雑草が埋まる、といったタイミングの
-- 問題が起きうるため、そもそも起きないように「芝生の上面は必ずこのYになる」と決め打ちする。
local function setupGrassGround(radius)
	local size = radius * 2 + 60
	local baseGroundY = getGroundY(0, 0)
	local ground = Instance.new("Part")
	ground.Name = "GrassGround"
	ground.Size = Vector3.new(size, 2, size)
	ground.Position = Vector3.new(0, baseGroundY + 1, 0)
	ground.Anchored = true
	ground.CanCollide = true
	ground.Material = Enum.Material.Grass
	ground.Color = Color3.fromRGB(86, 158, 74)
	ground.Parent = Workspace
	return baseGroundY + 2 -- 芝生の上面のY座標
end
local FIELD_GROUND_Y = setupGrassGround(TOWN_EXTENT)

-- ---------- 街の背景(道路・ビル・車を碁盤の目状にフィールド全体へ配置する) ----------
local function buildRoadSegment(cx, cz, length, angleY)
	local road = Instance.new("Part")
	road.Name = "Road"
	road.Size = Vector3.new(length, 0.2, 8)
	road.Color = Color3.fromRGB(60, 60, 65)
	road.Material = Enum.Material.Asphalt
	road.Anchored = true
	road.CanCollide = true
	road.CFrame = CFrame.new(cx, FIELD_GROUND_Y + 0.11, cz) * CFrame.Angles(0, angleY, 0)
	road.Parent = Workspace

	local line = Instance.new("Part")
	line.Name = "RoadLine"
	line.Size = Vector3.new(length * 0.96, 0.05, 0.3)
	line.Color = Color3.fromRGB(230, 220, 90)
	line.Material = Enum.Material.Neon
	line.Anchored = true
	line.CanCollide = false
	line.CFrame = road.CFrame * CFrame.new(0, 0.13, 0)
	line.Parent = Workspace
end

local TOWN_BUILDING_COLORS = {
	Color3.fromRGB(205, 190, 160),
	Color3.fromRGB(170, 175, 185),
	Color3.fromRGB(200, 150, 130),
	Color3.fromRGB(150, 180, 190),
}
local WINDOW_COLOR = Color3.fromRGB(210, 235, 250)
local DOOR_COLOR = Color3.fromRGB(90, 60, 40)

-- 建物の正面(+Z面)にドアと窓を並べる。建物自体は回転させていないので、
-- Z面固定のままの単純な座標計算で足りる。
local function addBuildingDetails(model, x, z, width, height, depth)
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size = Vector3.new(math.min(1.3, width * 0.3), 2.2, 0.12)
	door.Color = DOOR_COLOR
	door.Anchored = true
	door.CanCollide = false
	door.Position = Vector3.new(x, FIELD_GROUND_Y + 1.1, z + depth / 2 + 0.07)
	door.Parent = model

	local floors = math.clamp(math.floor(height / 3.2), 1, 5)
	local cols = math.clamp(math.floor(width / 1.8), 1, 4)
	local floorHeight = height / (floors + 1)
	local colWidth = width / (cols + 1)
	for floor = 1, floors do
		local wy = FIELD_GROUND_Y + floor * floorHeight
		for col = 1, cols do
			local wx = x - width / 2 + col * colWidth
			local window = Instance.new("Part")
			window.Name = "Window"
			window.Size = Vector3.new(colWidth * 0.55, floorHeight * 0.5, 0.08)
			window.Color = WINDOW_COLOR
			window.Material = Enum.Material.Glass
			window.Anchored = true
			window.CanCollide = false
			window.Position = Vector3.new(wx, wy, z + depth / 2 + 0.06)
			window.Parent = model
		end
	end
end

local function buildTownBuilding(x, z)
	local height = 6 + math.random() * 18
	local width = 5 + math.random() * 4
	local depth = 5 + math.random() * 4

	local model = Instance.new("Model")
	model.Name = "TownBuilding"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(width, height, depth)
	body.Color = TOWN_BUILDING_COLORS[math.random(1, #TOWN_BUILDING_COLORS)]
	body.Anchored = true
	body.CanCollide = true
	body.Position = Vector3.new(x, FIELD_GROUND_Y + height / 2, z)
	body.Parent = model

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(width * 1.05, 0.4, depth * 1.05)
	roof.Color = Color3.fromRGB(90, 90, 95)
	roof.Anchored = true
	roof.CanCollide = false
	roof.Position = Vector3.new(x, FIELD_GROUND_Y + height + 0.2, z)
	roof.Parent = model

	model.Parent = Workspace
	addBuildingDetails(model, x, z, width, height, depth)
	return model
end

local TOWN_CAR_COLORS = {
	Color3.fromRGB(200, 60, 60),
	Color3.fromRGB(60, 90, 200),
	Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(240, 200, 40),
}

local function buildCarModel(x, z, angleY)
	local model = Instance.new("Model")
	model.Name = "Car"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4.2, 1.2, 1.9)
	body.Color = TOWN_CAR_COLORS[math.random(1, #TOWN_CAR_COLORS)]
	body.Anchored = true
	body.CanCollide = true
	body.CFrame = CFrame.new(x, FIELD_GROUND_Y + 0.6, z) * CFrame.Angles(0, angleY, 0)
	body.Parent = model

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(2.2, 0.9, 1.7)
	cabin.Color = Color3.fromRGB(210, 230, 240)
	cabin.Transparency = 0.2
	cabin.Anchored = true
	cabin.CanCollide = false
	cabin.CFrame = body.CFrame * CFrame.new(-0.2, 1.0, 0)
	cabin.Parent = model

	for _, dx in ipairs({ 1.4, -1.4 }) do
		for _, dz in ipairs({ 0.95, -0.95 }) do
			local wheel = Instance.new("Part")
			wheel.Name = "Wheel"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(0.4, 0.7, 0.7)
			wheel.Color = Color3.fromRGB(25, 25, 25)
			wheel.Anchored = true
			wheel.CanCollide = false
			wheel.CFrame = body.CFrame * CFrame.new(dx, -0.6, dz) * CFrame.Angles(0, 0, math.rad(90))
			wheel.Parent = model
		end
	end

	model.PrimaryPart = body
	model.Parent = Workspace
	return model
end

-- 道路の上を行ったり来たり走らせる。Model:PivotTo でモデルごと動かすので、
-- 中のパーツがAnchoredのままでも(物理演算を使わなくても)一緒に動く。
-- sin(t)*halfLengthで位置を作っているため、tを動かす角速度(1秒あたりの
-- ラジアン数)をそのまま速度として使うと、実際の移動速度はhalfLength倍に
-- 膨れ上がってしまう(以前のバグ: halfLengthが約510だったため、指定した
-- つもりの速度の500倍以上で走っていた)。ここでは studsPerSecond(実際の
-- 移動速度)を受け取り、角速度 = studsPerSecond / halfLength に変換する。
local function animateDrivingCar(model, axis, fixedCoord, halfLength, studsPerSecond)
	local angularSpeed = studsPerSecond / halfLength
	task.spawn(function()
		local t = math.random() * math.pi * 2
		while model.Parent do
			t += angularSpeed * task.wait()
			local offset = math.sin(t) * halfLength
			local facingForward = math.cos(t) >= 0
			local x, z, angle
			if axis == "x" then
				x, z = offset, fixedCoord
				angle = facingForward and 0 or math.pi
			else
				x, z = fixedCoord, offset
				angle = facingForward and math.rad(90) or math.rad(-90)
			end
			model:PivotTo(CFrame.new(x, FIELD_GROUND_Y + 0.6, z) * CFrame.Angles(0, angle, 0))
		end
	end)
end

-- 碁盤の目状の道路網を通し、区画ごとにビル・駐車中の車を配置し、
-- 何本かの道路には走る車も出す。フィールドの外側だけでなく全体に行き渡らせる。
local function buildTownScenery()
	local half = TOWN_EXTENT
	local coords = {}
	local lineCount = math.floor((half * 2) / ROAD_SPACING)
	for i = 0, lineCount do
		table.insert(coords, -half + i * ROAD_SPACING)
	end

	for _, c in ipairs(coords) do
		buildRoadSegment(0, c, half * 2 + 20, 0)
		buildRoadSegment(c, 0, half * 2 + 20, math.rad(90))
	end

	for _, cx in ipairs(coords) do
		for _, cz in ipairs(coords) do
			if math.sqrt(cx * cx + cz * cz) > SPAWN_CLEARING then
				local bx = cx + ROAD_SPACING * 0.5 + (math.random() - 0.5) * (ROAD_SPACING * 0.35)
				local bz = cz + ROAD_SPACING * 0.5 + (math.random() - 0.5) * (ROAD_SPACING * 0.35)
				if math.random() < 0.75 then
					buildTownBuilding(bx, bz)
				end
				if math.random() < 0.3 then
					local angle = ({ 0, math.rad(90), math.pi, math.rad(-90) })[math.random(1, 4)]
					buildCarModel(bx + 8, bz + 8, angle)
				end
			end
		end
	end

	local movingCarBudget = 16
	for _, c in ipairs(coords) do
		if movingCarBudget <= 0 then
			break
		end
		if math.random() < 0.5 then
			local car = buildCarModel(0, c, 0)
			animateDrivingCar(car, "x", c, half, 24 + math.random() * 12) -- 24〜36スタッド/秒
			movingCarBudget -= 1
		end
		if movingCarBudget > 0 and math.random() < 0.5 then
			local car2 = buildCarModel(c, 0, math.rad(90))
			animateDrivingCar(car2, "z", c, half, 24 + math.random() * 12)
			movingCarBudget -= 1
		end
	end
end
buildTownScenery()

-- ---------- 見えない壁でワールドの外側を区切る ----------
-- 普通のゲームでは、作り込んでいる範囲の外に出られないよう、透明な壁や
-- 柵・山などで移動できる範囲を区切っている。今回も生成した範囲(街の一番外側)の
-- 外に歩いて出られないよう、見えない壁で囲っておく。
local function buildBoundaryWalls(extent)
	local wallHeight = 60
	local wallThickness = 4
	local half = extent + 10
	local span = half * 2 + wallThickness * 2

	local function wall(cx, cz, sizeX, sizeZ)
		local part = Instance.new("Part")
		part.Name = "BoundaryWall"
		part.Size = Vector3.new(sizeX, wallHeight, sizeZ)
		part.CFrame = CFrame.new(cx, FIELD_GROUND_Y + wallHeight / 2, cz)
		part.Anchored = true
		part.CanCollide = true
		part.Transparency = 1
		part.Parent = Workspace
	end

	wall(0, half, span, wallThickness)
	wall(0, -half, span, wallThickness)
	wall(half, 0, wallThickness, span)
	wall(-half, 0, wallThickness, span)
end
buildBoundaryWalls(TOWN_EXTENT)

-- 前方宣言。makeWeed/makeForbiddenの中(抜いた後)から呼べるようにしておく。
local spawnWeed
local spawnForbidden

-- 今フィールドに生えている物の位置一覧。1か所に密集して「ぬく」判定が
-- 重ならないようにするために使う。
local activePositions = {}

local function registerPosition(x, z)
	local entry = { x = x, z = z }
	table.insert(activePositions, entry)
	return entry
end

local function unregisterPosition(entry)
	local index = table.find(activePositions, entry)
	if index then
		table.remove(activePositions, index)
	end
end

local function makeWeed(tierIndex, x, z)
	local tier = GameConfig.WEED_TIERS[tierIndex]
	local groundY = FIELD_GROUND_Y
	local posEntry = registerPosition(x, z)
	local instanceRoot
	local promptAnchor

	local template = tier.assetId and ASSET_TEMPLATES[tier.assetId]
	if template then
		instanceRoot, promptAnchor = placeAssetModel(template, x, z, groundY)
	end

	if not instanceRoot then
		-- アセットが無い/読み込めなかった場合は、複数パーツを組み合わせた
		-- それっぽい見た目(花・草の束・建物)で代用する。
		if tier.shape == "blade" then
			instanceRoot, promptAnchor = buildGrassTuft(tier, x, z, groundY)
		elseif tier.shape == "ball" then
			instanceRoot, promptAnchor = buildFlower(tier, x, z, groundY)
		else -- "block"
			instanceRoot, promptAnchor = buildBuildingShape(tier, x, z, groundY)
		end
	end

	-- クライアント側(PullableHighlight.client.lua)が「今の自分のレベルで
	-- 抜けるかどうか」を判定するために、必要なレベルを属性として持たせておく。
	instanceRoot:SetAttribute("UnlockLevel", tier.unlockLevel)

	-- ボタン操作ではなく、触れるだけで抜ける。連続でTouchedが発火しても
	-- 二重に処理しないよう、pulledフラグで1回だけに絞る。
	local pulled = false
	local lockedNotified = false

	promptAnchor.Touched:Connect(function(hit)
		if pulled then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
		if not levelValue then
			return
		end

		if levelValue.Value < tier.unlockLevel then
			if not lockedNotified then
				lockedNotified = true
				showMessage:FireClient(player, tier.name .. " は まだ Lv." .. tier.unlockLevel .. " にならないと ぬけないよ")
				task.delay(2, function()
					lockedNotified = false
				end)
			end
			return
		end

		pulled = true
		applyPoints(player, tier.points)
		addToBouquet(player, 1)
		playPullSfx(character, tier.sfxId)
		showMessage:FireClient(player, tier.name .. " を ぬいた! (+" .. tier.points .. "pt)")
		unregisterPosition(posEntry)
		instanceRoot:Destroy()
		task.delay(RESPAWN_DELAY, spawnWeed)
	end)
end

-- 「抜いてはいけないもの」は柱+上に乗るパーツ(pole)、または単一パーツ(single)で表現する。
local function makeForbidden(typeIndex, x, z)
	local spec = GameConfig.FORBIDDEN_TYPES[typeIndex]
	local groundY = FIELD_GROUND_Y
	local posEntry = registerPosition(x, z)
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

	-- こちらもボタン操作ではなく触れるだけで反応する。うっかり触れてしまう
	-- ことこそが「抜いてはいけないもの」のリスクなので、あえて何もガードしない。
	local promptPart = parts[#parts]
	local pulled = false

	promptPart.Touched:Connect(function(hit)
		if pulled then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Level")

		if levelValue and levelValue.Value < spec.unlockLevel then
			return
		end

		pulled = true
		showMessage:FireClient(player, "それは" .. spec.name .. "! ぬいちゃダメだよ")
		applyPoints(player, -spec.penalty)
		unregisterPosition(posEntry)
		for _, p in ipairs(parts) do
			p:Destroy()
		end
		task.delay(RESPAWN_DELAY, spawnForbidden)
	end)
end

local function randomFieldPosition()
	for _ = 1, 20 do
		local x = (math.random() - 0.5) * 2 * FIELD_RADIUS
		local z = (math.random() - 0.5) * 2 * FIELD_RADIUS
		if math.sqrt(x * x + z * z) > FIELD_DEADZONE then
			local tooClose = false
			for _, pos in ipairs(activePositions) do
				if math.sqrt((pos.x - x) ^ 2 + (pos.z - z) ^ 2) < MIN_ITEM_SPACING then
					tooClose = true
					break
				end
			end
			if not tooClose then
				return x, z
			end
		end
	end
	return FIELD_RADIUS, FIELD_RADIUS
end

-- レベル順に少しずつ出すのではなく、最初から全種類をフィールドに混ぜて出す。
-- ただしレベルの低い(身近な)雑草の方がよく出るように、二乗した乱数で
-- インデックスを選ぶ(0に近いほど選ばれやすい=低いレベルの雑草ほど出やすい)。
-- レベルが足りない雑草も見えている(触っても反応しないだけ)のは、既存の
-- 「抜いてはいけないもの」と同じ考え方。
local function pickTierIndex()
	local total = #GameConfig.WEED_TIERS
	local roll = math.random()
	local index = math.floor((roll * roll) * total) + 1
	return math.clamp(index, 1, total)
end

-- おはなも同様に、レベルに関係なく全種類を最初から混ぜて出す。
local function pickForbiddenTypeIndex()
	return math.random(1, #GameConfig.FORBIDDEN_TYPES)
end

spawnWeed = function()
	local tierIndex = pickTierIndex()
	local x, z = randomFieldPosition()
	makeWeed(tierIndex, x, z)
end

spawnForbidden = function()
	local typeIndex = pickForbiddenTypeIndex()
	local x, z = randomFieldPosition()
	makeForbidden(typeIndex, x, z)
end

-- 「数が少なすぎる、今の100倍くらいに」との要望を受けて大幅に増やした。
-- ただし面積どおり文字通り100倍(2万本超)にすると、1雑草あたり複数パーツを
-- 使う今の見た目や、街の建物・車のパーツ数と合わせるとスマホでは確実に重くなる
-- ため、以前の約13倍(3000本)に留めている。これでもまだ少なく感じる場合は
-- この数をさらに増やして試してみてほしい。
for _ = 1, 3000 do
	spawnWeed()
end
for _ = 1, 200 do
	spawnForbidden()
end
