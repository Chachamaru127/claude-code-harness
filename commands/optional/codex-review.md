---
description: Second-opinion code review using Codex MCP
description-en: Second-opinion code review using Codex MCP
---

# /codex-review - Codex Second Opinion Review

Get a second opinion code review using OpenAI Codex.

---

## 🎯 Quick Reference

- "`/codex-review`" → Request review from Codex
- "Have Codex take a look too" → this command
- "Want another AI's opinion" → this command

---

## Deliverables

- Get a second opinion from Codex in addition to Claude's review
- Leverage different AI models' strengths (logical reasoning vs implementation pattern knowledge)
- Display integrated review results

---

## 🔧 Auto-invoke Skills (Required)

**This command must explicitly invoke the following skills with the Skill tool**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `codex-review` | Codex integration (parent skill) | At command start |

**How to call**:
```
Use Skill tool:
  skill: "claude-code-harness:codex-review"
```

---

## Prerequisites

### 1. Codex CLI is Installed

```bash
which codex  # Path should be displayed
```

### 2. Logged into Codex

```bash
codex login status  # Should be authenticated
```

### 3. Registered as MCP Server

```bash
claude mcp list  # codex should be displayed
```

**If not configured**:
```bash
claude mcp add --scope user codex -- codex mcp-server
```

---

## Execution Flow

### Step 0: Check Remaining Context

Before Codex review, **run /compact first if remaining context is 30% or less**.

> **Note**: Continue with Codex review even if space is still tight after /compact.

### Step 1: Check Codex Environment & Version

```bash
# Check if Codex is available
which codex && codex login status

# Check version
codex --version
npm show @openai/codex version  # Latest version
```

**If not configured**:
```markdown
⚠️ Codex is not configured

Setup instructions:
1. Install Codex CLI
2. Authenticate with `codex login`
3. Register with `claude mcp add --scope user codex -- codex mcp-server`

Details: `skills/codex-review/references/codex-mcp-setup.md`
```

**If version is outdated**:
```markdown
⚠️ Codex CLI is outdated

Installed: X.X.X
Latest version: Y.Y.Y

Update? (y/n)

→ If approved:
npm update -g @openai/codex
```

### Step 2: Identify Changed Files

```bash
git diff --name-only HEAD~1 2>/dev/null || git status --short
```

### Step 3: Execute Codex Review

Execute Codex CLI directly (progress displayed in real-time on STDERR):

```bash
codex exec "Review the following code changes and output issues and improvement suggestions:

Files: {changed_files}

{file_contents}"
```

> **Legacy mode**: Set `execution_mode: mcp` to use MCP (no progress display)

**Configuration**:
```yaml
# .claude-code-harness.config.yaml
review:
  codex:
    model: gpt-5.2-codex        # Recommended (top-tier model)
    # execution_mode: mcp       # Legacy: MCP (no progress display)
```

### Step 4: Claude Verification

**Claude verifies Codex's findings and determines if fixes are needed.**

```markdown
## 🤖 Codex Review Results (Claude Verified)

### Issues

| File | Line | Severity | Content | Claude Verification |
|------|------|----------|---------|---------------------|
| src/api/users.ts | 45 | High | Possible SQL injection | ✅ Valid |
| src/utils/calc.ts | 12 | Medium | Calculation precision issue | ⚠️ Needs confirmation |

### Improvement Suggestions (Verified)

1. Recommend using parameterized queries → **Fix recommended**
2. Add input validation → **Fix recommended**
```

### Step 5: Fix Proposal and Approval

```markdown
## 🔧 Items Requiring Fixes

Add the following fixes to Plans.md and execute with `/work`?

| # | Fix Content | File | Priority |
|---|-------------|------|----------|
| 1 | SQL injection protection | src/api/users.ts:45 | High |
| 2 | Add input validation | src/api/users.ts | Medium |

**Options:**
1. Approve all → Add to Plans.md and run `/work`
2. Approve selected → Specify numbers (e.g., 1)
3. Don't fix now → Report only
```

### Step 6: Apply to Plans.md and Execute (On Approval)

```
User approval
    ↓
Add fix tasks to Plans.md:
  - [ ] [bugfix] SQL injection protection (src/api/users.ts:45)
  - [ ] [feature] Add input validation
    ↓
Run /work (or suggest execution)
    ↓
Fix complete
```

---

## Options

```
/codex-review              # Review all changed files
/codex-review src/         # Specific directory only
/codex-review --security   # Focus on security perspective
```

---

## Difference from /harness-review

| Command | Content |
|---------|---------|
| `/harness-review` | Full review by Claude (+ optional Codex) |
| `/codex-review` | Codex standalone review |

**Recommendation**: Normally use `/harness-review`, use `/codex-review` when additional second opinion is needed

---

## Related Commands

- `/harness-review` - Full review (Claude + optional Codex)
- `/harness-init` - Project initialization (includes Codex setup)
