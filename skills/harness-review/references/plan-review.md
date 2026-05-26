# Plan Review

## In a nutshell

Plan Review examines whether `Plans.md` has the right granularity and ordering to be implementable.

## Checkpoints

- Each task is a single unit of completion
- DoD is verifiable
- Depends has no circular dependencies
- Status reflects reality
- Tasks that require an authoritative spec have `spec_path` or a creation task
- Implementation order does not defer the highest-risk parts
- Closeout of review / release / mirror / docs is not missing

## Verdict

| State | Verdict |
|---|---|
| DoD is measurable, Depends are valid, scope is clear | APPROVE |
| DoD is ambiguous, dependencies are broken, authoritative spec needed but absent | REQUEST_CHANGES |
| Scope needs to change without user input | decision_needed |

## Output

Plan Review prioritizes file:line.
Base findings on the relevant lines in `Plans.md`, docs, and the authoritative spec.
