-- 今の自分のレベルで抜ける雑草だけ、はっきり分かるように光らせる。
-- (Highlightは各クライアントのローカル表示のみで、他のプレイヤーには見えない)
-- 3000本もの雑草の中から探すので、うっすら程度だと埋もれて見えなくなるため、
-- 目立つ緑色・不透明寄り・AlwaysOnTop(他の物に隠れても透けて見える)にしてある。

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function getMyLevel()
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	return levelValue and levelValue.Value or 1
end

local function ensureHighlight(model)
	if model:FindFirstChild("PullableHighlight") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "PullableHighlight"
	highlight.FillColor = Color3.fromRGB(110, 255, 130)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(40, 255, 80)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
end

local function removeHighlight(model)
	local highlight = model:FindFirstChild("PullableHighlight")
	if highlight then
		highlight:Destroy()
	end
end

local function refresh()
	local level = getMyLevel()
	for _, model in ipairs(Workspace:GetChildren()) do
		if model:IsA("Model") and model.Name == "Weed" then
			local unlockLevel = model:GetAttribute("UnlockLevel")
			if unlockLevel and level >= unlockLevel then
				ensureHighlight(model)
			else
				removeHighlight(model)
			end
		end
	end
end

task.spawn(function()
	while true do
		refresh()
		task.wait(1)
	end
end)
