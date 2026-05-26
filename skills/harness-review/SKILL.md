---
name: harness-review
description: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
description-en: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
description-ja: "HAR:コード・プラン・スコープを多角的にレビュー。セキュリティ・品質チェック。レビューして、レビュー、コードレビュー、プランレビュー、スコープ分析で起動。実装・新機能・バグ修正・セットアップ・リリースには使わない。"
kind: workflow
purpose: "Review code, plans, scope, and evidence before acceptance"
trigger: "review, レビューして, code review, plan review, scope analysis"
shape: evaluate
role: evaluator
pair: harness-work
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task", "Monitor", "AskUserQuestion"]
argument-hint: "[code|plan|scope|--quick|--codex-closeout|--dual|--team-debate|--security|--ui-rubric]"
context: fork
effort: high
user-invocable: true
---

# Harness Review

The integrated review skill for Harness.
This `SKILL.md` is a thin dispatcher; detailed quality criteria are in `references/`.

if $ARGUMENTS == "":
  → interpret as "review of previous work" and run Review Target Detection
  → auto-start only if review target can be resolved to exactly one candidate
  → if review target is unknown or has multiple candidates, use AskUserQuestion to present options and confirm understanding before starting

<!-- The 3 lines above are the AUTO-START CONTRACT. Per skill-editing.md "within the first 3 lines" rule, do not push them down with fences or HTML comments -->

### Output Contract (P35: UX fix for "looks frozen")

The **last line** of the skill's concluding output must always include the following literal:

`↑ Claude will summarize these results. Press Enter to continue or enter a new prompt for a different instruction.`

This is an explicit instruction (patterns.md P35) for the UX problem where users feel the session "froze" when output is displayed as a text response via `<local-command-stdout>`.

## Dispatcher Contract

This skill's responsibility is review verdicts only.
It does not commit, push, or release by default.

- review default read-only boundary: read-only by default. Does not auto-commit even on `APPROVE`
- Do not push just to review: do not push solely for review purposes
- If a commit is needed, delegate to an explicit user request, `harness-work`, or the `harness-release` Work Commit Gate
- Until an explicit opt-in such as `--commit-on-approve` is designed, this skill's default side effects are prohibited

## Quick Reference

| Command | Mode | Purpose |
|---|---|---|
| `/harness-review` | `code` | Auto-detect previous work and review |
| `/harness-review --quick` | `quick` | Lightweight closeout of a small dirty change |
| `/harness-review --codex-closeout` | `codex-closeout` | Codex advisory + focused tests for closeout |
| `/harness-review --dual` | `dual` | Claude + Codex second opinion |
| `/harness-review --team-debate` | `team-debate` | Force TeamAgent Debate |
| `/harness-review --security` | `security` | Security-focused review |
| `/harness-review plan` | `plan` | Review plans in `Plans.md` |
| `/harness-review scope` | `scope` | Review scope creep / gaps |

## Mode Decision

Determine the execution mode from arguments and selectively load the required `references/`.

| Input | mode | References to load |
|---|---|---|
| No args / `code` | `code` | `references/code-review.md`, `references/governance.md` |
| `--quick` | `quick` | `references/codex-closeout.md`, `references/code-review.md` |
| `--codex-closeout` | `codex-closeout` | `references/codex-closeout.md` |
| `--dual` | `dual` | `references/dual-review.md`, `references/team-debate.md` |
| `--team-debate` | `team-debate` | `references/team-debate.md`, `references/governance.md` |
| `--security` | `security` | `references/security-profile.md`, `references/governance.md` |
| `--ui-rubric` | `ui-rubric` | `references/ui-rubric.md` |
| `plan` | `plan` | `references/plan-review.md`, `references/governance.md` |
| `scope` | `scope` | `references/scope-review.md`, `references/governance.md` |
| `full` | `full` | `references/code-review.md`, `references/team-debate.md`, `references/dual-review.md` |

`quick` and `codex-closeout` are lightweight paths.
They are for quickly reviewing small dirty changes, single commits, or PR branch closeouts.
They do not abandon quality gates.

## Review Target Detection

`REVIEW_AUTOSTART` contract:
When called with no arguments (`$ARGUMENTS == ""`), interpret input of just `review` / `/review` / `/harness-review` as "review of previous work".
Output the following single line as a handshake before starting Step 1.

