---
name: harness-loop
description: "Long-running task loop using /loop (Claude Code dynamic mode) and ScheduleWakeup to re-enter with fresh context on each wake-up. Internally invokes harness-work through Agent. Trigger: long-running, loop, wake-up, autonomous. Do NOT load for: one-shot task execution, review, release, planning."
---

# harness-loop

`/loop`（CC dynamic mode）と `ScheduleWakeup` を組み合わせ、
長時間タスクを **wake-up 毎に fresh context で再入実行** するメタスキル。

各 wake-up で `harness-work --breezing` を Agent 経由で呼び出し、
1 サイクル = 1 タスク完結の再入可能ループを構成する。

> **Long-session helpers (CC 2.1.108+)**:
> 人が戻ってきたら `/recap` で要約を取り直してから `/harness-loop status` を見る。
> 長めの離席や再入が多い運用では `ENABLE_PROMPT_CACHING_1H=1` を優先する。

> **長時間セッション推奨 (CC 2.1.108+)**:
> セッション長が 30 分を超える見込みの場合、plugin bundle root 解決後に `bash "${HARNESS_PLUGIN_ROOT}/scripts/enable-1h-cache.sh"` を実行して 1 時間 prompt cache を opt-in すること。

> **Codex 0.123.0 automatic bug fix inheritance**:
> manual shell follow-up queue と `/copy` after rollback は Codex 本体の TUI 修正として自動継承する。
> loop runner は追加入力 queue、copy wrapper、rollback workaround を追加しない。
> 長時間作業中に manual shell へ follow-up を投げた時の queueing は Codex runtime に任せる。

## Quick Reference

| 入力 | 動作 |
|------|------|
| `/harness-loop all` | 全未完了タスクをループ実行（default: max 8 サイクル） |
| `/harness-loop all --max-cycles 3` | 3 サイクルで停止 |
| `/harness-loop 41.1-41.3 --pacing ci` | タスク範囲を CI pacing で実行 |
| `/harness-loop all --plan roadmap` | named Plans の `roadmap` を対象にループ実行 |
| `/harness-loop all --pacing night` | 深夜バッチ（3600s 間隔） |
| `/harness-loop status` | 進行中ランナーの状態確認 |
| `/harness-loop stop` | 進行中ランナーの停止要求 |

## オプション

| オプション | 説明 | デフォルト |
|----------|------|----------|
| `all` | 全未完了タスクを対象 | - |
| `N-M` | タスク番号範囲指定 | - |
| `--plan NAME` | `plans/manifest.json` の named plan を使う | active/default |
| `--max-cycles N` | 最大サイクル数 | `8` |
| `--pacing <mode>` | wake-up 間隔モード | `worker`（270s） |

### pacing 値マッピング

| pacing | delaySeconds | 用途 |
|--------|-------------|------|
| `worker` | 270 | Worker 完了直後（5 min 以内で cache warm） |
| `ci` | 270 | CI 短時間ジョブ待ち |
| `plateau` | 1200 | 20 min（plateau 検知後の再試行間隔） |
| `night` | 3600 | 深夜の長時間放置 |

> **制約**: `ScheduleWakeup` の `delaySeconds` はランタイムで **[60, 3600]** に clamp される。
> `worker` / `ci` の 270s および `night` の 3600s はこの範囲内。
> `plateau` の 1200s も範囲内。値を直接指定する場合は必ず 60 以上 3600 以下にすること。

## 起動フロー（wake-up 毎のエントリ）

詳細版: [`${CLAUDE_SKILL_DIR}/references/flow.md`](${CLAUDE_SKILL_DIR}/references/flow.md)

### plugin bundle root 解決

`harness-loop` は host project の cwd ではなく、plugin bundle root 配下の helper script を呼ぶ。
たとえると、作業机（host project）と工具箱（plugin bundle）を分けて扱う。

各 wake-up の冒頭で次の順に `HARNESS_PLUGIN_ROOT` を決める:

