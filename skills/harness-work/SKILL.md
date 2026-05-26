---
name: harness-work
description: "HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel. Do NOT load for: planning, review, release, setup."
description-en: "HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel. Do NOT load for: planning, review, release, setup."
kind: workflow
purpose: "Execute Plans.md tasks end to end"
trigger: "implement, execute, do everything, breezing, team run, parallel"
shape: workflow
role: executor
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "Monitor"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--resume id] [--breezing] [--auto-mode] [--tdd-bypass]"
user-invocable: true
effort: high
---

# Harness Work

The integrated execution skill for Harness.
Consolidates the following legacy skills:

- `work` — Implement Plans.md tasks (auto-detected scope)
- `impl` — Feature implementation (task-based)
- `breezing` — Full automated team run
- `parallel-workflows` — Parallel workflow optimization
- `ci` — Recovery from CI failures

## Quick Reference

| User input | Mode | Behavior |
|------------|------|----------|
| `/harness-work` | **auto** | auto-detected based on task count (see below) |
| `/harness-work all` | **auto** | Run all incomplete tasks in auto mode |
| `/harness-work 3` | solo | Execute only task 3 immediately |
| `/harness-work --parallel 5` | parallel | Parallel execution with 5 workers (forced) |
| `/harness-work --codex` | codex | Delegate to Codex CLI (explicit only) |
| `/harness-work --breezing` | breezing | Force team execution |
| `/harness-work 3 --plan roadmap` | solo | Execute task 3 from the named plan `roadmap` |

## Execution Mode Auto Selection (auto-detection when no flags given)

When no explicit mode flags (`--parallel`, `--breezing`, `--codex`) are provided,
the optimal mode is auto-selected based on the number of target tasks:

| Target task count | Auto-selected mode | Reason |
|-------------------|--------------------|--------|
| **1** | Solo | Minimum overhead. Direct implementation is fastest |
| **2–3** | Parallel (Task tool) | Threshold where Worker isolation starts to benefit |
| **4+** | Breezing | Three-way separation of Lead coordination + Worker parallel + independent Reviewer is effective |

### Rules

1. **Explicit flags always override auto mode**
   - `--parallel N` → Parallel mode (regardless of task count)
   - `--breezing` → Breezing mode (regardless of task count)
   - `--codex` → Codex mode (regardless of task count)
2. **`--codex` is activated only when explicitly specified**. Not auto-selected because Codex CLI may not be installed in all environments
3. `--codex` can be combined with other modes: `--codex --breezing` → Codex + Breezing

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | Target all incomplete tasks | - |
| `N` or `N-M` | Task number / range | - |
| `--parallel N` | Number of parallel workers | auto |
| `--sequential` | Force sequential execution | - |
| `--codex` | Delegate implementation to Codex CLI (explicit only, not auto-selected) | false |
| `--plan NAME` | Use a named plan from `plans/manifest.json` | active/default |
| `--no-commit` | Suppress automatic commit | false |
| `--resume <id\|latest>` | Resume previous session. For long gaps, use with `/recap` | - |
| `--breezing` | Team execution with Lead/Worker/Reviewer | false |
| `--no-tdd` | Skip TDD phase | false |
| `--tdd-bypass` | Bypass forced TDD in emergencies only. Leave `HARNESS_TDD_BYPASS_REASON` or an explicit reason in the audit | false |
| `--no-simplify` | Skip Auto-Refinement | false |
| `--auto-mode` | Explicitly enables Harness-side Auto Mode rollout. Separate from `--enable-auto-mode` which became unnecessary in CC 2.1.111 | false |

## Progressive Disclosure

First check this main body for the entry point, auto-selection, and stop conditions only.
Read details only when needed.

| Detail | Reference |
|--------|-----------|
| Concrete steps for Solo / Parallel / Codex / Breezing | `references/execution-modes.md` |
| Codex review, Reviewer fallback, AI Residuals, Fix loop | `references/review-loop.md` |
| Generating Solo / Breezing completion reports | `references/completion-report.md` |
| Re-ticketing on test/CI failure | `references/failure-reticketing.md` |
| Criteria for spec source-of-truth check | `docs/plans/spec-ssot.md` |

