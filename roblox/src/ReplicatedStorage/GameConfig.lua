-- サーバーとクライアントの両方で使う、ゲームの中身をまとめた共有モジュール。
-- ここを直すだけでサーバー側の判定とクライアント側のHUD表示の両方に反映される。

local GameConfig = {}

-- ---------- レベル(1〜32、必要ポイントは二次関数で自動生成) ----------
local MAX_LEVEL = 32
GameConfig.LEVELS = {}
for level = 1, MAX_LEVEL do
	GameConfig.LEVELS[level] = { level = level, needPoints = 25 * level * (level - 1) }
end

function GameConfig.computeLevel(points)
	local level = 1
	for _, entry in ipairs(GameConfig.LEVELS) do
		if points >= entry.needPoints then
			level = entry.level
		end
	end
	return level
end

function GameConfig.levelInfo(level)
	for _, entry in ipairs(GameConfig.LEVELS) do
		if entry.level == level then
			return entry
		end
	end
	return GameConfig.LEVELS[1]
end

function GameConfig.nextLevelInfo(level)
	for _, entry in ipairs(GameConfig.LEVELS) do
		if entry.level == level + 1 then
			return entry
		end
	end
	return nil
end

-- ---------- 抜ける雑草・オブジェクト(そのレベルになったら抜けるようになる、全32種) ----------
-- shape: "blade"(細長い柱、垂直に立てる) / "ball"(丸い茂み) / "block"(四角い建造物系)
GameConfig.WEED_TIERS = {
	{ unlockLevel = 1, name = "たんぽぽ", points = 10, shape = "blade", length = 0.5, diameter = 0.12, color = Color3.fromRGB(120, 190, 90), assetId = 5342512389 },
	{ unlockLevel = 2, name = "しろつめくさ", points = 20, shape = "ball", diameter = 0.5, color = Color3.fromRGB(140, 200, 120), assetId = 9985686401 },
	{ unlockLevel = 3, name = "からすのえんどう", points = 30, shape = "blade", length = 0.6, diameter = 0.12, color = Color3.fromRGB(100, 170, 80) },
	{ unlockLevel = 4, name = "えのころぐさ", points = 40, shape = "blade", length = 0.8, diameter = 0.14, color = Color3.fromRGB(180, 190, 110) },
	{ unlockLevel = 5, name = "おおばこ", points = 50, shape = "ball", diameter = 0.6, color = Color3.fromRGB(110, 160, 90) },
	{ unlockLevel = 6, name = "すぎな", points = 60, shape = "blade", length = 0.9, diameter = 0.1, color = Color3.fromRGB(100, 180, 100) },
	{ unlockLevel = 7, name = "はこべ", points = 70, shape = "ball", diameter = 0.4, color = Color3.fromRGB(150, 210, 130) },
	{ unlockLevel = 8, name = "かたばみ", points = 80, shape = "ball", diameter = 0.45, color = Color3.fromRGB(120, 190, 100) },
	{ unlockLevel = 9, name = "せいたかあわだちそう", points = 90, shape = "blade", length = 1.6, diameter = 0.18, color = Color3.fromRGB(190, 200, 90) },
	{ unlockLevel = 10, name = "ススキ", points = 100, shape = "blade", length = 1.8, diameter = 0.16, color = Color3.fromRGB(200, 190, 140), assetId = 4743452860 },
	{ unlockLevel = 11, name = "アザミ", points = 110, shape = "ball", diameter = 0.9, color = Color3.fromRGB(150, 110, 170) },
	{ unlockLevel = 12, name = "くず", points = 120, shape = "ball", diameter = 1.0, color = Color3.fromRGB(70, 140, 70) },
	{ unlockLevel = 13, name = "いばら", points = 130, shape = "ball", diameter = 1.0, color = Color3.fromRGB(60, 120, 60), assetId = 15422478687 },
	{ unlockLevel = 14, name = "つたの茂み", points = 140, shape = "ball", diameter = 1.1, color = Color3.fromRGB(80, 150, 80) },
	{ unlockLevel = 15, name = "低木", points = 150, shape = "ball", diameter = 1.6, color = Color3.fromRGB(50, 110, 55), assetId = 580221169 },
	{ unlockLevel = 16, name = "若木", points = 160, shape = "ball", diameter = 1.8, color = Color3.fromRGB(45, 105, 50), assetId = 563810465 },
	{ unlockLevel = 17, name = "切り株", points = 170, shape = "blade", length = 0.6, diameter = 0.8, color = Color3.fromRGB(120, 80, 50), assetId = 306586433 },
	{ unlockLevel = 18, name = "竹", points = 180, shape = "blade", length = 2.6, diameter = 0.2, color = Color3.fromRGB(150, 190, 110), assetId = 122970778840406 },
	{ unlockLevel = 19, name = "蔦が絡まったフェンス", points = 190, shape = "ball", diameter = 2.0, color = Color3.fromRGB(70, 130, 70), assetId = 13499215049 },
	{ unlockLevel = 20, name = "街路樹", points = 200, shape = "ball", diameter = 2.6, color = Color3.fromRGB(40, 100, 45), assetId = 14804566604 },
	{ unlockLevel = 21, name = "大きな木", points = 210, shape = "ball", diameter = 3.4, color = Color3.fromRGB(35, 95, 40), assetId = 10950074600 },
	{ unlockLevel = 22, name = "石垣の隙間の草", points = 220, shape = "blade", length = 0.5, diameter = 0.12, color = Color3.fromRGB(110, 170, 90) },
	{ unlockLevel = 23, name = "放置自転車の雑草", points = 230, shape = "ball", diameter = 1.4, color = Color3.fromRGB(90, 150, 80), assetId = 17323454208 },
	{ unlockLevel = 24, name = "電柱に絡まる蔦", points = 240, shape = "blade", length = 3.0, diameter = 0.25, color = Color3.fromRGB(70, 130, 70), assetId = 16826638385 },
	{ unlockLevel = 25, name = "廃屋の庭", points = 250, shape = "ball", diameter = 3.6, color = Color3.fromRGB(55, 100, 50), assetId = 431080240 },
	{ unlockLevel = 26, name = "アスファルトの割れ目の草", points = 260, shape = "blade", length = 0.4, diameter = 0.1, color = Color3.fromRGB(120, 180, 90) },
	{ unlockLevel = 27, name = "古い看板", points = 270, shape = "block", size = Vector3.new(1.6, 2.2, 0.2), color = Color3.fromRGB(150, 150, 150) },
	{ unlockLevel = 28, name = "一軒家", points = 280, shape = "block", size = Vector3.new(4.5, 4.5, 4.5), color = Color3.fromRGB(210, 190, 150), assetId = 9625695695 },
	{ unlockLevel = 29, name = "マンション", points = 290, shape = "block", size = Vector3.new(6, 10, 6), color = Color3.fromRGB(170, 170, 175), assetId = 5612574306 },
	{ unlockLevel = 30, name = "ビル", points = 300, shape = "block", size = Vector3.new(7, 16, 7), color = Color3.fromRGB(120, 150, 170), assetId = 101888241591344 },
	{ unlockLevel = 31, name = "橋", points = 310, shape = "block", size = Vector3.new(10, 1.2, 3), color = Color3.fromRGB(140, 140, 140) },
	{ unlockLevel = 32, name = "電波塔", points = 320, shape = "blade", length = 12, diameter = 0.4, color = Color3.fromRGB(200, 60, 60), assetId = 4567948693 },
}

