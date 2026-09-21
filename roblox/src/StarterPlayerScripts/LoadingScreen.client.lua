-- サーバー側のワールド生成(地面・街・雑草3000本など)が終わるまで、
-- 画面全体を覆って隠しておく。これが無いと、組み上がっていく途中の
-- 何もない/中途半端な状態がプレイヤーに丸見えになってしまう。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local worldReadyEvent = ReplicatedStorage:WaitForChild("WorldReady")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(46, 92, 48)
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 480, 0, 50)
titleLabel.Position = UDim2.new(0.5, -240, 0.5, -40)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ワールドをつくっています"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 28
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Parent = overlay

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(0, 480, 0, 30)
subLabel.Position = UDim2.new(0.5, -240, 0.5, 14)
subLabel.BackgroundTransparency = 1
subLabel.Text = "雑草・道路・建物などを準備しています"
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 16
subLabel.TextColor3 = Color3.fromRGB(220, 235, 220)
subLabel.Parent = overlay

local animating = true
task.spawn(function()
	local dots = 0
	while animating do
		dots = (dots % 3) + 1
		titleLabel.Text = "ワールドをつくっています" .. string.rep(".", dots)
		task.wait(0.4)
	end
end)

local dismissed = false
local function dismiss()
	if dismissed then
		return
	end
	dismissed = true
	animating = false
	screenGui:Destroy()
end

worldReadyEvent.OnClientEvent:Connect(dismiss)

-- 万一シグナルが届かない場合の保険(ローディング画面が永遠に残らないように)。
task.delay(30, dismiss)