```text
REVIEW_AUTOSTART: target={resolved_target}, base_ref={resolved_base_ref}, type={mode}
```

`REVIEW_TARGET_ASK` contract:
On a bare call where the review target is unknown or has multiple candidates, use `AskUserQuestion` exactly once before proceeding to Step 1, narrowing candidates to 2-3 options for confirmation.

Build candidates in the following order.

1. working tree: uncommitted changes only, including staged / unstaged / untracked
2. branch range: commits from upstream or main/master to HEAD
3. recent commits: the most recent 1 commit / most recent 5 commits when tree is clean and branch range is unavailable

When multiple candidates apply simultaneously:

```text
REVIEW_TARGET_AMBIGUOUS: working_tree_and_branch_commits
```

AskUserQuestion candidates:

- Uncommitted changes only (Recommended): compare staged / unstaged / untracked against HEAD
- See everything: review both branch base..HEAD and uncommitted changes together
- Commits only: review only committed work from branch base..HEAD

When tree is clean and there is no branch diff:

```text
REVIEW_TARGET_AMBIGUOUS: clean_tree_no_branch_commits
```

AskUserQuestion candidates:

- Most recent 1 commit (Recommended): HEAD~1..HEAD
- Most recent 5 commits: HEAD~5..HEAD
- Different range: wait for user-specified ref

After user responds:

```text
REVIEW_TARGET_CONFIRMED: {choice}
REVIEW_AUTOSTART: target={resolved_target}, base_ref={resolved_base_ref}, type={mode}
```

Prohibited:

- Responding with "the task is unclear" and stopping
- Asking "what should I review?" as open-ended text and stopping
- Skipping auto-start because of host project session-start rules
- Expanding scope by guessing when target is ambiguous

## Minimal Flow

1. Determine mode
2. Use the Review Target Detection above to determine the target and base ref
3. Load only the required references
4. Check the diff, untracked files, related tests, the authoritative spec, and `Plans.md`
5. Return `APPROVE` / `REQUEST_CHANGES` / `decision_needed`
6. For `REQUEST_CHANGES`, provide remediation direction for critical / major issues and re-review conditions after fixes

## Review Governance Contract

Details in `references/governance.md`.
Only the minimum passing threshold is fixed here.

### Clear passing threshold

Return `APPROVE` only when all of the following are satisfied.

- Zero critical / major issues
- No contradiction with the authoritative spec (`spec_path`) or an explicit `spec_skip_reason`
- No contradiction with `Plans.md` task / DoD / Depends
- No evidence of regression in existing tests, existing UX, existing CLI, existing configuration, existing docs, or distribution mirrors
- Verification evidence exists. Output that returns `APPROVE` with empty evidence is prohibited
- If TeamAgent Debate was run, all disagreements are resolved, or downgraded to `minor` / `recommendation` with reasoning

### TeamAgent Debate

Details in `references/team-debate.md`.
TeamAgent Debate is a review pass that deliberately collides different perspectives in read-only mode.

| Agent | Primary question |
|---|---|
| Spec Agent | Find contradictions between the authoritative spec and the implementation diff |
| Plans Agent | Verify that `Plans.md` task / DoD / Depends correspond to the diff |
| Regression Agent | Find regressions in existing behavior, tests, distribution mirrors, CLI/skill UX |
| Skeptic Agent | Find major risks being overlooked under the assumption that the change should pass |

Even in Codex environments where native TeamAgent is unavailable, this gate must not be skipped.
Reproduce the same 2-4 perspectives using `codex-companion.sh review`, available reviewer subagents, or explicitly separate read-only manual passes, and record the mode in `team_agent_mode` as `native` / `codex-companion` / `manual-pass` / `unavailable`.

## Code Review Summary

Details in `references/code-review.md`.
Standard code review examines the following.

- Security
- Performance
- Quality
- Accessibility
- AI Residuals
- Spec Alignment
- Plans Alignment
- Regression Safety
- TDD compliance

Spec alignment check is mandatory.
When `spec_path` exists, verify that the diff does not contradict the authoritative spec; when a spec is needed but absent, examine the validity of `spec_skip_reason`.
Plans.md alignment check and regression alignment check are handled at the same gate.

