# GitHub Release Notes Rules

Formatting rules applied when creating GitHub Release notes.

## Required Format

### Structure

```markdown
## What's Changed

**One-line description of the change's value**

### Before / After

| Before | After |
|--------|-------|
| Previous state | New state |
| ... | ... |

---

## Added

- **Feature name**: Description
  - Detail 1
  - Detail 2

## Changed

- **Change**: Description

## Fixed

- **Fix**: Description

## Requirements (if applicable)

- **Claude Code vX.X.X+** (recommended)
- Link: [Documentation](URL)

---

Generated with [Claude Code](https://claude.com/claude-code)
```

### Required Elements

| Element | Required | Description |
|---------|----------|-------------|
| `## What's Changed` | Yes | Section heading |
| **Bold summary** | Yes | One-line value description |
| `Before / After` table | Yes | User-facing changes |
| `Added/Changed/Fixed` | When applicable | Detailed changes |
| Footer | Yes | `Generated with [Claude Code](...)` |

### Language

- **GitHub Release**: English required (public repository)
- **CHANGELOG.md**: English, detailed Before/After format (see below)
- Keep descriptions user-focused

## CHANGELOG Format (Detailed Before/After)

Describe each feature in CHANGELOG using a concrete "Before → After" format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Theme: [One-line summary of the overall change]

**[Value to the user in 1-2 sentences]**

---

#### 1. [Feature name]

**Before**: [Old behavior. Concrete description of the inconvenience the user experienced.]

**After**: [New behavior. What problem is solved + concrete examples.]

```example output or command```

#### 2. [Next feature name]

**Before**: ...
**After**: ...
```

**Writing rules**:
- Make each feature an independent section with `#### N. Feature Name`
- "Before" describes the **problem** (e.g., "you had to..." form)
- "After" describes the **concrete solution** (include command examples and output examples)
- Length is fine. Readability is the top priority.
- Technical details (filenames, step numbers) are included minimally as supplementary notes in "After"

## Prohibited

- No skipping the Before / After (CHANGELOG) or Before / After table (GitHub Release)
- No skipping the footer (GitHub Release)
- No technical-only descriptions (user perspective required)
- No bare change lists without value explanation

## Good Example (GitHub Release — English)

```markdown
## What's Changed

**`/work --full` now automates implement -> self-review -> improve -> commit in parallel**

### Before / After

| Before | After |
|--------|-------|
| `/work` executes tasks one at a time | `/work --full --parallel 3` runs in parallel |
| Reviews required separate manual step | Each task-worker self-reviews autonomously |
```

## Good Example (CHANGELOG)

```markdown
#### 1. Automatic re-ticketing of failed tasks

**Before**: When tests/CI failed, it would just retry 3 times and stop.
After stopping, you had to investigate the cause yourself and manually add a fix task to Plans.md.

**After**: When it stops after 3 failures, Harness classifies the failure cause and auto-generates a fix task proposal.
Once approved, it is automatically added to Plans.md as a `.fix` task.
```

## Bad Example

```markdown
## What's New

### Added
- Added task-worker.md
- Added --full option
```

-> Doesn't communicate user value

## Release Creation Command

```bash
gh release create vX.X.X \
  --title "vX.X.X - Title" \
  --notes "$(cat <<'EOF'
## What's Changed
...
EOF
)"
```

## Editing Past Releases

```bash
gh release edit vX.X.X --notes "$(cat <<'EOF'
...
EOF
)"
```

## CHANGELOG Pattern for CC Version Integration

For releases that include integration of a new Claude Code version, use the
**"CC update → Harness utilization" format** rather than the standard "Before / After" format.
By explaining from the upstream (CC) change's perspective first, readers can understand
"why this change is relevant to them" from the context.

### Trigger Conditions

Apply this pattern when any of the following applies:

- Version notation in the Feature Table has been updated
- A new CC-originated event has been added to hooks.json
- A usage guide for a new CC feature has been added to skills

### Structure

```markdown
#### N. Claude Code X.Y.Z Integration

(One-line overall summary)

##### N-1. Feature name

**CC update**: What changed in Claude Code. Explain in user-facing terms what the feature does.

**Harness utilization**: How Harness leverages that change. Include specific mechanisms (script names, flow).

##### N-2. Next feature name

**CC update**: ...
**Harness utilization**: ...
```

### Writing Rules

- Make each feature an independent section with `##### N-X.`
- "CC update" describes **the change in user experience**, not file changes
- "Harness utilization" describes **the specific mechanism** (what runs, what gets prevented)
- Avoid listing filenames. Write "prevents Worker freeze" rather than "updated hooks.json"
- Documentation-only changes (Feature Table updates, additional detail sections) are not separate entries; include them in the opening one-line summary

### Good Example

```markdown
##### 5-1. Automatic handling of MCP Elicitation

**CC update**: MCP servers can now ask the user "questions" during task execution (Elicitation).
For example, you might be prompted with a form input like "Which repository do you want to push to?"

**Harness utilization**: Breezing Workers run in the background and cannot respond to question forms.
If left unhandled, the Worker freezes. A new elicitation-handler.sh was created that auto-skips
during Breezing sessions while allowing normal sessions to pass through so the user can answer.
```

### Bad Example

```markdown
#### CC 2.1.76 Integration

- Added Elicitation to hooks.json
- Created elicitation-handler.sh
- Updated CLAUDE.md
```

-> A list of file changes that doesn't convey why the change was needed or what changes for the user

## Reference

- Good examples: v2.8.0, v2.8.2, v2.9.1, v3.10.3 (CC integration pattern)
- Keep consistent with CHANGELOG
