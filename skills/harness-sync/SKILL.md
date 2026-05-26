---
name: harness-sync
description: "HAR: Sync Plans.md with implementation. Drift detect, marker update, retrospective. Trigger: sync-status, where am I, check progress. --snapshot for snapshots. Do NOT load for: planning, implementation, review, release."
description-en: "HAR: Sync Plans.md with implementation. Drift detect, marker update, retrospective. Trigger: sync-status, where am I, check progress. --snapshot for snapshots. Do NOT load for: planning, implementation, review, release."
kind: workflow
purpose: "Reconcile Plans.md, git, and implementation state"
trigger: "sync-status, where am I, check progress"
shape: workflow
role: synchronizer
pair: harness-plan
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "[--snapshot|--no-retro]"
user-invocable: true
effort: medium
---

# Harness Sync

Reconciles Plans.md with the implementation state and detects/updates drift.
Standalone replacement for the legacy `sync-status` and `harness-plan sync` subcommand.

## Quick Reference

| User input | Action |
|------------|--------|
| `harness-sync` | Progress sync + retrospective (default ON) |
| `harness-sync --no-retro` | Progress sync only (skip retro) |
| `harness-sync --snapshot` | Save a snapshot (point-in-time record of progress) |
| `harness-sync --plan roadmap` | Sync the named `roadmap` plan |
| "Where am I?" / "Check progress" | Same as above |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--snapshot` | Save current progress as a snapshot | false |
| `--no-retro` | Skip the retrospective | false (runs by default) |
| `--plan NAME` | Use the named plan from `plans/manifest.json` | active/default |

## Step 0: Plans.md Validation

Verify that Plans.md exists and is correctly formatted. If there is a problem, guide the user
immediately and stop. In repos with multiple Plans.md files, confirm the target plan with
`scripts/plan-registry.sh list` or `--plan NAME` before reading.

| State | Guidance |
|-------|---------|
| Plans.md does not exist | `Plans.md not found. Create it with harness-plan create.` → **stop** |
| Header lacks DoD / Depends columns (v1 format) | `Plans.md is in the old format (3 columns). Regenerate it as v2 (5 columns) with harness-plan create. Existing tasks will be carried over automatically.` → **stop** |
| v2 format (5 columns) | Proceed to Step 1 as-is |

## Step 1: Gather Current State (parallel)

```bash
# Plans.md state
cat Plans.md

# Git change state
git status
git diff --stat HEAD~3

# Recent commit history
git log --oneline -10

# Agent trace (recently edited files)
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

## Step 1.5: Agent Trace Analysis

Retrieve recent edit history from the Agent Trace and cross-reference with tasks in Plans.md:

```bash
# List of recently edited files
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.files[].path' | sort -u)

# Project info
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.metadata.project')
```

**Cross-reference points**:

| Check item | Detection method |
|------------|-----------------|
| File edits not in Plans.md | Agent Trace vs. task description |
| Files differing from task description | Expected files vs. actual edits |
| Tasks with no edits for a long time | Agent Trace timeline vs. WIP duration |

## Step 2: Drift Detection

| Check item | Detection method |
|------------|-----------------|
| Completed but still `cc:WIP` | Commit history vs. marker |
| Started but still `cc:TODO` | Changed files vs. marker |
| `cc:done` but not committed | git status vs. marker |

## Step 3: Plans.md Update Proposal

When drift is detected, propose and apply updates:

```
Plans.md update needed

| Task | Current | After | Reason |
|------|---------|-------|--------|
| XX   | cc:WIP | cc:done | Already committed |
| YY   | cc:TODO | cc:WIP | Files already edited |

Apply update? (yes / no)
```

## Step 4: Progress Summary Output

```markdown
## Progress Summary

**Project**: {{project_name}}

| Status | Count |
|--------|-------|
| Not started (cc:TODO) | {{count}} |
| In progress (cc:WIP) | {{count}} |
| Done (cc:done) | {{count}} |
| PM confirmed (pm:confirmed) | {{count}} |

**Progress rate**: {{percent}}%

### Recently Edited Files (Agent Trace)
- {{file1}}
- {{file2}}
```

