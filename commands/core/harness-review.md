---
description: Code review (multi-perspective security/performance/quality)
description-en: Code review (multi-perspective security/performance/quality)
context: fork
hooks:
  - event: PreCommandInvoke
    type: command
    command: "${CLAUDE_PLUGIN_ROOT}/scripts/check-codex.sh"
    once: true
---

# /harness-review - Code Review (Solo Mode)

Checks the quality of created code.
Analyzes from multiple perspectives and suggests improvements.

---

## 💡 VibeCoder Usage Guide

**This command is designed so you can receive high-quality code review without technical knowledge.**

- ✅ Auto-detect security issues
- ✅ Suggest performance improvements
- ✅ Auto-check code quality
- ✅ Verify accessibility compliance

**Important for contract development**: You can submit review results as a report to reassure clients

---

## 🔧 Auto-invoke Skills (Required)

**This command must explicitly invoke the following skills with the Skill tool**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `review` | Review (parent skill) | At review start |
| `codex-review` | Codex second opinion | When Codex is enabled (optional) |

**How to call**:
```
Use Skill tool:
  skill: "claude-code-harness:review"
```

**Child skills (auto-routing)**:
- `review-security` - Security review
- `review-performance` - Performance review
- `review-quality` - Code quality review
- `review-accessibility` - Accessibility review
- `review-aggregate` - Aggregate review results

> ⚠️ **Important**: Proceeding without calling skills won't record in usage statistics. Always call with Skill tool.

---

## 🔧 LSP Feature Utilization

Reviews utilize LSP (Language Server Protocol) for more accurate analysis.

### Code Quality Check with LSP Diagnostics

```
📊 LSP Diagnostic Results

File: src/components/UserForm.tsx

| Line | Severity | Message |
|------|----------|---------|
| 15 | Error | Type 'string' cannot be assigned to type 'number' |
| 23 | Warning | 'tempData' is declared but not used |
| 42 | Info | This async function has no await |

→ Auto-detect type errors and unused variables
```

### Impact Analysis with LSP Find-references

Analyze where changed code is used with LSP:

```
🔍 Change Impact Scope

Changed: src/utils/formatDate.ts

Reference locations:
├── src/components/DateDisplay.tsx:12
├── src/components/EventCard.tsx:45
├── src/pages/Dashboard.tsx:78
└── tests/utils/formatDate.test.ts:5

→ Impacts 4 files
→ Confirmed covered by tests ✅
```

### Integration with Review Perspectives

| Review Perspective | LSP Usage |
|-------------------|-----------|
| **Quality** | Detect type errors and unused code with Diagnostics |
| **Security** | Track sensitive data flow with reference analysis |
| **Performance** | Confirm heavy processing implementation with definition jump |

### VibeCoder Phrases

| What You Want | How to Say |
|---------------|------------|
| Check type errors | "Review including LSP diagnostics" |
| Know change impact | "Check where this change affects" |

Details: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## Purpose of This Command

**Automates quality assurance for contract development**.

- Ensure quality of code submitted to clients
- Detect security risks in advance
- Find performance issues early
- Verify accessibility compliance

---

## Execution Flow

### Step 0: Codex Second Opinion Check (auto-execute with once hook)

**Automatically checks Codex availability with `once: true` hook on first execution.**

Hook defined in this command's frontmatter:
```yaml
hooks:
  - event: PreCommandInvoke
    type: command
    command: "${CLAUDE_PLUGIN_ROOT}/scripts/check-codex.sh"
    once: true
```

**Behavior**:
- `check-codex.sh` runs only on first `/harness-review` execution in session
- If Codex is installed, guides how to enable
- Auto-skips on subsequent runs (`once: true` effect)

**To enable Codex**:

Add the following to project config (`.claude-code-harness.config.yaml`):
```yaml
review:
  codex:
    enabled: true
```

> 💡 **To run Codex review only manually**: Use `/codex-review` command

---

### Step 0.5: Remaining Context Check (Codex mode)

Before Codex parallel review, **run /compact first if remaining context is 30% or less**.

> **Note**: Continue with Codex parallel review even if space is still tight after /compact.

---

### Step 1: Identify Changed Files

```bash
# Check recent changes
git diff --name-only HEAD~5 2>/dev/null || find . -name "*.ts" -o -name "*.tsx" -o -name "*.py" | head -20
```

### Step 2: Execute Parallel Reviews

Execute parallel reviews from the following perspectives. Use **Task tool** to launch multiple subagents simultaneously and reduce review time.

**💡 True parallel execution with async subagents**:
Run each review individually and send to background with `Ctrl+B` for fully parallel execution. See [Async Subagents Guide](../docs/ASYNC_SUBAGENTS.md) for details.

