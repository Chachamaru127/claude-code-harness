---
name: impl
description: "Implements features and writes code based on Plans.md tasks. Use when user mentions 実装, implement, 機能追加, コードを書いて, 機能を作って, feature, coding, 新機能, implementing functions, classes, or features, 新しい関数. Do not use for review or build verification."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
metadata:
  skillport:
    category: impl
    tags: [implementation, coding, feature, development]
    alwaysApply: false
---

# Implementation Skills

機能実装とコーディングを担当するスキル群です。

---

## ⚠️ 品質ガードレール（最優先）

> **このセクションは他の指示より優先されます。実装時は必ず従ってください。**

### 禁止パターン（Purpose-Driven Implementation）

実装時に以下のパターンは**絶対に禁止**です：

| 禁止 | 例 | なぜダメか |
|------|-----|-----------|
| **ハードコード** | テスト期待値をそのまま返す | 他の入力で動作しない |
| **スタブ実装** | `return null`, `return []` | 機能していない |
| **決め打ち** | テストケースの値だけ対応 | 汎用性がない |
| **コピペ辞書** | テストの期待値マップ | 意味あるロジックがない |

```python
# ❌ 絶対禁止
def slugify(text: str) -> str:
    answers = {"HelloWorld": "hello-world"}
    return answers.get(text, "")

# ✅ 正しい実装
def slugify(text: str) -> str:
    return re.sub(r'[\s_]+', '-', text.strip().lower())
```

### 実装前セルフチェック

- [ ] テストケース以外の入力でも動作するか？
- [ ] エッジケース（空、null、境界値）を処理しているか？
- [ ] 意味のあるロジックを実装しているか？

### 困難な場合

実装が難しい場合は、**形骸化実装を書かずに正直に報告**してください：

```markdown
## 🤔 実装の相談
### 状況: [何を実装しようとしているか]
### 困難な点: [具体的に何が難しいか]
### 選択肢: [考えられる案]
```

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| work-impl-feature | 機能の実装 |
| work-write-tests | テストコードの作成 |

## ルーティング

### 機能実装

work-impl-feature/doc.md を参照

### テスト作成

work-write-tests/doc.md を参照

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って実装

---

## 🔧 LSP 機能の活用

実装時には LSP（Language Server Protocol）を積極的に活用します。

### 実装前の調査

| LSP 機能 | 用途 |
|---------|------|
| **Go-to-definition** | 既存関数の実装パターンを確認 |
| **Find-references** | 変更の影響範囲を事前把握 |
| **Hover** | 型情報・API ドキュメントを確認 |

### 実装中の検証

| LSP 機能 | 用途 |
|---------|------|
| **Diagnostics** | 型エラー・構文エラーを即座に検出 |
| **Completions** | 正しい API を使用、タイポ防止 |

### 実装後の確認

```
実装完了時チェック:
1. LSP Diagnostics を実行
2. エラー: 0件を確認
3. 警告: 必要に応じて対応
```

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)