### Critical Stop Conditions

- Stop when `Plans.md` is in the old format and DoD / Depends / Status cannot be read.
- If a spec affects implementation decisions but no project spec SSOT is found, create/update the spec first before implementing.
- Do not proceed to implementation when sprint-contract is required but not ready.
- Do not mark as complete while critical / major review findings remain.
- Do not resolve by weakening tests, skipping them, or relaxing expectations to match the implementation.
- Call helper scripts from `${HARNESS_PLUGIN_ROOT}/scripts/`, not from the host project's `scripts/`.
- When multiple Plans.md files exist, do not switch plans within a single run. Start a new run with `--plan NAME` if needed.

> **Token Optimization (v2.1.69+)**: For lightweight tasks that do not involve git operations,
> enable `includeGitInstructions: false` in plugin settings to reduce prompt tokens.

> **Prompt Cache (CC 2.1.108+)**: For longer implementations or workflows that heavily use `--resume`,
> prefer `ENABLE_PROMPT_CACHING_1H=1`.

## Scope Dialog (when no arguments given)

```
/harness-work
How far do you want to go?
1) Next task: the next incomplete task in Plans.md → execute in Solo mode
2) All (recommended): complete all remaining tasks → auto mode selection based on task count
3) Specify number: enter a task number (e.g. 3, 5-7) → auto mode selection based on count
```

If arguments are provided, execute immediately (skip dialog):
- `/harness-work all` → all tasks, auto mode selection
- `/harness-work 3-6` → 4 tasks, so Breezing is auto-selected

## Effort Level Control (v2.1.68+, v2.1.72, v2.1.111)

In Claude Code v2.1.68, Opus 4.6 defaults to **medium effort** (`◐`).
In v2.1.72, the `max` level was removed and simplified to 3 levels: `low(○)/medium(◐)/high(●)`.
Use `/effort auto` to reset to the default.
For complex tasks, activate high effort (`●`) with the `ultrathink` keyword.
In CC 2.1.111, `xhigh` was added for Opus 4.7.
You may literally prepend `/effort xhigh` if needed.

### Multi-factor Scoring

At task start, sum the following scores and inject ultrathink when the **threshold is 3 or above**:

| Factor | Condition | Score |
|--------|-----------|-------|
| File count | 4 or more files to change | +1 |
| Directory | Includes core/, guardrails/, security/ | +1 |
| Keyword | Includes architecture, security, design, migration | +1 |
| Failure history | Agent memory has a failure record for the same task | +2 |
| Explicit specification | PM template contains ultrathink | +3 (auto-adopted) |

### Injection Method

When score ≥ 3, prepend `ultrathink` to the Worker spawn prompt.
The same logic applies in Breezing mode (managed centrally by harness-work).

## Execution Mode Details

### Harness helper script root

Harness-bundled helper scripts must always be called from the plugin bundle root, not from the target project's `scripts/`.

```bash
HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$HARNESS_PLUGIN_ROOT" ] && [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
  HARNESS_PLUGIN_ROOT="$(cd "${CLAUDE_SKILL_DIR}/../.." && pwd)"
fi
```

All subsequent `node "${HARNESS_PLUGIN_ROOT}/scripts/..."` / `bash "${HARNESS_PLUGIN_ROOT}/scripts/..."` calls assume this resolved root.

### Solo Mode (auto-selected for 1 task)

1. Load Plans.md and identify the target task
   - **If Plans.md does not exist**: auto-call `harness-plan create --ci` → generate Plans.md and continue
   - If the header lacks DoD / Depends columns: display `Plans.md is in old format. Please regenerate with harness-plan create.` → **stop**
   - **If there are tasks mentioned in the conversation but not in Plans.md**: extract requirements from the preceding conversation context and auto-append to Plans.md as `cc:TODO`
     - Extraction logic: detect action verbs from user messages ("add ~", "fix ~", "implement ~")
     - Appended entries follow v2 format (Task / Content / DoD / Depends / Status)
     - After appending, display "Appended the following to Plans.md" to the user (5-second timeout prompt, default: continue)