1. `CLAUDE_PLUGIN_ROOT` があり、`scripts/` を含むならそれを使う
2. `CLAUDE_PLUGIN_ROOT` がなければ、`CLAUDE_SKILL_DIR` から plugin bundle root を逆算する
   - `skills/harness-loop` 配布なら `${CLAUDE_SKILL_DIR}/../..`
   - `.agents/skills/harness-loop` mirror 配布なら `${CLAUDE_SKILL_DIR}/../../..`
3. どちらでも解けない場合は停止し、`CLAUDE_PLUGIN_ROOT` を plugin bundle root に設定して再実行する

`Plans.md` と `.claude/state/...` は host project 側に置く。
helper script だけを `${HARNESS_PLUGIN_ROOT}/scripts/...` から呼ぶ。

複数 Plans.md がある repo では、長時間 run の起動時に `--plan NAME` を明示する。
runner は開始時に解決した Plans file を cycle 間で保持するため、途中で active plan を切り替えない。

```
wake-up
  │
  ▼
[Step 0] plugin bundle root を HARNESS_PLUGIN_ROOT に解決
  CLAUDE_PLUGIN_ROOT が有効ならそれを使用
  なければ CLAUDE_SKILL_DIR から plugin bundle root を逆算
  ※ host project cwd の scripts/ は参照しない
  │
  ▼
[Step 1] Plans.md を先に読む
  cc:WIP / cc:TODO の先頭タスクを特定（task_id を得る）
  ※ 未完了タスクなし → ループ終了（正常完了）
  │
  ▼
[Step 2] sprint-contract 存在確認 & 生成
  .claude/state/contracts/${task_id}.sprint-contract.json の有無を確認
  無ければ node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" ${task_id} で生成
  生成直後（初回のみ）: bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh" <contract-path> \
    --check "wake-up 自動承認（harness-loop のため DoD を reviewer 観点で確認）" \
    --approve  ← draft → approved に昇格
  （既存 contract は approved 済みのためスキップ）
  │
  ▼
[Step 3] contract readiness チェック
  bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh" <contract-path>
  │
  ▼
[Step 4] Resume pack 再読込
  harness-mem resume-pack（コンテキスト再注入）
  │
  ▼
[Step 4.5] Advisor consult（必要時のみ）
  高リスク task の初回実行前 / 同じ原因の 2 回目失敗後 / plateau 直前で
  `advisor-request.v1` を組み立てて相談する
  │
  ├── PLAN        → 次回 executor prompt に advice を prepend
  ├── CORRECTION  → 局所修正の指示として再実行
  └── STOP        → その場で loop を停止し、理由を残す
  │
  ▼
[Step 5] 1 タスクサイクル実行
  worker_result = Agent(
      subagent_type="claude-code-harness:worker",  # worker エージェント（harness-work ではない）
      prompt="タスク: ${task_id}\nDoD: <Plans.md から抽出>\ncontract_path: ${CONTRACT_PATH}\nmode: breezing",
      isolation="worktree",
      run_in_background=false
  )
  # worker_result: { commit, branch, worktreePath, files_changed, summary }
  │
  ▼
[Step 5.5] Lead レビュー実行
  diff_text = git show worker_result.commit
  verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
  ※ 詳細は flow.md 参照
  │
  ▼
[Step 5.6] APPROVE → main に cherry-pick / REQUEST_CHANGES → 修正ループ（contract の max_iterations 回、デフォルト 3）
  APPROVE: git cherry-pick → Plans.md を cc:完了 [{hash}] に更新 → feature branch 削除
  REQUEST_CHANGES x MAX_REVIEWS 後も否決: エスカレーション
  ※ 詳細は flow.md 参照
  │
  ▼
[Step 6] plateau 判定
  bash "${HARNESS_PLUGIN_ROOT}/scripts/detect-review-plateau.sh" ${current_task_id}
  │
  ├── PIVOT_REQUIRED（exit 2）  → ループ停止 + ユーザーエスカレーション
  ├── INSUFFICIENT_DATA（exit 1）→ 続行
  └── PIVOT_NOT_REQUIRED（exit 0）→ 続行
  │
  ▼
[Step 7] サイクル数チェック
  │
  ├── cycles >= max_cycles → ループ停止（上限到達）
  │
  ▼
[Step 8] checkpoint 記録
  harness_mem_record_checkpoint(
      session_id, title, content=サイクル結果サマリ
  )
  │
  ▼
[Step 9] 次 wake-up 予約
  ScheduleWakeup(
      delaySeconds=<pacing値>,
      prompt="/harness-loop <同じ引数>",
      reason="サイクル {N}/{max} 完了 — 次タスクへ"
  )
```