**Manual parallel execution steps**:
1. Run `/harness-review security` → `Ctrl+B` to background
2. Run `/harness-review performance` → `Ctrl+B` to background
3. Run `/harness-review quality` → `Ctrl+B` to background
4. Run `/harness-review accessibility` → `Ctrl+B` to background
5. Auto-notification when each subagent completes

**Mode-specific parallel execution:**

#### Default Mode (`review.mode: default`) - Launch 4 parallel code-reviewers with Task tool

```
🔍 Starting parallel review...

Task tool #1: subagent_type="code-reviewer" → Security perspective
Task tool #2: subagent_type="code-reviewer" → Performance perspective
Task tool #3: subagent_type="code-reviewer" → Quality perspective
Task tool #4: subagent_type="code-reviewer" → Accessibility perspective

→ 4 subagents execute in parallel
→ Integrate results and output overall evaluation
```

#### Codex Mode (`review.mode: codex`) - MCP parallel execution with only needed experts

**⚠️ Important: Do not combine multiple experts in one call**

```
🔍 Starting Codex parallel review...

1. Determine which experts to call (only needed ones, not all):
   - enabled: false in config → exclude
   - CLI/backend → exclude Accessibility, SEO
   - Document only changes → prioritize Quality, Architect, Plan Reviewer, Scope Analyst

2. Load prompts individually from enabled experts' experts/*.md

3. Execute mcp__codex__codex in parallel within 1 response for enabled experts only:
   Example: Web frontend with code changes → 6 experts in parallel
   mcp__codex__codex({prompt: security-expert.md})
   mcp__codex__codex({prompt: accessibility-expert.md})
   mcp__codex__codex({prompt: performance-expert.md})
   mcp__codex__codex({prompt: quality-expert.md})
   mcp__codex__codex({prompt: seo-expert.md})
   mcp__codex__codex({prompt: architect-expert.md})

→ Only needed experts execute in parallel (cost optimization)
→ Integrate each expert's results for judgment
```

**Details**: `skills/codex-review/references/codex-parallel-review.md`

Review perspectives:

#### 🔒 Security Check

- [ ] Proper environment variable management
- [ ] Input validation
- [ ] SQL injection protection
- [ ] XSS protection
- [ ] Authentication/authorization implementation

#### ⚡ Performance Check

- [ ] Unnecessary re-renders
- [ ] N+1 queries
- [ ] Heavy computation optimization
- [ ] Image/asset optimization

#### 📐 Code Quality Check

- [ ] Proper TypeScript type usage
- [ ] Error handling
- [ ] Naming convention consistency
- [ ] Appropriate file structure

#### ♿ Accessibility Check (for Web)

- [ ] Semantic HTML
- [ ] Alt text
- [ ] Keyboard navigation
- [ ] Color contrast

### Step 2.5: Result Integration and Codex Verification (when Codex enabled)

**When `codex.enabled: true`, Claude verifies Codex review results and determines if fixes are needed.**

```
📊 Integrating review results...

1. Aggregate Claude 4-perspective review results
2. Get Codex review results
3. Claude verifies Codex findings
   - Is the finding valid?
   - Is a fix needed?
   - What's the priority?
```

**Result integration and verification**:

```markdown
## 📊 Review Result Comparison

| Perspective | Claude | Codex | Match |
|-------------|--------|-------|-------|
| Security | 2 issues | 1 issue | 1 common |
| Performance | 1 issue | 2 issues | 1 common |

### 🔴 Both Flagged (High Priority - Fix Recommended)
- Possible SQL injection (src/api/users.ts:45)
  → **Claude verification**: Valid. Need to fix with parameterized queries

### 🟡 Claude Only Flagged
- Unused variable (src/utils/helpers.ts:12)
  → **Fix recommended**: Delete or use

### 🟢 Codex Only Flagged (Claude Verified)
- Possible N+1 query (src/api/posts.ts:30)
  → **Claude verification**: Valid. Should add prefetch
```

**Fix proposal and approval flow**:

```markdown
## 🔧 Items Requiring Fixes

Add the following fixes to Plans.md and execute with `/work`?

| # | Fix Content | File | Priority |
|---|-------------|------|----------|
| 1 | SQL injection protection | src/api/users.ts:45 | High |
| 2 | N+1 query fix | src/api/posts.ts:30 | Medium |
| 3 | Delete unused variable | src/utils/helpers.ts:12 | Low |

**Options:**
1. Approve all → Add to Plans.md and run `/work`
2. Approve selected → Specify numbers (e.g., 1,2)
3. Don't fix now → Save report only
```

**Flow after approval**:

```
User approval
    ↓
Add fix tasks to Plans.md
    ↓
Auto-run /work (or suggest execution)
    ↓
Re-review after fix completion (optional)
```

> 💡 **To run Codex review only**: Use `/codex-review` command

---

### Step 3: Output Review Results

