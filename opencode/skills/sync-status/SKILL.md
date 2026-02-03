---
name: sync-status
description: "Checks progress, updates Plans.md to match reality, and suggests next action. Use when user mentions '/sync-status', progress check, where am I at, or sync Plans.md. Do NOT load for: casual 'how is it going' chat, informal progress questions."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "[--verbose]"
---

# Sync Status Skill

Checks current implementation status, detects differences with Plans.md, and suggests next action.

## Quick Reference

- "**How far have we progressed?**" → this skill
- "**What should I do next?**" → organize and suggest
- "**Check if Plans.md matches actual progress**" → detect and update

## Deliverables

1. **Progress check**: Consistency between implementation and Plans.md
2. **Difference update**: Update Plans.md markers to match reality
3. **Next action suggestion**: What to do next with priority

## Execution Flow

### Step 1: Gather Current Status (Parallel)

```bash
# Plans.md state
cat Plans.md

# Git change status
git status
git diff --stat HEAD~3

# Recent commit history
git log --oneline -10

# Agent Trace (直近の編集ファイル)
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

### Step 1.5: Agent Trace Analysis

Agent Trace から直近の編集履歴を取得し、Plans.md のタスクと照合:

```bash
# 直近の編集ファイル一覧
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u)

# プロジェクト情報
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.metadata.project')
PROJECT_TYPE=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.metadata.projectType')
```

**照合ポイント**:
| チェック項目 | 検出方法 |
|------------|---------|
| Plans.md にないファイル編集 | Agent Trace vs タスク記述 |
| タスク記述と異なるファイル | 想定ファイル vs 実際の編集 |
| 長時間編集がないタスク | Agent Trace 時系列 vs WIP期間 |

### Step 2: Detect Differences

| Check Item | Detection Method |
|------------|------------------|
| Done but still `cc:WIP` | Commit history vs marker |
| Started but still `cc:TODO` | Changed files vs marker |
| `cc:done` but not committed | git status vs marker |

### Step 3: Update Plans.md

If differences detected, suggest and execute:

```
📝 Plans.md update needed

| Task | Current | After | Reason |
|------|---------|-------|--------|
| XX | cc:WIP | cc:done | Committed |

Update? (yes / no)
```

### Step 4: Output Progress Summary

```markdown
## 📊 Progress Summary

**Project**: {{project_name}} ({{project_type}})

| Status | Count |
|--------|-------|
| 🔴 Not started (cc:TODO) | {{count}} |
| 🟡 In progress (cc:WIP) | {{count}} |
| 🟢 Done (cc:done) | {{count}} |

**Progress rate**: {{percent}}%

### 📄 直近の編集ファイル (Agent Trace)
- {{file1}}
- {{file2}}
- ...
```

### Step 5: Suggest Next Action

```
🎯 What to do next

**Priority 1**: {{task}}
- Reason: {{requested / unblock}}

**Recommended**: /work, /harness-review
```

## Anomaly Detection

| Situation | Warning |
|-----------|---------|
| Multiple `cc:WIP` | ⚠️ Multiple tasks in progress |
| `pm:requested` not processed | ⚠️ Process PM's request first |
| Large gap | ⚠️ Task management not keeping up |
