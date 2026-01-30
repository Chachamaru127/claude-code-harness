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
# 自然言語で範囲を指定
/ultrawork 認証機能からユーザー管理まで完了して
/ultrawork ログイン機能を終わらせて
/ultrawork 残りのコンポーネント全部やって
/ultrawork Header, Footer, Sidebar を作って

# キーワードで範囲指定
/ultrawork 認証系全部
/ultrawork フロントエンド完成させて
/ultrawork テストが通るまで

# シンプルに全部
/ultrawork 全部やって
/ultrawork Plans.md 完了まで
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

## 範囲指定の解釈

自然言語で指定された範囲を Plans.md のタスクにマッピングする。

### 解釈ルール

| 指定パターン | 解釈 |
|-------------|------|
| `認証機能からユーザー管理まで` | 「認証」を含むタスク 〜 「ユーザー管理」を含むタスク |
| `ログイン機能を終わらせて` | 「ログイン」を含む全タスク |
| `Header, Footer, Sidebar` | 列挙されたキーワードを含むタスク |
| `認証系全部` | 「認証」に関連する全タスク |
| `残りのコンポーネント全部` | `cc:TODO` のコンポーネント系タスク |
| `全部やって` | Plans.md の全未完了タスク |
| `テストが通るまで` | 全テスト通過を完了条件に設定 |

### 範囲確認プロンプト（必須）

**実行前に必ずユーザーに確認する。承認されるまで実行しない。**

```
📋 範囲を確認させてください

指定: 「認証機能からユーザー管理まで」

対象タスク:
├── 3. ログイン機能の実装 (cc:TODO)
├── 4. 認証ミドルウェアの作成 (cc:TODO)
├── 5. セッション管理 (cc:TODO)
└── 6. ユーザー管理画面 (cc:TODO)

計 4 タスクを完了まで実行します。

これで合っていますか？
```

**ユーザーの応答パターン**:

| 応答 | アクション |
|------|-----------|
| 「OK」「いいよ」「それで」 | 実行開始 |
| 「3と4だけ」 | 範囲を修正して再確認 |
| 「6は入れないで」 | タスク6を除外して再確認 |
| 「やっぱやめる」 | キャンセル |

---

## 内部オプション

| Option | Description | Default |
|--------|-------------|---------|
| max-iterations | 全体の最大反復回数 | 10 |
| parallel | 並列ワーカー数 | auto |
| checkpoint | 中間チェックポイント保存 | true |

> これらは自然言語で調整可能:
> - 「もっと粘って」→ max-iterations を増加
> - 「1つずつやって」→ parallel = 1
> - 「途中でコミットしないで」→ checkpoint = false

---

## Deliverables

- 指定範囲の**全タスクを完了まで自律的に実行**
- 失敗時は自己学習して再試行（同じ失敗を繰り返さない）
- 完了条件達成で自動終了
- ワークログで全ての試行を記録（再開可能）

---

## Execution Flow

```
/ultrawork 認証機能からユーザー管理まで完了して
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 0: 範囲確認（ユーザー承認必須）                        │
├─────────────────────────────────────────────────────────────┤
│  1. 自然言語を解析 → Plans.md のタスクにマッピング          │
│  2. 対象タスク一覧を表示                                     │
│  3. 「これで合っていますか？」と確認                         │
│  4. ★ ユーザーが承認するまで待機 ★                          │
│     - 「OK」「いいよ」→ Phase 1 へ                         │
│     - 修正指示 → 範囲を修正して再確認                       │
│     - 「やめる」→ キャンセル                                │
└─────────────────────────────────────────────────────────────┘
    ↓ ユーザー承認後
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: 初期化                                              │
├─────────────────────────────────────────────────────────────┤
│  1. 依存関係グラフ構築                                      │
│  2. 完了条件の設定                                          │
│  3. ワークログ初期化                                        │
│     → .claude/state/ultrawork.log.jsonl                    │
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
│  │  - 全完了 → 完了処理へ                             │   │
│  │  - 未完了あり → 次 iteration へ                    │   │
│  │  - max-iterations 到達 → 完了処理へ（部分完了）    │   │
│  │  - checkpoint → 中間コミット                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ※ 各 iteration 終了時にワークログ保存（再開可能）         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ 完了処理                                                    │
├─────────────────────────────────────────────────────────────┤
│  1. 最終コミット（「コミットしないで」でスキップ）          │
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
/ultrawork 続きやって

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

自然言語で完了条件を指定可能:

```bash
/ultrawork 認証機能、テストが全部通るまで
/ultrawork ログインページ、動作確認できるまで
/ultrawork API実装、Postmanで叩けるまで
```

指定された条件が真実になるまでループを継続。

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
3. 修正後「続きやって」で再開

### Worklog

Saved to: `.claude/state/ultrawork.log.jsonl`
修正後「/ultrawork 続きやって」で再開できます。
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

どうしますか？
1. 「もっと粘って」→ 反復回数を増やして継続
2. 「ここは飛ばして次へ」→ ブロックされたタスクをスキップ
3. 「一旦止めて」→ ワークログ保存して中断
```

---

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 全部終わらせて | `/ultrawork 全部やって` |
| この機能だけ | `/ultrawork ログイン機能を完了して` |
| ここからここまで | `/ultrawork 認証からユーザー管理まで` |
| 前回の続きから | `/ultrawork 続きやって` |
| もっと粘って | 「もっと粘って」「諦めないで」 |
| 1つずつ確実に | 「1つずつやって」 |
| 進捗見たい | 「進捗どう？」 |

---

## Related Commands

- `/work` - 1回の実装サイクル（短期タスク向け）
- `/harness-review` - コードレビュー実行
- `/handoff-to-cursor` - PM へのハンドオフ
