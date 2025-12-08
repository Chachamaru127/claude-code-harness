# cursor-cc-plugins v2.2

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)

**Build high-quality projects using only natural language.**

A development workflow plugin for Claude Code, designed for VibeCoders who want to develop without deep technical knowledge. Optionally supports 2-agent collaboration with Cursor.

English | [日本語](README.ja.md)

---

## Table of Contents

1. [What This Plugin Provides](#1-what-this-plugin-provides) - Commands and their purposes
2. [How to Talk to Claude Code](#2-how-to-talk-to-claude-code) - Natural language → which feature runs
3. [When Things Go Wrong](#3-when-things-go-wrong) - Troubleshooting and recovery
4. [The Complete Development Flow](#4-the-complete-development-flow) - Visual guide from idea to completion
5. [Advanced: 2-Agent Collaboration](#5-advanced-2-agent-collaboration) - Optional Cursor + Claude Code setup

---

## 1. What This Plugin Provides

This plugin gives you **8 commands** that automate the entire development process. Here's what each one does and why it exists:

### Core Commands

| Command | What It Does | Why You Need It |
|---------|--------------|-----------------|
| `/init` | Asks questions about your idea, suggests technology, creates project | **Start here** - turns your vague idea into a real project |
| `/plan` | Breaks down a feature request into organized tasks | **Before building** - prevents chaos by creating a clear roadmap |
| `/work` | Executes the planned tasks and writes actual code | **The building phase** - does the heavy lifting |
| `/review` | Checks code for security, performance, and quality issues | **Quality gate** - catches problems before they become disasters |

### Support Commands

| Command | What It Does | Why You Need It |
|---------|--------------|-----------------|
| `/sync-status` | Shows current progress and what's left to do | **Stay oriented** - know where you are at any time |
| `/start-task` | Picks up the next task from the plan | **Keep momentum** - no decision fatigue about what's next |
| `/handoff-to-cursor` | Creates a completion report (for 2-agent setup) | **Team handoff** - clean communication between agents |
| `/setup-2agent` | Configures 2-agent collaboration (optional) | **Team setup** - enables Cursor + Claude Code workflow |

### Automatic Features (No Command Needed)

| Feature | What It Does | When It Activates |
|---------|--------------|-------------------|
| **Session Memory** | Remembers what you did in previous sessions | When you ask about past work |
| **Error Recovery** | Automatically fixes build/test errors (up to 3 times) | When errors are detected |
| **Parallel Processing** | Runs independent tasks simultaneously | When multiple tasks don't depend on each other |
| **Troubleshoot** | Diagnoses and suggests fixes for problems | When you say something is broken |

---

## 2. How to Talk to Claude Code

You don't need to remember commands. Just say what you want naturally, and the right feature will activate automatically.

### Starting a Project

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "I want to build a blog" | → **`/init`** activates: asks clarifying questions, recommends tech stack, generates project |
| "Create a recipe sharing app" | → **`/init`** activates: same flow, tailored to your description |
| "Start a new project for task management" | → **`/init`** activates: analyzes requirements, suggests structure |

**Example conversation:**
```
You: "I want to build a recipe sharing app"

Claude Code (/init running):
"Let me understand your vision better:
 1. Who will use this app?
 2. What similar apps do you like?
 3. What's the #1 feature you need?"

You: "Home cooks, I like Cookpad, saving favorites is key"

Claude Code:
"I recommend: Next.js + Supabase + Tailwind
 Creating your project now..."
 ✅ Project created!
```

---

### Adding Features

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "Add user login" | → **`/plan`** activates: breaks into tasks → **`/work`** executes them |
| "I want users to save recipes" | → **`/plan`** activates: creates feature roadmap → **`/work`** builds it |
| "Add a search function" | → **`/plan`** + **`/work`**: plans then implements |

**Example conversation:**
```
You: "Add user login"

Claude Code (/plan running):
"Breaking this down into tasks:
 - [ ] Create login page
 - [ ] Create signup page
 - [ ] Connect authentication
 Adding to Plans.md..."

Claude Code (/work running):
"Implementing Phase 1..."
 ✅ Created src/app/login/page.tsx
 ✅ Created src/app/signup/page.tsx
 ✅ Connected Supabase Auth
"Done! Say 'run it' to test."
```

---

### Running and Testing

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "Run it" | → Starts development server, opens in browser |
| "Show me" | → Same as "run it" |
| "Test it" | → Runs automated tests if they exist |

**Example:**
```
You: "Run it"

Claude Code:
"Starting dev server...
 🌐 Open http://localhost:3000"
```

---

### Checking Quality

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "Check it" | → **`/review`** activates: security, performance, code quality scan |
| "Review the code" | → **`/review`** activates: same comprehensive check |
| "Is everything okay?" | → **`/review`** activates: reports any issues found |

**Example:**
```
You: "Check if everything is okay"

Claude Code (/review running):
"Running quality checks...

 ✅ Security: No vulnerabilities
 ✅ Performance: Good (no slow queries)
 ⚠️  Code Quality: 2 minor suggestions
     - Consider adding error handling to line 45
     - Unused import on line 12

 Overall: Ready for production!"
```

---

### Checking Progress

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "What's the status?" | → **`/sync-status`** activates: shows completed and remaining tasks |
| "How much is done?" | → **`/sync-status`** activates: progress summary |
| "What's next?" | → **`/start-task`** activates: picks up next task |

**Example:**
```
You: "What's the status?"

Claude Code (/sync-status running):
"📊 Project Status:

 ✅ Completed (3):
    - User login
    - Recipe upload
    - Image storage

 🔄 In Progress (1):
    - Comment system

 📋 Remaining (2):
    - Search function
    - User profiles

 Progress: 60% complete"
```

---

### Resuming After a Break

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "What did we do last time?" | → **Session Memory** activates: recalls previous session |
| "Continue from where we left off" | → **Session Memory** + **`/start-task`**: resumes work |
| "Pick up where we stopped" | → Same as above |

**Example:**
```
You: "What did we do last time?"

Claude Code (Session Memory):
"Last session (Dec 7):
 ✅ Completed: User login, Recipe upload
 🔄 Stopped at: Comment system (50% done)

 Want me to continue with the comment system?"

You: "Yes, continue"

Claude Code (/work running):
"Resuming comment system implementation..."
```

---

## 3. When Things Go Wrong

Problems happen. Here's how to handle them:

### Something Broke

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "It's broken" | → **Troubleshoot** activates: diagnoses the issue |
| "Not working" | → **Troubleshoot** activates: analyzes error logs |
| "Fix this error" | → **Error Recovery** activates: auto-fixes up to 3 times |

**Example:**
```
You: "It's broken"

Claude Code (Troubleshoot):
"🔍 Diagnosing...

 Found: Database connection error
 Cause: Environment variable SUPABASE_URL not set

 🔧 Fixing automatically..."

Claude Code (Error Recovery):
"✅ Fixed! Added missing environment variable.
 Try 'run it' again."
```

### Lost or Confused

| What to Say | What Happens Behind the Scenes |
|-------------|--------------------------------|
| "What should I do?" | → **VibeCoder Guide** activates: suggests next action based on context |
| "I'm stuck" | → **VibeCoder Guide** activates: analyzes situation, offers options |
| "Help" | → Shows available actions for current state |

**Example:**
```
You: "What should I do next?"

Claude Code (VibeCoder Guide):
"Based on your current progress:

 ✅ Login feature is complete
 🔄 Comment system is 50% done

 I suggest:
 1. 'Continue with comments' - finish what we started
 2. 'Check it' - review what's built so far
 3. 'Run it' - test current features

 What would you like?"
```

---

## 4. The Complete Development Flow

Here's how a typical project progresses from idea to completion:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           THE DEVELOPMENT JOURNEY                              ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  PHASE 1: IDEA → PROJECT                                                       ║
║  ─────────────────────────                                                     ║
║                                                                                ║
║    You: "I want to build X"                                                    ║
║                │                                                               ║
║                ▼                                                               ║
║    ┌─────────────────────────────────────────┐                                ║
║    │  /init                                  │                                ║
║    │  • Asks clarifying questions            │                                ║
║    │  • Recommends technology                │                                ║
║    │  • Creates project structure            │                                ║
║    └─────────────────────────────────────────┘                                ║
║                │                                                               ║
║                ▼                                                               ║
║    ✅ Project created!                                                         ║
║                                                                                ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  PHASE 2: FEATURE DEVELOPMENT LOOP                                             ║
║  ─────────────────────────────────                                             ║
║                                                                                ║
║         ┌──────────────────────────────────────────────────────────┐          ║
║         │                                                          │          ║
║         ▼                                                          │          ║
║    You: "Add X feature"                                            │          ║
║         │                                                          │          ║
║         ▼                                                          │          ║
║    ┌─────────────────────────────────────────┐                     │          ║
║    │  /plan                                  │                     │          ║
║    │  • Breaks feature into tasks            │                     │          ║
║    │  • Adds to Plans.md                     │                     │          ║
║    └─────────────────────────────────────────┘                     │          ║
║         │                                                          │          ║
║         ▼                                                          │          ║
║    ┌─────────────────────────────────────────┐                     │          ║
║    │  /work                                  │                     │          ║
║    │  • Writes actual code                   │                     │          ║
║    │  • Creates files                        │                     │          ║
║    │  • Runs commands (npm install, etc.)    │                     │          ║
║    └─────────────────────────────────────────┘                     │          ║
║         │                                                          │          ║
║         ▼                                                          │          ║
║    You: "Run it"                                                   │          ║
║         │                                                          │          ║
║         ▼                                                          │          ║
║    ┌─────────────────────────────────────────┐                     │          ║
║    │  Development server starts              │                     │          ║
║    │  • Test in browser                      │                     │          ║
║    └─────────────────────────────────────────┘                     │          ║
║         │                                                          │          ║
║         ▼                                                          │          ║
║    ┌─────────────────┐     ┌─────────────────┐                     │          ║
║    │ Works?          │────▶│ "Add next       │─────────────────────┘          ║
║    │ Yes ✅          │     │  feature"       │                                ║
║    └────────┬────────┘     └─────────────────┘                                ║
║             │ No ❌                                                            ║
║             ▼                                                                  ║
║    ┌─────────────────────────────────────────┐                                ║
║    │  You: "It's broken" or "Fix it"         │                                ║
║    │                                         │                                ║
║    │  Error Recovery:                        │                                ║
║    │  • Diagnoses problem                    │                                ║
║    │  • Auto-fixes (up to 3 times)           │                                ║
║    │  • Reports if can't fix                 │                                ║
║    └─────────────────────────────────────────┘                                ║
║                                                                                ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  PHASE 3: QUALITY CHECK                                                        ║
║  ──────────────────────                                                        ║
║                                                                                ║
║    You: "Check it" or "Review the code"                                        ║
║         │                                                                      ║
║         ▼                                                                      ║
║    ┌─────────────────────────────────────────┐                                ║
║    │  /review                                │                                ║
║    │  • Security scan                        │                                ║
║    │  • Performance check                    │                                ║
║    │  • Code quality analysis                │                                ║
║    │  • Suggests improvements                │                                ║
║    └─────────────────────────────────────────┘                                ║
║         │                                                                      ║
║         ▼                                                                      ║
║    ✅ Quality report generated                                                 ║
║                                                                                ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  PHASE 4: SESSION MANAGEMENT                                                   ║
║  ──────────────────────────                                                    ║
║                                                                                ║
║    ┌─────────────────────────────────────────┐                                ║
║    │  End of session?                        │                                ║
║    │                                         │                                ║
║    │  Session Memory automatically saves:    │                                ║
║    │  • What was completed                   │                                ║
║    │  • What's in progress                   │                                ║
║    │  • Important decisions made             │                                ║
║    └─────────────────────────────────────────┘                                ║
║                                                                                ║
║    Next session:                                                               ║
║    You: "What did we do last time?"                                            ║
║         │                                                                      ║
║         ▼                                                                      ║
║    ┌─────────────────────────────────────────┐                                ║
║    │  Session Memory recalls:                │                                ║
║    │  • Previous work                        │                                ║
║    │  • Unfinished tasks                     │                                ║
║    │  • Context and decisions                │                                ║
║    └─────────────────────────────────────────┘                                ║
║         │                                                                      ║
║         ▼                                                                      ║
║    You: "Continue" → Back to PHASE 2                                           ║
║                                                                                ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  PHASE 5: COMPLETION                                                           ║
║  ──────────────────                                                            ║
║                                                                                ║
║    All features done?                                                          ║
║         │                                                                      ║
║         ▼                                                                      ║
║    You: "Check everything one more time"                                       ║
║         │                                                                      ║
║         ▼                                                                      ║
║    ┌─────────────────────────────────────────┐                                ║
║    │  /review (final)                        │                                ║
║    │  • Complete security audit              │                                ║
║    │  • Performance optimization             │                                ║
║    │  • Ready for deployment                 │                                ║
║    └─────────────────────────────────────────┘                                ║
║         │                                                                      ║
║         ▼                                                                      ║
║    🎉 Your app is complete!                                                    ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## Real-World Example: Building a Todo App

Here's a concrete example showing the complete flow:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DAY 1: Getting Started
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You: "I want to build a todo app"
     └─→ /init activates
         • Asks: "Personal or team use? Need due dates? Categories?"
         • You answer: "Personal, yes due dates, no categories"
         • Creates Next.js + Tailwind project

You: "Run it"
     └─→ Starts dev server at localhost:3000
         • You see blank starter page

You: "Add ability to create todos"
     └─→ /plan activates: creates task list
     └─→ /work activates: builds the feature
         ✅ Created todo input form
         ✅ Added to database

You: "Run it"
     └─→ Test: You can now create todos!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DAY 2: Adding Features
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You: "What did we do last time?"
     └─→ Session Memory activates
         • "Yesterday: Created todo app, added todo creation"
         • "Ready to continue?"

You: "Add due dates"
     └─→ /plan + /work
         ✅ Added date picker
         ✅ Updated database schema

You: "Add ability to mark complete"
     └─→ /plan + /work
         ✅ Added checkbox functionality
         ✅ Strike-through styling

You: "Check it"
     └─→ /review activates
         ✅ Security: OK
         ✅ Performance: OK
         ⚠️ Suggestion: Add loading state

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DAY 3: Final Touches
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

You: "Add delete functionality"
     └─→ /plan + /work
         ✅ Added delete button
         ✅ Confirmation dialog

You: "Make it look nicer"
     └─→ /work applies styling
         ✅ Modern UI with shadows
         ✅ Smooth animations

You: "Check everything one more time"
     └─→ /review (comprehensive)
         ✅ All checks passed
         🎉 Ready for deployment!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RESULT: Complete todo app with create, due dates, complete, and delete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 5. Advanced: 2-Agent Collaboration

> **This section is optional.** Most users can use Claude Code alone. This is for teams that want to split responsibilities between Cursor and Claude Code.

### When to Use 2-Agent Setup

- Large projects with multiple developers
- Teams that want clear separation between planning (PM) and implementation (Worker)
- Projects requiring formal review/approval workflows

### Roles

| Agent | Role | Responsibilities |
|-------|------|------------------|
| **Cursor** | PM (Project Manager) | Planning, task assignment, code review, production deployment decisions |
| **Claude Code** | Worker (Developer) | Implementation, testing, staging deployment, completion reports |

### Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         2-AGENT COLLABORATION FLOW                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Cursor (PM)                              Claude Code (Worker)             │
│       │                                           │                         │
│       │  1. Plan feature & assign task            │                         │
│       │  ────────────────────────────────────────>│                         │
│       │     "Build user authentication"           │                         │
│       │                                           │                         │
│       │                                           │  2. /start-task         │
│       │                                           │     /plan → /work       │
│       │                                           │     Implement & test    │
│       │                                           │                         │
│       │  3. Completion report                     │                         │
│       │  <────────────────────────────────────────│                         │
│       │     /handoff-to-cursor                    │                         │
│       │                                           │                         │
│       │  4. Review & approve                      │                         │
│       │     (or request changes)                  │                         │
│       │                                           │                         │
│       │  5. Deploy to production                  │                         │
│       │     (PM responsibility)                   │                         │
│       │                                           │                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Setup

Run `/setup-2agent` to configure both agents with the necessary files:

```
Files created:
├── AGENTS.md           # Shared rules for both agents
├── CLAUDE.md           # Claude Code specific settings
├── Plans.md            # Shared task tracking
└── .cursor/
    └── commands/
        ├── assign-to-cc.md      # For PM to assign tasks
        └── review-cc-work.md    # For PM to review completions
```

### Task Status Markers

| Marker | Meaning | Who Sets It |
|--------|---------|-------------|
| `cursor:requested` | Task assigned by PM | Cursor |
| `cc:TODO` | Not started | Claude Code |
| `cc:WIP` | Work in progress | Claude Code |
| `cc:done` | Completed, awaiting review | Claude Code |
| `cursor:verified` | Reviewed and approved | Cursor |

---

## Installation

```bash
# Add the marketplace
/plugin marketplace add Chachamaru127/cursor-cc-plugins

# Install the plugin
/plugin install cursor-cc-plugins
```

### Team Configuration

To share with your team, add to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "cursor-cc-marketplace": {
      "source": {
        "source": "github",
        "repo": "Chachamaru127/cursor-cc-plugins"
      }
    }
  },
  "enabledPlugins": {
    "cursor-cc-plugins@cursor-cc-marketplace": true
  }
}
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [GitHub Repository](https://github.com/Chachamaru127/cursor-cc-plugins)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Report Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
