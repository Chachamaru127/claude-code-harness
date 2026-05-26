---
name: harness-accept
description: "Generate an Acceptance Demo HTML for non-engineer vibecoders right before ship/wait/reject decision. Reads back the acceptance_criteria that were stored as personal-preference.v1 by harness-plan-brief (joined by user_request_hash), then renders a single-file HTML showing each criterion as verified or unverified along with a ship/wait/reject recommendation. Use when the user asks for an acceptance review, wants to decide whether to ship a delivered task, or says: acceptance demo, accept demo, acceptance review, ship/wait/reject decision. Do NOT load for: implementation, code review, release work."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[task-description]"
user-invocable: true
---

# harness-accept

A skill for presenting the acceptance decision (ship / wait / reject) for a completed implementation task as a **single HTML page** — designed for non-engineer clients and producers.
Used at cognitive load peak (3): the acceptance decision stage.

Operates as the counterpart structure to Phase 65.1.x (`harness-plan-brief`), retrieving the `acceptance_criteria` approved in the Plan Brief and evaluating them on the read side via `user_request_hash`.

## Quick Reference

- "**Create an Acceptance Demo**" → this skill
- "**I want to make an acceptance decision**" → this skill
- "**ship/wait/reject decision**" → this skill

## Responsibility Boundaries

| Scope | This skill's responsibility |
|------|-----------------|
| Search | **Current project only** (`project: <current>`, `strict_project: true` always specified) |
| Cross-project | **Not done** (opt-in release via `--cross-project-group <name>` flag from Phase 65.3 onward) |
| Plan Brief integration | Read `personal-preference.v1` (Phase 65.1.4) using `user_request_hash` as the join key |
| Writes | Not done (memory write after Acceptance approval is the responsibility of `accept-record-decision.sh`) |
| Recommendation calculation | Threshold check at 0.8 / 0.5 based on verified / total criteria ratio. Logic is calculated just before `scripts/render-html.sh` |

## Input

Pass the user's request in the `[task-description]` argument (use the same text as at Plan Brief time).
If no argument is given, receive it interactively.

## Output

| Output | Path | Format |
|------|------|------|
| Acceptance Demo HTML | `.claude/state/views/accept-<timestamp>.html` | Self-contained HTML (no server, no JS framework) |
| Acceptance context JSON | `.claude/state/views/accept-<timestamp>.context.json` | `acceptance-context.v1` schema |

## Schema: `acceptance-context.v1`

```json
{
  "schema": "acceptance-context.v1",
  "user_request": "string",
  "user_request_hash": "sha256 hex (join key with personal-preference.v1 from Plan Brief side)",
  "demo_artifacts": [
    { "kind": "video|screenshot|text", "path": "string" }
  ],
  "verified_criteria": [
    { "name": "string", "passed": true, "evidence": "string" }
  ],
  "tdd_verified": "yes|no|not-required|skip:<reason>",
  "unverified_caveats": ["string"],
  "past_issue_patterns": [
    { "pattern_id": "P5", "title": "string", "verified_in_current_task": true }
  ],
  "recommendation": "ship|wait|reject",
  "recommendation_evidence": ["string"],
  "project": "string",
  "generated_at": "ISO8601"
}
```