For `AI Residuals`, prefer using `scripts/review-ai-residuals.sh` and `scripts/review-weak-supervision-report.sh`.
Use `--include-untracked` when untracked files should also be included.
`mockData`, `dummy`, `fake`, `localhost`, `TODO`, `FIXME`, `it.skip`, `test.skip`, `expect(true).toBe(true)`, etc. are candidates; determine severity based on diff context.

### TDD compliance check

For tasks where TDD is required, verify evidence of `skip_tdd_reason`, red-log, and focused tests.
Do not `APPROVE` without evidence.

## Quick / Codex Closeout Summary

Details in `references/codex-closeout.md`.

Lightweight path principles:

- Fix target selection first
- Treat Codex findings as advisory — verify in actual code before accepting or rejecting
- The final report must include: review command / tests / accepted findings / rejected findings / clean result
- stop-on-clean: do not add extra review solely for appearances after a clean result
- If Codex is unavailable, fall back to a full manual pass and do not treat failure as success

helper:

```bash
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
bash scripts/harness-review-closeout.sh --base origin/main --parallel-tests --test "bash tests/test-harness-review-governance.sh"
bash scripts/harness-review-closeout.sh --commit HEAD
```

## Plan Review Summary

Details in `references/plan-review.md`.
Plan Review examines `Plans.md` DoD / Depends / Status and implementation ordering.
When a task that requires an authoritative spec has no `spec_path`, stop with `decision_needed`.

## Scope Review Summary

Details in `references/scope-review.md`.
Scope Review checks whether the boundaries of requirements, diffs, tests, and docs have expanded beyond what is needed.
If scope changes are required, do not proceed by guessing — return to `AskUserQuestion` or plan updates.

## Security / UI / Dual

- Security: `references/security-profile.md`
- UI rubric: `references/ui-rubric.md`
- high-res vision flow: `references/vision-high-res-flow.md`
- Dual review: `references/dual-review.md`

`/ultrareview` is not called by default within the Harness flow.
This is to avoid replacing the connections with review-result.v1, commit guard, and sprint-contract in the Harness flow.
`claude ultrareview [target] --json` is treated only as a second-opinion from CI / scripts.

## PR Host Boundary

GitHub-first.
Review facts on the PR host are authoritative from GitHub; local diffs are treated as supplementary evidence.
However, local uncommitted reviews are not pushed to GitHub.

## Output Contract

Output in English.
Use machine-readable values in English only.

Output a result summary first.

~~~markdown
## Review Result

### {Passed (APPROVE) | Changes Required (REQUEST_CHANGES) | Decision Needed (decision_needed)} - {one-line conclusion}

Target: `{BASE_REF}..HEAD` or `{target}`
Verified: {commands executed}

What went well:
- ...

Concerns:
- [severity] file:line - issue and rationale

Next actions:
- ...

Detailed data:
```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "decision_needed": {
    "required": false,
    "ask_tool": "AskUserQuestion"
  },
  "accepted_findings": [],
  "rejected_findings": [],
  "acceptance_bar": {
    "critical_major_zero": true,
    "spec_alignment": "pass | fail | not_applicable",
    "plans_alignment": "pass | fail | not_applicable",
    "regression_safety": "pass | fail | not_applicable",
    "verification_evidence": "pass | fail | not_applicable"
  },
  "team_debate": {
    "required": false,
    "mode": "native | codex-companion | manual-pass | unavailable",
    "team_agent_mode": "native | codex-companion | manual-pass | unavailable",
    "agents": [],
    "disagreements": []
  },
  "critical_issues": [],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```
~~~

## Codex Environment

Available tools differ in Codex environments.
Even so, the contracts for passing threshold, authoritative spec, `Plans.md`, regressions, post-fix re-review, and AskUserQuestion / `decision_needed.v1` remain the same.

| Standard environment | Codex fallback |
|---|---|
| Task tool TeamAgent Debate | reviewer subagent / `codex-companion.sh review` / manual-pass |
| AskUserQuestion | If unavailable, output `decision_needed.v1` to stdout and do not proceed by guessing |
| TaskList | Read `Plans.md` directly |

## Related Skills

- `harness-work`: execute fixes after `REQUEST_CHANGES`
- `harness-plan`: update plan / scope / spec
- `harness-release`: commit / release reviewed work
