---
description: Plans.mdの指定範囲を完了まで自律的に反復実行する（/workの長期版）
description-en: Autonomously iterate until specified Plans.md range is complete (long-running /work)
---

# /ultrawork - Autonomous Task Completion Loop

Plans.md の指定範囲を**完了まで自動的に反復実行**する。
`/work` の長期版として、Ralph Loop + Ultrawork のコンセプトを採用。

## Philosophy

> **「人間介入は失敗シグナル」**
>
> システムが正しく設計されていれば、ユーザーが介入する必要はない。
> 反復 > 完璧性。失敗はデータ。粘り強さが勝つ。

---

## Quick Reference

```bash
/ultrawork 1-5                    # タスク1〜5を完了まで
/ultrawork --from 3               # タスク3から最後まで
/ultrawork --to 10                # 最初からタスク10まで
/ultrawork --from 3 --to 7        # タスク3〜7
/ultrawork --max-iterations 20    # 最大20反復（デフォルト10）
/ultrawork --completion-promise "All tests pass"  # カスタム完了条件
```

---

## /work との違い

| 特徴 | /work | /ultrawork |
|------|-------|------------|
| 実行範囲 | cc:TODO / pm:requested | **指定範囲の全タスク** |
| 反復 | 1回（手動で再実行） | **完了まで自動反復** |
| 完了条件 | タスク実装完了 | **全タスク完了 + ビルド成功 + テスト通過** |
| 自己学習 | なし | **前回の失敗から学習して回避** |
| ワークログ | session.events.jsonl | **.claude/state/ultrawork.log.jsonl** |
| 用途 | 1-2タスクの実装 | **大規模な実装を放置実行** |

---

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--from N` | タスク番号 N から開始 | 1 |
| `--to M` | タスク番号 M まで実行 | 最後 |
| `N-M` | `--from N --to M` の短縮形 | - |
| `--max-iterations` | 全体の最大反復回数 | 10 |
| `--completion-promise` | カスタム完了条件テキスト | "All tasks done" |
| `--parallel N` | 並列ワーカー数 | auto |
| `--checkpoint` | 中間チェックポイント保存 | true |
| `--ci` | CI非対話モード | false |
| `--no-commit` | コミットをスキップ | false |
| `--resume` | 前回の中断から再開 | false |

---

## Deliverables

- 指定範囲の**全タスクを完了まで自律的に実行**
- 失敗時は自己学習して再試行（同じ失敗を繰り返さない）
- 完了条件達成で自動終了
- ワークログで全ての試行を記録（再開可能）

---

## Execution Flow

```
/ultrawork 1-5 --max-iterations 10
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 0: 初期分析 (1回のみ)                                  │
├─────────────────────────────────────────────────────────────┤
│  1. Plans.md 解析 → タスク範囲抽出                          │
│  2. 依存関係グラフ構築                                      │
│  3. 完了条件の設定                                          │
│  4. ワークログ初期化                                        │
│     → .claude/state/ultrawork.log.jsonl                    │
│  5. 既存ワークログあれば読み込み（--resume）                │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Iteration 1〜N: 自律実行ループ                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 1: 現状評価                                    │   │
│  │  - 未完了タスク特定                                 │   │
│  │  - 失敗履歴から学習（前回の失敗を避ける戦略選択）   │   │
│  │  - 優先順位再計算                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 2: 並列実装（task-worker × N）                 │   │
│  │  - 独立タスクを並列実行                             │   │
│  │  - 各ワーカーが自己完結（実装→レビュー→ビルド）    │   │
│  │  - エスカレーションはログに記録して次へ             │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 3: 統合検証                                    │   │
│  │  - 全体ビルド実行                                   │   │
│  │  - テストスイート実行                               │   │
│  │  - 結果をワークログに記録                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 4: 判定                                        │   │
│  │  - 全完了 → Phase 1 へ                             │   │
│  │  - 未完了あり → 次 iteration へ                    │   │
│  │  - max-iterations 到達 → Phase 1 へ（部分完了）    │   │
│  │  - --checkpoint: true → 中間コミット                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ※ 各 iteration 終了時にワークログ保存（再開可能）         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: 完了処理                                           │
├─────────────────────────────────────────────────────────────┤
│  1. 最終コミット（--no-commit でスキップ）                  │
│  2. ワークログ保存（完了ステータス）                        │
│  3. 完了レポート生成                                        │
│  4. 2-Agent モードなら handoff 実行                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Self-Learning Mechanism

