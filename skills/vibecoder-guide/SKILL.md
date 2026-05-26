---
name: vibecoder-guide
description: "Explicit helper for non-technical VibeCoder coaching: what to ask next, how to describe work, and how to stay safe. Do NOT load for: direct implementation, technical review, or Cursor/PM workflow."
allowed-tools: ["Read"]
user-invocable: false
disable-model-invocation: true
---

# VibeCoder Guide Skill

A skill that guides VibeCoder users (non-technical) through development using only natural language.
Automatically responds to questions like "what should I do?" or "what's next?"

---

## Trigger Phrases

This skill is invoked automatically by the following phrases:

- "what should I do?", "what do I do now?"
- "what should I do next?", "what's next?"
- "what can I do?", "what should I work on?"
- "I'm stuck", "I don't know", "help"
- "show me how to use this"
- "what should I do?", "what's next?", "help"

---

## Overview

VibeCoder users can find out what to do next just by asking in plain language —
no knowledge of technical commands or workflows required.

---

## Response Patterns

### Pattern 1: No project exists

> 🎯 **Let's start a project first!**
>
> **Examples of what to say:**
> - "I want to build a blog"
> - "I want to build a task management app"
> - "I want to build a portfolio site"
>
> A rough idea is fine. Just tell me what you want to make.

### Pattern 2: Plans.md exists but no in-progress tasks

> 📋 **There's a plan. Let's get to work!**
>
> **Current plan:**
> - Phase 1: Foundation
> - Phase 2: Core features
> - ...
>
> **Examples of what to say:**
> - "Start Phase 1"
> - "Do the first task"
> - "Do everything"

### Pattern 3: Tasks in progress

> 🔧 **Work is in progress**
>
> **Current task:** {{task name}}
> **Progress:** {{done}}/{{total}}
>
> **Examples of what to say:**
> - "Continue"
> - "Next task"
> - "How far along are we?"

### Pattern 4: Phase complete

> ✅ **Phase complete!**
>
> **What you can do next:**
> - "Check it works" → start the dev server
> - "Review it" → run code quality check
> - "Move to the next phase" → start the next task
> - "Commit" → save the changes

### Pattern 5: Error occurred

> ⚠️ **A problem occurred**
>
> **Situation:** {{error summary}}
>
> **Examples of what to say:**
> - "Fix it" → attempt auto-fix
> - "Explain it" → describe the problem in detail
> - "Skip it" → move to the next task

---

## Common Phrase Reference

| What you want to do | What to say |
|---------------------|-------------|
| Start a project | "I want to build X" |
| View the plan | "Show me the plan" / "What's the current status?" |
| Start working | "Begin" / "Build it" / "Do Phase 1" |
| Continue where you left off | "Continue" / "Next" |
| Check it works | "Run it" / "Show me" |
| Check the code | "Review it" / "Check it" |
| Save changes | "Commit" / "Save" |
| When stuck | "What should I do?" / "Help" |
| Hand it all off | "Do everything" / "Take care of it" |

---

## Context Determination

This skill checks the following to select the appropriate response:

1. **AGENTS.md presence** → is the project initialized?
2. **Plans.md content** → is there a plan? what is the progress?
3. **Current task state** → is there a `cc:WIP` marker?
4. **Recent errors** → has a problem occurred?

---

## Implementation Notes

When this skill is invoked:

1. Analyze the current state
2. Select the appropriate response pattern
3. Present concrete "examples of what to say"
4. Wait for the user's next action

**Important**: Avoid technical jargon and explain in plain, accessible language
