---
description: harness-ui ダッシュボードを開く・状態確認
description-en: Open harness-ui dashboard and check status
---

# /harness-ui - ダッシュボード表示

harness-ui ダッシュボードを開き、プロジェクト状態を確認します。

## バイブコーダー向け（こう言えばOK）

- 「**ダッシュボードを開いて**」→ このコマンド
- 「**harness-ui を見たい**」→ このコマンド
- 「**UIで状態確認**」→ このコマンド

## できること

- ブラウザで harness-ui を開く
- サーバー状態の確認
- 登録プロジェクト一覧の表示

---

## 実行フロー

### Step 1: ライセンスキーの確認

```bash
# 環境変数を確認
echo $HARNESS_BETA_CODE
```

**キーが設定されている場合（空でない）:**
→ Step 2 へ進む

**キーが未設定または空の場合:**

> 🔑 **harness-ui を利用するにはライセンスキーが必要です**
>
> `/harness-ui-setup YOUR-LICENSE-KEY` を実行してセットアップしてください。
>
> ライセンスキーをお持ちでない場合は、管理者にお問い合わせください。

**処理終了**

### Step 2: サーバー状態の確認

```bash
# harness-ui サーバーの状態確認
curl -s --connect-timeout 2 http://localhost:37778/api/status
```

**サーバーが起動している場合:**
→ Step 3 へ進む

**サーバーが起動していない場合:**

> ⚠️ **harness-ui サーバーが起動していません**
>
> Claude Code を再起動すると自動的に起動します。
>
> または手動で起動する場合:
> ```bash
> cd {プラグインディレクトリ}/harness-ui && npm run dev
> ```

**処理終了**

### Step 3: プロジェクト情報の取得

```bash
# 登録プロジェクト一覧を取得
curl -s http://localhost:37778/api/projects
```

### Step 4: 情報表示

以下の情報を表示:

> 📊 **harness-ui ダッシュボード**
>
> **URL**: http://localhost:37778
>
> **サーバー状態**: ✅ 稼働中
>
> **登録プロジェクト**:
> | プロジェクト | パス |
> |-------------|------|
> | {name1} | {path1} |
> | {name2} | {path2} |
>
> 💡 ブラウザで http://localhost:37778 を開いてダッシュボードを確認してください。

### Step 5: ブラウザで開く（オプション）

ユーザーに確認:

> ブラウザでダッシュボードを開きますか？ (Y/n)

**Y の場合:**
```bash
open http://localhost:37778  # macOS
# または
xdg-open http://localhost:37778  # Linux
```

---

## 関連コマンド

- `/harness-ui-setup` - 初回セットアップ（ライセンスキー設定）
- `/validate` - プラグイン検証

---

## トラブルシューティング

### サーバーが起動しない

1. Claude Code を再起動
2. ポート 37778 が使用中でないか確認: `lsof -i :37778`
3. 環境変数 `HARNESS_BETA_CODE` が設定されているか確認

### ライセンスキーを再設定したい

```
/harness-ui-setup NEW-LICENSE-KEY
```