各イテレーションで前回の失敗から学習し、同じ失敗を繰り返さない。

```
┌─────────────────────────────────────────────────────────────┐
│ Iteration 1                                                 │
│   タスク A: 型エラー "User型が見つからない"                  │
│   → 失敗をワークログに記録                                  │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Iteration 2                                                 │
│   ワークログを読み込み:                                     │
│   「前回 User 型が見つからなかった」                        │
│   → 戦略: "User 型の定義を先に確認してから実装"            │
│   → タスク A: 成功                                          │
└─────────────────────────────────────────────────────────────┘
```

### 学習戦略パターン

| 失敗パターン | 次イテレーションの戦略 |
|-------------|----------------------|
| 型エラー | 関連する型定義を先に確認 |
| import エラー | パス構造を再確認 |
| テスト失敗 | テストケースを読んで期待値を理解 |
| ビルドエラー | 依存関係を確認、順序変更 |
| 3回連続同じエラー | 別アプローチを試行 |

---

## Worklog Format

`.claude/state/ultrawork.log.jsonl`:

```jsonl
{"ts":"2025-01-30T10:00:00Z","event":"start","range":"1-5","max_iterations":10}
{"ts":"2025-01-30T10:00:05Z","event":"iteration_start","iteration":1}
{"ts":"2025-01-30T10:00:30Z","event":"task_complete","task":"Create Header","status":"success","duration_s":25}
{"ts":"2025-01-30T10:00:55Z","event":"task_failed","task":"Create Footer","error":"Import not found","attempted_fix":"Check path"}
{"ts":"2025-01-30T10:01:20Z","event":"verify","build":"pass","test":"fail","test_log":"1 test failed"}
{"ts":"2025-01-30T10:01:25Z","event":"iteration_end","iteration":1,"completed":1,"failed":1,"remaining":3}
{"ts":"2025-01-30T10:01:30Z","event":"iteration_start","iteration":2}
{"ts":"2025-01-30T10:02:00Z","event":"task_complete","task":"Create Footer","status":"success","duration_s":30,"learned_from":"iter 1: Import not found → Check path first"}
{"ts":"2025-01-30T10:05:00Z","event":"complete","iterations":3,"tasks_completed":5,"tasks_failed":0}
```

### Resume from Worklog

```bash
# 前回の中断から再開
/ultrawork --resume

# 内部動作:
# 1. .claude/state/ultrawork.log.jsonl を読み込み
# 2. 最後の iteration_end を特定
# 3. 完了タスクをスキップして未完了から再開
# 4. 失敗履歴を学習データとして引き継ぎ
```

---

## Completion Conditions

### デフォルト完了条件

以下の**全て**を満たしたとき完了:

1. ✅ 指定範囲の全タスクが `cc:done`
2. ✅ 全体ビルド成功
3. ✅ 全テスト通過（またはテストなし）
4. ✅ harness-review で Critical/High なし

### カスタム完了条件

```bash
/ultrawork 1-5 --completion-promise "All integration tests pass"
```

`--completion-promise` で追加条件を指定可能。
指定されたテキストが真実になるまでループを継続。

---

## Progress Display

```
📊 /ultrawork Progress: Iteration 2/10

Range: Tasks 1-5
Completed: 2/5 tasks
Time elapsed: 2m 15s

├── Task 1: Create Header ✅ (iter 1, 25s)
├── Task 2: Create Footer ✅ (iter 2, 30s) [learned from iter 1 failure]
├── Task 3: Create Sidebar ⏳ In progress...
├── Task 4: Create Layout 🔜 Waiting (depends: 1,2,3)
└── Task 5: Create Page 🔜 Waiting (depends: 4)

Last iteration result:
├── Build: ✅ Pass
├── Tests: ⚠️ 14/15 pass (1 flaky)
└── Review: ✅ No Critical/High

Learning from failures:
└── Iteration 1: "Import not found" → Now checking paths first
```

---

## Completion Report

