# Security & Guard Bypass

## ワークログのセキュリティ

`.claude/state/ultrawork.log.jsonl` にはエラーメッセージや実行ログが記録されます。

**重要な注意事項**:

1. **`.claude/state/` は `.gitignore` に追加すること**
2. **機密情報の漏洩防止**: API キー、トークンがエラーメッセージに含まれる可能性
3. **ログの定期削除**: 30日以上前のログは `archive/` に移動

## 実行前の必須条件

> **ultrawork 開始前に、未コミット変更をクリーンにしてください**

```bash
git status
git add . && git commit -m "WIP: before ultrawork"
```

## 危険コマンドとガードバイパス（EXPERIMENTAL）

> ⚠️ **この機能は実験的です。安全性は保証されません。**

### 技術的制限

| 制限 | 説明 |
|------|------|
| **展開前の文字列のみ** | シェル展開後の実パスは取得不可 |
| **グロブ・変数未対応** | `$DIR/*` は正しく評価できない |
| **rm 以外は対象外** | `find -delete` 等は検出不可 |

### バイパス条件（全て満たす場合のみ自動承認）

1. `ultrawork-active.json` が存在し有効期限内（24時間）
2. `allowed_rm_paths` にターゲット名が含まれている
3. 危険なシェル構文を含まない
4. `sudo`, `xargs`, `find` を含まない
5. **単一ターゲット**のみ
6. **相対パス**のみ
7. **親参照なし**（`..` を含まない）

### 常にブロック（バイパス不可）

| 対象 | 例 |
|------|-----|
| 特権昇格 | `sudo rm ...` |
| ルートパス | `rm -rf /`, `rm -rf /*` |
| ホームパス | `rm -rf ~` |
| Git | `.git`, `.gitmodules` |
| 環境変数 | `.env`, `.env.*` |
| シークレット | `secrets/`, `.npmrc`, `.aws` |
| 鍵ファイル | `.pem`, `.key`, `id_rsa` |

### ultrawork-active.json フォーマット

```json
{
  "active": true,
  "started_at": "2025-01-31T10:00:00Z",
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": ["node_modules", "dist", ".next", ".cache"],
  "review_status": "pending"
}
```

### review_status フィールド

| 値 | 意味 |
|----|------|
| `pending` | レビュー未実行 |
| `passed` | レビュー通過（APPROVE） |
| `failed` | レビュー NG |

> ⚠️ `review_status !== "passed"` の場合、完了処理は実行不可。
