---
name: breezing
description: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
description-en: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
kind: workflow
purpose: "Wrap harness-work with team execution orchestration"
trigger: "breezing, team execution, do everything"
shape: wrap
role: orchestrator
base: harness-work
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "WebSearch", "Monitor"]
argument-hint: "[all|N-M|--codex|--parallel N|--no-commit|--no-discuss|--auto-mode]"
user-invocable: true
---

# Breezing — Team Execution Mode

> **Backward-compatible alias**: Runs `harness-work` in team execution mode.

## Quick Reference

```bash
/breezing                       # Ask for scope, then execute
/breezing all                   # Run all tasks in Plans.md to completion
/breezing 3-6                   # Run tasks 3–6 to completion
/breezing --codex all           # Run all tasks to completion via Codex CLI
/breezing --parallel 2 all      # Run all tasks to completion with 2 workers in parallel
/breezing --no-discuss all      # Run all tasks to completion, skipping planning discussion
/breezing --auto-mode all       # Try Auto Mode rollout in a compatible parent session
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | Target all incomplete tasks | - |
| `N` or `N-M` | Specify task number / range | - |
| `--codex` | Delegate implementation to Codex CLI | false |
| `--parallel N` | Number of parallel Implementers | auto |
| `--no-commit` | Suppress automatic commit | false |
| `--no-discuss` | Skip planning discussion | false |
| `--auto-mode` | Explicitly use the Harness-side Auto Mode rollout. Separate from `--enable-auto-mode`, which became unnecessary in CC 2.1.111 | false |

> **CC 2.1.111 note**:
> With Opus 4.7, `/effort xhigh` can be used literally.
> The built-in `/ultrareview` should only be added upon explicit request and does not replace the default review.

> **Long-session recommendation (CC 2.1.108+)**:
> If a session is expected to exceed 30 minutes, opt in to 1-hour prompt caching after resolving
> the plugin bundle root by running `bash "${HARNESS_PLUGIN_ROOT}/scripts/enable-1h-cache.sh"`.
> This script appends `export ENABLE_PROMPT_CACHING_1H=1` to `env.local` (idempotent).
> With the default 5-minute TTL cache, cache misses accumulate in breezing sessions exceeding
> 1 hour, which can raise input token costs by up to 12×; opt in explicitly for long team runs.
> Codex CLI child processes (`scripts/codex-companion.sh task --write`, etc.) normally inherit
> `ENABLE_PROMPT_CACHING_1H` via env, but if `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` is active,
> a shell wrapper that explicitly maintains the export is needed. See
> [`docs/long-running-harness.md`](../../docs/long-running-harness.md) for details.

## Execution

**This skill delegates to `harness-work`.** Run `harness-work` with the following settings:

1. **Pass arguments as-is to `harness-work`**
2. **Force team execution mode** — three-way separation of Lead → Worker spawn → Reviewer spawn
3. **Lead focuses on delegation** — does not write code directly
4. **Auto Mode is opt-in** — `--auto-mode` is accepted as a rollout flag for compatible parent sessions
5. **Advisor only when needed** — Lead calls an advisor only when Worker returns `advisor-request.v1`

### Differences from `harness-work`

| Feature | `harness-work` | `breezing` (this skill) |
|---------|----------------|------------------------|
| Parallelism | Auto-split based on need | **Role separation: Lead / Worker / Reviewer** |
| Lead's role | Coordination + implementation | **delegate (coordination only)** |
| Review | Lead self-review | **Independent Reviewer** |
| Default scope | Next task | **All tasks** |

### Team Composition

| Role | Agent Type | Mode | Responsibility |
|------|-----------|------|---------------|
| Lead | (self) | - | Coordination, direction, task distribution |
| Worker ×N | `claude-code-harness:worker` | `bypassPermissions` (current) / Auto Mode (follow-up)* | Implementation |
| Advisor | `claude-code-harness:advisor` | Read-only | Policy advice (`PLAN` / `CORRECTION` / `STOP`) |
| Reviewer | `claude-code-harness:reviewer` | `bypassPermissions` (current) / Auto Mode (follow-up)* | Independent review |

> *If the parent session or frontmatter specifies `bypassPermissions`, that takes precedence. Distribution templates currently use `bypassPermissions`, so Auto Mode is a follow-up rollout target and is not the default behavior.

### Codex Mode (`--codex`)

Delegates all implementation to the Codex CLI via the official plugin `codex-plugin-cc`:

```bash
# Delegate task (with write access)
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "task content"

