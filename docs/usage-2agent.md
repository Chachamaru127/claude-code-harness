# 2-Agent Mode Usage Guide

> **Cursor (PM) + Claude Code (Worker)** の詳細な使い方ガイド

---

## Overview

2-Agent モードでは、Cursor と Claude Code が役割分担して開発を進めます。

| Agent | Role | Responsibilities |
|-------|------|------------------|
| **Cursor** | PM (Project Manager) | 要件整理、タスク分解、レビュー、本番デプロイ判断 |
| **Claude Code** | Worker (Developer) | 実装、テスト、CI修正、stagingデプロイ |

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         2-AGENT WORKFLOW                                     │
│                                                                             │
│                         ┌─────────────────────┐                             │
│                         │        You          │                             │
│                         │   (Coordinator)     │                             │
│                         └──────────┬──────────┘                             │
│                                    │                                        │
│   ┌────────────────────────────────┼────────────────────────────────┐       │
│   │                                │                                │       │
│   ▼                                │                                ▼       │
│ ┌──────────────────┐               │               ┌──────────────────┐     │
│ │     Cursor       │               │               │   Claude Code    │     │
│ │      (PM)        │               │               │    (Worker)      │     │
│ └────────┬─────────┘               │               └────────┬─────────┘     │
│          │                         │                        │               │
│          │ 1. Create plan          │                        │               │
│          │    /handoff-to-claude        │                        │               │
│          │                         │                        │               │
│          └──────────────────────►  │ 2. Copy task           │               │
│                                    │    to Claude Code      │               │
│                                    │ ─────────────────────► │               │
│                                    │                        │               │
│                                    │                        │ 3. /start-task│
│                                    │                        │    /work      │
│                                    │                        │               │
│                                    │ 4. Copy result         │               │
│          ◄──────────────────────── │    to Cursor           │               │
│          │                         │ ◄───────────────────── │               │
│          │                         │    /handoff-to-cursor  │               │
│          │ 5. Review & approve     │                        │               │
│          │    /review-cc-work      │                        │               │
│          │                         │                        │               │
│          │ 6. Deploy to production │                        │               │
│          │    (PM decision)        │                        │               │
│          │                         │                        │               │
└──────────┴─────────────────────────┴────────────────────────┴───────────────┘
```

---

## Step-by-Step Guide

### Step 1: Plugin Setup (One-time)

In Claude Code, run:
```
/setup-2agent
```

This creates:
- `AGENTS.md` - Shared workflow rules
- `Plans.md` - Task tracking (shared between agents)
- `.cursor/commands/` - Cursor commands for PM
- `.cursor-cc-version` - Version tracking file

> **Note**: `/setup-2agent` はプラグインの初期設定です。新しいプロジェクトを1から作る場合は、この後に `/init` を実行します。既存プロジェクトに導入する場合は `/init` は不要です。

### Step 2: Start a New Feature (Cursor)

In Cursor, describe what you want:

```
User: "I want to add user authentication"

Cursor (PM):
"Breaking this down into tasks:
 - [ ] Create login page
 - [ ] Create signup page
 - [ ] Connect authentication backend

 Adding to Plans.md with marker: cursor:requested"

Cursor: /handoff-to-claude
"📋 Task ready for Claude Code. Please copy this to Claude Code."
```

### Step 3: Implement (Claude Code)

Copy the task from Cursor, then in Claude Code:

```
User: (paste task from Cursor)

Claude Code: /start-task
"Found task: User authentication
 Status: cursor:requested → cc:WIP

 Starting implementation..."

(Claude Code writes code, runs tests)

Claude Code: /handoff-to-cursor
"📋 Task Complete Report:
 ✅ Created src/app/login/page.tsx
 ✅ Created src/app/signup/page.tsx
 ✅ CI: Passing

 Please copy this report to Cursor for review."
```

### Step 4: Review (Cursor)

Copy the completion report to Cursor:

```
User: (paste completion report)

Cursor: /review-cc-work
"Reviewing changes...
 ✅ Login page implemented
 ✅ Signup page implemented
 ✅ Tests passing

 Approve for production? (Y/N)"
```

---

## Task Status Markers

| Marker | Meaning | Who Sets It |
|--------|---------|-------------|
| `cursor:requested` | Task assigned by PM | Cursor |
| `cc:TODO` | Not started | Claude Code |
| `cc:WIP` | Work in progress | Claude Code |
| `cc:done` / `cc:完了` | Completed, awaiting review | Claude Code |
| `cursor:verified` | Reviewed and approved | Cursor |

---

## Conversation Examples

### Example: Adding a Feature

**Phase 1: Planning (Cursor)**
```
User: "Add a search function"

Cursor: "I'll break this into tasks:
 1. Add search input component
 2. Implement search API endpoint
 3. Connect frontend to backend
 4. Add loading states

 Creating task for Claude Code..."
```

**Phase 2: Implementation (Claude Code)**
```
User: (paste task)

Claude Code: "Starting search implementation...
 ✅ Created SearchInput.tsx
 ✅ Created /api/search endpoint
 ✅ Connected with React Query
 ✅ Added Skeleton loading

 Ready for review."
```

**Phase 3: Review (Cursor)**
```
User: (paste completion report)

Cursor: "Reviewing search feature...
 - Code quality: Good
 - Test coverage: 85%
 - No security issues

 ✅ Approved. Ready for production."
```

---

## Error Handling

### CI Failure (Claude Code)

Claude Code automatically retries up to 3 times:

```
Claude Code: "CI failed. Analyzing...
 Error: Type mismatch in SearchInput.tsx:42

 Fixing automatically... (Attempt 1/3)

 ✅ Fixed. CI now passing."
```

### Escalation (After 3 Failures)

```
Claude Code: "⚠️ CI failed 3 times. Escalating to Cursor.

 Error summary:
 - TypeScript errors in auth module
 - Attempted fixes: [list]

 Please review in Cursor."
```

---

## Best Practices

1. **One task = One handoff**: Don't batch multiple features
2. **Clear completion criteria**: Define "done" before starting
3. **Regular sync**: Use `/sync-status` to check progress
4. **Trust but verify**: Always review before production deploy
