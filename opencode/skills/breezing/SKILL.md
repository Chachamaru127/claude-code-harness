---
name: breezing
description: "楽勝で流す。Agent Teamsで完全自走、寝てる間にゴール。Use when user mentions '/breezing', agent teams, team execution, full auto completion, multi-agent workflow, 'チームで完走', 'チームで全部'. Do NOT load for: single tasks, reviews, setup, or /work (direct implementation)."
description-en: "Auto-complete Plans.md with Agent Teams, fully autonomous. Use when user mentions '/breezing', agent teams, team execution, full auto completion, multi-agent workflow. Do NOT load for: single tasks, reviews, setup, or /work (direct implementation)."
description-ja: "楽勝で流す。Agent Teamsで完全自走、寝てる間にゴール。Use when user mentions '/breezing', agent teams, team execution, full auto completion, multi-agent workflow, 'チームで完走', 'チームで全部'. Do NOT load for: single tasks, reviews, setup, or /work (direct implementation)."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--no-discuss] [--from-work]"
disable-model-invocation: true
---

# Breezing Skill

Agent Teams を活用して Plans.md の未完了タスクを**チーム協調で完全自動完走**する。

## Philosophy

> **「Lead は指揮するだけ、手を動かすのは Teammate」**
>
> delegate mode で Lead は調整に専念。
> 実装は Implementer、レビューは Reviewer。三者分離の完全自律。

## Quick Reference

```bash
/breezing                                     # スコープを聞いてから実行
/breezing all                                 # Plans.md 全タスクを完走
/breezing 3-6                                 # タスク3〜6を完走
/breezing 認証機能からユーザー管理まで          # 自然言語で範囲指定
/breezing --codex all                         # Codex MCP で全タスク完走
/breezing --codex --parallel 2 ログイン機能    # Codex 2並列で範囲指定
/breezing --parallel 2 ログイン機能            # Claude 2並列で範囲指定
/breezing --no-discuss all                      # 計画議論をスキップして全タスク完走
/breezing 続きやって                           # 前回中断から再開
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--codex` | Codex MCP で実装委託 | false (Claude 実装) |
| `--parallel N` | Implementer 並列数 | auto |
| `--no-commit` | 自動コミット抑制 | false |
| `--no-discuss` | 計画議論 Phase (Phase 0) をスキップ | false |
| `--from-work` | `/work` から invoke された場合のマーカー（内部用） | false |

## Scope Dialog (引数なし時)

引数なしで呼ぶと、対話でスコープを確認:

```
/breezing
どこまでやりますか?
1) 全部 (推奨): 残りのタスクを全て完走
2) 指定: タスク番号や範囲を指定 (例: 3, 3-6)

> [Enter = 1]
```

引数ありなら即実行（対話スキップ）:
```
/breezing all        # 全タスク即実行
/breezing 3-6        # 範囲即実行
```

## `/work` との違い

| 特徴 | `/work` | `/breezing` |
|------|---------|-------------|
| 並列手段 | Task tool (サブエージェント) | **Agent Teams (Teammates)** |
| Lead の役割 | 調整+実装 | **delegate (調整専念)** |
| レビュー | Lead 自己レビュー | **独立 Reviewer Teammate** |
| リテイク | 自動 (Lead 自己修正) | **自動 (Lead 分解 → Impl 修正)** |
| デフォルトスコープ | 次のタスク | **全部** |
| コスト | 低〜中 | 高 |

## --codex Engine

`--codex` フラグで Codex MCP にすべての実装を委託:

| 項目 | デフォルト | --codex |
|------|-----------|---------|
| Implementer | task-worker (Claude) | codex-implementer (Codex MCP) |
| 実装の仕組み | Sonnet が直接コーディング | Codex MCP 経由で委託 |
| 品質保証 | セルフレビュー 4 観点 | AGENTS_SUMMARY + Quality Gates |
| ファイル分離 | owns: アノテーション | Lead 判断（worktree or owns:） |
| コスト特性 | Claude トークン消費 | Codex API + Claude レビュー |

詳細: [references/codex-engine.md](references/codex-engine.md)

## Feature Details

| Feature | Reference |
|---------|-----------|
| **Execution Flow** | See [references/execution-flow.md](references/execution-flow.md) |
| **Planning Discussion** | See [references/planning-discussion.md](references/planning-discussion.md) |
| **Team Composition** | See [references/team-composition.md](references/team-composition.md) |
| **Review/Retake Loop** | See [references/review-retake-loop.md](references/review-retake-loop.md) |
| **Plans.md → TaskList** | See [references/plans-to-tasklist.md](references/plans-to-tasklist.md) |
| **Codex Engine** | See [references/codex-engine.md](references/codex-engine.md) |
| **Session Resilience** | See [references/session-resilience.md](references/session-resilience.md) |
| **Guardrails Inheritance** | See [references/guardrails-inheritance.md](references/guardrails-inheritance.md) |
| **Codex Review Integration** | See [references/codex-review-integration.md](references/codex-review-integration.md) |

## Prerequisites

1. **Agent Teams 有効化**: `settings.json` に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
2. **Plans.md** が存在し、未完了タスクがあること
3. (--codex) Codex MCP サーバーが登録済み

