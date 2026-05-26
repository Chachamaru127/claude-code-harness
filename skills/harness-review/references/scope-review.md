# Scope Review

## In a nutshell

Scope Review examines whether required work is missing, or conversely, whether unnecessary work has been included.

## Checkpoints

- The user request matches the diff
- The task's DoD is satisfied
- Unrelated refactoring is not mixed in
- The required scope of docs / tests / mirror / changelog is in place
- Checked that no new public surfaces have been added
- migration / release / permission boundaries have not been changed without authorization

## Scope creep

Scope creep is "when the scope of work expands beyond what is necessary."
For example, starting to change release scripts during a docs-only task is dangerous.

When scope creep is found, split it into one of the following.

- Required for the current DoD: explicitly note in the plan and proceed
- Not required for the current DoD: extract as a separate task

## Verdict

| State | Verdict |
|---|---|
| Request matches diff | APPROVE |
| DoD not met or unnecessary changes mixed in | REQUEST_CHANGES |
| Business decision needed for scope change | decision_needed |