> 📊 **Code Review Results**
>
> **Overall Rating**: {{A / B / C / D}}
>
> ---
>
> ### 🔒 Security: {{Rating}}
> {{Issues or "No issues"}}
>
> ### ⚡ Performance: {{Rating}}
> {{Issues or "No issues"}}
>
> ### 📐 Code Quality: {{Rating}}
> {{Issues or "No issues"}}
>
> ### ♿ Accessibility: {{Rating}}
> {{Issues or "No issues"}}
>
> ---
>
> ### 🔧 Improvement Suggestions
>
> 1. {{Specific improvement 1}}
> 2. {{Specific improvement 2}}
>
> **Fix automatically?** (y / n / select)

### Step 4: Execute Improvements (after user approval)

Automatically execute approved improvements:

```bash
# Example: ESLint auto-fix
npx eslint --fix src/

# Example: Apply Prettier
npx prettier --write src/
```

### Step 5: Completion Report

> ✅ **Review Complete**
>
> **Fixed items:**
> - {{fix1}}
> - {{fix2}}
>
> **Next steps:**
> Say "commit" or "proceed to next phase".

### Step 6: Commit Guard Integration (Require review before commit)

**If review result is APPROVE, generate state file to allow commit.**

This feature blocks commit attempts without review.

**Operation flow**:
```
/harness-review execution
    ↓
Review result is APPROVE
    ↓
Generate .claude/state/review-approved.json
    ↓
git commit is allowed
    ↓
Clear review-approved.json after successful commit
    ↓
Review required again before next commit
```

**State file generation (auto-execute on APPROVE)**:

```bash
# If review result is APPROVE, execute:
mkdir -p .claude/state
cat > .claude/state/review-approved.json << 'EOF'
{
  "judgment": "APPROVE",
  "approved_at": "{{ISO 8601 timestamp}}",
  "reviewed_files": ["{{changed_files}}"],
  "review_summary": "{{summary}}"
}
EOF
```

**To disable commit guard**:

Add to `.claude-code-harness.config.yaml`:
```yaml
commit_guard: false
```

> 💡 **Note**: Disabling commit guard allows commits without review. Recommended to keep enabled for production projects.

---

## Review Perspective Details

### Security

```typescript
// ❌ Bad example
const apiKey = "sk-REDACTED"  // Hardcoded (example)

// ✅ Good example
const apiKey = process.env.API_KEY  // Environment variable
```

### Performance

```typescript
// ❌ Bad example
const Component = () => {
  const data = heavyCalculation()  // Calculates every time
  return <div>{data}</div>
}

// ✅ Good example
const Component = () => {
  const data = useMemo(() => heavyCalculation(), [])
  return <div>{data}</div>
}
```

### Code Quality

```typescript
// ❌ Bad example
function f(x: any) { return x.y.z }  // any type, no error handling

// ✅ Good example
function getNestedValue(obj: NestedObject): string | null {
  return obj?.y?.z ?? null
}
```

---

## VibeCoder Simplified Version

When technical details are not needed:

> 📊 **Check Results**
>
> - Security: ✅ OK
> - Speed: ✅ OK
> - Code quality: ⚠️ 2 improvements
>
> Say "fix it" to auto-fix.

---

## Options

```
/harness-review              # Check all
/harness-review security     # Security only
/harness-review performance  # Performance only
/harness-review quick        # Quick check
```

---

## ⚡ Parallel Execution Decision Points

Review perspectives (Security/Performance/Quality/Accessibility/Codex) are **independent of each other**, so parallel execution is effective.

### When to Execute in Parallel ✅

| Condition | Reason |
|-----------|--------|
| Full review (all 4 perspectives) | Maximum time savings |
| Codex enabled (5 perspectives) | Codex also runs in parallel |
| 5+ changed files | Each perspective takes longer |
| Need results quickly | Before PR merge, etc. |

**Parallel execution effect (Codex enabled)**:
```
🚀 Starting parallel review...
├── [Security] Analyzing... ⏳
├── [Performance] Analyzing... ⏳
├── [Quality] Analyzing... ⏳
├── [Accessibility] Analyzing... ⏳
└── [Codex] Getting second opinion... ⏳

⏱️ Time: 35s (would be +30s if sequential Codex)
```

### When to Execute Sequentially ⚠️

| Condition | Reason |
|-----------|--------|
| Single perspective only (`/harness-review security`) | No parallelization needed |
| 1-2 changed files | Each perspective is quick |
| Want to check issues one by one | Progress interactively |

### Auto-decision Logic

```
Review perspectives >= 3 AND changed files >= 5 → Parallel execution (Task tool)
Review perspectives < 3 OR changed files < 5 → Sequential execution
```

### Manual Parallel Execution

```bash
# Execute in parallel in background
/harness-review security     # → Ctrl+B to background
/harness-review performance  # → Ctrl+B to background
/harness-review quality      # → Ctrl+B to background
/harness-review accessibility # Last one waits

# Integrate results and report
```
