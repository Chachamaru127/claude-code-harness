# Execution Modes

`harness-work` chooses the lightest execution mode that still preserves review
and validation.

## Shared Preflight

1. Read `Plans.md` and identify the selected task set.
2. Stop if the task table lacks `Task`, `DoD`, `Depends`, or `Status`.
3. Check whether a project spec SSOT exists when product behavior can drift.
   Prefer existing project-level docs, then `docs/spec/00-project-spec.md`.
4. If the task changes product behavior, API, data model, permissions, billing,
   integrations, or tenant boundaries and no stable spec exists, create or
   update the spec before implementation.
5. Skip spec creation only for mechanical work such as typo, formatting,
   dependency bump, docs-only, or behavior-preserving refactor tasks. Record
   the skip reason in the task context or sprint contract.
6. Resolve helper scripts through `HARNESS_PLUGIN_ROOT`, not the caller
   project's `scripts/` directory.
7. Mark only the selected task as `cc:WIP`.
8. Generate and approve a sprint contract before implementation when the task
   needs reviewable DoD checks.

## Solo

Use for one task. The parent session implements directly, validates, runs the
review loop, commits unless `--no-commit` is set, and marks `Plans.md`
`cc:完了 [hash]`.

## Parallel

Use for two or three independent tasks, or when `--parallel N` is explicit.
Workers may use isolated worktrees when file ownership can conflict. The Lead
still owns final integration and status updates.

## Codex

