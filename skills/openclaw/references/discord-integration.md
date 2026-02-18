# Discord 統合

## MCP パッケージ

`mcp-discord` — Discord Bot MCP サーバー。

## 利用可能なツール

| ツール | 説明 |
|-------|------|
| `mcp__discord__discord_send` | メッセージ送信 |
| `mcp__discord__discord_read` | メッセージ読み取り |
| `mcp__discord__discord_list_channels` | チャンネル一覧取得 |
| `mcp__discord__discord_list_guilds` | サーバー一覧取得 |
| `mcp__discord__discord_get_user` | ユーザー情報取得 |

## Cron 実行時の動作

### メンション・未読チェックフロー

1. `discord_list_channels` で監視対象チャンネルを取得
2. `discord_read` で最新メッセージを確認
3. ボットへのメンション（`@bot`）を抽出
4. 各メンションの内容を分析:
   - 質問 → 回答を作成
   - コマンド → 対応処理を実行
   - 雑談 → スキップ
5. `discord_send` で返信

## 必要な環境変数

```bash
DISCORD_TOKEN=xxxxx
```

## Discord Bot セットアップ

### 1. アプリケーション作成

1. https://discord.com/developers/applications にアクセス
2. New Application → 名前を設定
3. Bot タブ → Token をコピー

### 2. 権限設定

Bot Permissions:
- Read Messages/View Channels
- Send Messages
- Read Message History
- Mention Everyone (オプション)

### 3. サーバーに招待

OAuth2 → URL Generator:
- Scopes: `bot`
- Permissions: 上記を選択
- 生成された URL でサーバーに招待

## 注意事項

- Discord API のレート制限: 50 req/second (global)
- Bot は招待されたサーバーのみアクセス可能
- メッセージ内容の Intent 設定が必要（Privileged Gateway Intents）
- DM の読み取りには追加設定が必要
