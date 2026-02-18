# OpenClaw セットアップガイド

## 前提条件

1. **Bun** がインストール済み
   ```bash
   curl -fsSL https://bun.sh/install | bash
   bun --version  # v1.0+
   ```

2. **Claude Agent SDK** の認証
   ```bash
   export ANTHROPIC_API_KEY=your-api-key
   ```

3. **Claude Code Harness** がインストール済み

## セットアップ手順

### Step 1: 依存パッケージのインストール

```bash
cd "${CLAUDE_PLUGIN_ROOT}/openclaw/daemon"
bun install
```

### Step 2: 環境変数の設定

`.env` ファイルまたはシェル環境変数で設定:

```bash
# 必須: Anthropic API Key
export ANTHROPIC_API_KEY="sk-ant-..."

# Gmail + Calendar (Google Workspace)
export GOOGLE_CLIENT_ID="xxxxx.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="GOCSPX-xxxxx"
export GOOGLE_REFRESH_TOKEN="1//xxxxx"

# LINE
export LINE_CHANNEL_ACCESS_TOKEN="xxxxx"
export LINE_DESTINATION_USER_ID="Uxxxxx"

# Slack
export SLACK_BOT_TOKEN="xoxb-xxxxx"
export SLACK_TEAM_ID="Txxxxx"

# Discord
export DISCORD_TOKEN="xxxxx"
```

### Step 3: 設定ファイルの編集

`.claude-code-harness.config.yaml` に以下を追加:

```yaml
openclaw:
  enabled: true
  cron_interval: "*/30 * * * *"
  max_turns: 20
  max_budget_usd: 1.00
  services:
    gmail:
      enabled: true
    calendar:
      enabled: true
    line:
      enabled: false    # LINE を使う場合は true
    slack:
      enabled: false    # Slack を使う場合は true
    discord:
      enabled: false    # Discord を使う場合は true
```

### Step 4: 動作テスト

```bash
# 単発テスト（cron ではなく即時実行）
cd "${CLAUDE_PLUGIN_ROOT}/openclaw/daemon"
bun run index.ts
```

### Step 5: デーモン起動

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-start.sh"
```

## Google OAuth セットアップ

### 1. GCP Console でプロジェクト作成

1. https://console.cloud.google.com/ にアクセス
2. 新しいプロジェクトを作成
3. Gmail API と Google Calendar API を有効化
4. OAuth 2.0 クライアント ID を作成
5. リダイレクト URI: `http://localhost:3000/oauth2callback`

### 2. Refresh Token の取得

```bash
# mcp-google-workspace の認証フローを使用
npx mcp-google-workspace auth
```

## LINE セットアップ

### 1. LINE Developers Console

1. https://developers.line.biz/ にアクセス
2. Messaging API チャンネルを作成
3. Channel Access Token を発行
4. Webhook URL を設定（必要な場合）

### 2. ユーザー ID の取得

LINE Official Account Manager → チャット → 対象ユーザーの User ID を確認

## Slack セットアップ

### 1. Slack App 作成

1. https://api.slack.com/apps にアクセス
2. 新しいアプリを作成
3. Bot Token Scopes: `channels:history`, `channels:read`, `chat:write`, `users:read`
4. ワークスペースにインストール

## Discord セットアップ

### 1. Discord Bot 作成

1. https://discord.com/developers/applications にアクセス
2. 新しいアプリケーションを作成
3. Bot タブで Token を取得
4. OAuth2 → URL Generator で bot を選択、サーバーに招待

## トラブルシューティング

### デーモンが起動しない

```bash
# ログを確認
cat .claude/logs/openclaw-daemon.log

# 設定を確認
grep -A 10 "openclaw:" .claude-code-harness.config.yaml
```

### MCP サーバーに接続できない

```bash
# 各 MCP サーバーの単体テスト
npx mcp-google-workspace --help
npx @line/line-bot-mcp-server --help
```

### 予算超過で停止

`max_budget_usd` を増やすか、有効サービス数を減らす:

```yaml
openclaw:
  max_budget_usd: 2.00  # $1.00 → $2.00
```
