# Execution Flow

## Step 0: Check Conversation Context

**Confirm with AskUserQuestion tool**:

> 📝 **Choose how to create the plan**
>
> 1. **Based on previous conversation** - Create plan from brainstormed content
> 2. **Start fresh** - Create plan from scratch with hearing

**If "Based on previous conversation"**:
- Extract requirements, ideas, and decisions from recent conversation
- Confirm extracted content with user
- After confirmation, skip to Step 3 (technical research)

**If "Start fresh"**:
- Start hearing from Step 1

## Step 1: Hearing What to Build

Check user input. If no input, ask:

> 🎯 **What do you want to build?**
>
> Examples:
> - "Reservation management system"
> - "Blog site"
> - "Task management app"
> - "API server"
>
> Rough ideas are fine!

**Wait for response**

## Step 2: Increase Resolution (Max 3 questions)

> 📋 **Tell me a bit more:**
>
> 1. **Who will use it?** (yourself only? team? public?)
> 2. **Any similar services?** (references)
> 3. **How far do you want to build?** (MVP? full features?)

**Wait for response**

## Step 3: Technical Research (WebSearch)

**Don't ask the user. Claude Code researches and suggests.**

```
WebSearch for:
- "{{project type}} tech stack 2025"
- "{{similar service}} architecture"
```

## Step 4: Extract Feature List

Extract concrete feature list from requirements.

**Example**: For "Reservation management system"
- User registration/login
- Reservation calendar display
- Create/edit/cancel reservations
- Admin dashboard
- Email notifications
- Payment feature
- Review feature

## Step 5: Create Feature Priority Matrix

Classify each feature into 3 categories:

| Priority | Description | Criteria |
|----------|-------------|----------|
| **Required** | Needed for MVP | Won't work without this |
| **Recommended** | Improves user experience | Nice to have |
| **Optional** | Consider for future | If there's time |

## Step 6: Effort Estimation (Reference)

**Estimation standards** (with Claude Code):

| Feature Type | Effort (person-days) |
|--------------|---------------------|
| Auth (using Clerk) | 0.5-1 |
| CRUD (1 table) | 1-2 |
| Admin panel (basic) | 2-3 |
| Payment (using Stripe) | 2-3 |
| Email notifications | 1-2 |
| CI/CD setup | 1 |
| Deploy setup | 0.5 |

## Step 7: Generate Plans.md

Generate `Plans.md` for implementation with auto-assigned quality markers.

**Marker judgment logic**:

```
Analyze task content
    ↓
├── "auth" "login" "API" → [feature:security]
├── "component" "UI" "screen" → [feature:a11y]
├── "fix" "bug" → [bugfix:reproduce-first]
├── "service" "logic" "core" → [feature:tdd]
├── "calculation" "transform" "validation" → [feature:tdd]
├── "payment" "amount" "billing" → [feature:security] + [feature:tdd]
└── Other → no marker
```

## Step 8: Guide Next Actions

> ✅ **Plan complete!**
>
> 📄 **Generated files**:
> - `Plans.md` - Implementation task list
>
> **Next steps:**
> - Start implementation with "`/work`"
> - Or say "start from Phase 1"
