# sync subcommand — progress sync flow

Compare the implementation state with Plans.md and detect and apply differences.

## Step 0: Validate Plans.md

Verify that Plans.md exists and has a valid format. If there is a problem, immediately guide the user and stop.

| State | Guidance |
|-------|----------|
| Plans.md does not exist | `Plans.md not found. Please create one with /harness-plan create.` → **stop** |
| Header is missing DoD / Depends columns (v1 format) | `Plans.md is in the old format (3 columns). Please regenerate it as v2 (5 columns) with /harness-plan create. Existing tasks will be carried over automatically.` → **stop** |
| v2 format (5 columns) | Proceed to Step 1 as-is |

## Step 1: Collect current state (in parallel)

```bash
# State of Plans.md
cat Plans.md

# Git change state
git status
git diff --stat HEAD~3

# Recent commit history
git log --oneline -10

# Agent trace (recently edited files)
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

## Step 1.5: Analyze Agent Trace

Fetch the recent edit history from the Agent Trace and compare it with the tasks in Plans.md:

```bash
# List of recently edited files
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.files[].path' | sort -u)

# Project info
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.metadata.project')
```

**Comparison points**:

| Check item | Detection method |
|------------|------------------|
| File edits not in Plans.md | Agent Trace vs task descriptions |
| Files different from task descriptions | Expected files vs actual edits |
| Tasks with no recent edits | Agent Trace timeline vs WIP duration |

## Step 2: Detect differences

| Check item | Detection method |
|------------|------------------|
| Already completed but still `cc:WIP` | Commit history vs marker |
| Already started but still `cc:TODO` | Changed files vs marker |
| Marked `cc:done` but not yet committed | git status vs marker |

### Artifact hash backward compatibility

Recognize both the `cc:done [a1b2c3d]` format (with commit hash) and `cc:done` (without hash).

**Matching rules**:
- `cc:done` → treat as done without hash
- `cc:done [xxxxxxx]` → treat as done with hash. Retain the 7-character short hash
- When a hash is present, the commit's existence can be verified against `git log --oneline`

> **Backward compatible**: The format without a hash remains valid. Does not break existing Plans.md files.

## Step 3: Propose Plans.md updates

When differences are detected, propose and apply them:

```
Plans.md update needed

| Task | Current | After | Reason |
|------|---------|-------|--------|
| XX   | cc:WIP | cc:done | Committed |
| YY   | cc:TODO | cc:WIP | Files edited |

Update? (yes / no)
```

## Step 4: Output progress summary

```markdown
## Progress Summary

**Project**: {{project_name}}

| Status | Count |
|--------|-------|
| Not started (cc:TODO) | {{count}} |
| In progress (cc:WIP) | {{count}} |
| Done (cc:done) | {{count}} |
| PM approved (pm:approved) | {{count}} |

**Progress**: {{percent}}%

### Recently edited files (Agent Trace)
- {{file1}}
- {{file2}}
```

## Step 5: Propose next actions

```
Next steps

**Priority 1**: {{task}}
- Reason: {{requested / waiting to unblock}}

**Recommended**: harness-work, harness-review
```

## Anomaly detection

| Situation | Warning |
|-----------|---------|
| Multiple `cc:WIP` | Multiple tasks in progress simultaneously |
| Unprocessed `pm:requested` | Process the PM's request first |
| Large discrepancy | Task management is falling behind |
| WIP not updated for 3+ days | Check whether it is blocked |

## Step 6: Retrospective (default ON)

When `sync` runs and there is at least one `cc:done` task, automatically run a retrospective.
Can be explicitly skipped with `--no-retro`.

### Step R1: Collect completed tasks

```bash
# Extract cc:done / pm:approved tasks from Plans.md
grep -E 'cc:done|pm:approved' Plans.md

# Recent completion commit history
git log --oneline --since="7 days ago"

# Change scale
git diff --stat HEAD~10
```

### Step R2: Four retrospective items

| Item | Analysis method |
|------|----------------|
| **Estimate accuracy** | Infer expected file count from task descriptions in Plans.md → compare with actual changed file count from `git diff --stat` |
| **Blocker causes** | Tally the reason patterns for tasks marked `blocked` (technical / external dependency / unclear spec) |
| **Quality marker hit rate** | Did tasks with markers like `[feature:security]` actually produce related issues? |
| **Scope change** | Number of tasks in Plans.md at first commit vs now (added/removed count) |

### Step R3: Output retrospective summary

```markdown
## Retrospective Summary

**Period**: {{start_date}} – {{end_date}}

| Metric | Value |
|--------|-------|
| Completed tasks | {{count}} |
| Blockers occurred | {{blocked_count}} |
| Scope change | +{{added}} / -{{removed}} |
| Estimate accuracy | Expected {{est}} files → Actual {{actual}} files |

### Learnings
- {{1–2 lines of learnings}}

### What to apply next time
- {{1–2 lines of improvement actions}}
```

### Step R4: Record to harness-mem

Record the retrospective results in harness-mem so they can be referenced during the next `create`.
Record destination: the relevant agent memory under `.claude/agent-memory/`.
