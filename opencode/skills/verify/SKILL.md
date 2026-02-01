---
name: verify
description: "Verifies builds, recovers from errors, and applies review fixes. Use when user mentions build verification, error recovery, applying review fixes, test failures, lint errors, or CI breaks. Do NOT load for: implementation work, reviews, setup, or new feature development."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
user-invocable: false
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

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **関連ファイル検証** | See [references/verify-related-files.md](references/verify-related-files.md) |
| **ビルド検証** | See [references/build-verification.md](references/build-verification.md) |
| **エラー復旧** | See [references/error-recovery.md](references/error-recovery.md) |
| **レビュー集約** | See [references/review-aggregation.md](references/review-aggregation.md) |
| **指摘適用** | See [references/applying-fixes.md](references/applying-fixes.md) |

## 実行手順

1. **品質判定ゲート**（Step 0）
2. ユーザーのリクエストを分類
3. **（実装完了後）関連ファイル検証**（Step 1.5）
4. **（Claude-mem 有効時）過去のエラーパターンを検索**
5. 上記の「機能詳細」から適切な参照ファイルを読む
6. その内容に従って検証/復旧実行

### Step 0: 品質判定ゲート（再現テスト提案）

エラー/バグ報告時に、TDD アプローチを提案:

```
エラー報告受領
    ↓
┌─────────────────────────────────────────┐
│           品質判定ゲート                 │
├─────────────────────────────────────────┤
│  判定項目:                              │
│  ├── バグ報告？ → 再現テスト先行を提案  │
│  ├── テスト失敗？ → テスト vs 実装判断  │
│  └── ビルドエラー？ → 直接修正          │
└─────────────────────────────────────────┘
          ↓
    適切なアプローチを提案
```

#### バグ報告時の提案

```markdown
🐛 バグ報告を受け付けました

**推奨アプローチ**: 再現テスト先行

1. まずバグを再現するテストを書く
2. テストが失敗することを確認（Red）
3. 実装を修正してテストを通す（Green）
4. リファクタリング（Refactor）

この方法で進めますか？
1. 再現テストから書く（推奨）
2. 直接修正に進む
```

#### テスト失敗時の判断フロー

```markdown
🔴 テストが失敗しています

**判断が必要です**:

テスト失敗の原因を分析:
- [ ] 実装が間違っている → 実装を修正
- [ ] テストの期待値が古い → ユーザーに確認

⚠️ テストの改ざん（skip化、アサーション削除）は禁止です

どちらに該当しますか？
1. 実装を修正する
2. テストの期待値について確認したい
```

#### VibeCoder 向け

```markdown
🐛 問題が報告されました

**推奨**: まず「問題が起きる条件」を明確にしましょう

1. どんな操作をすると問題が起きますか？
2. 期待する動作は何ですか？
3. 実際にはどうなりますか？

これを整理してから修正に進むと、確実に直せます。
```

### Step 1.5: 関連ファイル検証（実装完了後）

実装完了後、コミット前に編集ファイルの関連ファイルをチェック：

```
編集ファイルを取得
    ↓
┌─────────────────────────────────────────┐
│           関連ファイル検証               │
├─────────────────────────────────────────┤
│  変更パターンを分析:                     │
│  ├── 関数シグネチャ変更 → 呼び出し元確認 │
│  ├── 型/interface変更 → 実装箇所確認    │
│  ├── export削除 → import文確認         │
│  └── 設定変更 → 関連設定ファイル確認    │
└─────────────────────────────────────────┘
    ↓
  修正漏れ候補を警告
```

**出力例**:

```markdown
📋 関連ファイル検証

✅ 編集済み: src/auth.ts
   └─ 関数 `validateToken` のシグネチャ変更を検出

⚠️ 要確認: 以下のファイルが影響を受ける可能性
   ├─ src/api/middleware.ts:45 (validateToken 呼び出し)
   ├─ src/routes/protected.ts:12 (validateToken 呼び出し)
   └─ tests/auth.test.ts:28 (テストケース)

確認済みですか？
1. 確認済み、続行
2. 各ファイルを確認する
3. LSP find-references で詳細表示
```

**重要度の判定**:

| 重要度 | 条件 | アクション |
|--------|------|-----------|
| `🚨 critical` | 必ずエラーになる（export削除、必須引数追加） | 修正必須 |
| `⚠️ warning` | エラーの可能性あり（オプショナル引数、型変更） | 確認推奨 |
| `ℹ️ info` | 影響軽微（コメント、ドキュメント） | 参考情報 |

詳細: [references/verify-related-files.md](references/verify-related-files.md)

---

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
