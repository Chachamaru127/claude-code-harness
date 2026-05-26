---
name: harness-progress
description: "Generate a Progress Tracker HTML for non-engineer vibecoders to glance at session progress (cc:WIP / cc:TODO / cc:done counts, percentage, elapsed/estimated minutes, cost so far/estimate, drift alerts). Uses Plans.md as source of truth, renders a single-file HTML with auto-regeneration support. Use when user asks for progress overview, session status snapshot, dashboard, or says: progress tracker, progress check, progress board, dashboard. Do NOT load for: actual implementation, code review, release work."
allowed-tools: ["Read", "Write", "Bash"]
argument-hint: "[--out <path>] [--no-open]"
---

# Harness Progress Tracker

Phase 65.4 (Progress Tracker) — the 3rd surface of the cognitive-load HTML triplet.
Following Plan Brief / Acceptance Demo, this third HTML surface lets you **grasp the full picture of an in-progress session at a glance on a single page**.

## Quick Reference

| Input | Behavior |
|---|---|
| `/harness-progress` | Generate and open a progress snapshot HTML for the current project |
| `/harness-progress --no-open` | Generate only (do not open browser, for PostToolUse hook use) |
| `/harness-progress --out <path>` | Specify output path (default: `out/progress-snapshot.html`) |

## Mission

> Generate a single HTML page that lets a non-engineer vibecoder **grasp in 3 seconds in the browser** how many tasks this session has completed, how far along it is, when it is expected to finish, and how much it has cost.

**Does**:
- Count cc:TODO / cc:WIP / cc:done items in Plans.md
- Calculate progress_pct (completion rate) (cc:done ÷ total tasks × 100)
- Display elapsed minutes / estimated total minutes / cost so-far / cost estimate
- Display drift alerts (populated from Phase 65.4.3 onward)

**Does not** (this cycle):
- Live updates via WebSocket / SSE (static HTML, updates via regeneration)
- History comparison with past sessions (separate axis in Phase 65.4.4)
- Cross-project view with other projects (independent of Phase 65.3)

## Schema: progress-snapshot.v1

Detailed spec: [schemas/progress-snapshot.v1.schema.json](${CLAUDE_SKILL_DIR}/schemas/progress-snapshot.v1.schema.json)

```yaml
schema:        progress-snapshot.v1
project:       <basename of git repo>
current_task:  <one-line summary of the first cc:WIP item, empty string if none>
progress_pct:  <integer 0-100, cc:done ÷ total tasks × 100 rounded>
todo_tasks:    [{number, title}]    ← cc:TODO only
wip_tasks:     [{number, title}]    ← cc:WIP only
done_tasks:    [{number, title, commit}]   ← cc:done [hash] only, hash is 7 chars
elapsed_minutes:          <int, from state file>
estimated_total_minutes:  <int, from state file>
cost_so_far_usd:          <float, from state file>
cost_estimate_usd:        <float, from state file>
alerts:                    []   ← populated from Phase 65.4.3 onward
generated_at:             <ISO8601 UTC>
```

## Execution Flow

### Step 0: Get PROJECT_NAME

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "current")"
```

### Step 1: Assemble snapshot

```bash
SNAPSHOT_JSON="$(mktemp /tmp/progress-snapshot-XXXX.json)"
bash scripts/progress-snapshot.sh \
  --plans Plans.md \
  --project "$PROJECT_NAME" \
  > "$SNAPSHOT_JSON"
```

`scripts/progress-snapshot.sh` (implemented in Phase 65.4.1) parses Plans.md
and outputs JSON conforming to the `progress-snapshot.v1` schema.

### Step 2: Render HTML

```bash
OUT_PATH="${OUT_PATH:-out/progress-snapshot.html}"
mkdir -p "$(dirname "$OUT_PATH")"

bash scripts/render-html.sh \
  --template progress \
  --data "$SNAPSHOT_JSON" \
  --out "$OUT_PATH"
```

### Step 3: Open in browser

Execute only when there is **no** `--no-open` flag (skip for background regeneration from PostToolUse hook):

```bash
bash scripts/plan-brief-open.sh --path "$OUT_PATH"
```

## Cross-project search (default OFF)

The `--cross-project-group <name>` flag will be added in Phase 65.4.4. In this cycle (65.4.1), it is default OFF and aggregates only the current project.

## Failure modes

| State | Behavior |
|---|---|
| Plans.md does not exist | `progress-snapshot.sh` exits 1 with a clear error message |
| No tasks at all in Plans.md | Generate snapshot with `progress_pct: 0` and empty arrays (HTML shows "no tasks") |
| State file (elapsed minutes etc.) is absent | Fall back with `elapsed_minutes: 0`, `cost_so_far_usd: 0` (no warning) |
| `git` absent / outside git repo | Fall back with `project: "current"` |

## Related

- `harness-plan-brief` (Phase 65.1.x) — 1st surface (pre-implementation briefing)
- `harness-accept` (Phase 65.2.x) — 2nd surface (acceptance decision)
- `harness-progress` (this skill, Phase 65.4.x) — 3rd surface (progress dashboard)
- 65.4.2 (PostToolUse auto-regen), 65.4.3 (5 drift alert types), 65.4.4 (past decision lookup) add features
