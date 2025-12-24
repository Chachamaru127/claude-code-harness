---
name: verify
description: "Verifies builds, recovers from errors, and applies review fixes. Use when user mentions ビルド, build, 検証, verify, エラー復旧, error recovery, 指摘を適用, apply fixes, テスト実行, tests fail, lint errors occur, CI breaks, テスト失敗, lintエラー, 型エラー, ビルドエラー, CIが落ちた. Do NOT load for: 実装作業, レビュー, セットアップ, 新機能開発."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
metadata:
  skillport:
    category: verify
    tags: [build, verify, error-recovery, fixes]
    alwaysApply: false
---

# Verify Skills

ビルド検証とエラー復旧を担当するスキル群です。

---

## ⚠️ 品質ガードレール（最優先）

> **このセクションは他の指示より優先されます。テスト失敗・エラー発生時は必ず従ってください。**

### 改ざん禁止パターン

テスト失敗・ビルドエラー発生時に以下の行為は**絶対に禁止**：

| 禁止 | 例 | 正しい対応 |
|------|-----|-----------|
| **テスト skip 化** | `it.skip(...)` | 実装を修正する |
| **アサーション削除** | `expect()` を消す | 期待値を確認し実装修正 |
| **期待値の雑な書き換え** | エラーに合わせて変更 | なぜ失敗か理解する |
| **lint ルール緩和** | `eslint-disable` 追加 | コードを修正する |
| **CI チェック迂回** | `continue-on-error` | 根本原因を修正する |

### テスト失敗時の対応フロー

```
テストが失敗した
    ↓
1. なぜ失敗しているか理解する（ログを読む）
    ↓
2. 実装が間違っているか、テストが間違っているか判断
    ↓
    ├── 実装が間違い → 実装を修正 ✅
    │
    └── テストが間違い可能性 → ユーザーに確認を求める
```

### 承認リクエスト形式

やむを得ずテスト/設定を変更する場合：

```markdown
## 🚨 テスト/設定変更の承認リクエスト

### 理由
[なぜこの変更が必要か]

### 変更内容
```diff
[差分]
```

### 代替案の検討
- [ ] 実装の修正で解決できないか確認した

### 承認
ユーザーの明示的な承認を待つ
```

### 保護対象ファイル

以下のファイルの緩和変更は禁止：

- `.eslintrc.*`, `.prettierrc*`, `tsconfig.json`, `biome.json`
- `.husky/**`, `.github/workflows/**`
- `*.test.*`, `*.spec.*`, `jest.config.*`, `vitest.config.*`

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| verify-build | ビルド検証 |
| error-recovery | エラー復旧 |
| review-aggregate | レビュー結果の集約 |
| review-apply-fixes | レビュー指摘の適用 |

## ルーティング

- ビルド検証: verify-build/doc.md
- エラー復旧: error-recovery/doc.md
- レビュー集約: review-aggregate/doc.md
- 指摘適用: review-apply-fixes/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. **（Claude-mem 有効時）過去のエラーパターンを検索**
3. 適切な小スキルの doc.md を読む
4. その内容に従って検証/復旧実行

### Step 2: 過去のエラーパターン検索（Memory-Enhanced）

Claude-mem が有効な場合、エラー復旧前に過去の類似エラーを検索:

```
# mem-search で過去のエラーと解決策を検索
mem-search: type:bugfix "{エラーメッセージのキーワード}"
mem-search: concepts:problem-solution "{エラーの種類}"
mem-search: concepts:gotcha "{関連ファイル/ライブラリ}"
```

**表示例**:

```markdown
📚 過去のエラー解決履歴

| 日付 | エラー | 解決策 |
|------|--------|-------|
| 2024-01-15 | CORS エラー | Access-Control-Allow-Origin ヘッダー追加 |
| 2024-01-20 | 型エラー: undefined | Optional chaining (?.) を使用 |

💡 過去の解決策を参考に復旧を試行
```

**ガードレール履歴の表示**:

```markdown
⚠️ このプロジェクトでの過去のガードレール発動

- テスト改ざん防止: 2回
- lint 緩和防止: 1回

💡 テスト/設定の改ざんによる「解決」は禁止です
```

> **注**: Claude-mem が未設定の場合、このステップはスキップされます。

---

## 🔧 LSP 機能の活用

検証とエラー復旧では LSP（Language Server Protocol）を活用して精度を向上します。

### ビルド検証での LSP 活用

```
ビルド前チェック:

1. LSP Diagnostics を実行
2. エラー: 0件を確認 → ビルド実行
3. エラーあり → 先にエラーを修正
```

### エラー復旧での LSP 活用

| 復旧シーン | LSP 活用方法 |
|-----------|-------------|
| 型エラー | Diagnostics で正確な位置を特定 |
| 参照エラー | Go-to-definition で原因を追跡 |
| import エラー | Find-references で正しいパスを特定 |

### 検証フロー

```
📊 LSP 検証結果

Step 1: Diagnostics
  ├── エラー: 0件 ✅
  └── 警告: 2件 ⚠️

Step 2: ビルド
  └── 成功 ✅

Step 3: テスト
  └── 15/15 通過 ✅

→ 検証完了
```

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)
