# 3 HTML Surfaces to Reduce Cognitive Load (Phase 65)

Three HTML surfaces that let anyone — engineers and non-engineers alike — understand in 3 seconds what Claude is thinking, where it stands, and what it has accomplished.

## The Goal

When developing alongside AI, continuously reading commit logs or Plans.md (a task-list markdown file) creates high cognitive load.
These 3 single-page HTML surfaces let sponsors, producers, and executives **open a browser and make decisions at a glance** without technical context.

| Surface | Purpose | When to view |
|---------|---------|--------------|
| **Plan Brief** (before kickoff) | "This is how Claude understood the request. OK to proceed?" | Approval before implementation |
| **Progress Tracker** (during work) | "How far along is it, and when is it expected to finish?" | Any time (auto-regenerated) |
| **Acceptance Demo** (at handoff) | "Will you accept this deliverable?" | Sign-off after implementation is complete |

## How to Use

### Plan Brief (1st surface)

```bash
# During a Claude session
/harness-plan-brief
```

Claude produces a single-page HTML summarizing:
- Claude's understanding of the user request
- Options (each option if multiple approaches exist)
- Risks (potential problem areas)
- Acceptance criteria
- Confidence score (0-100, with reasoning)

The user responds with "OK, proceed," "revise this part," or "I have a question."
The decision is recorded using the `personal-preference.v1` schema (with sha256 hash).

### Progress Tracker (2nd surface)

```bash
# Check progress
/harness-progress
```

Or the PostToolUse hook auto-regenerates **once every 60 seconds** when Edit/Write/Bash fires.

Displayed content:
- progress_pct (cc:完了 tasks / total tasks × 100)
- Currently in-progress (WIP) task
- Last 5 completed tasks
- Next 5 pending tasks
- Drift alerts (5 types, color-coded by severity: red=critical / yellow=warn / blue=info)

### Acceptance Demo (3rd surface)

```bash
# After implementation is complete
/harness-accept
```

Claude produces a single-page HTML summarizing:
- Verdict (3 choices: ship / wait / reject)
- Verification of acceptance criteria (each Plan Brief item marked "confirmed" or "not confirmed")
- Unverified reservations
- History of past issue patterns
- List of delivered artifacts

The user responds with accept / override / reject.
The decision is recorded as `acceptance-decision.v1` and can be graph-joined with the Plan Brief via **the same user_request_hash**.

## Things to Keep in Mind

### 1. Plan Brief and Acceptance Demo are linked via user_request_hash

At Plan Brief launch, a sha256 hash of the user request text is taken and saved to the record.
The Acceptance Demo takes the same hash and saves it to its record.
**These 2 records can be graph-joined from `mcp__harness__harness_mem_search` using the same hash.**

This enables a complete retrospective of "what happened with that plan from back then?"

### 2. Progress Tracker rate limit (60 seconds)

Even when a large refactor causes a large number of Edit/Write calls from the PostToolUse hook, HTML regeneration is limited to once every 60 seconds.
State file: `.claude/state/progress-last-regen.txt` (epoch seconds).

### 3. Drift alerts accumulate within a session and are not persisted

The 5 alert types (scope-creep / time-overrun / repeated-failure / cost-warning / high-risk-file) display the in-session state in the Progress Tracker HTML.
**They are not persisted to memory** (issue #87 policy — Lead process in-memory only).

Past alert user decisions are aggregated by `progress-past-judgments.sh` and displayed as "You declined similar proposals in M of the last N occurrences," but these have design room to be permanently stored as `alert-judgment.v1` records (not implemented in this phase).

### 4. Handling client information

When the `--cross-project-group <name>` flag is used to enable cross-project search,
**3-layer redaction** (Layer 2a dictionary + Layer 2b NER + Layer 3 final scan) is applied automatically.
Details: [cross-project-safety.md](cross-project-safety.md)

## Related Files

| File | Purpose |
|------|---------|
| `skills/harness-plan-brief/` | Plan Brief skill (Phase 65.1) |
| `skills/harness-accept/` | Acceptance Demo skill (Phase 65.2) |
| `skills/harness-progress/` | Progress Tracker skill (Phase 65.4) |
| `templates/html/plan-brief.html.template` | Plan Brief HTML template |
| `templates/html/accept.html.template` | Acceptance Demo HTML template |
| `templates/html/progress.html.template` | Progress Tracker HTML template |
| `scripts/render-html.sh` | Mustache-style template renderer (supports `--with-redaction` flag) |
| `scripts/plan-brief-record-decision.sh` | Plan Brief decision recorder |
| `scripts/accept-record-decision.sh` | Acceptance Demo decision recorder |
| `scripts/progress-snapshot.sh` | Plans.md → snapshot JSON |
| `scripts/progress-detect-drift.sh` | 5 alert type detection |
| `scripts/progress-past-judgments.sh` | Past judgment lookup |
| `scripts/hook-handlers/posttool-progress-regen.sh` | PostToolUse auto-regeneration hook |

## Related Schemas

- `plan-brief-context.v1` (Plan Brief render input)
- `acceptance-context.v1` (Acceptance Demo render input)
- `progress-snapshot.v1` (Progress Tracker render input)
- `personal-preference.v1` (Plan Brief decision record)
- `acceptance-decision.v1` (Acceptance Demo decision record)
- `progress-alert.v1` (drift alert)
