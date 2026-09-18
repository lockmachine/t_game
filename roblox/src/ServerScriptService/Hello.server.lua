-- Rojoの同期テスト用スクリプト。
-- Studioでこのプレイスを再生(▶)すると、緑のブロックが出現し、
-- 出力(Output)ウィンドウにメッセージが表示されます。
-- これが確認できたら、Rojoでの接続は成功です。

print("つながったよ! Rojoの同期に成功しました。")

local part = Instance.new("Part")
part.Name = "ZassouTestPart"
part.Size = Vector3.new(4, 1, 4)
part.Position = Vector3.new(0, 10, 0)
part.Anchored = true
part.BrickColor = BrickColor.new("Bright green")
part.Parent = workspace
