# Slack 統合

## MCP パッケージ

`@anthropic-ai/mcp-server-slack` — Anthropic 公式の Slack MCP サーバー。

## 利用可能なツール

| ツール | 説明 |
|-------|------|
| `mcp__slack__slack_list_channels` | チャンネル一覧取得 |
| `mcp__slack__slack_get_channel_history` | チャンネル履歴取得 |
| `mcp__slack__slack_post_message` | メッセージ投稿 |
| `mcp__slack__slack_reply_to_thread` | スレッド返信 |
| `mcp__slack__slack_get_thread_replies` | スレッド返信取得 |
| `mcp__slack__slack_get_users` | ユーザー一覧取得 |
| `mcp__slack__slack_search_messages` | メッセージ検索 |

## Cron 実行時の動作

### メンション・未読チェックフロー

1. `slack_search_messages` でボットへのメンションを検索
2. 各メンションの内容を分析:
   - 質問 → 回答を作成
   - タスク依頼 → 受領確認を返信
   - 情報共有 → リアクションのみ
3. `slack_reply_to_thread` でスレッド返信（チャンネル汚染防止）

### チャンネル監視

設定で指定されたチャンネルの `slack_get_channel_history` で最新メッセージを確認。
前回実行時刻以降のメッセージのみ処理。

## 必要な環境変数

```bash
SLACK_BOT_TOKEN=xoxb-xxxxx
SLACK_TEAM_ID=Txxxxx
```

## Slack App セットアップ

### 必要な Bot Token Scopes

| Scope | 用途 |
|-------|------|
| `channels:history` | チャンネル履歴の読み取り |
| `channels:read` | チャンネル一覧の取得 |
| `chat:write` | メッセージの投稿 |
| `users:read` | ユーザー情報の取得 |
| `search:read` | メッセージ検索 |

### セットアップ手順

1. https://api.slack.com/apps で新しいアプリ作成
2. OAuth & Permissions → Bot Token Scopes 追加
3. ワークスペースにインストール
4. Bot User OAuth Token をコピー

## 注意事項

- Slack API のレート制限: Tier 3 (50+ req/min)
- スレッド返信を優先（チャンネルの可読性維持）
- ボットが参加していないチャンネルは読めない
- Enterprise Grid は追加設定が必要
