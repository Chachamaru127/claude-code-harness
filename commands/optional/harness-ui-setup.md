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

### Step 4: 依存関係のインストール

harness-ui の依存関係をインストール:

```bash
cd ${CLAUDE_PLUGIN_ROOT}/harness-ui && bun install
```

**Bun がインストールされていない場合:**

```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash

# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"
```

**インストール成功の確認:**

```bash
ls ${CLAUDE_PLUGIN_ROOT}/harness-ui/node_modules | head -5
```

→ パッケージ名が表示されれば成功

### Step 5: 環境変数の反映とサーバー起動確認

```bash
# 環境変数を反映
source ~/.zshrc  # または source ~/.bashrc

# harness-ui サーバーを手動起動（確認用）
cd ${CLAUDE_PLUGIN_ROOT}/harness-ui && bun run dev &
```

**起動確認:**

```bash
curl -s http://localhost:37778/api/status
```

→ `{"status":"ok"...}` が返れば成功

### Step 6: 現在のプロジェクトを登録

サーバー起動後、現在のプロジェクトをドロップダウンに登録:

```bash
# 現在のプロジェクトを取得
PROJECT_PATH=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# プロジェクトを登録
curl -s -X POST http://localhost:37778/api/projects \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$PROJECT_NAME\", \"path\": \"$PROJECT_PATH\"}"
```

**成功時のレスポンス:**

```json
{"project":{"id":"proj_xxx","name":"your-project","path":"/path/to/project"}}
```

**既に登録済みの場合:**

```json
{"error":"Project with path \"/path/to/project\" already exists"}
```

→ エラーでも問題なし（既存プロジェクトが使用される）

### Step 7: Plans.md フォーマット確認（必要に応じて）

Plans.md に旧フォーマット（`cursor:WIP` / `cursor:完了`）がある場合、**文脈に応じて**適切なマーカーに移行してください。

**移行の考え方:**

| 旧マーカー | 文脈 | 新マーカー |
|-----------|------|-----------|
| `cursor:WIP` | Claude Code が作業中 | `cc:WIP` |
| `cursor:WIP` | PM(Cursor) が作業中 | `pm:依頼中` または維持 |
| `cursor:完了` | 実装が完了 | `cc:完了` |
| `cursor:完了` | PM が確認済み | `pm:確認済` |

**2-Agent 運用の場合:**
- `cursor:依頼中` / `cursor:確認済` はそのまま有効（`pm:*` と同義）
- 無理に変換する必要はありません

**移行が必要な場合:**
Claude Code に「Plans.md の旧フォーマットを文脈に応じて新フォーマットに移行して」と依頼してください。

### Step 8: 完了メッセージ

> ✅ **harness-ui のセットアップが完了しました！**
>
> 📋 **設定内容**:
> - ライセンスキー: {キーの先頭8文字}...
> - Customer ID: {顧客ID}
> - 環境変数: `HARNESS_BETA_CODE` を ~/.zshrc に追加
> - 依存関係: インストール済み
> - プロジェクト登録: 完了
>
> **確認方法:**
> 1. ブラウザで http://localhost:37778 にアクセス
> 2. 右上のドロップダウンに現在のプロジェクト名が表示されていることを確認
> 3. 次回以降は Claude Code 起動時に自動起動＆自動登録
>
> 💡 **ヒント**: ドロップダウンが「All Projects」のみの場合は、Step 6 のプロジェクト登録を再実行してください。

---

## トラブルシューティング

### エラー: Cannot find module / node_modules が見つからない

**原因**: 依存関係がインストールされていない

**解決策**:
```bash
cd ${CLAUDE_PLUGIN_ROOT}/harness-ui
bun install
```

### エラー: bun: command not found

**原因**: Bun がインストールされていない

**解決策**:
```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc  # または source ~/.zshrc

# 確認
bun --version
```

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

### プロジェクトがドロップダウンに表示されない

**原因**: プロジェクト登録がされていない

**解決策**:
```bash
# サーバーが起動していることを確認
curl -s http://localhost:37778/api/status

# プロジェクトを手動登録
PROJECT_PATH=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")
curl -s -X POST http://localhost:37778/api/projects \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$PROJECT_NAME\", \"path\": \"$PROJECT_PATH\"}"

# 登録済みプロジェクト一覧を確認
curl -s http://localhost:37778/api/projects | jq
```

---

## Plans.md フォーマット要件

harness-ui の自動プロジェクト登録には、以下のいずれかが必要です:

### 方法1: `/harness-init` を実行（推奨）

```bash
/harness-init
```

→ `.claude-code-harness-version` マーカーファイルが作成され、自動認識されます。

### 方法2: Plans.md に正しいマーカーを含める

Plans.md に以下のマーカーを含めてください:

**新フォーマット（推奨）:**

| マーカー | 意味 |
|---------|------|
| `cc:TODO` | 未着手タスク |
| `cc:WIP` | 作業中タスク |
| `cc:完了` | 完了タスク |
| `cc:blocked` | ブロック中 |
| `pm:依頼中` | PM から依頼 |
| `pm:確認済` | PM 確認済 |

**旧フォーマット（互換、非推奨）:**

| マーカー | 移行先 |
|---------|-------|
| `cursor:WIP` → | `cc:WIP` |
| `cursor:完了` → | `cc:完了` |

**テンプレート:**

```markdown
# Plans.md

## タスク一覧

- [ ] タスク1 `cc:TODO`
- [x] タスク2 `cc:完了`
```

---

## 関連コマンド

- `/validate` - プラグイン検証
- `/harness-update` - プラグイン更新
- `/harness-init` - プロジェクト初期化（Plans.md 自動生成）

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
