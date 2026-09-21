-- 画面左上にレベル・ポイント・進捗バーを表示するカスタムHUD。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZassouHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Position = UDim2.new(0, 16, 0, 16)
panel.Size = UDim2.new(0, 220, 0, 66)
panel.BackgroundColor3 = Color3.fromRGB(254, 250, 224)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.BackgroundColor3 = Color3.fromRGB(255, 183, 3)
levelLabel.Size = UDim2.new(0, 56, 0, 24)
levelLabel.Position = UDim2.new(0, 12, 0, 10)
levelLabel.Text = "Lv.1"
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextSize = 15
levelLabel.TextColor3 = Color3.fromRGB(40, 54, 24)
levelLabel.Parent = panel

local levelCorner = Instance.new("UICorner")
levelCorner.CornerRadius = UDim.new(1, 0)
levelCorner.Parent = levelLabel

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "PointsLabel"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Size = UDim2.new(0, 140, 0, 24)
pointsLabel.Position = UDim2.new(0, 76, 0, 10)
pointsLabel.Text = "0 ポイント"
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.TextSize = 14
pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
pointsLabel.TextColor3 = Color3.fromRGB(40, 54, 24)
pointsLabel.Parent = panel

local track = Instance.new("Frame")
track.Name = "Track"
track.BackgroundColor3 = Color3.fromRGB(233, 216, 166)
track.BorderSizePixel = 0
track.Size = UDim2.new(1, -24, 0, 10)
track.Position = UDim2.new(0, 12, 0, 44)
track.Parent = panel

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(251, 133, 0)
fill.BorderSizePixel = 0
fill.Size = UDim2.new(0, 0, 1, 0)
fill.Parent = track

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local function refresh()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local levelValue = leaderstats:FindFirstChild("Level")
	local pointsValue = leaderstats:FindFirstChild("Points")
	if not levelValue or not pointsValue then
		return
	end

	levelLabel.Text = "Lv." .. levelValue.Value
	pointsLabel.Text = pointsValue.Value .. " ポイント"

	local next = GameConfig.nextLevelInfo(levelValue.Value)
	if not next then
		fill.Size = UDim2.new(1, 0, 1, 0)
	else
		local cur = GameConfig.levelInfo(levelValue.Value).needPoints
		local ratio = math.clamp((pointsValue.Value - cur) / (next.needPoints - cur), 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local leaderstats = player:WaitForChild("leaderstats")
leaderstats:WaitForChild("Level"):GetPropertyChangedSignal("Value"):Connect(refresh)
leaderstats:WaitForChild("Points"):GetPropertyChangedSignal("Value"):Connect(refresh)
refresh()
