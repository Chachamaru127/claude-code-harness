---
name: harness-loop
description: "Long-running task loop using /loop (Claude Code dynamic mode) and ScheduleWakeup to re-enter with fresh context on each wake-up. Internally invokes harness-work through Agent. Trigger: long-running, loop, wake-up, autonomous. Do NOT load for: one-shot task execution, review, release, planning."
kind: workflow
purpose: "Re-enter long-running Plans.md execution with fresh context"
trigger: "long-running, loop, wake-up, autonomous"
shape: delegate
role: orchestrator
base: harness-work
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Edit", "Bash", "Task", "ScheduleWakeup", "mcp__harness__harness_mem_resume_pack", "mcp__harness__harness_mem_record_checkpoint"]
argument-hint: "[all|N-M] [--max-cycles N] [--pacing worker|ci|plateau|night]"
user-invocable: true
---

# harness-loop

A meta-skill that combines `/loop` (CC dynamic mode) and `ScheduleWakeup` to
**re-enter long-running tasks with fresh context on each wake-up**.

On each wake-up, it calls `harness-work --breezing` via Agent,
constructing a re-entrant loop where 1 cycle = 1 task completion.

> **Long-session helpers (CC 2.1.108+)**:
> When you return, use `/recap` to get a summary before checking `/harness-loop status`.
> For workflows with long absences or frequent re-entries, prefer `ENABLE_PROMPT_CACHING_1H=1`.

> **Long session recommendation (CC 2.1.108+)**:
> If the session is expected to exceed 30 minutes, after resolving the plugin bundle root, run `bash "${HARNESS_PLUGIN_ROOT}/scripts/enable-1h-cache.sh"` to opt in to the 1-hour prompt cache.

> **Codex 0.123.0 automatic bug fix inheritance**:
> The manual shell follow-up queue and `/copy` after rollback are automatically inherited as TUI fixes in the Codex core.
> The loop runner does not add an extra input queue, copy wrapper, or rollback workaround.
> Queueing when a follow-up is sent to the manual shell during long-running work is left to the Codex runtime.

## Quick Reference

| Input | Behavior |
|------|------|
| `/harness-loop all` | Loop through all incomplete tasks (default: max 8 cycles) |
| `/harness-loop all --max-cycles 3` | Stop after 3 cycles |
| `/harness-loop 41.1-41.3 --pacing ci` | Run task range with CI pacing |
| `/harness-loop all --plan roadmap` | Loop through the named Plan `roadmap` |
| `/harness-loop all --pacing night` | Night batch (3600s interval) |
| `/harness-loop status` | Check the status of the running runner |
| `/harness-loop stop` | Request stop of the running runner |

## Options

| Option | Description | Default |
|----------|------|----------|
| `all` | Target all incomplete tasks | - |
| `N-M` | Task number range | - |
| `--plan NAME` | Use the named plan from `plans/manifest.json` | active/default |
| `--max-cycles N` | Maximum number of cycles | `8` |
| `--pacing <mode>` | Wake-up interval mode | `worker` (270s) |

### Pacing Value Mapping

| pacing | delaySeconds | Use case |
|--------|-------------|------|
| `worker` | 270 | Immediately after Worker completion (within 5 min cache warm) |
| `ci` | 270 | Short CI job waits |
| `plateau` | 1200 | 20 min (retry interval after plateau detection) |
| `night` | 3600 | Long overnight unattended runs |

> **Constraint**: `ScheduleWakeup` `delaySeconds` is **clamped to [60, 3600]** at runtime.
> `worker` / `ci` at 270s and `night` at 3600s are within this range.
> `plateau` at 1200s is also within range. When specifying values directly, always use 60 or above and 3600 or below.

## Startup Flow (entry on each wake-up)

Detailed version: [`${CLAUDE_SKILL_DIR}/references/flow.md`](${CLAUDE_SKILL_DIR}/references/flow.md)

### Resolve plugin bundle root

`harness-loop` calls helper scripts under the plugin bundle root, not the host project's cwd.
Think of it as keeping the work surface (host project) and the toolbox (plugin bundle) separate.

At the start of each wake-up, determine `HARNESS_PLUGIN_ROOT` in the following order:

1. If `CLAUDE_PLUGIN_ROOT` exists and contains `scripts/`, use it
2. If `CLAUDE_PLUGIN_ROOT` does not exist, back-calculate the plugin bundle root from `CLAUDE_SKILL_DIR`
   - If distributed as `skills/harness-loop`: `${CLAUDE_SKILL_DIR}/../..`
   - If distributed as `.agents/skills/harness-loop` mirror: `${CLAUDE_SKILL_DIR}/../../..`
3. If neither resolves, stop and re-run with `CLAUDE_PLUGIN_ROOT` set to the plugin bundle root

`Plans.md` and `.claude/state/...` reside on the host project side.
Only helper scripts are called from `${HARNESS_PLUGIN_ROOT}/scripts/...`.

In repos with multiple Plans.md files, specify `--plan NAME` explicitly when starting a long run.
The runner retains the Plans file resolved at startup between cycles, so do not switch the active plan mid-run.

