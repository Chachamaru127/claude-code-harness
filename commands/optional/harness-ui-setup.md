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

→ ライセンスキーを環境変数に自動設定

### 引数なし

```
/harness-ui-setup
```

→ ライセンスキーの入力を求められます

---

## 実行フロー

### Step 0: 既存設定の確認

**最初に環境変数 `HARNESS_BETA_CODE` をチェック:**

```bash
echo $HARNESS_BETA_CODE
```

**設定済みの場合（値が存在する）:**

> ✅ **ライセンスキーは既に設定されています**
>
> 現在のキー: {先頭8文字}...
>
> harness-ui は既に利用可能です。http://localhost:37778 にアクセスしてください。
>
> キーを再設定する場合は `/harness-ui-setup --force` を実行してください。

**処理終了**（`--force` オプションがない場合）

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

### Step 3: 環境変数の設定

ユーザーのシェル設定ファイル（`~/.zshrc` または `~/.bashrc`）に環境変数を追加:

```bash
export HARNESS_BETA_CODE="ユーザーのライセンスキー"
```

**注意**: プラグインの `.mcp.json` は編集不要（環境変数から自動取得）

### Step 4: 完了メッセージ

> ✅ **harness-ui のセットアップが完了しました！**
>
> 📋 **設定内容**:
> - ライセンスキー: {キーの先頭8文字}...
> - Customer ID: {顧客ID}
> - 環境変数: `HARNESS_BETA_CODE` を ~/.zshrc に追加
>
> **次にやること:**
> 1. `source ~/.zshrc` を実行（または新しいターミナルを開く）
> 2. Claude Code を再起動
> 3. ブラウザで http://localhost:37778 にアクセス
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

**原因**: 環境変数が設定されていない、または Claude Code を再起動していない

**解決策**:
```bash
# 環境変数を確認
echo $HARNESS_BETA_CODE

# 設定されていない場合
source ~/.zshrc

# Claude Code を再起動
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

## セキュリティ

ライセンスキーは環境変数（`HARNESS_BETA_CODE`）で管理されます。

- **リポジトリに含めない**: `.env` ファイルは `.gitignore` に追加
- **シェル設定ファイル**: `~/.zshrc` は通常 Git 管理外なので安全
- **チーム開発時**: 各メンバーが個別のライセンスキーを取得することを推奨