```markdown
## 📊 /ultrawork Complete

**Range**: Tasks 1-5
**Iterations**: 3 / 10 (max)
**Duration**: 5m 30s
**Status**: ✅ All tasks completed

### Task Results

| # | Task | Status | Iteration | Duration |
|---|------|--------|-----------|----------|
| 1 | Create Header | ✅ | 1 | 25s |
| 2 | Create Footer | ✅ | 2 | 30s |
| 3 | Create Sidebar | ✅ | 2 | 28s |
| 4 | Create Layout | ✅ | 2 | 45s |
| 5 | Create Page | ✅ | 3 | 35s |

### Verification

| Check | Result |
|-------|--------|
| Build | ✅ Pass |
| Tests | ✅ 15/15 pass |
| Review | ✅ APPROVE |

### Self-Learning Applied

| Iteration | Failure | Learned Strategy |
|-----------|---------|------------------|
| 1 | "Import not found" | Check paths first |
| 2 | "Type mismatch" | Verify types before impl |

### Changed Files

- `src/components/Header.tsx` (new)
- `src/components/Footer.tsx` (new)
- `src/components/Sidebar.tsx` (new)
- `src/components/Layout.tsx` (new)
- `src/app/page.tsx` (modified)

### Commit

```
feat: implement Header, Footer, Sidebar, Layout, Page components

Completed via /ultrawork (3 iterations)
```

### Worklog

Saved to: `.claude/state/ultrawork.log.jsonl`
Use `/ultrawork --resume` to continue if interrupted.
```

---

## Partial Completion Report

max-iterations に達しても全タスク完了しなかった場合:

```markdown
## 📊 /ultrawork Partial Complete

**Range**: Tasks 1-5
**Iterations**: 10 / 10 (max reached)
**Duration**: 15m 20s
**Status**: ⚠️ Partial completion (3/5 tasks)

### Task Results

| # | Task | Status | Attempts | Last Error |
|---|------|--------|----------|------------|
| 1 | Create Header | ✅ | 1 | - |
| 2 | Create Footer | ✅ | 2 | - |
| 3 | Create Sidebar | ✅ | 2 | - |
| 4 | Create Layout | ❌ | 5 | Type 'unknown' is not assignable |
| 5 | Create Page | ⏸️ | 0 | Blocked by Task 4 |

### Blocking Issues

**Task 4: Create Layout** - 5 attempts, all failed

```
Attempted fixes:
1. Type assertion → Failed (unknown is not User)
2. Type guard → Failed (property does not exist)
3. Interface extension → Failed (incompatible)
4. Generic type → Failed (constraint error)
5. Optional chaining → Failed (still unknown)

Suggestion: User型の定義を確認し、Layout.propsの型を修正する必要があります。
```

### Recommended Actions

1. Review `src/types/User.ts` definition
2. Check `Layout.props` interface compatibility
3. Run `/ultrawork --resume` after fixing

### Worklog

Saved to: `.claude/state/ultrawork.log.jsonl`
Use `/ultrawork --resume` after fixing blocking issues.
```

---

## Error Handling

### 同じエラーが3回連続

```
⚠️ Same error 3 times in a row

Task: Create Layout
Error: Type 'unknown' is not assignable to 'User'

Tried approaches:
1. Type assertion
2. Type guard
3. Generic constraint

Switching strategy: Will try alternative approach...
→ Checking User type definition first
→ Looking for similar patterns in codebase
```

### max-iterations 到達

```
⚠️ Max iterations (10) reached

Completed: 3/5 tasks
Remaining: 2 tasks with blocking issues

Options:
1. Continue with higher limit: /ultrawork --resume --max-iterations 20
2. Fix blocking issues manually, then: /ultrawork --resume
3. Skip blocked tasks: /ultrawork --from 6
```

---

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 全部終わるまでやって | `/ultrawork 1-10` |
| ここからここまで | `/ultrawork 3-7` |
| 前回の続きから | `/ultrawork --resume` |
| もっと粘って | `/ultrawork --max-iterations 20` |
| 進捗見たい | ワークログを確認 |

---

## Related Commands

- `/work` - 1回の実装サイクル（短期タスク向け）
- `/harness-review` - コードレビュー実行
- `/handoff-to-cursor` - PM へのハンドオフ
