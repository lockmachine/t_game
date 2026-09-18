# Roblox版(Rojoプロジェクト)

これまでブラウザ(`index.html`)で作っていたゲームを、Robloxに移行して作り直すためのプロジェクトです。
Robloxのスクリプト(Luau)はこのフォルダにファイルとして置き、[Rojo](https://rojo.space)という
無料ツールでRoblox Studioとリアルタイム同期しながら開発します。

## はじめに(1回だけ行う準備)

### 1. Roblox Studioをインストール
[roblox.com](https://www.roblox.com) でアカウントを作り(未登録なら)、Roblox Studioをダウンロード・
インストールします(Windows/Mac対応、無料)。

### 2. Rokit(ツール管理ソフト)をインストール

ターミナル(Mac)またはPowerShell(Windows)で実行します。

**Mac:**
```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

**Windows(PowerShell):**
```sh
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

### 3. このフォルダ(`roblox/`)でRojoをインストール

ターミナルでこの`roblox`フォルダに移動してから実行します。

```sh
rokit add rojo-rbx/rojo
rokit install
```

### 4. Roblox Studio用のRojoプラグインを入れる

```sh
rojo plugin install
```

## 毎回の開発の流れ

1. `roblox` フォルダでターミナルを開き、以下を実行してサーバーを起動する

   ```sh
   rojo serve
   ```

2. Roblox Studioで新規プレイス(Baseplateなど)を開く
3. Studio上部のツールバーから **Rojo** プラグインのボタンを押し、パネルの **Connect** を押す
4. 同期されたら、Studio上部の **▶(再生)** ボタンを押してテスト再生する
5. 緑色のブロックが出現し、出力(View → Output)に「つながったよ!」と表示されれば接続成功

## 現在の状況

- 接続確認 ✅ 完了
- 雑草ぬき最小ロジック(近づいてぬく→ポイント増減) ✅ 完了・動作確認済み
- レベルの仕組み ✅ 追加(ブラウザ版と同じLv.1〜3、レベルが足りない雑草はぬけない、
  おはなを抜くとレベルダウンもあり)
- レベルアップ・ロック中の案内は画面右上の通知(`StarterGui:SendNotification`)で表示
- 雑草の見た目を種類ごとに変更 ✅(小=細い葉っぱ、中・大=丸い茂み、おはな=茎+光る花の頭)
- 雑草・おはなはランダムな位置に生え、抜くと数秒後に別の場所にまた生える ✅
- 未対応: ロック中の雑草を灰色にする(見ただけでロック中と分かるようにする)、
  お片づけステージ、年齢に応じた見た目変化、カスタムHUD(今はRobloxデフォルトの
  プレイヤーリスト+通知のみ)

`rojo serve` を起動してStudioと接続したままにしておけば、このリポジトリを `git pull` するだけで
最新のスクリプトが自動的にStudio側へ同期されます。**ただし、新しく追加されたファイルが同期
されないことがあるので、その場合は `rojo serve` を再起動してから、StudioのRojoパネルで
Disconnect→Connectし直してください。**
