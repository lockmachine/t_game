-- ちょうせんステージ中だけ、画面上部に残り時間とボーナス獲得数を表示する。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local stageEvent = ReplicatedStorage:WaitForChild("StageEvent")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StageHud"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 70)
panel.Position = UDim2.new(0.5, -130, 0, 16)
panel.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
panel.BackgroundTransparency = 0.15
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -20, 0, 30)
timerLabel.Position = UDim2.new(0, 10, 0, 6)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 22
timerLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
timerLabel.Text = "のこり 30秒"
timerLabel.Parent = panel

local bonusLabel = Instance.new("TextLabel")
bonusLabel.Size = UDim2.new(1, -20, 0, 24)
bonusLabel.Position = UDim2.new(0, 10, 0, 36)
bonusLabel.BackgroundTransparency = 1
bonusLabel.Font = Enum.Font.Gotham
bonusLabel.TextSize = 16
bonusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bonusLabel.Text = "ボーナス +0pt"
bonusLabel.Parent = panel

local totalBonus = 0

stageEvent.OnClientEvent:Connect(function(kind, value)
	if kind == "start" then
		totalBonus = 0
		bonusLabel.Text = "ボーナス +0pt"
		timerLabel.Text = "のこり " .. tostring(value) .. "秒"
		screenGui.Enabled = true
	elseif kind == "tick" then
		timerLabel.Text = "のこり " .. tostring(value) .. "秒"
	elseif kind == "collect" then
		totalBonus += value
		bonusLabel.Text = "ボーナス +" .. totalBonus .. "pt"
	elseif kind == "end" then
		screenGui.Enabled = false
	end
end)
