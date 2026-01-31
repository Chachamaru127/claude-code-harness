# Browser Automation with agent-browser

agent-browser CLI を使用したブラウザ自動化の詳細ガイド。

---

## インストール

```bash
# グローバルインストール
npm install -g agent-browser

# Chromium をダウンロード
agent-browser install

# Linux の場合、システム依存関係も
agent-browser install --with-deps
```

---

## 基本操作

### ページを開く

```bash
# 基本
agent-browser open https://example.com

# ブラウザを表示して開く（デバッグ用）
agent-browser open https://example.com --headed

# カスタムヘッダー付き
agent-browser open https://api.example.com --headers '{"Authorization": "Bearer token"}'
```

### クリック

```bash
# 要素参照でクリック（推奨）
agent-browser click @e1

# CSS セレクタでクリック
agent-browser click "button.submit"

# ダブルクリック
agent-browser dblclick @e1
```

### 入力

```bash
# フォームをクリア&入力
agent-browser fill @e1 "hello@example.com"

# 追加入力（クリアしない）
agent-browser type @e1 "追加テキスト"

# キーを押す
agent-browser press Enter
agent-browser press Tab
agent-browser press "Control+a"
```

### フォーム操作

```bash
# チェックボックス
agent-browser check @e1
agent-browser uncheck @e1

# セレクトボックス
agent-browser select @e1 "option-value"

# ファイルアップロード
agent-browser upload @e1 /path/to/file.pdf
```

### スクロール

```bash
# 方向指定
agent-browser scroll down
agent-browser scroll up 500

# 要素を表示
agent-browser scrollintoview @e1
```

---

## 情報取得

```bash
# テキスト取得
agent-browser get text @e1

# HTML 取得
agent-browser get html @e1

# 属性取得
agent-browser get attr href @e1

# 値取得（input）
agent-browser get value @e1

# 現在の URL
agent-browser get url

# ページタイトル
agent-browser get title

# 要素数
agent-browser get count "li.item"

# 要素の位置とサイズ
agent-browser get box @e1
```

---

## 状態チェック

```bash
# 表示されているか
agent-browser is visible @e1

# 有効か（disabled でないか）
agent-browser is enabled @e1

# チェックされているか
agent-browser is checked @e1
```

---

## 待機

```bash
# 要素が表示されるまで待機
agent-browser wait @e1
agent-browser wait "button.loaded"

# 時間で待機（ミリ秒）
agent-browser wait 2000
```

---

## スクリーンショット

```bash
# 基本
agent-browser screenshot

# ファイル名指定
agent-browser screenshot output.png

# フルページ
agent-browser screenshot --full page.png

# PDF として保存
agent-browser pdf document.pdf
```

---

## JavaScript 実行

```bash
# スクリプト実行
agent-browser eval "document.title"
agent-browser eval "localStorage.getItem('token')"
agent-browser eval "window.scrollTo(0, document.body.scrollHeight)"
```

---

## ネットワーク操作

```bash
# リクエストをモック
agent-browser network route "*/api/users" --body '{"users": []}'

# リクエストをブロック
agent-browser network route "*/analytics/*" --abort

# ルート解除
agent-browser network unroute "*/api/users"

# リクエスト履歴
agent-browser network requests
agent-browser network requests --filter "api"
agent-browser network requests --clear
```

---

## Cookie/Storage

```bash
# Cookie 取得
agent-browser cookies get

# Cookie 設定
agent-browser cookies set '{"name": "session", "value": "abc123", "domain": "example.com"}'

# Cookie クリア
agent-browser cookies clear

# LocalStorage
agent-browser storage local get "key"
agent-browser storage local set "key" "value"
agent-browser storage local clear

# SessionStorage
agent-browser storage session get "key"
```

---

## タブ管理

```bash
# 新しいタブを開く
agent-browser tab new

# タブ一覧
agent-browser tab list

# タブを切り替え
agent-browser tab 2

# タブを閉じる
agent-browser tab close
```

---

## ブラウザ設定

```bash
# ビューポートサイズ
agent-browser set viewport 1920 1080

# デバイスエミュレーション
agent-browser set device "iPhone 12"

# 位置情報
agent-browser set geo 35.6762 139.6503

# オフラインモード
agent-browser set offline on
agent-browser set offline off

# ダークモード
agent-browser set media dark
agent-browser set media light

# 認証情報
agent-browser set credentials admin password123
```

---

## デバッグ

```bash
# コンソールログを表示
agent-browser console
agent-browser console --clear

# ページエラーを表示
agent-browser errors
agent-browser errors --clear

# 要素をハイライト
agent-browser highlight @e1

# トレース記録
agent-browser trace start
# ... 操作 ...
agent-browser trace stop trace.zip
```

---

## Find コマンド（高度な要素検索）

```bash
# ロールで検索してクリック
agent-browser find role button click --name "Submit"

# テキストで検索
agent-browser find text "Click here" click

# ラベルで検索
agent-browser find label "Email" fill "test@example.com"

# プレースホルダーで検索
agent-browser find placeholder "Enter your name" fill "John"

# テスト ID で検索
agent-browser find testid "submit-btn" click

# 最初/最後/n番目
agent-browser find first "button" click
agent-browser find last "input" fill "text"
agent-browser find nth 2 "li" click
```

---

## マウス操作（低レベル）

```bash
# マウス移動
agent-browser mouse move 100 200

# マウスボタン
agent-browser mouse down
agent-browser mouse up
agent-browser mouse down right

# ホイール
agent-browser mouse wheel 100
agent-browser mouse wheel 100 50  # dy, dx
```

---

## ドラッグ&ドロップ

```bash
# 要素間のドラッグ
agent-browser drag @e1 @e2

# 座標指定
agent-browser drag @e1 "500,300"
```

---

## セッション管理

```bash
# 名前付きセッション
agent-browser --session myapp open https://example.com

# セッション一覧
agent-browser session list

# 現在のセッション名
agent-browser session

# 環境変数でも指定可能
AGENT_BROWSER_SESSION=myapp agent-browser snapshot
```

---

## JSON 出力

```bash
# JSON 形式で出力
agent-browser snapshot --json
agent-browser get text @e1 --json
agent-browser network requests --json
```

---

## カスタムブラウザ

```bash
# カスタム実行ファイル
agent-browser --executable-path /path/to/chrome open https://example.com

# 環境変数でも指定可能
AGENT_BROWSER_EXECUTABLE_PATH=/path/to/chrome agent-browser open https://example.com
```