## Step 4.5: Save Snapshot (when `--snapshot` is specified)

When `--snapshot` is specified, save the current progress state as a timestamped snapshot.

### Save location

Save in JSON format in the `.claude/state/snapshots/` directory:

```bash
SNAPSHOT_DIR="${PROJECT_ROOT}/.claude/state/snapshots"
mkdir -p "${SNAPSHOT_DIR}"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/progress-$(date -u +%Y%m%dT%H%M%SZ).json"
```

### Snapshot contents

```json
{
  "timestamp": "2026-03-08T10:30:00Z",
  "phase": "Phase 26",
  "progress": {
    "total": 16,
    "todo": 5,
    "wip": 3,
    "done": 6,
    "confirmed": 2
  },
  "progress_rate": 50,
  "recent_commits": ["abc1234 feat: ...", "def5678 fix: ..."],
  "recent_files": ["skills/harness-work/SKILL.md", "..."],
  "notes": ""
}
```

### Diff comparison

When a previous snapshot exists, display the diff:

```markdown
## Snapshot Diff

| Metric | Previous ({{prev_time}}) | Current | Change |
|--------|--------------------------|---------|--------|
| Progress rate | {{prev}}% | {{current}}% | +{{diff}}%pt |
| Completed tasks | {{prev_done}} | {{current_done}} | +{{diff_done}} |
| WIP tasks | {{prev_wip}} | {{current_wip}} | {{diff_wip}} |
```

> **Design intent**: Snapshots are used manually when the user wants to "record the current state."
> This is a separate feature from the automatic progress feed during breezing (26.2.3).

## Step 5: Next Action Proposal

```
Next steps

**Priority 1**: {{task}}
- Reason: {{requested / waiting to unblock}}

**Recommended**: harness-work, harness-review
```

## Anomaly Detection

| Situation | Warning |
|-----------|---------|
| Multiple `cc:WIP` entries | Multiple tasks are in progress simultaneously |
| Unprocessed `pm:requested` | Process PM requests first |
| Large drift | Task management is falling behind |
| WIP not updated for 3+ days | Check whether the task is blocked |

## Step 6: Retrospective (default ON)

Automatically runs a retrospective when there is at least 1 `cc:done` task.
Can be explicitly skipped with `--no-retro`.

### Step R1: Collect Completed Tasks

```bash
# Extract cc:done / pm:confirmed tasks from Plans.md
grep -E 'cc:done|pm:confirmed' Plans.md

# Recent completion commit history
git log --oneline --since="7 days ago"

# Change scale
git diff --stat HEAD~10
```

### Step R2: Retrospective 4 Items

| Item | Analysis method |
|------|----------------|
| **Estimation accuracy** | Infer expected file count from task descriptions in Plans.md → compare with actual changed file count from `git diff --stat` |
| **Blocking causes** | Aggregate reason patterns for tasks that received a `blocked` marker (technical / external dependency / unclear spec) |
| **Quality marker hit rate** | Did tasks tagged with `[feature:security]` etc. actually produce related issues? |
| **Scope variation** | Task count at the initial commit of Plans.md vs. current task count (added/removed) |

### Step R3: Retrospective Summary Output

```markdown
## Retrospective Summary

**Period**: {{start_date}} – {{end_date}}

| Metric | Value |
|--------|-------|
| Completed tasks | {{count}} |
| Blocks encountered | {{blocked_count}} |
| Scope variation | +{{added}} / -{{removed}} |
| Estimation accuracy | Expected {{est}} files → Actual {{actual}} files |

### Learnings
- {{1–2 lines of learning}}

### Next improvements
- {{1–2 lines of improvement actions}}
```

### Step R4: Record to harness-mem

Record the retrospective results in harness-mem so they can be referenced during the next `create`.
Record location: the relevant agent memory under `.claude/agent-memory/`.

## Related Skills

- `harness-plan` — Plan creation and task management
- `harness-work` — Task implementation
- `harness-review` — Code review
