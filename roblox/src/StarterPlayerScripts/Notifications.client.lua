-- サーバーから届いたメッセージ(レベルアップ・お知らせなど)を
-- 画面右上の通知として表示するだけのスクリプト。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local remote = ReplicatedStorage:WaitForChild("ShowMessage")

remote.OnClientEvent:Connect(function(text)
	StarterGui:SetCore("SendNotification", {
		Title = "ざっそうぬき",
		Text = text,
		Duration = 3,
	})
end)
