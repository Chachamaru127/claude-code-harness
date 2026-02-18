# LINE 統合

## MCP パッケージ

`@line/line-bot-mcp-server` — LINE 公式の MCP サーバー。

## 利用可能なツール

| ツール | 説明 |
|-------|------|
| `mcp__line-bot__push_text_message` | テキストメッセージ送信 |
| `mcp__line-bot__push_flex_message` | Flex Message 送信（リッチ UI） |
| `mcp__line-bot__get_profile` | ユーザープロフィール取得 |
| `mcp__line-bot__get_message_content` | メッセージコンテンツ取得 |
| `mcp__line-bot__broadcast_text_message` | ブロードキャスト送信 |

## Cron 実行時の動作

### メッセージチェックフロー

1. Webhook 経由で受信したメッセージを確認
2. 各メッセージの内容を分析:
   - 質問 → 回答を作成して送信
   - 依頼 → 対応可否を判定
   - 挨拶 → 適切な返信
3. `push_text_message` で返信

### 注意

LINE Messaging API は Webhook ベースのため、定期ポーリングではなく
Webhook 受信履歴からの処理が中心となる。
デーモンは未処理の Webhook イベントを確認する。

## 必要な環境変数

```bash
LINE_CHANNEL_ACCESS_TOKEN=xxxxx
LINE_DESTINATION_USER_ID=Uxxxxx
```

## LINE Developers Console セットアップ

1. https://developers.line.biz/ にアクセス
2. プロバイダー作成 → チャンネル作成（Messaging API）
3. チャンネルアクセストークン発行（長期）
4. Webhook 設定（オプション）

## 注意事項

- Push Message は有料プランが必要（月1000通まで無料）
- Reply Message は無料（Webhook トリガー時のみ）
- Flex Message で構造化された返信が可能
- ユーザーがボットをブロックすると送信エラーになる
