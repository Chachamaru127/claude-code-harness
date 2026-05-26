---
name: ci
description: "CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
description-en: "CI red? Call us. Pipeline fire brigade deploys. Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
description-ja: "CIが赤くなったら呼んで。パイプライン消防隊、出動します。Use when user mentions CI failures, build errors, test failures, or pipeline issues. Do NOT load for: local builds, standard implementation work, reviews, or setup."
allowed-tools: ["Read", "Grep", "Bash", "Task", "Monitor"]
user-invocable: true
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
| **失敗分析** | See [references/analyzing-failures.md](${CLAUDE_SKILL_DIR}/references/analyzing-failures.md) | 「ログを見て」「原因を調べて」 |
| **テスト修正** | See [references/fixing-tests.md](${CLAUDE_SKILL_DIR}/references/fixing-tests.md) | 「テストを直して」「修正案を出して」 |

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

### Git log 拡張フラグの活用（CC 2.1.49+）

CI 失敗時の原因コミット特定に構造化ログを活用します。

#### 原因コミットの特定

```bash
# 構造化フォーマットでコミット分析
git log --format="%h|%s|%an|%ad" --date=short -10

# トポロジカル順序で時系列分析
git log --topo-order --oneline -20

# 変更ファイルと原因の紐付け
git log --raw --oneline -5
```

#### 主な活用場面

| 用途 | フラグ | 効果 |
|------|--------|------|
| **失敗原因の特定** | `--format="%h|%s"` | コミット一覧の構造化 |
| **時系列での追跡** | `--topo-order` | マージ順序を考慮した追跡 |
| **変更影響の把握** | `--raw` | ファイル変更の詳細表示 |
| **マージ除外分析** | `--cherry-pick --no-merges` | 実コミットのみを抽出 |

#### 出力例

```markdown
🔍 CI 失敗原因分析

最近のコミット（構造化）:
| Hash | Subject | Author | Date |
|------|---------|--------|------|
| a1b2c3d | feat: update API | Alice | 2026-02-04 |
| e4f5g6h | test: add tests | Bob | 2026-02-03 |

変更ファイル（--raw）:
├── src/api/endpoint.ts (Modified) ← 型エラー発生
├── tests/api.test.ts (Modified)
└── package.json (Modified)

→ a1b2c3d のコミットが原因の可能性大
  型エラー: src/api/endpoint.ts:42
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
