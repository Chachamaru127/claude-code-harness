---
name: harness-plan-brief
description: "Generate a Plan Brief HTML for non-engineer vibecoders before implementation starts. Searches harness-mem (project-only) for relevant past decisions, patterns, and Plans archive entries, then renders a single-file HTML artifact summarizing understanding, options, risks, acceptance criteria, and confidence. Use when the user requests a planning preview, a non-engineer-friendly summary before approval, or says: plan brief, planning preview, plan overview, pre-implementation review. Do NOT load for: actual implementation, code review, release work."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[task-description]"
user-invocable: true
---

# harness-plan-brief

A skill for presenting the plan Claude is about to begin as a **single HTML page** — designed for non-engineer clients and producers.
Used at cognitive load peak (1): the plan comprehension stage.

## Quick Reference

- "**Create a Plan Brief**" → this skill
- "**Summarize roughly before implementation**" → this skill
- "**Show the plan in a non-engineer-friendly way**" → this skill

## Responsibility Boundaries

| Scope | This skill's responsibility |
|------|-----------------|
| Search | **Current project only** (`project: <current>`, `strict_project: true` always specified) |
| Cross-project | **Not done** (opt-in release via `--cross-project-group <name>` flag from Phase 65.3 onward) |
| Writes | Not done (memory write after Plan Brief approval is the responsibility of `plan-brief-record-decision.sh`) |
| Confidence calculation | Delegated to `scripts/plan-brief-compile.sh` implemented in 65.1.3 |

## Input

Pass the user's request in the `[task-description]` argument.
If no argument is given, receive it interactively.

## Output

| Output | Path | Format |
|------|------|------|
| Plan Brief HTML | `.claude/state/views/plan-brief-<timestamp>.html` | Self-contained HTML (no server, no JS framework) |
| Plan Brief context JSON | `.claude/state/views/plan-brief-<timestamp>.context.json` | `plan-brief-context.v1` schema |

## Schema: `plan-brief-context.v1`

```json
{
  "schema": "plan-brief-context.v1",
  "user_request": "string (user's original request)",
  "my_understanding": "string (Claude's understanding in 1-3 paragraphs)",
  "options": [
    { "name": "string", "summary": "string", "pros": ["string"], "cons": ["string"] }
  ],
  "risks": [
    { "kind": "string", "severity": "info|warn|critical", "description": "string", "mitigation": "string" }
  ],
  "acceptance_criteria": [
    { "id": "string", "description": "string", "verifiable_by": "string" }
  ],
  "tdd_required": "yes|no|skip:<reason>",
  "confidence": 0,
  "confidence_evidence": ["string"],
  "related_decisions": [
    { "id": "string", "title": "string", "relevance": "string" }
  ],
  "similar_past_plans": [
    { "archive_path": "string", "phase": "string", "outcome": "cc:done|cc:WIP|cc:TODO|skipped", "relevance": "string" }
  ],
  "project": "string",
  "generated_at": "ISO8601"
}
```