```
wake-up
  │
  ▼
[Step 0] Resolve plugin bundle root into HARNESS_PLUGIN_ROOT
  Use CLAUDE_PLUGIN_ROOT if valid
  Otherwise back-calculate plugin bundle root from CLAUDE_SKILL_DIR
  * Do not reference the host project cwd's scripts/
  │
  ▼
[Step 1] Read Plans.md first
  Identify the leading task with cc:WIP / cc:TODO (get task_id)
  * No incomplete tasks → end loop (normal completion)
  │
  ▼
[Step 2] Check for sprint-contract and generate if missing
  Check for .claude/state/contracts/${task_id}.sprint-contract.json
  If absent: generate with node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" ${task_id}
  Immediately after generation (first time only): bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh" <contract-path> \
    --check "Auto-approved on wake-up (reviewing DoD from reviewer perspective for harness-loop)" \
    --approve  ← promote draft → approved
  (Existing contracts are already approved, so skip)
  │
  ▼
[Step 3] Contract readiness check
  bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh" <contract-path>
  │
  ▼
[Step 4] Reload resume pack
  harness-mem resume-pack (context re-injection)
  │
  ▼
[Step 4.5] Advisor consult (only when needed)
  Before the first run of a high-risk task / after 2 consecutive failures with the same cause / just before plateau
  Assemble an `advisor-request.v1` and consult
  │
  ├── PLAN        → prepend advice to the next executor prompt
  ├── CORRECTION  → re-run as a local fix instruction
  └── STOP        → stop the loop there and leave the reason
  │
  ▼
[Step 5] Execute 1 task cycle
  worker_result = Agent(
      subagent_type="claude-code-harness:worker",  # worker agent (not harness-work)
      prompt="Task: ${task_id}\nDoD: <extracted from Plans.md>\ncontract_path: ${CONTRACT_PATH}\nmode: breezing",
      isolation="worktree",
      run_in_background=false
  )
  # worker_result: { commit, branch, worktreePath, files_changed, summary }
  │
  ▼
[Step 5.5] Run Lead review
  diff_text = git show worker_result.commit
  verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
  * See flow.md for details
  │
  ▼
[Step 5.6] APPROVE → cherry-pick to main / REQUEST_CHANGES → fix loop (up to max_iterations in contract, default 3)
  APPROVE: git cherry-pick → update Plans.md to cc:done [{hash}] → delete feature branch
  REQUEST_CHANGES x MAX_REVIEWS then still rejected: escalate
  * See flow.md for details
  │
  ▼
[Step 6] Plateau detection
  bash "${HARNESS_PLUGIN_ROOT}/scripts/detect-review-plateau.sh" ${current_task_id}
  │
  ├── PIVOT_REQUIRED (exit 2)   → stop loop + escalate to user
  ├── INSUFFICIENT_DATA (exit 1) → continue
  └── PIVOT_NOT_REQUIRED (exit 0) → continue
  │
  ▼
[Step 7] Cycle count check
  │
  ├── cycles >= max_cycles → stop loop (limit reached)
  │
  ▼
[Step 8] Record checkpoint
  harness_mem_record_checkpoint(
      session_id, title, content=cycle result summary
  )
  │
  ▼
[Step 9] Schedule next wake-up
  ScheduleWakeup(
      delaySeconds=<pacing value>,
      prompt="/harness-loop <same arguments>",
      reason="Cycle {N}/{max} complete — moving to next task"
  )
```

## Cycle Stop Conditions

| Condition | Stop type | Response |
|------|---------|------|
| `cycles >= max_cycles` | Normal stop (limit reached) | Report to user |
| `PIVOT_REQUIRED` (exit 2) | Abnormal stop (escalation) | Ask user for decision |
| No incomplete tasks | Normal stop (all complete) | Output completion report |

When `--max-cycles 3` is specified, stop after 3 cycles complete.
With the default (`--max-cycles 8`), stop after 8 cycles.

## Mid-run Reports / Silence Policy

In long-running loops, mid-run reports are treated as "notification when a decision changes" rather than "heartbeat for reassurance."
In environments where the Codex `0.123.0` background agent can receive transcript deltas, do not respond solely because a delta arrived — be explicitly silent when not needed.

Report:

- cycle complete, limit reached, all complete, blocked
- validation failure, review `REQUEST_CHANGES`, plateau, advisor `STOP`
- advisor / reviewer drift, contract readiness failure
- summary when user requests `status`

Stay silent for:

- when only transcript deltas are growing with no change in task / review / advisor state
- when only fine-grained stdout in logs is growing
- during pacing wait before the next wake-up

Default is "1 final report per cycle."
However, unanswered Advisor requests, pending Reviewer results, and warnings just before plateau take priority over the silence policy.

## Integration with /loop

This skill is used in combination with CC's `/loop` (dynamic mode).

With `/loop` enabled, CC continues autonomous re-entry,
and calling `ScheduleWakeup` at the end of each cycle reserves the next wake-up.

`/loop` sentinel: `<<autonomous-loop-dynamic>>`

Each wake-up starts with **fresh context**, preventing context contamination from the previous cycle.
Reloading the resume pack via `harness-mem resume-pack` is mandatory (Step 2).

## Checkpoint Recording

`harness_mem_record_checkpoint` schema:

```json
{
  "session_id": "<session ID>",
  "title": "harness-loop cycle {N}/{max}: {task name}",
  "content": "One-line summary of cycle_result + commit hash"
}
```

## Advisor Strategy

The main actor in this skill is the executor; the advisor is called only when needed.
Think of it as the person in charge normally working independently and consulting a senior only at difficult junctures.

Consultation conditions are fixed; natural-language "low confidence" judgments are not used.

| Condition | Consult? |
|------|-----------|
| `needs-spike` / `security-sensitive` / `state-migration` | Yes |
| `<!-- advisor:required -->` | Yes |
| 2nd consecutive failure with the same cause | Yes |
| Just before stopping due to plateau | Yes |

The same trigger is consulted only once.
That determination uses `trigger_hash = task_id + reason_code + normalized_error_signature`.

## Related Skills

- `harness-work` — task implementation skill executed in each cycle
- `harness-plan` — planning for loop target tasks
- `harness-review` — review of individual tasks
- `session-control` — session state management
