# Failure Reticketing

If validation or CI fails after a task was implemented, do not hide the failure
by weakening tests.

## Trigger Conditions

| Condition | Action |
|---|---|
| Test fails before completion | Fix in the same task if the cause is in scope |
| Test fails after `cc:完了` | Create a follow-up fix proposal |
| Same CI cause fails 3 times | Stop and escalate with evidence |

## Proposal Shape

Write pending proposals to `.claude/state/pending-fix-proposals.jsonl`.

Each proposal should include:

- original task id
- proposed fix task id, usually `<task>.fix`
- failure category
- failing command
- minimal DoD
- dependency on the original task

Only add the task to `Plans.md` after user approval.

## Commands

- `approve fix <task_id>` — add the proposal to `Plans.md` as `cc:TODO`.
- `reject fix <task_id>` — discard the proposal.
- Bare `yes` / `no` — accepted only when exactly one proposal is pending.

## Failure Category Detection

Classify the cause before writing the proposal: `syntax_error` / `import_error` /
`type_error` / `assertion_error` / `timeout` / `runtime_error`. The category feeds
the proposed fix task's title (`fix: [original task] - [category]`).
