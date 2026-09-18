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

ここまで確認できたら、`src/` の中身を少しずつ本編のゲームロジックに置き換えていきます。