1.5. **Task background confirmation** (30 seconds):
   - Infer and display the **purpose** (the problem this task solves) in one line from the task "content" and "DoD"
   - Infer and display the **impact scope** (files/modules affected) using `git grep` / `Glob`
   - If confident in the inference: proceed to implementation without delay
   - If not confident: ask the user one question only ("Is this understanding correct?")
1.6. **Spec SSOT preflight**:
   - Search for an existing project spec SSOT (e.g. `docs/spec/00-project-spec.md`, `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `docs/oem/PROJECT_COMPASS.md`, `docs/specs/`)
   - If the task changes product behavior / API / data model / permission / billing / integration / tenant boundary and no spec exists, create `docs/spec/00-project-spec.md`
   - If the spec is outdated or contradicts the task, update the spec before implementing
   - For typo / format / dependency bump / docs-only / no-behavior-change refactor: leave a skip reason and continue
   - Include `spec_path` or `spec_skip_reason` in the context passed to Worker / Reviewer
2. Update task to `cc:WIP`
3. **TDD phase** (when no `[skip:tdd]` and a test framework exists):
   a. Create the test file first (Red)
   b. Confirm the test fails
   c. Run `bash "${HARNESS_PLUGIN_ROOT}/scripts/log-tdd-red.sh"` to leave a FAIL record in `.claude/state/tdd-red-log/<task-id>.jsonl`. In environments where the script is unavailable, attach the literal failing test output to the `self_review` evidence in the worker-report
   d. When using `--tdd-bypass`, explicitly set `HARNESS_TDD_BYPASS=1` and `HARNESS_TDD_BYPASS_REASON="<reason>"`, and leave the reason for skipping TDD in the sprint-contract / worker-report
4. Generate `sprint-contract.json` with `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" <task-id>`
5. Add Reviewer perspective with `bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh"` and confirm approved with `bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh"`
6. **Advisor consult (only when needed)**:
   - For high-risk tasks (`needs-spike` / `security-sensitive` / `state-migration`), consult once before the first execution
   - If the same failure cause recurs twice in a row, consult before the 3rd attempt
   - When the plateau detector (stall detection) returns `PIVOT_REQUIRED`, consult once before escalating to the user
   - Receive the consultation result as `advisor-response.v1`: treat `PLAN` as a workflow restructure, `CORRECTION` as a local fix, `STOP` as immediate escalation
   - Consult only once per `trigger_hash`. Maximum 3 consultations per task
7. Implement the code (Green) (Read/Write/Edit/Bash)
8. Auto-Refinement with `/simplify` (can be skipped with `--no-simplify`)
9. **Automatic review stage** (see "Review loop"):
   - Run review preferring Codex exec → fallback to internal Reviewer agent
   - If `sprint-contract.json` `reviewer_profile` is `runtime`, run `bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh"`
   - On REQUEST_CHANGES: fix based on findings → re-review (`MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`)
   - Proceed to the next step on APPROVE. Do not finalize completion based on self-check alone
10. Normalize and save the review artifact with `bash "${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh"` (pass `--browser-result` for browser profile; adopt static verdict when `browser_verdict == PENDING_BROWSER`)
11. Auto-commit with `git commit` (can be skipped with `--no-commit`)
12. Update task to `cc:done` (with commit hash)
   - Get the most recent commit hash (7-character short form) with `git log --oneline -1`
   - Update Plans.md Status to `cc:done [a1b2c3d]` format
   - When there is no commit (`--no-commit`), use `cc:done` without a hash
13. **Rich completion report** (see "Completion report format")
14. **Auto re-ticketing on failure** (only when test/CI fails):
    - Check test execution results
    - On failure: save the proposed fix task to state and add to Plans.md after approval (see "Auto re-ticketing of failed tasks")
    - On success: proceed to the next task

### Parallel Mode (auto-selected for 2–3 tasks / forced with `--parallel N`)

Run tasks marked `[P]` in parallel with N workers.
When `--parallel N` is explicitly specified, this mode is used regardless of task count.
When writes to the same file would conflict, isolate using git worktree.

### Codex Mode (only when `--codex` is explicitly specified)

Delegate tasks to Codex CLI via the companion of the official plugin `codex-plugin-cc`.

```bash
# Task delegation (writable)
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "Task content"

# Via stdin (for large prompts)
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# Write task content
cat "$CODEX_PROMPT" | bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write
rm -f "$CODEX_PROMPT"

# Resume a previous thread
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --resume-last --write "Continue from where we left off"
```

The companion communicates with Codex via App Server Protocol,
providing job management, thread resume, and structured output.
Verify results and self-correct if quality standards are not met.

### Breezing Mode (auto-selected for 4+ tasks / forced with `--breezing`)

Execute as a team with separated roles: Lead / Worker / Advisor / Reviewer.
In Codex, native subagent orchestration using `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`
is assumed; the old TeamCreate / TaskCreate-based approach is not used.

**Permission policy**:
- The current shipped default is `bypassPermissions`
- `--auto-mode` is treated as an opt-in rollout flag for compatible parent sessions
- Do not write undocumented `autoMode` values in `permissions.defaultMode` or agent frontmatter `permissionMode`

> **CC v2.1.69+**: Because the platform prohibits nested teammates,
> do not add redundant nested-prevention language to Worker/Reviewer prompts.

```
Lead (this agent)
├── Worker (task-worker agent) — responsible for implementation
├── Advisor (claude-code-harness:advisor) — policy advice
└── Reviewer (code-reviewer agent) — responsible for review
```

**Phase A: Pre-delegate (preparation)**:
1. Load Plans.md and identify target tasks
2. Analyze the dependency graph and determine execution order (Depends column)
3. Effort scoring for each task (ultrathink injection decision)
4. Generate `sprint-contract.json` with `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js"`
5. Add Reviewer perspective with `bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh"` and stop if not approved with `bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh"`

**Phase B: Delegate (Worker spawn → Advisor when needed → review → cherry-pick)**:

Execute the following **sequentially** for each task (in dependency order):

> **API note**: The following is written in Claude Code API syntax.
> In Codex environments, replace `Agent(...)` → `spawn_agent(...)`, `SendMessage(...)` → `send_input(...)`.
> See the API mapping table in `team-composition.md` for details.

```
for task in execution_order:
    # B-1. Generate sprint-contract
    contract_path = bash("node \"${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js\" {task.number}")
    contract_path = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh\" {contract_path} --check \"Verify DoD from reviewer perspective\" --approve")
    bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh\" {contract_path}")

    # B-2. Spawn Worker (foreground, worktree isolation)
    # The Agent tool return value contains agentId — used with SendMessage in the fix loop
    Plans.md: task.status = "cc:WIP"  # Update at start (tasks not yet started remain cc:TODO)

    # Also propagate universal violations when running /harness-work sequentially
    # (assume universal_violations = [] is initialized on first run)
    briefing_header = ""
    if universal_violations:
        briefing_header = (
            "🚨 Universal violations already detected in this session (must not recur):\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )

    worker_result = Agent(
        subagent_type="claude-code-harness:worker",
        prompt=briefing_header + "Task: {task.content}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing",
        isolation="worktree",
        run_in_background=false  # Run in foreground → wait for Worker to complete
    )
    worker_id = worker_result.agentId  # Retain for SendMessage
    # worker_result contains {commit, worktreePath, files_changed, summary}

    # B-3. Lead calls Advisor only when Worker returns an advice request
    if worker_result.type == "advisor-request.v1":
        advisor_result = Advisor(
            prompt=worker_result.request_json
        )
        worker_result = SendMessage(
            to=worker_id,
            message="advisor-response.v1: {advisor_result}"
        )

    # B-3.5. self_review gate (Lead mechanically verifies before spawning Reviewer)
    # Worker's worker-report.v1 must have all active self_review rules with verified=true and non-empty evidence
    # When tdd.enforce.enabled=true and tdd_required=true, `tdd-red-evidence-attached` is also required as an active rule
    # If even one entry has verified=false or evidence=="" , send back to Worker without spawning Reviewer
    self_review_failures = 0
    MAX_SELF_REVIEW_RETRIES = 2  # Lead escalates on 3rd attempt (retries=2)
    while True:
        unverified = [
            r for r in worker_result.self_review
            if (not r.get("verified")) or (not r.get("evidence"))
        ]
        if not unverified:
            break  # All rules verified → proceed to B-4 (actual review)
        self_review_failures += 1
        if self_review_failures > MAX_SELF_REVIEW_RETRIES:
            # Still unconfirmed items after 3rd attempt → escalate to Lead
            Plans.md: task.status = "cc:TODO"  # Revert to pre-start state
            raise EscalationError(f"self_review still unconfirmed after 3 send-backs (rules: {[u['rule'] for u in unverified]})")
        # Send back to Worker (do not spawn Reviewer)
        SendMessage(
            to=worker_id,
            message=f"self_review has unconfirmed rules: {[u['rule'] for u in unverified]}. Fill in evidence for each rule with actual command output or literal test results; when TDD is required, attach .claude/state/tdd-red-log/<task-id>.jsonl or literal failing test output and set verified=true, then amend"
        )
        worker_result = wait_for_response(worker_id)

    # B-4. Lead runs review (Codex exec preferred)
    diff_text = git("-C", worker_result.worktreePath, "show", worker_result.commit)
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
    profile = jq(contract_path, ".review.reviewer_profile")
    review_input = "review-output.json"
    if profile == "runtime":
        review_input = bash("cd {worker_result.worktreePath} && bash \"${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh\" {contract_path}")
        runtime_verdict = jq(review_input, ".verdict")
        if runtime_verdict == "REQUEST_CHANGES":
            verdict = "REQUEST_CHANGES"
        elif runtime_verdict == "DOWNGRADE_TO_STATIC":
            pass  # No runtime validation command → use static verdict as-is
    browser_result = ""
    if profile == "browser":
        # Reuse route / browser_mode / execution_instructions from the browser artifact to launch the browser runner
        browser_artifact = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/generate-browser-review-artifact.sh\" {contract_path}")
        browser_result = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/browser-review-runner.sh\" {browser_artifact}")
        browser_verdict = jq(browser_result, ".browser_verdict")
        if browser_verdict == "REQUEST_CHANGES":
            verdict = "REQUEST_CHANGES"
        elif browser_verdict == "APPROVE" and verdict != "REQUEST_CHANGES":
            verdict = "APPROVE"
        # When browser_verdict == PENDING_BROWSER, keep the static verdict
    # When review_input is DOWNGRADE_TO_STATIC, use the static review result
    if review_input != "review-output.json" and jq(review_input, ".verdict") == "DOWNGRADE_TO_STATIC":
        review_input = "review-output.json"  # Fall back to static review result
    bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh\" {review_input} {latest_commit} --browser-result {browser_result}")

    # B-5. Fix loop (on REQUEST_CHANGES, up to contract's max_iterations)
    # Worker has completed in the foreground but can be resumed via SendMessage
    # (CC: SendMessage(to: agentId) / Codex: resume_agent(agent_id) + send_input)
    review_count = 0
    # Read max_iterations from sprint-contract only when it exists. Default is 3 (backward compatible)
    MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
    latest_commit = worker_result.commit
    while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
        SendMessage(to=worker_id, message="Review findings: {issues}\nPlease fix and amend")
        # Worker fixes → amends → returns the updated commit hash
        updated_result = wait_for_response(worker_id)
        latest_commit = updated_result.commit
        diff_text = git("-C", worker_result.worktreePath, "show", latest_commit)
        verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
        review_count++

    # B-6. APPROVE → cherry-pick to trunk (via feature branch)
    # Worker's Branch Guard keeps trunk HEAD unchanged; commit is expected to be on the feature branch
    if verdict == "APPROVE":
        TRUNK=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
        git checkout "$TRUNK"  # safety: no-op if already on trunk
        # Check if the feature branch commit is already on trunk (fallback for Branch Guard failure)
        if git("merge-base", "--is-ancestor", latest_commit, "HEAD"):
            pass  # Already on trunk — cherry-pick not needed (re-entry prevention)
        else:
            git cherry-pick --no-commit {latest_commit}  # feature branch → trunk
            git commit -m "{task.content}"
        # Remove worktree then delete feature branch
        if worker_result.worktreePath:
            git worktree remove {worker_result.worktreePath} --force
        if worker_result.branch and worker_result.branch not in ["main", "master"] and worker_result.branch != TRUNK:
            git branch -D {worker_result.branch}
        Plans.md: task.status = "cc:done [{hash}]"
        # Record auto-checkpoint (idempotency guard (c))
        # Call immediately after rewriting Plans.md. Fail-open (|| true) so it doesn't stop the loop
        HASH=$(git rev-parse --short HEAD)
        REVIEW_RESULT_PATH=".claude/state/review-results/${task.number}.review-result.json"
        bash "${HARNESS_PLUGIN_ROOT}/scripts/auto-checkpoint.sh" \
            "${task.number}" "${HASH}" "${contract_path}" "${REVIEW_RESULT_PATH}" \
            || true  # fail-open: continue even in environments without harness-mem running
    else:
        → escalate to user

    # B-7. Progress feed
    print("📊 Progress: Task {completed}/{total} done — {task.content}")
```

### Advisor Protocol (common to all modes)

The Advisor is neither an "implementer" nor a "reviewer".
It acts as a consultant to help the executor decide the next step, only when stuck.

1. Workers do not spawn generic subagents; return `advisor-request.v1` only when needed
2. Lead calls the advisor exactly once
3. Advisor returns one of `PLAN` / `CORRECTION` / `STOP`
4. Lead sends that advice back to the same Worker to continue
5. Reviewer only sees the final artifact. Does not issue APPROVE / REQUEST_CHANGES on the advisor's response

### Advisor in Solo Mode

In solo execution, the parent session itself acts as Lead.
This means "implement yourself, consult the advisor yourself, then hand off to an independent review at the end."

- Consultation conditions are the same as in loop / breezing
- Consultation budget is also the same: maximum 3 times per task
- `STOP` stops immediately and escalates to the user
- The review artifact gate is not skipped

### Sprint Contract

A `sprint-contract` is a small contract file that makes "what counts as passing this task" readable by both machines and humans with the same meaning.
The default save location is `.claude/state/contracts/<task-id>.sprint-contract.json`.

```bash
node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" 32.1.1
```

The generated artifact includes:

- `checks`: confirmation items decomposed from the DoD
- `non_goals`: what is out of scope for this task
- `runtime_validation`: validation commands such as test, lint, typecheck
- `browser_validation`: UI flow validation items the browser reviewer should cover
- `browser_mode`: `scripted` or `exploratory`
- `route`: which of `playwright` / `agent-browser` / `chrome-devtools` the browser reviewer uses
- `risk_flags`: `needs-spike`, `security-sensitive`, `ux-regression`, etc.
- `reviewer_profile`: `static`, `runtime`, or `browser`

**Phase C: Post-delegate (integration and reporting)**:
1. Aggregate commit logs from all tasks
2. Output the **rich completion report** (Breezing template from "Completion report format")
3. Final check of Plans.md (confirm all tasks are marked cc:done)

## Handling CI Failures

When CI fails:

1. Check the logs and identify the error
2. Apply the fix
3. Stop the automatic fix loop after 3 consecutive failures for the same root cause
4. Escalate with a summary of failure logs, attempted fixes, and remaining open points

## Auto Re-ticketing of Failed Tasks

When test/CI fails after task completion, automatically generate a proposed fix task and apply it to Plans.md after approval:

### Trigger Conditions

| Condition | Action |
|-----------|--------|
| Test failure after `cc:done` | Save proposed fix task to state and wait for approval |
| CI failure (fewer than 3 times) | Apply fix and increment failure count |
| CI failure (3rd time) | Present proposed fix task + escalate |

### Auto-generation of Fix Tasks

1. Classify the failure cause (syntax_error / import_error / type_error / assertion_error / timeout / runtime_error)
2. Save the proposed fix task to `.claude/state/pending-fix-proposals.jsonl`:
   - Number: original task number + `.fix` suffix (e.g. `26.1.fix`)
   - Content: `fix: [original task name] - [failure cause category]`
   - DoD: tests/CI must pass
   - Depends: original task number
3. When the user sends `approve fix <task_id>`, add it to Plans.md as `cc:TODO`
4. Use `reject fix <task_id>` to discard the proposal. When there is only one pending item, `yes` / `no` also work

## Review Loop

The quality verification stage that runs automatically after implementation is complete (after step 5).
Applied uniformly across **all modes** (Solo / Parallel / Breezing).
In Parallel mode, each Worker runs the same loop as step 10 (external review acceptance).

### Review Execution Priority

```
1. Codex exec (preferred)
   ↓ codex command not found or timeout (120s)
2. Internal Reviewer agent (fallback)
```

### APPROVE / REQUEST_CHANGES Criteria

Pass the following threshold criteria to the reviewer and have them determine the verdict **based solely on these criteria**.
Improvement suggestions outside the criteria are returned as `recommendations` but do not affect the verdict.

| Severity | Definition | Effect on verdict |
|----------|------------|-------------------|
| **critical** | Security vulnerability, data loss risk, potential production outage | 1 or more → REQUEST_CHANGES |
| **major** | Breaking existing functionality, clear contradiction with spec, failing tests | 1 or more → REQUEST_CHANGES |
| **minor** | Naming improvement, missing comments, style inconsistency | No effect on verdict |
| **recommendation** | Best practice suggestion, future improvement idea | No effect on verdict |

> **Important**: When there are only minor / recommendation findings, **always return APPROVE**.
> "Nice-to-have improvements" are not a reason for REQUEST_CHANGES.

### Codex exec Review (via official plugin)

Retain the HEAD at task start as `BASE_REF` and use the diff against that ref as the review target.
Use the companion review of the official plugin `codex-plugin-cc`.

```bash
# Record base ref at task start (run before the cc:WIP update in Step 2)
BASE_REF=$(git rev-parse HEAD)

# ... after implementation is complete ...

# Run the structured review via the official plugin
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" review --base "${BASE_REF}"
REVIEW_EXIT=$?
```

**Verdict mapping** (official plugin → Harness format):

The official plugin returns structured output conforming to `review-output.schema.json`.
Conversion rules to Harness verdict format:

| Official plugin | Harness | Verdict effect |
|-----------------|---------|----------------|
| `approve` | `APPROVE` | - |
| `needs-attention` | `REQUEST_CHANGES` | - |
| `findings[].severity: critical` | `critical_issues[]` | 1 or more → REQUEST_CHANGES |
| `findings[].severity: high` | `major_issues[]` | 1 or more → REQUEST_CHANGES |
| `findings[].severity: medium/low` | `recommendations[]` | No effect on verdict |

The AI Residuals scan continues to run with `bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh"`,
and the final verdict is determined in combination with the companion review result.

```bash
# AI Residuals scan (can run in parallel with companion review)
AI_RESIDUALS_JSON="$(bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh" --base-ref "${BASE_REF}" --include-untracked 2>/dev/null || echo '{"tool":"review-ai-residuals","scan_mode":"diff","base_ref":null,"include_untracked":true,"files_scanned":[],"untracked_files_scanned":[],"summary":{"verdict":"APPROVE","major":0,"minor":0,"recommendation":0,"total":0},"observations":[]}')"
```

### Internal Reviewer Agent Fallback

When Codex exec is unavailable (`command -v codex` fails, or exit code ≠ 0):

```
Agent tool: subagent_type="reviewer"
prompt: "Please review the following changes. Criteria: critical/major → REQUEST_CHANGES, minor/recommendation only → APPROVE. diff: {git diff ${BASE_REF}}"
```

The Reviewer agent runs a safe review in Read-only mode (Write/Edit/Bash disabled).

### Fix Loop (on REQUEST_CHANGES)

```
review_count = 0
# Read max_iterations from sprint-contract only when it exists. Default is 3 (backward compatible)
contract_path = get_sprint_contract_path()  # e.g. .claude/state/contracts/<task-id>.sprint-contract.json
MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. Parse review findings (target critical / major only)
    2. Implement fixes for each finding
    3. Run review again (same criteria, same priority)
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    → escalate to user
    → display "Fixed MAX_REVIEWS times but the following critical/major findings remain:" + list of findings
    → wait for user decision (continue / abort)
```

### Application in Breezing Mode

In Breezing mode, **Lead** runs the review loop (see Phase B above):

1. Worker implements and commits in the worktree → returns result to Lead
2. Lead reviews with Codex exec (preferred) / Reviewer agent (fallback)
3. REQUEST_CHANGES → Lead sends fix instructions to Worker via SendMessage → Worker amends
4. After fixing, re-review (up to `MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3` times)
5. APPROVE → Lead cherry-picks to trunk (default branch) → updates Plans.md to `cc:done [{hash}]`

## Completion Report Format

A visual summary automatically output when a task is complete (`cc:done` + after commit).
Intended to communicate the changes and their impact even to non-engineers.

### Template

```
┌─────────────────────────────────────────────┐
│  ✓ Task {N} done: {Task name}               │
├─────────────────────────────────────────────┤
│                                              │
│  ■ What was done                             │
│    • {Change 1}                              │
│    • {Change 2}                              │
│                                              │
│  ■ What changes                              │
│    Before: {old behavior}                    │
│    After:  {new behavior}                    │
│                                              │
│  ■ Changed files ({N} files)                 │
│    {file path 1}                             │
│    {file path 2}                             │
│                                              │
│  ■ Remaining issues                          │
│    • Task {X} ({status}): {content} ← Plans.md │
│    • Task {Y} ({status}): {content} ← Plans.md │
│    ({M} incomplete tasks remain in Plans.md) │
│                                              │
│  commit: {hash} | review: {APPROVE}          │
└─────────────────────────────────────────────┘
```

### Generation Rules

1. **What was done**: Auto-extracted from `git diff --stat HEAD~1` and the commit message. Minimize technical jargon and start with a verb
2. **What changes**: Infer Before/After from the task "content" and "DoD". Emphasize changes in user experience
3. **Changed files**: Retrieved from `git diff --name-only HEAD~1`. Abbreviate to count when more than 5 files
4. **Remaining issues**: List `cc:TODO` / `cc:WIP` tasks from Plans.md. Explicitly indicate whether they are recorded in Plans.md
5. **review**: Display the review result (APPROVE / REQUEST_CHANGES → APPROVE)

### Reporting in Parallel Mode

- **1 task** (when `--parallel` is forced): Use the Solo template
- **Multiple tasks**: Use the Breezing aggregated template (see below)

### Reporting in Breezing Mode

Output all at once after all tasks are complete. List each task in abbreviated form (what was done + commit hash only),
then output an overall summary (total changed files + remaining issues) at the end:

```
┌─────────────────────────────────────────────┐
│  ✓ Breezing done: {N}/{M} tasks             │
├─────────────────────────────────────────────┤
│                                              │
│  1. ✓ {Task name 1}            [{hash1}]    │
│  2. ✓ {Task name 2}            [{hash2}]    │
│  3. ✓ {Task name 3}            [{hash3}]    │
│                                              │
│  ■ Overall changes                           │
│    {N} files changed, {A} insertions(+),    │
│    {D} deletions(-)                          │
│                                              │
│  ■ Remaining issues                          │
│    {K} incomplete tasks remain in Plans.md  │
│    • Task {X}: {content}                    │
│                                              │
└─────────────────────────────────────────────┘
```

## Related Skills

- `harness-plan` — Plan the tasks to execute
- `harness-sync` — Sync implementation with Plans.md
- `harness-review` — Review the implementation
- `harness-release` — Version bump and release