Full schema: [`schemas/acceptance-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/acceptance-context.v1.schema.json)

## Recommendation Calculation Logic

```
verified_count    = count of verified_criteria where passed=true
total_criteria    = count of verified_criteria
ratio             = verified_count / total_criteria  (0 when total=0)

  ratio >= 0.8 → "ship"
  ratio >= 0.5 → "wait"
  ratio <  0.5 → "reject"
  total = 0    → "reject" (0 criteria means judgment is not possible — safe-side reject)
```

Evaluation evidence is recorded as literal numbers in `recommendation_evidence`.
Example: `"4 verified / 5 total (80%) → above ship threshold"`

## Execution Flow

When the skill launches, Claude operates in the following steps.

### Step 1: Resolve project name and user_request_hash

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
USER_REQUEST_HASH="$(printf '%s' "$USER_REQUEST" | sha256sum | awk '{print $1}')"
```

If `PROJECT_NAME` is empty (outside of a git repo), use `current` as the default.

### Step 2: Search harness-mem **project-only** to retrieve the Plan Brief record (default)

When there is **no** `--cross-project-group <name>` flag in the arguments (default behavior):

Call `mcp__harness__harness_mem_search` with the following parameters:

```
project: <PROJECT_NAME>
strict_project: true
tags: ["personal-preference", "plan-brief-approval"]
limit: 10
```

> **Important**: The `project` parameter is **required**. Specify `strict_project: true` and **never** perform cross-project searches.

Filter the retrieved records by `data.user_request_hash == <USER_REQUEST_HASH>` and select the most recent one.
This holds the approval content from Plan Brief time (chosen_option / acceptance_criteria etc.).

### Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)

Only when there is a `--cross-project-group <name>` flag in the arguments, retrieve the cross-group history of similar plan-brief-approval / acceptance-decision records from other projects in the group (D43 Option α):

```bash
MEMBERS_JSON="$(bash scripts/load-cross-project-groups.sh --group "<name>" 2>/dev/null)" || {
  echo "ERROR: cross-project group not found: <name>" >&2
  exit 1
}
```

If `MEMBERS_JSON` is `[]`, fall back to the default single-project search.

If `MEMBERS_JSON` is non-empty, issue one MCP search per member project:

```
for each project in MEMBERS_JSON:
  mcp__harness__harness_mem_search(
    project: <member>,
    strict_project: true,
    tags: ["personal-preference", "plan-brief-approval"],
    limit: 10
  )
```

Merge results on the client side and filter by `data.user_request_hash == <USER_REQUEST_HASH>`.
Hash matches are generally from the same user request origin, so cross-project duplicates are rare, but dedupe by id as a precaution.

When adopting records from cross-project origins, chosen_option / acceptance_criteria from past other projects may be mixed in, so **always use the `--with-redaction` flag** when generating HTML output:

```bash
bash scripts/render-html.sh --template accept ... --with-redaction
```

For details, see "Phase 65.3 Implementation Decisions (D43)" in `.claude/rules/cross-repo-handoff.md`.

### Step 3: Retrieve past issue patterns (Phase 65.2.2 delegation)

```bash
bash scripts/accept-past-issues.sh --project "$PROJECT_NAME" --task "$USER_REQUEST" > "$PAST_ISSUES_JSON"
```

This script performs a semantic search on patterns.md (P1-P33) and past `acceptance-context.v1` records,
returning up to 3 `past-issue.v1` entries, each with `verified_in_current_task: bool`.

### Step 4: Build verified_criteria

For each acceptance_criteria item from Plan Brief time, evaluate the current task's state.
The user (or Claude) provides "evidence of verification" and fills in the `evidence` string.

If `evidence` is an empty string, a warning is displayed in the HTML (DoD c).

For tasks where TDD is required, the Acceptance Demo must include a single line `TDD verified: yes|no`.
For cases where TDD is not required or is skipped, display `TDD verified: not-required` or `TDD verified: skip:<reason>`.
`yes` can only be set when Red evidence is confirmed in `.claude/state/tdd-red-log/<task-id>.jsonl`, or when literal failing test output is available.

### Step 5: Calculate the recommendation

Determine ship / wait / reject following the "Recommendation Calculation Logic" above.

### Step 6: Generate HTML

Call `scripts/render-html.sh` (Phase 65.1.1) with `templates/html/accept.html.template`:

```bash
bash scripts/render-html.sh \
  --template accept \
  --data "$CONTEXT_JSON" \
  --out "$HTML_OUT"
```

### Step 7: Auto-open in browser

Reuse `scripts/plan-brief-open.sh` (the **general-purpose OS dispatcher** introduced in Phase 65.1.2):

```bash
bash scripts/plan-brief-open.sh "$HTML_OUT"
```

> **Note**: The script name contains "plan-brief" but its actual purpose is a per-OS browser open dispatcher that is kind-neutral.
> It was named this way because it was introduced first in Phase 65.1.2. It is also reused for other purposes such as Layer 3 (HTML pre-render final scan).
> When the `BROWSER=true` env variable is set (CI environment), open is **skipped** and only the path is printed via `printf`.

### Step 8: Wait for user decision

Confirm whether the user accepts the ship / wait / reject recommendation or overrides it.
Memory write after the decision is the responsibility of a separate skill (`accept-record-decision.sh`, Phase 65.2.3).

## Failure Behavior

| Failure | Behavior |
|------|------|
| `mcp__harness__harness_mem_search` unreachable | Display warning and continue with `verified_criteria` as empty array (recommendation = reject) |
| Plan Brief record not found | Output warning and continue with `verified_criteria` as empty array |
| `git rev-parse --show-toplevel` fails | Continue with `PROJECT_NAME=current` |
| `accept-past-issues.sh` fails | Continue with `past_issue_patterns: []` (best-effort) |
| `render-html.sh` fails | Output error to stderr and exit 1 |

## Related

- `harness-plan-brief` (Phase 65.1.2) — The counterpart skill for the planning stage. This skill reads back `personal-preference.v1` from Plan Brief time via `user_request_hash`
- `scripts/accept-past-issues.sh` (Phase 65.2.2) — Past issue pattern retrieval (read side)
- `scripts/accept-record-decision.sh` (Phase 65.2.3) — Approval memory write (`acceptance-decision.v1`)
- `scripts/render-html.sh` (Phase 65.1.1) — HTML template engine
- `scripts/plan-brief-open.sh` (Phase 65.1.2) — General-purpose OS browser dispatcher
- `harness-progress` skill (Phase 65.4.1) — Progress management skill (middle of the 3 surfaces)
