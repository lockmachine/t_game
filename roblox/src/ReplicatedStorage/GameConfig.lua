-- サーバーとクライアントの両方で使う、レベルのルールをまとめた共有モジュール。
-- ここを直すだけでサーバー側の判定とクライアント側のHUD表示の両方に反映される。

local GameConfig = {}

GameConfig.LEVELS = {
	{ level = 1, needPoints = 0 },
	{ level = 2, needPoints = 50 },
	{ level = 3, needPoints = 130 },
}

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

return GameConfig
