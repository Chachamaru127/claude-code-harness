# Review Loop

The review loop is shared by Solo, Parallel, and Breezing. Parallel runs it once
per Worker; Breezing runs it from the Lead (see below).

## Order

1. Prefer Codex companion structured review when available.
2. Fall back to the internal `reviewer` agent (when `command -v codex` fails or
   the companion times out at 120s).
3. Run AI Residuals in parallel with either:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh" --base-ref "${BASE_REF}" --include-untracked
```

4. Normalize the review artifact with `write-review-result.sh`.

## Verdict Threshold

Give the reviewer only this threshold; it must judge verdict from it alone.
Below-threshold suggestions become `recommendations` and never flip the verdict.

| Severity | Definition | Verdict effect |
|---|---|---|
| `critical` | Security vulnerability, data loss risk, possible production outage | Any finding means `REQUEST_CHANGES` |
| `major` | Breaks an existing feature, clearly contradicts spec, failing test | Any finding means `REQUEST_CHANGES` |
| `minor` | Naming, missing comment, style inconsistency | Does not change verdict |
| `recommendation` | Best-practice suggestion, future improvement | Does not change verdict |

Minor-only and recommendation-only reviews must approve. "Would be nice to have" is never a reason for `REQUEST_CHANGES`.

## Codex Companion Review

Capture `BASE_REF=$(git rev-parse HEAD)` before implementation starts, then diff against it:

```bash
BASE_REF=$(git rev-parse HEAD)
# ... implementation complete ...
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" review --base "${BASE_REF}"
REVIEW_EXIT=$?
```

Verdict mapping (official plugin → Harness):

| Official plugin | Harness | Verdict effect |
|---|---|---|
| `approve` | `APPROVE` | - |
| `needs-attention` | `REQUEST_CHANGES` | - |
| `findings[].severity: critical` | `critical_issues[]` | Any → `REQUEST_CHANGES` |
| `findings[].severity: high` | `major_issues[]` | Any → `REQUEST_CHANGES` |
| `findings[].severity: medium/low` | `recommendations[]` | Does not change verdict |

## Internal Reviewer Agent Fallback

When Codex exec is unavailable:

```
Agent tool: subagent_type="reviewer"
prompt: "Review this diff. Verdict rule: critical/major -> REQUEST_CHANGES, minor/recommendation only -> APPROVE. diff: {git diff ${BASE_REF}}"
```

The `reviewer` agent is read-only (no Write/Edit/Bash) so it can review safely.

## Repair Loop

```
review_count = 0
MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. Parse the findings (critical / major only)
    2. Fix each finding
    3. Re-run the review with the same threshold and priority order
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    -> escalate to the user with the remaining critical/major findings, wait for continue/abort
```

Breezing repair instructions go back to the same Worker. In Codex, resume the
Worker and use `send_input`; in Claude Code, send the equivalent teammate
message (`SendMessage`).

## Breezing-Specific Application

In Breezing, the **Lead** runs the review loop:

1. Worker implements and commits inside its worktree, then returns the result to Lead.
2. Lead reviews via Codex exec (preferred) or the Reviewer agent (fallback).
3. `REQUEST_CHANGES` → Lead sends fix instructions via `SendMessage`; Worker amends.
4. Re-review after the fix (up to `MAX_REVIEWS`).
5. `APPROVE` → Lead cherry-picks onto trunk and marks `Plans.md` `cc:完了 [{hash}]`.
