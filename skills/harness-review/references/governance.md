# Review Governance

## In a nutshell

Return `APPROVE` only when you can say with evidence that there are no critical issues.

## Clear passing threshold

Conditions for `APPROVE`:

- Zero critical / major issues
- No contradiction with the authoritative spec (`spec_path`) or `spec_skip_reason`
- No contradiction with `Plans.md` task / DoD / Depends
- No evidence of regression in existing behavior, existing tests, existing UX, existing CLI, existing configuration, existing docs, or distribution mirrors
- Evidence exists: verification commands, diff, file:line, test results, etc.
- No unresolved disagreements from TeamAgent Debate

## Severity

| severity | meaning | verdict |
|---|---|---|
| critical | Directly leads to secret exposure, data destruction, permission breakage, or release accidents | REQUEST_CHANGES |
| major | DoD not met, spec violation, clear regression, dangerous to ship without tests | REQUEST_CHANGES |
| minor | Quality improves but not severe enough to block shipment | APPROVE possible |
| recommendation | Optional improvement | APPROVE possible |

If there are only minor / recommendation findings, blocking is not required.
If blocking, explain specifically why it is major.

## AskUserQuestion / decision_needed

Decisions that would break things if made by guessing should be returned as `decision_needed`, not `REQUEST_CHANGES`.

Examples of `decision_needed`:

- The authoritative spec needs to be changed
- `Plans.md` DoD / Depends needs to be changed
- The user needs to choose between security and UX priorities
- A business decision is needed on whether to keep or remove backward compatibility

Use AskUserQuestion when available.
In Codex environments or when it is unavailable, output `decision_needed.v1` to stdout and do not proceed by guessing.

## Side effects

review default read-only boundary:

- Do not auto-commit even on `APPROVE`
- Do not push just to review
- commit / push / release is the responsibility of `harness-work` / `harness-release` / explicit user request

## Output evidence

Required:

- Target scope
- Review commands executed
- Tests executed
- Accepted findings
- Rejected findings
- Clean result or remaining issues
- Passing threshold for authoritative spec / Plans.md / regressions

If `APPROVE` is returned with empty evidence, that `APPROVE` is invalid.