## サイクル停止条件

| 条件 | 停止種別 | 対応 |
|------|---------|------|
| `cycles >= max_cycles` | 正常停止（上限到達） | ユーザーに報告 |
| `PIVOT_REQUIRED`（exit 2） | 異常停止（エスカレーション） | ユーザーに判断を仰ぐ |
| 未完了タスクなし | 正常停止（全完了） | 完了報告を出力 |

`--max-cycles 3` 指定時は 3 サイクル完了後に停止する。
default（`--max-cycles 8`）時は 8 サイクルで停止する。

## 途中報告 / Silence Policy

長時間 loop では、途中報告は「安心のための heartbeat」ではなく「判断が変わった時の通知」として扱う。
Codex `0.123.0` の background agent が transcript delta を受け取れる環境では、delta 到着だけを理由に返答せず、必要ない時は明示的に沈黙する。

報告するもの:

- cycle 完了、上限到達、全完了、blocked
- validation failure、review `REQUEST_CHANGES`、plateau、advisor `STOP`
- advisor / reviewer drift、contract readiness failure
- user が `status` を求めた時の要約

沈黙してよいもの:

- transcript delta だけが増え、task / review / advisor の状態が変わっていない時
- log に残る細かな stdout だけが増えた時
- 次 wake-up までの pacing 待機中

default は「1 cycle につき最終報告 1 回」。
ただし Advisor request 未応答、Reviewer result 未到着、plateau 直前の警告は silence policy より優先して報告する。

## /loop との連携

このスキルは CC の `/loop`（dynamic mode）と組み合わせて使用する。

`/loop` を有効にすると CC は自律的な再入実行を継続し、
各サイクルの末尾で `ScheduleWakeup` を呼ぶことで次回 wake-up を予約する。

`/loop` のセンチネル: `<<autonomous-loop-dynamic>>`

各 wake-up は **fresh context** で開始されるため、前サイクルのコンテキスト汚染を防ぐ。
`harness-mem resume-pack` による resume pack 再読込が必須（Step 2）。

## checkpoint 記録

`harness_mem_record_checkpoint` スキーマ:

```json
{
  "session_id": "<セッション ID>",
  "title": "harness-loop cycle {N}/{max}: {タスク名}",
  "content": "cycle_result の 1 行サマリ + commit hash"
}
```

## Advisor Strategy

この skill の主役は executor で、advisor は必要な時だけ呼ぶ。
たとえると、担当者が普段は自走し、難所だけベテランに相談する形。

相談条件は固定で、自然言語の「自信が低い」判定は使わない。

| 条件 | 相談するか |
|------|-----------|
| `needs-spike` / `security-sensitive` / `state-migration` | する |
| `<!-- advisor:required -->` | する |
| 同じ原因の 2 回目失敗 | する |
| plateau で停止する直前 | する |

同じ trigger は 1 回しか相談しない。
その判定には `trigger_hash = task_id + reason_code + normalized_error_signature` を使う。

## 関連スキル

- `harness-work` — 各サイクルで実行されるタスク実装スキル
- `harness-plan` — ループ対象タスクの計画
- `harness-review` — 個別タスクのレビュー
- `session-control` — セッション状態管理
