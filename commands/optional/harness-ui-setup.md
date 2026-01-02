---
description: "[オプション] harness-ui ダッシュボードのセットアップ"
description-en: "[Optional] Set up harness-ui dashboard"
---

# /harness-ui-setup - harness-ui ダッシュボードセットアップ

harness-ui（ブラウザベースのダッシュボード）を有効化します。

## バイブコーダー向け（こう言えばOK）

- 「**harness-ui を有効にして**」→ このコマンド
- 「**ダッシュボードを使いたい**」→ このコマンド
- 「**UIでヘルススコアを見たい**」→ このコマンド

## できること（成果物）

- ブラウザで http://localhost:37778 にアクセス可能
- ヘルススコア、Usage、Skills の可視化
- Claude Code 起動時に自動起動

---

## 使い方

### 引数付き（推奨）

```
/harness-ui-setup YOUR-LICENSE-KEY
```

→ ライセンスキーを自動設定

### 引数なし

```
/harness-ui-setup
```

→ ライセンスキーの入力を求められます

---

## 実行フロー

### Step 1: ライセンスキーの確認

**引数でキーが渡された場合:**
→ Step 2 へ進む

**引数がない場合:**

> 🔑 **Polar ライセンスキーを入力してください**
>
> ライセンスキーをお持ちでない場合は、ベータ版のため管理者からライセンスキーをリクエストしてください。
>
> キーを入力:

**回答を待つ**

### Step 2: ライセンスキーの検証

Polar API でキーを検証:

```typescript
// POST https://api.polar.sh/v1/customer-portal/license-keys/validate
{
  "key": "ユーザーのキー",
  "organization_id": "54443411-11a2-45b0-9473-7aa37f96a677"
}
```

**検証成功の場合:**
→ Step 3 へ進む

**検証失敗の場合:**

> ❌ **ライセンスキーが無効です**
>
> 理由: {エラー理由}
>
> 正しいキーを確認するか、管理者にお問い合わせください。

**処理終了**

### Step 3: プラグインの .mcp.json を更新

プラグインディレクトリの `.mcp.json` を更新:

```json
{
  "mcpServers": {
    "harness-ui": {
      "type": "stdio",
      "command": "bun",
      "args": ["${CLAUDE_PLUGIN_ROOT}/harness-ui/src/mcp/server.ts"],
      "env": {
        "PROJECT_ROOT": "${CLAUDE_PLUGIN_ROOT}",
        "HARNESS_BETA_CODE": "ユーザーのライセンスキー"
      }
    }
  }
}
```

**注意**: `HARNESS_UI_DEV` は削除し、`HARNESS_BETA_CODE` を設定

### Step 4: 完了メッセージ

> ✅ **harness-ui のセットアップが完了しました！**
>
> 📋 **設定内容**:
> - ライセンスキー: {キーの先頭8文字}...
> - Customer ID: {顧客ID}
>
> **次にやること:**
> 1. Claude Code を再起動
> 2. ブラウザで http://localhost:37778 にアクセス
>
> 💡 **ヒント**: MCP 一覧で `harness-ui` が表示されていれば成功です。

---

## トラブルシューティング

### エラー: ライセンスキーが無効

**原因**: キーが間違っているか、期限切れ

**解決策**:
1. 受け取ったキーを再確認
2. 再度 `/harness-ui-setup YOUR-KEY` を実行

### エラー: harness-ui が起動しない

**原因**: Claude Code を再起動していない

**解決策**:
```
Ctrl+C で終了 → claude で再起動
```

### エラー: ポート 37778 が使用中

**原因**: 別のプロセスがポートを使用

**解決策**:
```bash
lsof -i :37778
kill -9 {PID}
```

---

## 関連コマンド

- `/validate` - プラグイン検証
- `/harness-update` - プラグイン更新

---

## 注意事項

- ライセンスキーは Polar API でオンライン検証されます
- 無効なキーでは harness-ui は起動しません
- 開発者は `HARNESS_UI_DEV=true` でバイパス可能

## ⚠️ セキュリティ警告

**`.mcp.json` にはライセンスキーが平文で保存されます。**

以下の点に注意してください：

1. **Git に絶対コミットしない**
   - `.gitignore` に `.mcp.json` が含まれていることを確認
   - `git status` で `.mcp.json` が追跡されていないことを確認

2. **公開リポジトリに注意**
   - 誤ってプッシュした場合、ライセンスキーを即座に失効させてください
   - Polar ダッシュボードから新しいキーを発行できます

3. **チーム開発時**
   - 各メンバーが個別のライセンスキーを取得することを推奨
   - 共有キーは使用回数制限に注意
