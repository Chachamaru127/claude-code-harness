# Codex Failure Reticketing

Codex must not turn a red validation into a green result by weakening tests.

When validation fails:

1. Fix in scope if the failure belongs to the current task.
2. If the task was already marked complete, create a pending fix proposal.
3. After three repeats of the same CI cause, stop and escalate.

Pending fix proposals belong in `.claude/state/pending-fix-proposals.jsonl`
until the user approves adding them to `Plans.md`.
