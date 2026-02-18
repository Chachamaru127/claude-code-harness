# Gmail + Google Calendar 統合

## MCP パッケージ

`mcp-google-workspace` — Gmail と Calendar を一つの MCP サーバーで提供。

## 利用可能なツール

### Gmail

| ツール | 説明 |
|-------|------|
| `mcp__google-workspace__gmail_search` | メール検索（未読、送信者、件名等） |
| `mcp__google-workspace__gmail_get` | メール本文の取得 |
| `mcp__google-workspace__gmail_send` | メール送信 |
| `mcp__google-workspace__gmail_reply` | メールへの返信 |
| `mcp__google-workspace__gmail_draft` | 下書き作成 |
| `mcp__google-workspace__gmail_label` | ラベル操作 |

### Calendar

| ツール | 説明 |
|-------|------|
| `mcp__google-workspace__calendar_list` | 予定の一覧取得 |
| `mcp__google-workspace__calendar_get` | 予定の詳細取得 |
| `mcp__google-workspace__calendar_create` | 予定の作成 |
| `mcp__google-workspace__calendar_update` | 予定の更新 |
| `mcp__google-workspace__calendar_delete` | 予定の削除 |

## Cron 実行時の動作

### Gmail チェックフロー

1. `gmail_search` で未読メール一覧取得（query: `is:unread`）
2. 各メールの `gmail_get` で本文取得
3. 優先度判定:
   - **緊急**: 重要な連絡先 or 件名に「緊急」「至急」「URGENT」
   - **重要**: 返信が必要なメール
   - **通常**: 情報共有、ニュースレター
   - **低**: 広告、自動通知
4. 緊急・重要: `gmail_reply` で返信 or `gmail_draft` で下書き
5. 通常・低: サマリーのみ

### Calendar チェックフロー

1. `calendar_list` で今後24時間の予定取得
2. 各予定の準備事項を判定:
   - ミーティング → 議題・資料の確認
   - デッドライン → 進捗確認
   - 移動 → 所要時間の確認
3. 結果をレポートに含める

## 必要な環境変数

```bash
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
GOOGLE_REDIRECT_URI=http://localhost:3000/oauth2callback
GOOGLE_REFRESH_TOKEN=1//xxxxx
```

## 注意事項

- Gmail API の日次クォータ: 250 units/user/second
- Calendar API の日次クォータ: 1,000,000 queries/day
- Refresh Token は定期的に更新が必要な場合あり
- 送信メールにはレート制限あり（500件/日）
