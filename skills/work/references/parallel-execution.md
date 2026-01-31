# Parallel Execution

This command **actively utilizes parallel execution**.

## Basic Policy

```
2+ independent tasks → Parallel execution (default)
Has dependencies → Sequential execution
```

## Parallel Execution Criteria

| Condition | Judgment | Example |
|-----------|----------|---------|
| Edit different files | ✅ Parallel | Header.tsx and Footer.tsx |
| Edit same file | ⚠️ Sequential | Append to same index.tsx |
| A's output is B's input | ⚠️ Sequential | Create API → Page using it |
| Independent checks | ✅ Parallel | lint, test, type-check |

## Execution Image

```
📋 Detected 5 tasks from Plans.md

Dependency analysis:
├── [Independent] Create Header
├── [Independent] Create Footer
├── [Independent] Create Sidebar
├── [Dependent] Create Layout ← Depends on Header, Footer, Sidebar
└── [Dependent] Create Page ← Depends on Layout

Execution plan:
🚀 Parallel group 1: Header, Footer, Sidebar (simultaneous)
   ↓
🔧 Sequential: Create Layout
   ↓
🔧 Sequential: Create Page

Estimated time: Sequential 5min → With parallel 2min30s (50% reduction)
```

## Task Tool Usage

Use Claude Code's Task tool to **execute in background in parallel**.

```
🚀 Starting parallel execution...

├── [Agent 1] Creating Header... ⏳
├── [Agent 2] Creating Footer... ⏳
└── [Agent 3] Creating Sidebar... ⏳
```

**Important**:
- Launch Task tool with `run_in_background: true`
- Collect results with `TaskOutput`
- Up to 10 tasks simultaneously

## Background Agent Permission Pre-approval (v2.1.20+)

Claude Code v2.1.20 以降、background agent は起動前にツール権限の承認を求めます。

**推奨設定**（プロジェクトの `.claude/settings.json` に手動で追加）:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Bash(npm run:*)",
      "Bash(pnpm:*)",
      "Bash(git diff:*)",
      "Bash(git status:*)",
      "Grep",
      "Glob"
    ]
  }
}
```

> 💡 task-worker は `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob` を使用します。
>
> ⚠️ **セキュリティ注意**: 信頼できるプロジェクトでのみ設定してください。

## Execution Patterns

### Pattern 1: Multiple Components (Parallel)

```
Input: Create Header, Footer, Sidebar

→ All 3 tasks independent → Parallel execution
→ Launch 3 agents with Task tool
→ Summarize results in integration report
```

### Pattern 2: Quality Checks (Parallel)

```
Input: Run lint, test, type-check

→ All independent → Parallel execution
→ Results:
  ├── [Lint] ✅ Warnings: 2
  ├── [Test] ✅ 15/15 passed
  └── [Type] ✅ No errors
```

### Pattern 3: Dependency Chain (Mixed)

```
Input: Create API → Page → Tests

→ Has dependencies → Sequential execution
→ But API tests and page tests can be parallelized
```