-- ---------- 抜いてはいけないもの(5レベルごとに新しい種類が「抜けてしまう」ようになる、全10種) ----------
-- 見た目は最初から全種類が世界に置かれるが、そのレベルに達するまでは
-- ぬこうとしても反応しない(=誤って抜けてしまうことがない)。
-- kind: "pole"(柱+上に乗るパーツ) / "single"(単一パーツ)
GameConfig.FORBIDDEN_TYPES = {
	{ unlockLevel = 1, name = "おはな", penalty = 15, kind = "pole",
		poleHeight = 0.55, poleDiameter = 0.06, poleColor = Color3.fromRGB(76, 154, 42),
		topperShape = "ball", topperSize = Vector3.new(0.45, 0.45, 0.45), topperColor = Color3.fromRGB(230, 57, 70), glow = false },
	{ unlockLevel = 5, name = "きのこ", penalty = 25, kind = "pole",
		poleHeight = 0.35, poleDiameter = 0.1, poleColor = Color3.fromRGB(235, 225, 205),
		topperShape = "ball", topperSize = Vector3.new(0.6, 0.35, 0.6), topperColor = Color3.fromRGB(210, 60, 60), glow = false },
	{ unlockLevel = 10, name = "郵便ポスト", penalty = 35, kind = "pole",
		poleHeight = 0.9, poleDiameter = 0.16, poleColor = Color3.fromRGB(200, 30, 30),
		topperShape = "block", topperSize = Vector3.new(0.5, 0.6, 0.4), topperColor = Color3.fromRGB(200, 30, 30), glow = false },
	{ unlockLevel = 15, name = "道路標識", penalty = 45, kind = "pole",
		poleHeight = 1.6, poleDiameter = 0.08, poleColor = Color3.fromRGB(150, 150, 150),
		topperShape = "block", topperSize = Vector3.new(0.6, 0.6, 0.05), topperColor = Color3.fromRGB(230, 200, 40), glow = false },
	{ unlockLevel = 20, name = "街灯", penalty = 55, kind = "pole",
		poleHeight = 2.2, poleDiameter = 0.1, poleColor = Color3.fromRGB(80, 80, 90),
		topperShape = "ball", topperSize = Vector3.new(0.4, 0.4, 0.4), topperColor = Color3.fromRGB(255, 240, 180), glow = true },
	{ unlockLevel = 25, name = "信号機", penalty = 65, kind = "pole",
		poleHeight = 1.8, poleDiameter = 0.1, poleColor = Color3.fromRGB(60, 60, 60),
		topperShape = "block", topperSize = Vector3.new(0.35, 0.9, 0.35), topperColor = Color3.fromRGB(50, 50, 50), glow = false },
	{ unlockLevel = 30, name = "消火栓", penalty = 75, kind = "single",
		shape = "ball", size = Vector3.new(0.5, 0.6, 0.5), color = Color3.fromRGB(210, 40, 40) },
	{ unlockLevel = 35, name = "公園の遊具", penalty = 85, kind = "single",
		shape = "ball", size = Vector3.new(1.4, 1.4, 1.4), color = Color3.fromRGB(240, 150, 40) },
	{ unlockLevel = 40, name = "ベンチ", penalty = 95, kind = "single",
		shape = "block", size = Vector3.new(1.4, 0.4, 0.5), color = Color3.fromRGB(150, 110, 70) },
	{ unlockLevel = 45, name = "停めてある自転車", penalty = 105, kind = "single",
		shape = "block", size = Vector3.new(1.2, 0.7, 0.3), color = Color3.fromRGB(50, 120, 200) },
}

