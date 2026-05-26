# Command Reference

Details of commands used in the two-agent workflow.

---

## Claude Code Commands

### /setup

Initial project setup (replaces `/harness-init`).

```
/setup
```

**Files generated**:
- Plans.md - Task management
- AGENTS.md - Role assignment definition
- CLAUDE.md - Claude Code configuration
- .claude/rules/ - Project rules

---

### /setup codex

Install/update Harness configuration for Codex CLI at the **user level** (`${CODEX_HOME:-~/.codex}`).

```
/setup codex
```

**Files generated (default)**:
- ${CODEX_HOME:-~/.codex}/skills/
- ${CODEX_HOME:-~/.codex}/rules/
- (optional) ${CODEX_HOME:-~/.codex}/config.toml

**Project mode only**:
- .codex/skills/
- .codex/rules/
- AGENTS.md

---

### /plan-with-agent

Plan and break down tasks.

```
/plan-with-agent [task description]
```

**Example**:
```
/plan-with-agent I want to implement user authentication
```

**Output**: Tasks are added to Plans.md

---

### /work

Execute tasks from Plans.md.

```
/work
```

**Features**:
- Auto-detects `cc:TODO` or `pm:依頼中` tasks
- Supports parallel execution of multiple tasks
- Automatically updates to `cc:完了` on completion

---

### /sync-status

Output a summary of the current state.

```
/sync-status
```

**Example output**:
```
📊 Current Status
- In progress: 2
- Not started: 5
- Complete (awaiting confirmation): 1
```

---

### /handoff-to-cursor

Completion report to Cursor PM.

```
/handoff-to-cursor
```

**Included information**:
- List of completed tasks
- Changed files
- Test results
- Suggested next actions

---

## Cursor Commands (Reference)

### /handoff-to-claude

Request tasks from Claude Code.

### /review-cc-work

Review Claude Code's completion reports.
If changes are requested (request_changes), update Plans.md and **use `/claude-code-harness/handoff-to-claude` to generate a revision request and pass it along directly**.

---

## Skills (auto-invoked in conversation)

### handoff-to-pm

**Trigger**: "Report completion to PM", "report that work is done"

Generates a completion report from Worker to PM.

### handoff-to-impl

**Trigger**: "Hand off to the implementer", "request from Claude Code"

Formats a task request from PM to Worker.

---

## Command Usage Flow

```
[Session start]
    │
    ▼
/sync-status  ←── Check current state
    │
    ▼
/work  ←── Execute tasks
    │
    ▼
/handoff-to-cursor  ←── Report completion
    │
    ▼
[Session end]
```
