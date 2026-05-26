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
