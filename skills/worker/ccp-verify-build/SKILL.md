---
name: ccp-verify-build
description: "ビルドとテストを実行して動作を確認する。実装完了後、またはレビュー前に動作確認が必要な場合に使用します。"
allowed-tools: [Read,Bash]
metadata:
  skillport:
    category: worker
    tags: [build, test, verify, ci]
    alwaysApply: false
---

# Verify Build

実装後にビルドとテストを実行し、変更が正常に動作することを確認するスキル。

---

## 目的

コード変更後に以下を自動実行して、問題がないことを確認：
- ビルドの成功
- テストの通過
- 型チェック（TypeScript の場合）
- Lint チェック

---

## 入力

| 項目 | 説明 |
|------|------|
| `changed_files` | 変更されたファイルのリスト |
| `tech_stack` | プロジェクトの技術スタック |

---

## 出力

| 項目 | 説明 |
|------|------|
| `build_success` | ビルド成功フラグ |
| `test_results` | テスト結果サマリー |
| `errors` | エラーがあれば詳細 |

---

## 実行手順

### 1. プロジェクトタイプの判定

```
package.json あり → Node.js プロジェクト
pyproject.toml あり → Python プロジェクト
Cargo.toml あり → Rust プロジェクト
go.mod あり → Go プロジェクト
```

### 2. ビルドコマンドの実行

**Node.js:**
```bash
npm run build
# または
npm run type-check
```

**Python:**
```bash
python -m py_compile app/**/*.py
# または
mypy app/
```

### 3. テストの実行

**Node.js:**
```bash
npm test
# または
npm run test:unit
```

**Python:**
```bash
pytest tests/
```

### 4. Lint チェック

**Node.js:**
```bash
npm run lint
```

**Python:**
```bash
ruff check app/
```

---

## 結果の判定

| 状態 | 判定 | 次のアクション |
|------|------|---------------|
| すべて成功 | `build_success: true` | 次のステップへ進む |
| ビルド失敗 | `build_success: false` | エラー修正スキルを起動 |
| テスト失敗 | `build_success: false` | テスト修正スキルを起動 |

---

## 出力例

### 成功時

```
✅ ビルド検証完了

- ビルド: 成功
- 型チェック: 成功
- テスト: 12/12 通過
- Lint: 問題なし

次のステップに進めます。
```

### 失敗時

```
❌ ビルド検証失敗

- ビルド: 成功
- 型チェック: 成功
- テスト: 10/12 通過 (2 件失敗)

失敗したテスト:
1. test_user_login - AssertionError
2. test_create_post - TypeError

自動修正を試みます...
```

---

## 注意事項

- テスト実行には時間がかかる場合があるため、進捗を表示する
- 失敗時は `ccp-error-recovery` スキルと連携する
- CI 環境と同じ条件でチェックすることを推奨
