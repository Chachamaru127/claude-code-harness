# Long-Running Task Execution Guide

This document is a practical guide for safely running **tasks that cannot finish in a single session** with Claude Code.
"Long-running tasks" here refers to work that progresses incrementally using `/loop` and `ScheduleWakeup`.
This document is the output of Phase 41.4.1.

The scope is **operation within the same Phase 41 session**. Automatic re-entry across separate hosts is not covered at this stage.

Reference: [skills/harness-loop/SKILL.md](../skills/harness-loop/SKILL.md) / [skills/harness-loop/references/flow.md](../skills/harness-loop/references/flow.md) / [docs/CLAUDE-feature-table.md](CLAUDE-feature-table.md)

---

## 1. Getting the big picture

Long-running tasks proceed by repeating these 4 steps:

1. Decide the 1 unit of work to do now
2. Implement or verify in small steps
3. Leave the result as a checkpoint
4. Schedule the next wake-up

The key here is to **re-enter with "fresh eyes" each time**.
Rather than carrying forward the previous conversation, re-inject only the necessary information
from the resume pack and resume from there.

### Mapping to the 12 B-axes

| Axis | What to decide | How Harness handles it |
|---|---|---|
| B1 | What to achieve | Read the target task and DoD from Plans.md |
| B2 | How far to go in one run | Advance 1 cycle = 1 task unit |
| B3 | Where to start | Use `/loop` as the entry point |
| B4 | How to resume | Schedule the next wake-up with `ScheduleWakeup` |
| B5 | What to carry forward | Restore only needed info with `harness-mem resume-pack` |
| B6 | How long to wait | Choose the interval with `pacing` |
| B7 | When to stop | Set a ceiling with `--max-cycles` |
| B8 | How to avoid conflicts | Prevent multiple launches with locks and idempotency guards |
| B9 | How to record progress | Record checkpoints with `harness_mem_record_checkpoint` |
| B10 | Whether progress is being made | Find stalls with plateau detection |
| B11 | What to scope | Phase 41 is limited to the same session |
| B12 | What to watch out for | Understand the limits of `bypassPermissions` and Plans.md flock |

---

## 2. Using `/loop` + `ScheduleWakeup`

`/loop` signals Claude Code to "continue working."
`ScheduleWakeup` schedules when to resume next.

### Basic usage

```text
/loop all
/loop 41.1-41.3 --pacing ci
/loop all --pacing night
```

### One cycle flow

1. Select 1 task from `Plans.md`
2. Execute only the minimum work needed for that task
3. Leave a checkpoint
4. Schedule the next wake-up with `ScheduleWakeup`

### Example schedule

```text
ScheduleWakeup(
  delaySeconds=270,
  prompt="/harness-loop all --cycles-done 1 --pacing worker",
  reason="1 cycle complete. Proceeding to next task."
)
```

`delaySeconds` is "how many seconds until returning."
Too short feels rushed; too long makes it easy to forget the previous flow.
In practice, keep it in the range of 60 to 3600 seconds.

---

## 3. Choosing a pacing preset

`pacing` controls how long to wait before the next wake-up.

| pacing | delaySeconds | When to use | One-liner |
|---|---:|---|---|
| `worker` | 270 | Continue immediately from the previous work | Standard setting |
| `ci` | 270 | Waiting for CI results | Keep the wait short |
| `plateau` | 1200 | Prone to stalling | Let it cool down a bit longer |
| `night` | 3600 | Running overnight in batch | Longest wait |

### Cache boundary considerations

Claude Code has a "short-term cache" that remembers the previous flow for a brief period.
`worker` and `ci` at 270 seconds are still within the short-term cache window.

On the other hand, `plateau` and `night` are likely to expire the short-term cache,
so **always depend on the resume pack** to be safe.
In other words, the longer the wait, the more you design for "re-injecting needed info"
rather than "remembering on your own."

### Using the 1-hour cache

Since Claude Code `2.1.108`, you can opt into a **1-hour cache** (longer than the standard 5-minute
cache) by setting `ENABLE_PROMPT_CACHING_1H=1`.

This is useful for cases where "almost the same premise is re-read each time, but the next
input tends to exceed 5 minutes." For the long-running tasks covered in this document,
it works particularly well in these situations:

1. `/harness-loop` with wait intervals between each cycle
2. Reusing the same premise across `/resume` or `/continue`
3. Review or advisor consult is interleaved and returns after more than 5 minutes

Conversely, if it's just a short back-and-forth of a few seconds to a few minutes, the default
5-minute cache is sufficient.

### Choosing between 1h vs 5m cache

| Decision axis | Choose 1h cache | 5m cache (default) is sufficient |
|--------|----------------|------------------------|
| Expected session length | **Over 30 minutes** | Within 30 minutes |
| Wake-up interval | `plateau` (1200s) or `night` (3600s) | `worker`/`ci` (270s) |
| Premise information reuse | Reading almost the same SKILL.md / Plans.md each cycle | Premises change each time in short back-and-forth |
| Target skill | `/breezing` / `/harness-loop` multi-task runs | Single `/work` or conversational |

**Decision rule**: If the expected session length **exceeds 30 minutes**, choose 1h cache. Otherwise, the default 5-minute cache is sufficient.

Opt-in procedure:

```bash
bash scripts/enable-1h-cache.sh
```

