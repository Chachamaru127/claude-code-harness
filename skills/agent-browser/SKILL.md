---
name: agent-browser
description: "Control browser like hands and feet. Navigate, fill forms, screenshot, bring it on. Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include 'go to [url]', 'click on', 'fill out the form', 'take a screenshot', 'scrape', 'automate', 'test the website', 'log into', or any browser interaction request. Do NOT load for: sharing URLs, embedding links, screenshot image files."
description-en: "Control browser like hands and feet. Navigate, fill forms, screenshot, bring it on. Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include 'go to [url]', 'click on', 'fill out the form', 'take a screenshot', 'scrape', 'automate', 'test the website', 'log into', or any browser interaction request. Do NOT load for: sharing URLs, embedding links, screenshot image files."
description-ja: "ブラウザを手足のように操る。ページ遷移、フォーム入力、スクショ、なんでもこい。Use when users ask to navigate websites, fill forms, take screenshots, extract web data, test web apps, or automate browser workflows. Trigger phrases include 'go to [url]', 'click on', 'fill out the form', 'take a screenshot', 'scrape', 'automate', 'test the website', 'log into', or any browser interaction request. Do NOT load for: sharing URLs, embedding links, screenshot image files."
allowed-tools: ["Bash", "Read"]
user-invocable: false
context: fork
argument-hint: "[url] [--headless]"
---

# Agent Browser Skill

ブラウザ自動化を行うスキル。agent-browser CLI を使用して、UI デバッグ・検証・自動操作を実行します。

---

## トリガーフレーズ

このスキルは以下のフレーズで自動起動します：

- 「ページを開いて」「URLを確認して」
- 「クリックして」「入力して」「フォームに」
- 「スクリーンショットを撮って」
- 「UIを確認して」「画面をテストして」
- "open this page", "click on", "fill the form", "screenshot"

---

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **ブラウザ自動化** | See [references/browser-automation.md](${CLAUDE_SKILL_DIR}/references/browser-automation.md) |
| **AI スナップショットワークフロー** | See [references/ai-snapshot-workflow.md](${CLAUDE_SKILL_DIR}/references/ai-snapshot-workflow.md) |

## 実行手順

### Step 0: agent-browser の確認

```bash
# インストール確認
which agent-browser

# 未インストールの場合
npm install -g agent-browser
agent-browser install
```

### Step 1: ユーザーのリクエストを分類

| リクエストタイプ | 対応アクション |
|----------------|---------------|
| URL を開く | `agent-browser open <url>` |
| 要素をクリック | スナップショット → `agent-browser click @ref` |
| フォーム入力 | スナップショット → `agent-browser fill @ref "text"` |
| 状態確認 | `agent-browser snapshot -i -c` |
| スクリーンショット | `agent-browser screenshot <path>` |
| デバッグ | `agent-browser --headed open <url>` |

### Step 2: AI スナップショットワークフロー（推奨）

ほとんどの操作で、まず**スナップショットを取得**してから要素参照で操作します：

```bash
# 1. ページを開く
agent-browser open https://example.com

# 2. スナップショット取得（AI 向け、インタラクティブ要素のみ）
agent-browser snapshot -i -c

# 出力例:
# - link "Home" [ref=e1]
# - button "Login" [ref=e2]
# - input "Email" [ref=e3]
# - input "Password" [ref=e4]
# - button "Submit" [ref=e5]

# 3. 要素参照で操作
agent-browser click @e2           # Login ボタンをクリック
agent-browser fill @e3 "user@example.com"
agent-browser fill @e4 "password123"
agent-browser click @e5           # Submit
```

### Step 3: 結果の確認

```bash
# 現在の状態をスナップショットで確認
agent-browser snapshot -i -c

# または URL を確認
agent-browser get url

# スクリーンショットを取得
agent-browser screenshot result.png
```

---

## クイックリファレンス

### 基本操作

| コマンド | 説明 |
|---------|------|
| `open <url>` | URL を開く |
| `snapshot -i -c` | AI 向けスナップショット |
| `click @e1` | 要素をクリック |
| `fill @e1 "text"` | フォームに入力 |
| `type @e1 "text"` | テキストを入力 |
| `press Enter` | キーを押す |
| `screenshot [path]` | スクリーンショット |
| `close` | ブラウザを閉じる |

### ナビゲーション

| コマンド | 説明 |
|---------|------|
| `back` | 戻る |
| `forward` | 進む |
| `reload` | リロード |

### 情報取得

| コマンド | 説明 |
|---------|------|
| `get text @e1` | テキスト取得 |
| `get html @e1` | HTML 取得 |
| `get url` | 現在の URL |
| `get title` | ページタイトル |

### 待機

| コマンド | 説明 |
|---------|------|
| `wait @e1` | 要素を待機 |
| `wait 1000` | 1秒待機 |

### デバッグ

| コマンド | 説明 |
|---------|------|
| `--headed` | ブラウザを表示 |
| `console` | コンソールログ |
| `errors` | ページエラー |
| `highlight @e1` | 要素をハイライト |

---

## セッション管理

複数のタブ/セッションを並列管理：

```bash
# セッションを指定
agent-browser --session admin open https://admin.example.com
agent-browser --session user open https://example.com

# セッション一覧
agent-browser session list

# 特定セッションで操作
agent-browser --session admin snapshot -i -c
```

---

## MCP ブラウザツールとの使い分け

| ツール | 推奨度 | 用途 |
|--------|--------|------|
| **agent-browser** | ★★★ | 第一選択。AI 向けスナップショットが強力 |
| chrome-devtools MCP | ★★☆ | Chrome が既に開いている場合 |
| playwright MCP | ★★☆ | 複雑な E2E テスト |

**原則**: まず agent-browser を試し、うまくいかない場合のみ MCP ツールを使用。

---

## 注意事項

- agent-browser はヘッドレスモードがデフォルト
- `--headed` オプションでブラウザを表示可能
- セッションは明示的に `close` するまで維持される
- 認証が必要なサイトはセッションを活用
