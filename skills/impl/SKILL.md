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
2. **（Claude-mem 有効時）過去の実装パターンを検索**
3. 適切な小スキルの doc.md を読む
4. その内容に従って実装

### Step 2: 過去の実装パターン検索（Memory-Enhanced）

Claude-mem が有効な場合、実装前に過去の類似パターンを検索:

```
# mem-search で過去の実装パターンを検索
mem-search: type:feature "{実装機能のキーワード}"
mem-search: concepts:pattern "{関連技術}"
mem-search: concepts:gotcha "{使用ライブラリ/フレームワーク}"
mem-search: type:decision "{設計方針に関するキーワード}"
```

**表示例**:

```markdown
📚 過去の実装パターン

| 日付 | パターン | ファイル |
|------|---------|---------|
| 2024-01-15 | API エンドポイント: RESTful 設計 | src/api/*.ts |
| 2024-01-20 | フォームバリデーション: Zod 使用 | src/components/forms/*.tsx |

💡 過去の gotcha（落とし穴）:
- CORS: サーバー側で Allow-Origin 設定必須
- 型安全: any 禁止、unknown + type guard 推奨
```

**関連する決定事項の表示**:

```markdown
⚖️ 関連する設計決定

- D5: 状態管理は Zustand を採用（Redux より軽量）
- D8: API通信は tRPC を使用（型安全）

💡 上記の決定に従って実装してください
```

> **注**: Claude-mem が未設定の場合、このステップはスキップされます。

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