Use only when `--codex` is explicit. Delegate implementation to the Codex
companion entrypoint:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "task"
```

Validate the result locally. Codex output is not accepted until the normal
review loop approves it.

## Breezing

Use for four or more tasks, or when `--breezing` is explicit. Lead coordinates
Workers, Advisor, and Reviewer while preserving the implementation/review
boundary.

Codex-native Breezing reads this flow through `spawn_agent`, `send_input`,
`wait_agent`, and `close_agent` rather than Claude Code `Agent` /
`SendMessage` pseudo-code.

## Lane and Stage Contract

Sprint contract generation passes `spec_path`, `lane`, `stage`, and evidence
fields to Worker / Reviewer. See `skills/harness-work/SKILL.md`「Sprint
Contract」for the full field list.

### Stage gate (5 stages)

| stage | 目的 |
|-------|------|
| `research` | 現状調査・evidence 収集。未取得データは `unknown` と報告 |
| `plan` | scope / DoD / lane を Plans に freeze |
| `impl` | TDD Red→Green 実装。`[tdd:required]` は `tdd_red_log` 必須 |
| `review` | `review_artifact`（`APPROVE` / `REQUEST_CHANGES`）を contract に載せる |
| `closeout` | `pr_closeout`（`base_ref` / `head_ref` / evidence pack）を載せる |

### Lane: what to lighten vs what to keep

| lane | 軽くする項目 | 省けない項目 |
|------|-------------|-------------|
| `fast` | full review（major-only または advisory で可）、PR body の詳細、release preflight | `spec_path`、unknown data contract（`not_observed != absent`）、focused checks（`runtime_validation` / `checks`）、`tdd_red_log` または `skip_tdd_reason`（`[tdd:required]` 時） |
| `gate` | —（軽量化なし） | spec alignment、TDD when required、major-only or full review、re-review until clean、`research_evidence` |
| `release` | —（軽量化なし） | version/tag/GitHub Release/CI 検証、`pr_closeout` + release preflight、full evidence pack |

`[tdd:required]` タスクは lane に関わらず、`tdd_red_log` または明示 `skip_tdd_reason` が sprint contract に無い限り完了扱いにしない。

## Solo — Detailed Steps

1. Read `Plans.md`, identify the target task.
   - If `Plans.md` doesn't exist: auto-invoke `harness-plan create --ci` to generate it.
   - If the header lacks DoD / Depends columns: stop and ask for `harness-plan create` regeneration.
   - Extract undocumented requirements from recent conversation into a `cc:TODO` row (action-verb detection: 追加/修正/実装).
2. Task background confirmation (30s): infer the purpose from DoD, infer blast radius via `git grep`/`Glob`. Low confidence → ask one question; high confidence → proceed without delay.
3. **仕様正本 preflight**: look for an existing project spec SSOT (`docs/spec/00-project-spec.md`, `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `docs/oem/PROJECT_COMPASS.md`, `docs/specs/`). If the task changes product behavior/API/data model/permission/billing/integration/tenant boundary and no spec exists, create `docs/spec/00-project-spec.md` first. If the spec is stale or contradicts the task, update it first. Skip only for typo/format/dependency-bump/docs-only/behavior-preserving refactor, recording the skip reason. Pass `spec_path` or `spec_skip_reason` to Worker/Reviewer context.
4. **Active scope + plan-time preapproval read**: before preapproval, atomically write `{"phase":"<phase>","task":"<task>"}` to this task worktree's `.claude/state/active-task.json`; register cleanup that removes it on every success, failure, or stop path. Read `.claude/state/plan-preapprovals.json` if present and validate with `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" validate .claude/state/plan-preapprovals.json` (write schema: `templates/schemas/plan-preapproval.v2.json`; v1 is read-compatible only). Only entries matching this task's `scope.phase`/`scope.task` with `decision: approved` count as declared. Apply declared `secret-read` via `bash "${HARNESS_PLUGIN_ROOT}/scripts/plan-preapproval.sh" apply-secret-allow "$PROJECT_ROOT"` (writes `runtimefloor.secretAllow` in project config). R12 may consume matching, unexpired, usage-bounded v2 `external-send` approvals. It never suppresses an explicit R12 deny or any runtime-floor category. Pass declared external-send/destructive items to worker briefing/sprint-contract as "plan approved". 確認は plan 承認時 1 回のみ。work 中の宣言済み事項起因 `AskUserQuestion` はゼロにする。Undeclared items still stop on runtime floor / ask — never silently allowlist them.
5. Mark the task `cc:WIP`; declare presence with `bin/harness session declare --task <task-id>` (clear with `--clear` on completion).
6. TDD phase (unless `[skip:tdd]` or no test framework): write the failing test first (Red), confirm the failure, log it with `bash "${HARNESS_PLUGIN_ROOT}/scripts/log-tdd-red.sh"` into `.claude/state/tdd-red-log/<task-id>.jsonl` (or attach literal failing output to the `worker-report`'s `self_review` evidence if the script is unavailable). `--tdd-bypass` requires `HARNESS_TDD_BYPASS=1` and `HARNESS_TDD_BYPASS_REASON="<reason>"` recorded in the sprint contract.
7. Generate `sprint-contract.json` with `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" <task-id>`.
8. Enrich with reviewer perspective (`enrich-sprint-contract.sh`) and confirm approval (`ensure-sprint-contract-ready.sh`).
9. Advisor consult (only when needed): a high-risk task (`needs-spike`/`security-sensitive`/`state-migration`) gets one consult before the first attempt; the same failure cause twice in a row triggers a consult before the third attempt; a plateau `PIVOT_REQUIRED` verdict triggers one consult before escalating. The response is `advisor-response.v1`: `PLAN` reshapes the approach, `CORRECTION` is a local fix, `STOP` escalates immediately. The same `trigger_hash` is consulted at most once; max 3 consults per task.
10. Implement via the backend-resolved executor path (Green).
11. `/simplify` for Auto-Refinement (skip with `--no-simplify`).
12. Run the automatic review stage — see [review-loop.md](review-loop.md). When `sprint-contract.json`'s `reviewer_profile` is `runtime`, also run `bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh"`.
13. Normalize the review artifact with `bash "${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh"` (pass `--browser-result` for the browser profile; `browser_verdict == PENDING_BROWSER` keeps the static verdict).
14. `git commit` (skip with `--no-commit`).
15. Mark `cc:完了 [hash]`, clear the presence declaration, record the short commit hash.
16. Render the rich completion report — see the `Completion Report Output Contract` in the main `SKILL.md` and [completion-report.md](completion-report.md).
17. On test/CI failure after completion, see [failure-reticketing.md](failure-reticketing.md).

## Breezing — Phase Detail

```
Lead (this agent)
├── Worker (task-worker agent) — implementation
├── Advisor (claude-code-harness:advisor) — guidance
└── Reviewer (code-reviewer agent) — review
```

### Phase A — Pre-delegate

1. Read `Plans.md`, identify target tasks, and resolve execution order from the `Depends` column.
2. For each task, atomically write its phase/task to the task worktree's `.claude/state/active-task.json` before preapproval. Remove it on every task exit path.
3. Read `.claude/state/plan-preapprovals.json` if present; validate v2 or read-compatible v1 with `plan-preapproval.sh validate`.
4. Pass this task's `decision: approved` items to the worker briefing; apply declared `secret-read` via `plan-preapproval.sh apply-secret-allow "$PROJECT_ROOT"`. R12 may consume only a matching v2 `external-send` approval; explicit deny and runtime floor remain unchanged. Do not stop mid-work or ask for declared items; undeclared secret-read/external-send/destructive operations still stop on runtime floor / ask.
5. Score each task's effort tier — see [effort-routing.md](effort-routing.md).
6. Generate and enrich `sprint-contract.json` for each task (same scripts as Solo); stop if `ensure-sprint-contract-ready.sh` reports not-ready.

### Phase B — Delegate (per task, sequential in dependency order)

> API note: the pseudo-code below uses Claude Code syntax. On Codex, read `Agent(...)` as `spawn_agent(...)` and `SendMessage(...)` as `send_input(...)` — see `team-composition.md`'s API mapping table.

```
for task in execution_order:
    contract_path = generate + enrich + ensure-ready sprint-contract for task.number

    Plans.md: task.status = "cc:WIP"
    worker_result = Agent(
        subagent_type="claude-code-harness:worker",
        prompt=briefing_header + "タスク: {task.内容}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing",
        isolation="worktree",
        run_in_background=false
    )
    worker_id = worker_result.agentId

    if worker_result.type == "advisor-request.v1":
        advisor_result = Advisor(prompt=worker_result.request_json)
        worker_result = SendMessage(to=worker_id, message="advisor-response.v1: {advisor_result}")

    # self_review gate (Lead checks mechanically before spawning Reviewer)
    self_review_failures = 0
    MAX_SELF_REVIEW_RETRIES = 2  # a 3rd failure escalates
    while True:
        unverified = [r for r in worker_result.self_review if not r.get("verified") or not r.get("evidence")]
        if not unverified:
            break
        self_review_failures += 1
        if self_review_failures > MAX_SELF_REVIEW_RETRIES:
            Plans.md: task.status = "cc:TODO"
            raise EscalationError(f"self_review unresolved after 3 return trips: {[u['rule'] for u in unverified]}")
        SendMessage(to=worker_id, message=f"self_review に未確認 rule があります: {[u['rule'] for u in unverified]}。evidence を実コマンド出力か literal テスト結果で埋め、verified=true にしてから amend してください")
        worker_result = wait_for_response(worker_id)

    # review (see review-loop.md for verdict priority/thresholds)
    diff_text = git("-C", worker_result.worktreePath, "show", worker_result.commit)
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
    profile = jq(contract_path, ".review.reviewer_profile")
    if profile == "runtime":
        review_input = run-contract-review-checks.sh output; DOWNGRADE_TO_STATIC falls back to the static verdict
    if profile == "browser":
        browser artifact -> browser-review-runner.sh; REQUEST_CHANGES/APPROVE override the static verdict, PENDING_BROWSER keeps it
    write-review-result.sh normalizes the artifact

    review_count = 0
    MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
    latest_commit = worker_result.commit
    while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
        SendMessage(to=worker_id, message="指摘内容: {issues}\n修正して amend してください")
        updated_result = wait_for_response(worker_id)
        latest_commit = updated_result.commit
        verdict = codex_exec_review(...) or reviewer_agent_review(...)
        review_count++

    if verdict == "APPROVE":
        cherry-pick latest_commit onto trunk (skip if already an ancestor — re-entry guard)
        remove the worker's worktree; delete the feature branch
        Plans.md: task.status = "cc:完了 [{hash}]"
        bash "${HARNESS_PLUGIN_ROOT}/scripts/auto-checkpoint.sh" "${task.number}" "${HASH}" "${contract_path}" "${REVIEW_RESULT_PATH}" || true  # fail-open
    else:
        escalate to the user

    print("📊 Progress: Task {completed}/{total} 完了 — {task.内容}")
```

### Phase C — Post-delegate

1. Aggregate the commit log for all tasks.
2. Render the rich completion report (Breezing template in [completion-report.md](completion-report.md)).
3. Confirm every task in `Plans.md` reached `cc:完了`.
