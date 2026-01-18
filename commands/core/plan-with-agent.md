---
description: Create implementation plan (idea → Plans.md → ready for /work)
description-en: Create implementation plan (idea → Plans.md → ready for /work)
---

# /plan-with-agent - Create Implementation Plan

Organizes ideas and requirements, and converts them into executable tasks in Plans.md.
After completion, you can immediately start work with `/work`.

## Quick Reference

- "**Create a plan**" → this command
- "**Turn what we talked about into a plan**" → extract requirements from conversation and create plan
- "**Want to organize what to build**" → start with hearing and create plan
- "**List out features**" → feature list → priority → Plans.md
- "**Plan with TDD**" → force TDD adoption, prioritize test case design
- "**Start with test design**" → design test cases for each feature first

## Deliverables

- **Plans.md** - Task list executable with `/work` (required)
- **Feature priority matrix** - Classification into required/recommended/optional

---

## ⚠️ Mode-specific Usage

| Mode | Recommended Command | Description |
|------|---------------------|-------------|
| **Solo mode** | `/plan-with-agent` (this command) | Claude Code alone: plan → execute → review |
| **2-agent mode** | `/plan-with-cc` (Cursor side) | Plan with Cursor → Execute with Claude Code |

---

## 🔧 Required Skills (Call First)

> ⛔ **When executing this command, you must call the Skill tool first**
>
> Proceeding without calling the Skill tool is prohibited.

**Required skills to call**:

| Skill | Fully Qualified Name | When to Call |
|-------|---------------------|--------------|
| `setup` | `claude-code-harness:setup` | **Call first** (executes adaptive setup) |
| `vibecoder-guide` | `claude-code-harness:vibecoder-guide` | When user is non-technical |

**How to call (required)**:
```
Use Skill tool:
  skill: "claude-code-harness:setup"
```

**Why Skill call is required**:
1. Recorded in usage statistics (quality tracking)
2. Guardrails in skill are applied
3. Accurate grasp of project state

> ❌ **Prohibited**: Reading command document and proceeding directly to execution flow
> ✅ **Correct**: Call `setup` with Skill tool first, then proceed

---

## Execution Flow

### Step 0: Check Conversation Context (Execute after Skill call)

**Confirm with AskUserQuestion tool**:

> 📝 **Choose how to create the plan**
>
> 1. **Based on previous conversation** - Create plan from brainstormed content
> 2. **Start fresh** - Create plan from scratch with hearing

**If "Based on previous conversation" is selected**:
- Extract requirements, ideas, and decisions from recent conversation
- Confirm extracted content with user
- After confirmation, skip to Step 3 (technical research)

**If "Start fresh" is selected**:
- Start hearing from Step 1

---

### Step 1: Hearing What You Want to Build

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

### Step 2: Increase Resolution (Max 3 questions)

> 📋 **Tell me a bit more:**
>
> 1. **Who will use it?** (yourself only? team? public?)
> 2. **Any similar services?** (references)
> 3. **How far do you want to build?** (MVP? full features?)

**Wait for response**

### Step 3: Technical Research (WebSearch)

**Don't ask the user. Claude Code researches and suggests.**

```
WebSearch for:
- "{{project type}} tech stack 2025"
- "{{similar service}} architecture"
```

### Step 4: Extract Feature List

Extract concrete feature list from requirements.

**Example**: For "Reservation management system"
- User registration/login
- Reservation calendar display
- Create/edit/cancel reservations
- Admin dashboard
- Email notifications
- Payment feature
- Review feature

### Step 5: Create Feature Priority Matrix

Classify each feature into these 3 categories:

| Priority | Description | Criteria |
|----------|-------------|----------|
| **Required** | Needed for MVP (minimum viable product) | Won't work without this |
| **Recommended** | Greatly improves user experience | Nice to have, but works without |
| **Optional** | Consider for future addition | If there's time |

**Example**: For reservation management system