## Execution Flow Summary

```
/breezing [scope] [--codex] [--parallel N] [--no-discuss]
    │
Phase 0: Planning Discussion（デフォルト実行、--no-discuss でスキップ）
  Planner + Critic Teammate spawn → 計画議論 最大 3 ラウンド
  → 精査済み計画をユーザーに提示 → 承認後 Phase A へ
    │
Phase A: Pre-delegate（ユーザーのパーミッションモード維持）
  Step 0: breezing-active.json に impl_mode を即時書き込み
          --codex あり → impl_mode: "codex"
          --codex なし → impl_mode: "standard"
  Step 1-2: スコープ確認 → ユーザー承認
  Step 3: Team 初期化 → TaskCreate → Implementer N 個を同時 spawn:
          impl_mode: "codex"    → subagent_type: codex-implementer (必須)
          impl_mode: "standard" → subagent_type: task-worker
          ※ impl_mode と subagent_type の不一致は絶対禁止
  ※ delegate mode に入る前に全準備を完了
    │
    ↓ delegate mode ON
Phase B: Delegate（Lead は調整専念）
  実装・レビューサイクル (Lead の判断で柔軟に運用):
  ├── 実装: Implementer N 個が並列で self-claim → build/test
  │        (--codex: codex-implementer が Codex CLI 経由で実装)
  │        (標準: task-worker が直接コーディング)
  ├── レビュー: Reviewer 独立レビュー (部分/全体、任意タイミング)
  └── リテイク: findings → 修正タスク → 再レビュー (直接対話可)
    │
    ↓ delegate mode OFF
Phase C: Post-delegate（パーミッションモード復元）
  全タスク完了 + APPROVE → 統合検証 → Plans.md 更新 → commit → cleanup
```

## Compaction Recovery

**Compaction が発生した場合の復元手順:**

1. `.claude/state/breezing-active.json` を Read する
2. `impl_mode` を確認（`"codex"` or `"standard"`）
3. `team_name` で TaskList が存在するか確認
4. Team が消失していれば再作成:
   - `impl_mode: "codex"` → `codex-implementer` を `team.implementer_count` 個 spawn
   - `impl_mode: "standard"` → `task-worker` を `team.implementer_count` 個 spawn
5. TaskList で未完了タスクを確認し、サイクルを再開

**絶対禁止**:
- `impl_mode: "codex"` がある限り、Lead が Write/Edit でソースコードを直接書くことは禁止
- `impl_mode: "codex"` のときに `task-worker` を spawn することは禁止（必ず `codex-implementer`）
- `impl_mode: "standard"` のときに `codex-implementer` を spawn することは禁止（必ず `task-worker`）

## Completion Conditions

以下を**全て**満たしたとき完了:

1. 指定範囲の全タスクが `cc:done`
2. 統合ビルド成功
3. 全テスト通過
4. Reviewer が最終 APPROVE (Critical/Major findings = 0)
5. (--codex) 全タスクの AGENTS_SUMMARY 検証通過

## Completion Tip

```
Done! 5 tasks completed by team.
Tip: /work でサクッと1タスクだけ進めることもできます
Tip: --codex を付けると Codex に実装を委託できます
```

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 全部終わらせて | `/breezing all` |
| Codex で全部 | `/breezing --codex all` |
| この機能だけ | `/breezing ログイン機能を完了して` |
| ここからここまで | `/breezing 認証からユーザー管理まで` |
| 前回の続きから | `/breezing 続きやって` |
| 1タスクだけ | → `/work` を使用 |

## Invoked from /work（`--from-work` 時の動作）

`/work` の Strategy Analyzer が breezing を推奨し、ユーザーが承認した場合に Skill tool 経由で invoke される。

### 動作変更

| Phase | 通常 | `--from-work` |
|-------|------|---------------|
| Phase 0 (Planning Discussion) | 実行 | **実行**（計画議論は独自の価値がある） |
| Phase A Step 2 (範囲確認) | ユーザー承認 | **スキップ**（/work 側で確認済み） |
| breezing-active.json | 通常記録 | `source: "work"` を追加記録 |

### 引き継ぎデータスキーマ

`/work` から渡される情報（Skill tool の args に含まれる scope 情報から復元）:

```json
{
  "source": "work" | "work-escalation",
  "scope": "all" | "3-6",
  "completed_tasks": ["1", "2"],
  "failure_history": [],
  "strategy_analysis": {
    "recommended": "breezing",
    "confidence": "high",
    "metrics": { ... }
  }
}
```

- `source: "work"` → 事前戦略分析による提案
- `source: "work-escalation"` → 反復失敗からのエスカレーション
  - `completed_tasks` に /work で完了済みタスクの ID が含まれる
  - `failure_history` に失敗エントリが含まれる → Phase 0 の分析材料として活用

### breezing-active.json への記録

```json
{
  "session_id": "breezing-...",
  "invoked_from": {
    "source": "work",
    "strategy_analysis": { ... },
    "completed_tasks": []
  }
}
```

## Related Skills

- `work` - Claude が直接実装（1タスクから全タスクまで。breezing を自動提案する）
- `harness-review` - コードレビュー（breezing 内で自動起動）
- `codex-review` - Codex によるセカンドオピニオンレビュー