This command appends `ENABLE_PROMPT_CACHING_1H=1` to `env.local` (idempotent).
It does not change global settings. Does nothing if already configured.

### Recommended adoption policy

This repository **does not enable this globally for all sessions**.
The reason is that the 1-hour cache is useful but involves additional cost and tends to be
overkill for short interactions.

Instead, use a thin launch wrapper dedicated to long-running tasks:

```bash
bash scripts/claude-longrun.sh
```

You can also pass arguments directly:

```bash
bash scripts/claude-longrun.sh --resume
bash scripts/claude-longrun.sh --model claude-opus-4-6
```

This script simply launches `claude` with `ENABLE_PROMPT_CACHING_1H=1` internally.
It does not change global settings, so the impact on normal work is minimized.

### Env inheritance by child processes (Codex CLI integration)

When calling Codex CLI via `/breezing --codex` or `scripts/codex-companion.sh task --write`,
verify whether `ENABLE_PROMPT_CACHING_1H` is inherited by child processes.

| Path | Inherited | Notes |
|------|------------|--------|
| `bash scripts/codex-companion.sh task --write "..."` | Yes | Normal bash subprocesses inherit the parent env |
| `bash scripts/codex-companion.sh review --base "${REF}"` | Yes | Same as above |
| Parent process launched via `claude-longrun.sh` | Yes | The script exports before launching claude |
| When `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` is enabled | **May be scrubbed** | Ensure `ENABLE_PROMPT_CACHING_1H` is not included in the scrub target env list |

The `env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB="1"` in `.claude-plugin/settings.json` is intended to
purge contaminated subprocess environments, so Claude Code's own behavioral control env vars like
`ENABLE_PROMPT_CACHING_1H` should be preserved.
When adding new hook scripts or wrappers, either explicitly `export ENABLE_PROMPT_CACHING_1H`
or avoid cutting env with `env -i bash`.

---

## 4. Wake-up count limit, locks, and idempotency guards

Long-running tasks can inadvertently run the same process twice.
Three layers of protection prevent this.

### 4-1. Count limit

Use `--max-cycles` to decide how many times to continue.
When the limit is reached, stop there.

### 4-2. Locks

Take a lock so the same task doesn't run twice simultaneously.
This repository uses `.claude/state/locks/loop-session.lock.d`.

The lock is a marker meaning "this is already running here."
If a lock already exists, a new execution stops.
This prevents conflicts from parallel execution.

### 4-3. Idempotency guard

Idempotency means an operation can run twice without breaking things.
By adding a lightweight check like `tests/validate-plugin.sh --quick` upfront, you avoid
forcing progress in a broken state.

Also, always clean up the lock at exit.
Whether it exits normally or abnormally, this ensures the remnant doesn't interfere with the next run.

---

## 5. Plateau detection and golden fixtures

A plateau is a state where work appears to be progressing but is actually going in circles.
For example: applying the same fix repeatedly, running more re-executions without gaining
more decision information.

### Thinking about thresholds

Actual judgment is based on the results of `scripts/detect-review-plateau.sh`.
The focus here is **whether new information is accumulating**, rather than "how many failures
before stopping."

### What to use as fixtures

Golden fixtures to prevent regressions belong in `tests/fixtures/`.
For example, an organized bundle like `tests/fixtures/long-running-harness/` makes them
easy to find. Especially for plateau-related cases, fixing these cases is useful:

1. Cases where the failure reason is the same every time
2. Cases where the judgment doesn't change even if conditions change
3. Cases that appear to be progressing but are actually stalled

Fixtures are examples of "this judgment should stay the same going forward."
With these in place, you can easily verify that stall detection hasn't broken when the logic is modified later.

---

## 6. Scope of Phase 41

Phase 41 covers **long-running tasks that complete within the same Claude Code session**.

The two things to accomplish:

1. Safe re-entry within the current session
2. Continuing the same work across wake-ups

What is not covered: automatic re-entry across separate hosts.
That is for future Phase 42+.

---

## 7. Known constraints

### Relationship with `bypassPermissions`

`/loop` does not increase permissions.
It operates under the assumption that existing permission guards are in place.
In other words, even if `bypassPermissions` is enabled, dangerous operations are not unlimited.

In long-running tasks, it is more important to "not do strong things on your own."
Perform only necessary operations, at the necessary timing, for the necessary number of times.

### Limitations of Plans.md flock

`Plans.md` can be touched by multiple execution entities.
It is designed with flock for sequential access, but this is **a mechanism to prevent simultaneous writes to the same file**, not a perfect solution.

In particular, if another session or process is reading simultaneously, the visible state may
be slightly delayed.
Therefore, when reading `Plans.md`, hold the premise that "the content currently visible may
not be the latest" and make judgments in combination with checkpoints and contracts.

---

## 8. Quick links

- Execution flow details: [skills/harness-loop/references/flow.md](../skills/harness-loop/references/flow.md)
- Command entry point: [skills/harness-loop/SKILL.md](../skills/harness-loop/SKILL.md)
- Claude Code feature list: [docs/CLAUDE-feature-table.md](CLAUDE-feature-table.md)

> **Note (v4.2.0+)**: `HARNESS_WEBHOOK_URL` is set as an environment variable. `[telemetry] webhook_url` in `harness.toml` is deprecated (dead config cleanup on 2026-04-18).