| Feature | Priority | Reason |
|---------|----------|--------|
| User registration/login | Required | Need authentication for reservations |
| Reservation calendar display | Required | Core feature |
| Create/edit/cancel reservations | Required | Core feature |
| Admin dashboard | Recommended | Improves operational efficiency |
| Email notifications | Recommended | Improves user experience |
| Payment feature | Optional | Can add later |
| Review feature | Optional | Can add later |

---

### Step 5.5: TDD Adoption Judgment and Strict Test Design (Important)

**Purpose**: Strict TDD = accurately understanding user intent. Tests are "specification documentation", agreeing before implementation.

#### TDD Adoption Judgment

**Adopt TDD if any of the following conditions apply**:

| Judgment Condition | Reason |
|-------------------|--------|
| Contains business logic | Calculation, judgment, state transition require specification documentation |
| Has data transformation/processing | Many boundary conditions in input→output conversion |
| Has external API integration | Clarify specifications through mock design |
| Has multiple branches/conditions | Need to identify edge cases |
| Involves money/auth/permissions | No room for error (security + TDD) |
| User's words are vague | Align understanding through test cases |

**Record judgment result**:
```
Feature "{{feature name}}" → TDD adoption reason: {{matching condition}}
```

#### Deep Intent Questions (Confirm with AskUserQuestion tool)

For features with TDD adoption decision, **always ask the following**:

> 🎯 **Let me confirm about "{{feature name}}" before writing tests**
>
> 1. **Normal case**: What's the most common usage? (specific scenario)
> 2. **Boundary conditions**: Where's the line between "barely OK" and "barely NG"?
> 3. **On error**: How do you want to show errors to users?
> 4. **Implicit expectations**: What do you consider "obvious"? (unspoken rules)

**Additional questions to draw out tacit knowledge** (as needed):

| Situation | Additional Question |
|-----------|---------------------|
| Handling numbers | "Allow 0 or negative?" "Decimal places?" |
| Handling dates | "Timezone?" "Allow past dates?" |
| Handling strings | "Empty string?" "Max length?" "Emojis?" |
| Handling lists | "Empty list?" "Upper limit?" "Duplicates?" |
| State transitions | "Can go back?" "Cancel midway?" "Timeout?" |
| User operations | "What if spammed?" "What if they leave midway?" |

#### Test Case Design (Include in Plans.md)

**TDD-adopted features include test design before implementation tasks**:

```markdown
### {{Feature Name}} `[feature:tdd]`

#### Test Case Design (Agree before implementation)

| Test Case | Input | Expected Output | Notes |
|-----------|-------|-----------------|-------|
| Normal: basic | {{example}} | {{expected}} | Most common case |
| Normal: boundary lower | {{barely OK}} | {{success}} | Lower limit test |
| Normal: boundary upper | {{barely OK}} | {{success}} | Upper limit test |
| Error: boundary exceeded | {{barely NG}} | {{error}} | Validation check |
| Error: null/empty | null, "", [] | {{error}} | Defensive programming |
| Edge case | {{special case}} | {{expected behavior}} | Tacit knowledge documentation |

#### Implementation Tasks
- [ ] Create test file (implement above cases)
- [ ] Create implementation code (until tests pass)
- [ ] Refactor (while maintaining tests)
```

#### When TDD Not Adopted

Simple features not matching TDD judgment conditions (static UI, config file generation, etc.) proceed with normal implementation flow. However, if user requests "also write tests", adopt TDD.

---

### Step 6: Effort Estimation (Reference)

Calculate implementation effort for each feature as reference.

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

### Step 7: Generate Plans.md (Auto-assign Quality Judgment Markers)

Generate `Plans.md` for implementation.

**Auto-assign quality judgment markers**:

Analyze each task's content and auto-assign appropriate quality markers:

| Task Content | Marker | Effect |
|--------------|--------|--------|
| Auth/login feature | `[feature:security]` | Show security checklist |
| UI component | `[feature:a11y]` | Recommend a11y check |
| Business logic | `[feature:tdd]` | Recommend TDD |
| API endpoint | `[feature:security]` | Input validation check |
| Bug fix | `[bugfix:reproduce-first]` | Recommend reproduction test first |

