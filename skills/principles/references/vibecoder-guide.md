---
name: vibecoder-guide
description: "A skill that guides VibeCoder (non-technical users) to progress through development using natural language. Use when providing guidance to non-technical users."
allowed-tools: ["Read"]
---

# VibeCoder Guide

A skill that enables VibeCoder (non-technical users) to drive development
using only natural language. Automatically responds to questions like
"What should I do?" or "What's next?"

---

## Trigger Phrases

This skill activates on the following phrases:

- "What should I do?", "What do I do?", "How should I approach this?"
- "What should I do next?", "What's next?"
- "What can I do?", "What should I work on?"
- "I'm stuck", "I don't know", "Help"
- "Show me how to use this"
- "what should I do?", "what's next?", "help"

---

## Overview

With VibeCoder, you can figure out the next action just by asking naturally,
without knowing technical commands or workflows.

---

## Response Patterns

### Pattern 1: No project yet

> **Let's start a project first!**
>
> **Example phrases:**
> - "I want to create a blog"
> - "I want to build a task management app"
> - "I want to make a portfolio site"
>
> A rough idea is fine. Just tell me what you'd like to build.

### Pattern 2: Plans.md exists but no in-progress tasks

> **There's a plan. Let's get to work!**
>
> **Current plan:**
> - Phase 1: Foundation
> - Phase 2: Core features
> - ...
>
> **Example phrases:**
> - "Start Phase 1"
> - "Do the first task"
> - "Do everything"

### Pattern 3: Task in progress

> **Work in progress**
>
> **Current task:** {{task name}}
> **Progress:** {{completed}}/{{total}}
>
> **Example phrases:**
> - "Keep going"
> - "Next task"
> - "How far along are we?"

### Pattern 4: Phase just completed

> **Phase complete!**
>
> **What you can do next:**
> - "Verify it works" → start the dev server
> - "Review it" → code quality check
> - "Move to the next phase" → start the next batch of work
> - "Commit it" → save the changes

### Pattern 5: Error encountered

> **A problem has occurred**
>
> **Situation:** {{error summary}}
>
> **Example phrases:**
> - "Fix it" → attempt automatic repair
> - "Explain it" → describe the problem in detail
> - "Skip it" → move on to the next task

---

## Common Phrase Reference

| What you want to do | What to say |
|-------------|--------|
| Start a project | "I want to build ..." |
| See the plan | "Show me the plan", "What's the current status?" |
| Start working | "Start", "Build it", "Do Phase 1" |
| Continue | "Keep going", "Next" |
| Verify it works | "Run it", "Show me" |
| Check the code | "Review it", "Check it" |
| Save changes | "Commit it", "Save it" |
| When stuck | "What should I do?", "Help" |
| Leave everything to Claude | "Do everything", "Your call" |

---

## Context Assessment

This skill checks the following to select the appropriate response:

1. **Presence of AGENTS.md** → whether the project is initialized
2. **Contents of Plans.md** → whether a plan exists and the current progress
3. **Current task state** → presence of `cc:WIP` markers
4. **Recent errors** → whether a problem has occurred

---

## Implementation Notes

When this skill activates:

1. Analyze the current state
2. Select the appropriate pattern
3. Present concrete "example phrases"
4. Wait for the user's next action

**Important**: Avoid technical jargon and explain in plain language
