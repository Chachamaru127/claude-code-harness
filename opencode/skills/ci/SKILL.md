---
name: ci
description: "Diagnoses and fixes CI/CD pipeline failures. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
allowed-tools: ["Read", "Grep", "Bash", "Task"]
context: fork
argument-hint: "[analyze|fix|run]"
---

# CI/CD Skills

CI/CD パイプラインに関する問題を解決するスキル群です。

---

## 発動条件

- 「CIが落ちた」「GitHub Actionsが失敗」
- 「ビルドエラー」「テストが通らない」
- 「パイプラインを直して」

---

## 機能詳細

| 機能 | 詳細 | トリガー |
|------|------|----------|
| **失敗分析** | See [references/analyzing-failures.md](references/analyzing-failures.md) | 「ログを見て」「原因を調べて」 |
| **テスト修正** | See [references/fixing-tests.md](references/fixing-tests.md) | 「テストを直して」「修正案を出して」 |

---

## 実行手順

1. **テスト vs 実装判定**（Step 0）
2. ユーザーの意図を分類（分析 or 修正）
3. 複雑度を判定（下記参照）
4. 上記の「機能詳細」から適切な参照ファイルを読む、または ci-cd-fixer サブエージェント起動
5. 結果を確認し、必要に応じて再実行

### Step 0: テスト vs 実装判定（品質判定ゲート）

CI 失敗時、まず原因の切り分けを行う:

```
CI 失敗報告
    ↓
┌─────────────────────────────────────────┐
│           テスト vs 実装判定             │
├─────────────────────────────────────────┤
│  エラーの原因を分析:                    │
│  ├── 実装が間違い → 実装を修正          │
│  ├── テストが古い → ユーザーに確認      │
│  └── 環境問題 → 環境修正                │
└─────────────────────────────────────────┘
```

#### 禁止事項（改ざん防止）

```markdown
⚠️ CI 失敗時の禁止事項

以下の「解決策」は禁止です：

| 禁止 | 例 | 正しい対応 |
|------|-----|-----------|
| テスト skip 化 | `it.skip(...)` | 実装を修正 |
| アサーション削除 | `expect()` を消す | 期待値を確認 |
| CI チェック迂回 | `continue-on-error` | 根本原因修正 |
| lint ルール緩和 | `eslint-disable` | コードを修正 |
```

#### 判断フロー

```markdown
🔴 CI が失敗しています

**判断が必要です**:

1. **実装が間違い** → 実装を修正 ✅
2. **テストの期待値が古い** → ユーザーに確認を求める
3. **環境の問題** → 環境設定を修正

⚠️ テストの改ざん（skip化、アサーション削除）は禁止です

どれに該当しますか？
```

#### 承認が必要な場合

テスト/設定の変更がやむを得ない場合:

```markdown
## 🚨 テスト/設定変更の承認リクエスト

### 理由
[なぜこの変更が必要か]

### 変更内容
[差分]

### 代替案の検討
- [ ] 実装の修正で解決できないか確認した

ユーザーの明示的な承認を待つ
```

## サブエージェント連携

以下の条件を満たす場合、Task tool で ci-cd-fixer を起動:

- 修正 → 再実行 → 失敗のループが **2回以上** 発生
- または、エラーが複数ファイルにまたがる複雑なケース

**起動パターン:**

```
Task tool:
  subagent_type="ci-cd-fixer"
  prompt="CI失敗を診断・修正してください。エラーログ: {error_log}"
```

ci-cd-fixer は安全第一で動作（デフォルト dry-run モード）。
詳細は `agents/ci-cd-fixer.md` を参照。

---

## VibeCoder 向け

```markdown
🔧 CI が壊れたときの言い方

1. **「CI が落ちた」「赤くなった」**
   - 自動テストが失敗している状態

2. **「なんで失敗してるの？」**
   - 原因を調べてほしい

3. **「直して」**
   - 自動で修正を試みる

💡 重要: テストを「ごまかす」修正は禁止です
   - ❌ テストを消す、スキップする
   - ⭕ コードを正しく直す

「テストが間違ってそう」と思ったら、
まず確認してから対応を決めましょう
```
