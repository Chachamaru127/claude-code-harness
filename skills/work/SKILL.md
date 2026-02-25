---
name: work
description: "Plans.mdのタスクを実装。スコープを聞いて自動判断、1タスクから全タスクまで。Use when user mentions '/work', execute plan, implement tasks, build features, work on tasks, 'do everything', 'implement', '実装して', '全部やって', 'ここだけ'. Do NOT load for: planning, reviews, setup, deployment, or breezing (team execution)."
description-en: "Execute Plans.md tasks. Asks scope, auto-selects strategy from single task to full iteration. Use when user mentions '/work', execute plan, implement tasks, build features, work on tasks, 'do everything', 'implement'. Do NOT load for: planning, reviews, setup, deployment, or breezing (team execution)."
description-ja: "Plans.mdのタスクを実装。スコープを聞いて自動判断、1タスクから全タスクまで。Use when user mentions '/work', execute plan, implement tasks, build features, work on tasks, 'do everything', 'implement', '実装して', '全部やって', 'ここだけ'. Do NOT load for: planning, reviews, setup, deployment, or breezing (team execution)."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--no-breezing] [--resume id]"
disable-model-invocation: true
---

# Work Skill

Plans.md のタスクを実装する**主力スキル**。スコープに応じて戦略を自動選択。

## Philosophy

> **「聞いて、判断して、実行する」**
>
> 1タスクなら直接実装。複数なら並列。大量なら自動反復。
> ユーザーはスコープだけ決めれば、あとは自動。

## Quick Reference

```bash
/work                    # スコープを聞いてから実行
/work 3                  # タスク3だけ即実行
/work all                # 全タスクを即実行
/work 3-6                # タスク3〜6を即実行
/work --codex            # Codex CLI で実装（スコープを聞く）
/work --codex all        # Codex CLI で全タスク即実行
/work --parallel 5       # 並列5ワーカーで実行
/work --no-commit        # 自動コミット抑制
/work --resume latest    # 前回セッション再開
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--codex` | Codex CLI で実装委託 | false |
| `--parallel N` | 並列ワーカー数 | auto |
| `--sequential` | 並列禁止（直列実行） | - |
| `--no-commit` | 自動コミット抑制 | false |
| `--no-breezing` | breezing 提案を抑制 | false |
| `--max-iterations N` | 反復上限（all 時） | 10 |
| `--resume <id\|latest>` | セッション再開 | - |
| `--fork <id\|current>` | セッションフォーク | - |

## Scope Dialog (引数なし時)

引数なしで呼ぶと、対話でスコープを確認:

```
/work
どこまでやりますか?
1) 次のタスク (推奨): Plans.md の次の未完了タスク
2) 全部: 残りのタスクを全て完了
3) 指定: タスク番号や範囲を指定 (例: 3, 3-6)

> [Enter = 1]
```

引数ありなら即実行（対話スキップ）。

詳細: [references/scope-dialog.md](references/scope-dialog.md)

## Auto Strategy Selection

スコープに応じて、内部戦略を自動選択:

| スコープ | 戦略 | 元スキル相当 |
|---------|------|------------|
| 1タスク | 直接実装 | 旧 `/work` |
| 2-3タスク | サブエージェント並列 | 旧 `/work --parallel` |
| 4+タスク or `all` | サブエージェント並列 + 自動反復 | 旧 `/ultrawork` |
| 4+タスク + breezing 推奨 | (ユーザー承認後) Agent Teams で完走 | `/breezing` に委譲 |

```
実行開始時に戦略を表示:

🔧 戦略: 直接実装 (タスク1件)
🔧 戦略: 並列 3 ワーカー (タスク3件)
🔧 戦略: 並列 3 ワーカー + 自動反復 (タスク8件, 最大10回)
🏇 戦略提案: breezing を推奨 (タスク5件, 独立率80%) → ユーザー承認待ち
```

ユーザーは戦略を意識する必要なし。4+ タスクで breezing が有効な場合は自動提案。

詳細: [references/strategy-analyzer.md](references/strategy-analyzer.md)

## Default Flow

```
/work [scope]
    ↓
Phase 0: スコープ確認 (引数なしなら対話)
    ↓
Phase 0.5: 戦略分析 (4+タスク時、--no-breezing で省略)
    → breezing 推奨 → AskUserQuestion で提案
    → ユーザーが breezing 選択 → /breezing に委譲 (終了)
    → ユーザーが parallel/direct 選択 → Phase 1 へ
    ↓
Phase 1: 戦略選択 (タスク数で自動判断)
    ↓
Phase 2: 実装
    → 1タスク: 直接実装
    → 複数: task-worker サブエージェント並列
    → 全部/4+: 並列 + 反復ループ (完了まで自動)
    → (反復失敗時: breezing エスカレーション提案)
    ↓
Phase 3: Review Loop (harness-review)
    → APPROVE: proceed
    → REQUEST_CHANGES: fix → re-review
    ↓
Phase 4: Auto-commit (unless --no-commit)
    ↓
Tip 表示
```

## Unified Memory Gate（必須）

`/work` 実行時は、以下の順序で Unified Harness Memory を必ず通す:

1. 実装前: `harness_mem_resume_pack(project, session_id?, limit=5, include_private=false)`
2. マイルストーン到達時（設計確定・大きな修正・方針転換）:
   `harness_mem_record_checkpoint(session_id, title, content, tags?, privacy_tags?)`
3. 実装完了時（handoff 前）:
   `harness_mem_finalize_session(session_id, summary_mode="standard")`

補足:
- `session_id` は `$CLAUDE_SESSION_ID` → `.claude/state/session.json` の `.session_id` の順で取得する
- `harness_mem_sessions_list(project, limit=1)` の先頭利用は read-only（resume確認）に限定し、`record_checkpoint` / `finalize_session` は明示 `session_id` が無い場合に失敗扱いとする
- Codex では `notify` hook（after_agent）とこの手順を併用し、記録漏れを抑える
- `.codex/history.jsonl` は daemon 側で自動インジェストされるため、手動追記不要
- いずれかが失敗した場合は `harness_mem_health()` と `scripts/harness-memd doctor` で状態確認し、復旧後に同ステップを再実行する

## Auto-Iteration (4+ tasks or `all`)

大量タスク時は自動反復ロジックが有効化:

- 前回の失敗から自己学習
- 未完了タスクを次イテレーションで再試行
- 完了条件: 全タスク cc:done + ビルド成功 + テスト通過 + Review APPROVE
- 最大反復回数: `--max-iterations` (default: 10)

詳細: [references/auto-iteration.md](references/auto-iteration.md)

## --codex Engine

`--codex` フラグで Codex CLI にすべての実装を委託:

| 項目 | デフォルト | --codex |
|------|-----------|---------|
| 実装主体 | Claude (直接コーディング) | Codex CLI |
| Claude の役割 | 調整 + 実装 | PM (調整のみ) |
| Edit/Write | 許可 | 禁止 (guard 適用) |
| 品質保証 | セルフレビュー | AGENTS_SUMMARY + Quality Gates |

詳細: [references/codex-engine.md](references/codex-engine.md)

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Strategy Analyzer** | See [references/strategy-analyzer.md](references/strategy-analyzer.md) |
| **Scope Dialog** | See [references/scope-dialog.md](references/scope-dialog.md) |
| **Auto-Iteration** | See [references/auto-iteration.md](references/auto-iteration.md) |
| **Codex Engine** | See [references/codex-engine.md](references/codex-engine.md) |
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **Parallel Execution** | See [references/parallel-execution.md](references/parallel-execution.md) |
| **Session Management** | See [references/session-management.md](references/session-management.md) |
| **Review Loop** | See [references/review-loop.md](references/review-loop.md) |
| **Auto-commit** | See [references/auto-commit.md](references/auto-commit.md) |
| **Error Handling** | See [references/error-handling.md](references/error-handling.md) |

## Smart Parallel Detection

| Condition | Parallel Count |
|-----------|:--------------:|
| 1 task | 1 |
| All tasks edit same file | 1 |
| 2-3 independent tasks | 2-3 |
| 4+ independent tasks | 3 (max) |

## Completion Tip

実行完了時に次のアクションを案内:

```
Done! 2 tasks completed. (3 remaining)
Tip: /breezing でチーム並列実行できます
Tip: --codex を付けると Codex に実装を委託できます
```

**条件分岐**:
- 残タスクあり + breezing 推奨条件に該当 → `/breezing` Tip を表示
- 残タスクあり + breezing 条件外 → 従来の Tip
- 全タスク完了 → Tip なし
- breezing を提案済みでユーザーが却下 → `/breezing` Tip を**表示しない**（ノイズ削減）

## Session State

### 初期化

```bash
# work-active.json を作成
cat > .claude/state/work-active.json <<EOF
{
  "active": true,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "strategy": "iteration",
  "codex_mode": false,
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": ["node_modules", "dist", ".next", ".cache"],
  "review_status": "pending"
}
EOF
```

### 完了時クリア

```bash
rm -f .claude/state/work-active.json
```

## Auto-invoke Skills

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `impl` | Feature implementation | On task implementation |
| `verify` | Build verification | On post-implementation verification |
| `harness-review` | Multi-perspective review | After implementation complete |

## Project Configuration

Override defaults via `.claude-code-harness.config.yaml`:

```yaml
work:
  auto_commit: false          # Disable auto-commit
  commit_on_pm_approve: true  # 2-Agent: defer commit until PM approves
  breezing_auto_approve: false  # Auto-invoke breezing when recommended (high confidence)
```

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 次のタスクだけ | `/work` (Enter で次のタスク) |
| 全部終わらせて | `/work all` |
| この番号だけ | `/work 3` |
| ここからここまで | `/work 3-6` |
| Codex に任せて | `/work --codex` |
| 並列で速く | `/work --parallel 5 all` |
| チームで完走して | → `/breezing` を使用 |

## Related Skills

- `breezing` - Agent Teams でチーム並列完走（Lead は指揮のみ）
- `harness-review` - コードレビュー（/work 内で自動起動）
- `impl` - 個別タスクの実装ロジック