Full schema: [`schemas/plan-brief-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/plan-brief-context.v1.schema.json)

## Execution Flow

When the skill launches, Claude operates in the following steps.

### Step 1: Resolve project name

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")"
```

If `PROJECT_NAME` is empty (outside of a git repo), use `current` as the default.

### Step 2: Search harness-mem **project-only** (default)

When there is **no** `--cross-project-group <name>` flag in the arguments (default behavior):

**Always** call `mcp__harness__harness_mem_search` with the following parameters:

```
project: <PROJECT_NAME>
strict_project: true
query: <user request>
expand_links: true
limit: 5
```

> **Important**: The `project` parameter is **required**. Do not pass an empty string or `null`.
> Specify `strict_project: true` and **never** perform cross-project searches.
> You may optionally filter by `tags` with `decision` / `pattern`, but `project` is fixed.

Retrieve up to 5 similar entries from past decisions (D1-D41) / patterns (P1-P33) / Plans archive (28 entries).

### Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)

Only when there is a `--cross-project-group <name>` flag in the arguments:

Follow D43 Option α (MCP N-call) for cross-project search.

```bash
# (a) Resolve group → member projects (yaml SSOT)
MEMBERS_JSON="$(bash scripts/load-cross-project-groups.sh --group "<name>" 2>/dev/null)" || {
  echo "ERROR: cross-project group not found: <name>" >&2
  exit 1
}
# MEMBERS_JSON is a JSON array in ["proj1","proj2",...] format
```

If `MEMBERS_JSON` is `[]` (empty array), output a warning and fall back to the default single-project search.

If `MEMBERS_JSON` is non-empty, **issue one MCP search per member project**:

```
for each project in MEMBERS_JSON:
  mcp__harness__harness_mem_search(
    project: <member>,
    strict_project: true,
    query: <user request>,
    expand_links: true,
    limit: 5
  )
```

On the client side, **merge, dedupe (by id), sort descending by relevance_score**, and narrow to a maximum of 5 entries.
Note that the total number of calls increases (e.g. 5 calls if the group has 5 projects), resulting in higher latency.

> **Rationale for D43 decision 1**: The MCP tool schema exposes neither `projects: [array]` nor `strict_project: false`,
> so client-side N-call is the only option for cross-project search.
> For details, see "Phase 65.3 Implementation Decisions (D43)" in `.claude/rules/cross-repo-handoff.md`.

Cross-project results must always pass through Layer 2/3 redaction (Phase 65.3.2-65.3.4):
- Use `bash scripts/render-html.sh ... --with-redaction` when rendering HTML
- This ensures proper nouns do not leak through 3 stages: dictionary + NER + final scan

### Step 3: Build context JSON

Use `scripts/plan-brief-compile.sh` (implemented in Phase 65.1.3) to build JSON conforming to the `plan-brief-context.v1` schema from mem search results.

Before 65.1.3 is implemented, Claude assembles it directly with jq:

```bash
jq -n \
  --arg req "$USER_REQUEST" \
  --arg proj "$PROJECT_NAME" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    schema: "plan-brief-context.v1",
    user_request: $req,
    my_understanding: "(not yet started)",
    options: [],
    risks: [],
    acceptance_criteria: [],
    confidence: 0,
    confidence_evidence: ["(stub) calculation logic implemented in 65.1.3"],
    tdd_required: "no",
    related_decisions: [],
    similar_past_plans: [],
    project: $proj,
    generated_at: $ts
  }' > "$CONTEXT_JSON"
```

### Step 4: Generate HTML

Call `scripts/render-html.sh` (Phase 65.1.1) with `templates/html/plan-brief.html.template`:

The HTML must include a single TDD decision line.
Format is one of `tdd_required: yes`, `tdd_required: no`, or `tdd_required: skip:<reason>`.

```bash
bash scripts/render-html.sh \
  --template plan-brief \
  --data "$CONTEXT_JSON" \
  --out "$HTML_OUT"
```

### Step 5: Auto-open in browser

OS-specific dispatch with `scripts/plan-brief-open.sh`:

```bash
bash scripts/plan-brief-open.sh "$HTML_OUT"
```

When the `BROWSER=true` env variable is set (CI environment), open is **skipped** and only the path is printed via `printf`.

### Step 6: Wait for user approval

Confirm "is it okay to proceed to implementation with this understanding?"
Memory write after approval is the responsibility of a separate skill (Phase 65.1.4's `plan-brief-record-decision.sh`).

## Failure Behavior

| Failure | Behavior |
|------|------|
| `mcp__harness__harness_mem_search` unreachable | Display warning and continue with `related_decisions` / `similar_past_plans` as empty arrays |
| `git rev-parse --show-toplevel` fails | Continue with `PROJECT_NAME=current` |
| `render-html.sh` fails | Output error to stderr and exit 1 |
| `plan-brief-open.sh` fails | Output only the HTML path to stdout and exit 0 (browser open is best-effort) |

## Related

- `scripts/render-html.sh` (Phase 65.1.1) — HTML template engine
- `scripts/plan-brief-compile.sh` (Phase 65.1.3) — context compilation
- `scripts/plan-brief-record-decision.sh` (Phase 65.1.4) — approval memory write
- `harness-accept` skill (Phase 65.2.1) — acceptance decision skill (counterpart structure)
- `harness-progress` skill (Phase 65.4.1) — progress management skill (counterpart structure)
