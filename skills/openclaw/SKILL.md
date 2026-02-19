---
name: openclaw
description: "OpenClaw autonomous daemon management. Use when user mentions 'OpenClaw', 'デーモン起動', 'メール確認の自動化', 'LINE自動返信', 'Slack監視', 'Discord監視', '定期実行', 'cron設定', 'openclaw setup', 'openclaw start', 'heartbeat', 'HEARTBEAT.md'. Do NOT load for: general implementation tasks, code review, planning, CI/CD."
description-ja: "OpenClaw 自律デーモン管理。Heartbeat 駆動のサービス別 isolated session、Memory、配信機能を含む。Use when user mentions 'OpenClaw', 'デーモン起動', 'メール確認の自動化', 'LINE自動返信', 'Slack監視', 'Discord監視', '定期実行', 'cron設定', 'heartbeat'."
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob"]
argument-hint: "[setup|start|stop|status|config|heartbeat]"
---

# OpenClaw - Autonomous Daemon

Claude Agent SDK + Bun で構築された自律デーモン。30分間隔で Gmail / Google Calendar / LINE / Slack / Discord を巡回し、メッセージ確認・返信・スケジュール管理を自動実行します。

## Do NOT Load For (誤発動防止)

| トリガーワード | 正しいスキル | 理由 |
|---------------|-------------|------|
| "**実装して**" | `/impl` | 実装 ≠ デーモン管理 |
| "**レビューして**" | `/harness-review` | レビュー ≠ デーモン管理 |
| "**CI修正**" | `/ci` | CI ≠ メッセージ監視 |

## サブコマンド

| コマンド | 説明 |
|---------|------|
| `/openclaw setup` | 初回セットアップ（依存パッケージ、環境変数、MCP サーバー設定） |
| `/openclaw start` | デーモン起動 |
| `/openclaw stop` | デーモン停止 |
| `/openclaw status` | 稼働状態・最新ログ表示 |
| `/openclaw config` | 設定の表示・編集（サービス有効化、cron間隔、予算上限） |
| `/openclaw heartbeat` | HEARTBEAT.md の確認・編集（タスク追加・削除） |

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **セットアップ** | See [references/setup-guide.md](references/setup-guide.md) |
| **Gmail + Calendar** | See [references/gmail-calendar.md](references/gmail-calendar.md) |
| **LINE 統合** | See [references/line-integration.md](references/line-integration.md) |
| **Slack 統合** | See [references/slack-integration.md](references/slack-integration.md) |
| **Discord 統合** | See [references/discord-integration.md](references/discord-integration.md) |
| **デーモン管理** | See [references/daemon-management.md](references/daemon-management.md) |

## 実行手順

1. ユーザーのサブコマンドを判定
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従って実行

### setup 実行時

1. `references/setup-guide.md` を読み込み
2. 依存パッケージインストール確認
3. 環境変数の設定ガイド
4. `.claude-code-harness.config.yaml` に `openclaw` セクション追加
5. 動作テスト

### start / stop / status 実行時

```bash
# 起動
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-start.sh"

# 停止
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-stop.sh"

# 状態確認
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-status.sh"
```

### heartbeat 実行時

1. `openclaw/HEARTBEAT.md` を読み込み
2. 現在のタスク一覧を表示
3. ユーザーの指示に従いタスクを追加・削除・編集
4. 次回 cron 実行時に自動処理される旨を通知

## アーキテクチャ

```
Bun Daemon (openclaw/daemon/index.ts)
  │
  ├── croner (30分間隔 cron)
  │
  ├── Step 1: HEARTBEAT.md チェック → 空なら SKIP (API 呼ばない)
  │
  ├── Step 2: 有効サービス確認 → なければ SKIP
  │
  ├── Step 3: 予算チェック → 当日累計コスト ≧ 日次上限なら SKIP
  │
  ├── Step 4: サービス別 isolated query() (resume なし)
  │     ├── Memory: 前回 context_snapshot を prompt に注入
  │     ├── systemPrompt: claude_code preset
  │     ├── settingSources: ["project"]
  │     ├── plugins: [harness]
  │     ├── mcpServers: (サービス別)
  │     ├── model: サービス別設定 (opus/sonnet/haiku)
  │     ├── maxTurns: サービス別設定
  │     ├── maxBudgetUsd: サービス別設定
  │     └── permissionMode: bypassPermissions
  │     └── 結果を run-history.jsonl に保存
  │
  ├── Step 5: 結果マージ
  │
  ├── Step 6: 配信: LINE/Slack/Discord/Gmail に結果 push
  │
  └── Step 7: ログサマリー出力
```

## 設定

`.claude-code-harness.config.yaml`:

```yaml
openclaw:
  enabled: true
  cron_interval: "*/30 * * * *"
  max_turns: 20
  max_budget_usd: 1.00
  heartbeat:
    enabled: true
    file: "HEARTBEAT.md"
    skip_when_empty: true
  delivery:
    enabled: false
    channel: "line"
    only_when_actions: true
  services:
    gmail:
      enabled: true
      model: sonnet
      max_turns: 10
      max_budget_usd: 0.40
      priority: high
    calendar:
      enabled: true
      model: haiku
      max_turns: 5
      max_budget_usd: 0.20
      priority: medium
    line:
      enabled: false
    slack:
      enabled: false
    discord:
      enabled: false
```

## 必要な環境変数

| サービス | 環境変数 |
|---------|---------|
| Gmail + Calendar | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` |
| LINE | `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_DESTINATION_USER_ID` |
| Slack | `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` |
| Discord | `DISCORD_TOKEN` |

## 安全ルール

- 金銭に関わる承認は行わない（サマリーのみ）
- 個人情報の外部送信禁止
- 不審なリンク・添付ファイルは無視してフラグ
- 各実行に予算上限あり（サービス別 + 全体上限）