# Via stdin (for large prompts)
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# Write task content
cat "$CODEX_PROMPT" | bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write
rm -f "$CODEX_PROMPT"
```

## Flow Summary

```
breezing [scope] [--codex] [--parallel N] [--no-discuss] [--auto-mode]
    │
    ↓ Load harness-work with team mode
    │
Phase 0: Planning Discussion (skipped with --no-discuss)
Phase A: Pre-delegate (team initialization)
Phase B: Delegate (Worker implementation + Advisor when needed + Reviewer review)
Phase C: Post-delegate (integration validation + Plans.md update + commit)
```

## Advisor Protocol

Workers do not spawn generic subagents.
When uncertain, return a structured JSON consultation request only, and Lead calls the advisor.

1. Worker → `advisor-request.v1`
2. Lead → Advisor
3. Advisor → `advisor-response.v1`
4. Lead → returns advice to the same Worker to continue
5. Reviewer only looks at the final deliverable

Consultation conditions align with loop / solo mode.

- Before the first run of high-risk tasks (`needs-spike` / `security-sensitive` / `state-migration`)
- After the same root cause fails 2 consecutive times
- Just before returning `PIVOT_REQUIRED` due to a plateau
- Same `trigger_hash` only once; maximum 3 consultations per task

### Progress Feed (progress notifications during Phase B)

Lead outputs progress in the following format on each task completion by a Worker:

```
📊 Progress: Task {completed}/{total} done — "{task_subject}"
```

**Output examples**:
```
📊 Progress: Task 1/5 done — "Add failure re-ticketing to harness-work"
📊 Progress: Task 2/5 done — "Add --snapshot to harness-sync"
📊 Progress: Task 3/5 done — "Add progress feed to breezing"
```

> **Design intent**: Breezing often runs for a long time.
> This ensures that when the user glances at the terminal, they can immediately see how far things have progressed.
> The task-completed.sh hook outputs equivalent information via systemMessage, complementing Lead's output.

### Silence Policy (notification management for long runs)

In Codex `0.123.0` realtime handoff, background agents receive transcript deltas and can
explicitly go silent when not needed. Breezing's progress feed aligns with this premise and
focuses notifications on "milestones in the work."

Report:

- Task completion, blocked, validation failure, review `REQUEST_CHANGES`
- Advisor's `PLAN` / `CORRECTION` / `STOP`
- Reviewer's `APPROVE` / `REQUEST_CHANGES`
- Advisor / reviewer drift, plateau, contract readiness failure
- Summary when the user explicitly asks for status

Stay silent for:

- Receiving a transcript delta with no change in decision or status
- Fine-grained increments in tool stdout that are sufficient to remain in logs
- Parallel Worker waiting heartbeats

The basic frequency is once per task completion.
Rather than increasing heartbeats to create a sense of reassurance, separate responsibilities into status / log / drift detection.
However, do not silence unanswered Advisor requests, missing Reviewer results, or pre-plateau warnings.

### Monitor Tool Usage Guide (CC 2.1.98+)

When monitoring long-running commands, use the **Monitor tool** rather than polling
(periodically reading file tails with Read). Monitor delivers each stdout line from
a background process as a sequential notification to Lead, enabling lower latency and
lower token consumption than polling.

**Application examples**:
- Progress monitoring during `go test ./... -v`
- GitHub Actions progress tracking via `gh run watch`
- Immediate build error detection with `npm run build --watch` / `vite build --watch`
- Codex job completion detection via `codex-companion.sh status <job-id>`
- Deploy log tracking with `docker-compose logs -f` / `kubectl logs -f`

**Decision criteria**:

| Target | Use Monitor? | Reason |
|--------|-------------|--------|
| Completion monitoring for Agent (Worker / Reviewer) | Not needed | The Agent layer sends its own completion notification |
| Shell process launched with `run_in_background: true` | Recommended | Each stdout line can be captured as a sequential notification |
| Short one-shot command (single `go test` run) | Not needed | Normal Bash tool execution is sufficient |
| Long-running tail / watch / stream commands | Recommended | More efficient than polling |

**Typical pattern in Breezing Lead**:

```
Lead:
  Task(Worker1, ...)           ← Wait for Agent completion (Monitor not needed)
  Task(Worker2, ...)           ← Same
  Bash(run_in_background, "gh run watch --exit-status")
  Monitor(tailCommand="...")   ← Detect CI failure immediately → instruct Worker to fix