```markdown
## 🎯 Project: {{Project Name}}

### Overview
- **Purpose**: {{what you want to do}}
- **Target**: {{who will use it}}
- **Reference**: {{similar service}}
- **Scope**: {{MVP or full features}}

### Tech Stack
- Frontend: {{tech}}
- Backend: {{tech}}
- Database: {{tech}}
- Deploy: {{tech}}

---

## 🔴 Phase 1: Foundation Setup `cc:TODO`

- [ ] Project initialization
- [ ] Basic setup (linter, formatter)
- [ ] Database design
- [ ] Environment variable setup
- [ ] Git init & initial commit

## 🟡 Phase 2: Core Features (Required) `cc:TODO`

### {{Required Feature 1}} `[feature:tdd]`

#### Test Case Design (Agreed before implementation)
| Test Case | Input | Expected Output | Notes |
|-----------|-------|-----------------|-------|
| Normal: basic | {{example}} | {{expected}} | From user hearing |
| Boundary | {{boundary value}} | {{expected behavior}} | Confirmed in Step 5.5 |
| Error | {{error input}} | {{error}} | Tacit knowledge documentation |

#### Implementation Tasks
- [ ] Create test file
- [ ] Create implementation code
- [ ] Refactor

### {{Required Feature 2}} `[feature:tdd]`
(Same test case design)

### {{Auth Feature}} `[feature:security]`

## 🟢 Phase 3: Recommended Features `cc:TODO`

- [ ] {{UI feature}} `[feature:a11y]`
- [ ] {{recommended feature}}

## 🔵 Phase 4: Finishing `cc:TODO`

- [ ] Review (`/harness-review`)
- [ ] Deploy setup
- [ ] Operation check
```

**Marker judgment logic**:

```
Analyze task content
    ↓
├── "auth" "login" "API" → [feature:security] + go to TDD judgment
├── "component" "UI" "screen" → [feature:a11y]
├── "fix" "bug" → [bugfix:reproduce-first]
├── "service" "logic" "core" → [feature:tdd] + go to Step 5.5
├── "calculation" "transform" "validation" → [feature:tdd] + go to Step 5.5
├── "payment" "amount" "billing" → [feature:security] + [feature:tdd] + go to Step 5.5
└── Other → no marker
```

**Important**: Features with `[feature:tdd]` marker must go through TDD adoption judgment flow in Step 5.5, including deep intent questions to user and test case design.

### Step 8: Guide Next Actions

> ✅ **Plan complete!**
>
> 📄 **Generated files**:
> - `Plans.md` - Implementation task list
>
> **Next steps:**
> - Start implementation with "`/work`"
> - Or say "start from Phase 1"
>
> 💡 **Hint**: To adjust the plan, say "add {{feature}}" or "postpone {{feature}}".

---

## Output Examples

### Example 1: Plan from Brainstorming

```
User: (Was brainstorming "want to make a task management app, like Notion")
User: /plan-with-agent

Claude Code:
> 📝 Choose how to create the plan
> 1. Based on previous conversation
> 2. Start fresh

User: 1

Claude Code:
> Extracted the following from conversation:
> - What to build: Task management app
> - Reference: Notion
> - Feature candidates: Task CRUD, kanban view, tag feature
>
> Proceed with this plan?

User: OK

→ Generate Plans.md
```

### Example 2: Plan from Scratch

```
User: /plan-with-agent

Claude Code:
> 📝 Choose how to create the plan

User: Start fresh

Claude Code:
> 🎯 What do you want to build?

User: Blog site

(Continue hearing)
→ Generate Plans.md
```

---

## Notes

- **Plans.md is the priority**: Purpose is to get to a state executable with `/work`
- **Flexibly adjustable**: Can change with "add XXX" or "remove XXX" after planning
- **Use brainstorming context**: Select "Based on conversation" in Step 0 to reflect discussed content
