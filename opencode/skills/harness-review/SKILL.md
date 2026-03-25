---
name: harness-review
description: "Unified review skill for Harness v3. Multi-angle code, plan, and scope review. Use when user mentions: review, code review, plan review, scope analysis, security, performance, quality checks, PRs, diffs, harness-review. Do NOT load for: implementation, new features, bug fixes, setup, or release."
description-ja: "Harness v3 統合レビュースキル。コード・プラン・スコープを多角的にレビュー。以下で起動: レビュー、コードレビュー、プランレビュー、スコープ分析、セキュリティ、品質チェック、harness-review。実装・新機能・バグ修正・セットアップ・リリースには使わない。"
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[code|plan|scope]"
effort: high
context: fork
---

# Harness Review (v3)

Harness v3 の統合レビュースキル。
以下の旧スキルを統合:

- `harness-review` — コード・プラン・スコープ多角的レビュー
- `codex-review` — Codex CLI によるセカンドオピニオン
- `verify` — ビルド検証・エラー復旧・レビュー修正適用
- `troubleshoot` — エラー・障害の診断と修復

## Quick Reference

| ユーザー入力 | サブコマンド | 動作 |
|------------|------------|------|
| "レビューして" / "review" | `code`（自動） | コードレビュー（直近の変更） |
| "`harness-plan` 実行後" | `plan`（自動） | 計画レビュー |
| "スコープ確認" | `scope`（自動） | スコープ分析 |
| `harness-review code` | `code` | コードレビュー強制 |
| `harness-review plan` | `plan` | 計画レビュー強制 |
| `harness-review scope` | `scope` | スコープ分析強制 |

## レビュータイプ自動判定

| 直前のアクティビティ | レビュータイプ | 観点 |
|--------------------|--------------|------|
| `harness-work` 後 | **Code Review** | Security, Performance, Quality, Accessibility |
| `harness-plan` 後 | **Plan Review** | Clarity, Feasibility, Dependencies, Acceptance |
| タスク追加後 | **Scope Review** | Scope-creep, Priority, Feasibility, Impact |

## Code Review フロー

### Step 1: 変更差分を収集

```bash
git diff HEAD~1 --stat
git diff HEAD~1 -- <changed_files>
```

### Step 2: 4観点でレビュー

| 観点 | チェック内容 |
|------|------------|
| **Security** | SQLインジェクション, XSS, 機密情報露出, 入力バリデーション |
| **Performance** | N+1クエリ, 不要な再レンダリング, メモリリーク |
| **Quality** | 命名, 単一責任, テストカバレッジ, エラーハンドリング |
| **Accessibility** | ARIA属性, キーボードナビ, カラーコントラスト |

### Step 3: レビュー結果出力

```markdown
## レビュー結果

### APPROVE / REQUEST_CHANGES

**重大な問題**: なし / {{詳細}}

| 観点 | 評価 | 詳細 |
|------|------|------|
| Security | OK / NG | {{詳細}} |
| Performance | OK / NG | {{詳細}} |
| Quality | OK / NG | {{詳細}} |
| Accessibility | OK / NG | {{詳細}} |

### 推奨改善点（必須ではない）
- {{改善提案}}
```

### Step 4: コミット判定

- **APPROVE**: 自動コミット実行（`--no-commit` でなければ）
- **REQUEST_CHANGES**: 問題箇所と修正方針を提示。`harness-work` で修正後に再レビュー

## Plan Review フロー

1. Plans.md を読み込む
2. 以下の **5 観点** でレビュー:
   - **Clarity**: タスク説明が明確か
   - **Feasibility**: 技術的に実現可能か
   - **Dependencies**: タスク間の依存関係が正しいか（Depends カラムと実際の依存が一致しているか）
   - **Acceptance**: 完了条件（DoD カラム）が定義され、検証可能か
   - **Value**: このタスクはユーザー課題を解くか？
     - 「誰の、どんな問題」が明示されているか
     - 代替手段（作らない選択肢）は検討されたか
     - Elephant（全員気づいているが放置されている問題）はないか
3. DoD / Depends カラムの品質チェック:
   - DoD が空欄のタスク → 警告（「完了条件が未定義です」）
   - DoD が検証不能（「いい感じ」「ちゃんと動く」等） → 警告 + 具体化提案
   - Depends に存在しないタスク番号 → エラー
   - 循環依存 → エラー
4. 改善提案を提示

## Scope Review フロー

1. 追加されたタスク/機能をリスト化
2. 以下の観点で分析:
   - **Scope-creep**: 当初スコープからの逸脱
   - **Priority**: 優先度は適切か
   - **Feasibility**: 現在のリソースで実現可能か
   - **Impact**: 既存機能への影響
3. リスクと推奨アクションを提示

## 異常検知

| 状況 | アクション |
|------|----------|
| セキュリティ脆弱性 | 即座に REQUEST_CHANGES |
| テスト改ざん疑い | 警告 + 修正要求 |
| force push 試み | 拒否 + 代替案提示 |

## Codex Environment

Codex CLI 環境（`CODEX_CLI=1`）では一部ツールが利用不可のため、以下のフォールバックを使用する。

| 通常環境 | Codex フォールバック |
|---------|-------------------|
| `TaskList` でタスク一覧取得 | Plans.md を `Read` して WIP/TODO タスクを確認 |
| `TaskUpdate` でステータス更新 | Plans.md のマーカーを `Edit` で直接更新（例: `cc:WIP` → `cc:完了`） |
| レビュー結果を Task に書き込み | レビュー結果を stdout に出力 |

### 検出方法

```bash
if [ "${CODEX_CLI:-}" = "1" ]; then
  # Codex 環境: Plans.md ベースのフォールバック
fi
```

### Codex 環境でのレビュー出力

Task ツール非対応のため、レビュー結果は標準出力にマークダウン形式で出力する。
Lead エージェントまたはユーザーが結果を読み取り、次のアクションを判断する。

## 関連スキル

- `harness-work` — レビュー後に修正を実装
- `harness-plan` — 計画を作成・修正
- `harness-release` — レビュー通過後にリリース