-- ---------- 道具(レベルが上がるごとに自動的に手に装着される、全8種) ----------
GameConfig.TOOLS = {
	{ unlockLevel = 1, name = "軍手", size = Vector3.new(0.3, 0.25, 0.15), color = Color3.fromRGB(230, 220, 90) },
	{ unlockLevel = 3, name = "虫眼鏡", size = Vector3.new(0.35, 0.35, 0.08), color = Color3.fromRGB(200, 220, 230) },
	{ unlockLevel = 7, name = "草刈り鎌", size = Vector3.new(0.5, 0.15, 0.08), color = Color3.fromRGB(140, 140, 145) },
	{ unlockLevel = 11, name = "熊手", size = Vector3.new(0.4, 0.5, 0.1), color = Color3.fromRGB(150, 100, 60) },
	{ unlockLevel = 15, name = "剪定ばさみ", size = Vector3.new(0.5, 0.2, 0.1), color = Color3.fromRGB(40, 40, 40) },
	{ unlockLevel = 19, name = "電動草刈り機", size = Vector3.new(0.7, 0.4, 0.25), color = Color3.fromRGB(255, 140, 0) },
	{ unlockLevel = 24, name = "チェーンソー", size = Vector3.new(0.8, 0.35, 0.2), color = Color3.fromRGB(30, 30, 30) },
	{ unlockLevel = 29, name = "クレーン付き重機", size = Vector3.new(1.2, 0.8, 0.7), color = Color3.fromRGB(240, 200, 20) },
}

function GameConfig.toolForLevel(level)
	local best = GameConfig.TOOLS[1]
	for _, tool in ipairs(GameConfig.TOOLS) do
		if level >= tool.unlockLevel then
			best = tool
		end
	end
	return best
end

return GameConfig
