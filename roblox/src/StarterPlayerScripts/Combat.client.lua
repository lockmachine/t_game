-- 画面右下に「たたく」ボタンを出し、押すと手に持っている花束で近くのプレイヤーを叩く。
-- クリック(PC)でもタップ(スマホ)でも同じボタンで操作できるようにしている。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZassouCombat"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "AttackButton"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -20, 1, -20)
button.Size = UDim2.new(0, 92, 0, 92)
button.BackgroundColor3 = Color3.fromRGB(255, 138, 101)
button.Text = "たたく"
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.AutoButtonColor = true
button.Parent = screenGui

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(1, 0)
buttonCorner.Parent = button

-- サーバー側にもクールダウンがあるが、連打でリモートイベントを無駄に
-- 飛ばさないようクライアント側でも簡単に絞っておく。
local ATTACK_COOLDOWN = 0.6
local onCooldown = false

button.Activated:Connect(function()
	if onCooldown then
		return
	end
	onCooldown = true
	attackRequest:FireServer()
	task.delay(ATTACK_COOLDOWN, function()
		onCooldown = false
	end)
end)