```

This enables Lead to speed up the "Worker completes → detect CI failure → instruct fix" reaction cycle.

### Review Policy (unified across all modes)

Even in Breezing mode, reviews follow the unified policy of **Codex exec first → internal Reviewer fallback**.
See the "Review loop" section of `harness-work` for details.

- Worker implements and commits within worktree → returns `worker-report.v1` (5 self_review items) to Lead
- **self_review gate (before Reviewer spawn)**: Lead mechanically verifies `self_review[].verified` and `evidence`. If even 1 item has `verified:false` or `evidence:""`, Lead automatically sends it back to Worker without spawning a Reviewer (maximum 2 times within the same session; escalate on the 3rd)
- Lead reviews via Codex exec (120s timeout, fallback: Reviewer agent)
- REQUEST_CHANGES → Lead instructs Worker to amend via SendMessage (up to `MAX_REVIEWS` times; `MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`)
- APPROVE → **Lead** cherry-picks to main → updates Plans.md to `cc:done [{hash}]`

### Completion Report (Phase C — generated by Lead)

After all tasks complete, **Lead** generates a rich completion report following these steps:

1. Collect all cherry-pick commits with `git log --oneline {base_ref}..HEAD`
2. Get overall change scale with `git diff --stat {base_ref}..HEAD`
3. Extract remaining `cc:TODO` / `cc:WIP` tasks from Plans.md
4. Output following the Breezing template in `harness-work`'s "Completion Report Format"

> **Generated by Lead**. Not by Worker or a hook. Lead reads git + Plans.md in Phase C to generate it.

### Phase 0: Planning Discussion (structured 3-question check)

Before executing all tasks, confirm plan health with the following 3 questions.
All are skipped when `--no-discuss` is specified.

**Q1. Scope confirmation**:
> "I will execute {{N}} tasks. Is the scope appropriate?"

If too many, propose narrowing by priority (Required > Recommended > Optional).

**Q2. Dependency confirmation** (only when Plans.md has a Depends column):
> "Task {{X}} depends on {{Y}}. Is the execution order correct?"

Read the Depends column and display the dependency chain. Error if a circular dependency is found.

**Q3. Risk flags** (only when there are `[needs-spike]` tasks):
> "Task {{Z}} is marked [needs-spike]. Would you like to spike it first?"

If there are incomplete `[needs-spike]` tasks, confirm whether to run the spike first.

When all 3 questions pass, proceed to Phase A (designed to complete in 30 seconds total).

### Universal Violations Injection (learning propagation between Workers in a session)

Automatically injects Reviewer universal gotchas accumulated within the same `/breezing` invocation
into the briefing header of the next Worker. **Valid within the same session only**
(discarded when the session ends; not written to `session-memory`).

```python
# Initialize Lead process in-memory array at Phase A start
universal_violations = []  # List[str] — accumulated within this session

# Just before spawning a Worker in Phase B, inject at the top of the briefing:
def build_worker_briefing(task, contract_path):
    header = ""
    if universal_violations:
        header = (
            "🚨 Universal violations already detected in this session (must not recur):\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )
    return header + f"Task: {task.content}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing"

# After Reviewer returns review-result.v1, Lead extracts scope="universal" only and accumulates:
for update in reviewer_result.memory_updates:
    # Backward compat: strings are treated as task-specific → ignore
    if isinstance(update, str):
        continue
    if update.get("scope") == "universal":
        universal_violations.append(update["text"])
```

**Policy**: To avoid over-engineering, do not persist to `session-memory` or `decisions.md`.
Keep only in the Lead process's in-memory array, discarded when the `/breezing` session ends
(per the policy in issue #87).

### Dependency-graph-based task assignment

When Plans.md has a Depends column (v2 format), execute tasks following the dependency graph:

1. **Execute tasks with Depends `-` first.** Multiple independent tasks can be spawned in parallel.
2. After each Worker completes, Lead reviews → cherry-picks (see harness-work Phase B).
3. Once a depended-on task is cherry-picked to main, execute the tasks that depended on it next.
4. Repeat until all tasks are complete.

> **Note**: "Worker completes → review → cherry-pick" for each task is sequential.
> Parallelization is only possible for the Worker spawn portion of independent tasks (Depends is `-`).

## Codex Native Orchestration

In Codex, use native subagents.
Representative control surfaces are `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`.

> **Claude Code vs Codex communication API** (SSOT: API mapping table in `team-composition.md`):
> - Claude Code: instruct Worker to amend via `SendMessage(to: agentId, message: "...")`
> - Codex: resume Worker with `resume_agent(agent_id)` → send instruction with `send_input(agent_id, "...")`
>
> Pseudocode in harness-work is written in Claude Code syntax. Translate to the above for Codex environments.

## Related Skills

- `harness-work` — From single tasks to team execution (core)
- `harness-sync` — Progress sync
- `harness-review` — Code review (auto-triggered within breezing)
