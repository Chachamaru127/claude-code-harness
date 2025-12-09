# Solo Mode Usage Guide

> **Claude Code のみ**で開発する場合のガイド

---

## When to Use Solo Mode

Solo Mode は以下の場合に適しています:

- Cursor を使えない環境
- 簡単なプロトタイプを素早く試したい
- 個人プロジェクトで役割分担が不要
- 2-Agent 構成を試す前の導入テスト

> **Note**: 2-Agent モードに比べて、タスク分担や進行管理の自動化は限定的です。

---

## Quick Start

```bash
# Install
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins

# Start
"I want to build a blog app"
```

That's it. Claude Code handles everything.

---

## Commands

| Command | What It Does |
|---------|--------------|
| `/init` | Create new project from description |
| `/plan` | Break feature into tasks |
| `/work` | Execute tasks and write code |
| `/review` | Check code quality |
| `/sync-status` | Show current progress |

---

## Conversation Examples

### Starting a Project

```
User: "I want to build a todo app"

Claude Code (/init):
"Let me understand your needs:
 1. Who will use this? (Personal/Team/Public)
 2. Any similar apps you like?

 I recommend: Next.js + Tailwind + Supabase
 Creating project now...

 ✅ Project created!
 Say 'run it' to start the dev server."
```

### Adding Features

```
User: "Add user login"

Claude Code (/plan + /work):
"Breaking into tasks:
 - [ ] Create login page
 - [ ] Create signup page
 - [ ] Connect auth

 Implementing...
 ✅ Created src/app/login/page.tsx
 ✅ Created src/app/signup/page.tsx

 Say 'run it' to test."
```

### Running and Testing

```
User: "Run it"

Claude Code:
"Starting dev server...
 🌐 Open http://localhost:3000"
```

### Checking Quality

```
User: "Check it"

Claude Code (/review):
"Running quality checks...
 ✅ Security: No issues
 ✅ Performance: Good
 ⚠️ Suggestion: Add error handling to line 45

 Overall: Ready for production!"
```

---

## Natural Language Commands

You don't need to remember commands. Just say:

| What to Say | What Happens |
|-------------|--------------|
| "Build a blog" | `/init` activates |
| "Add login" | `/plan` + `/work` |
| "Run it" | Starts dev server |
| "Check it" | `/review` runs |
| "What's next?" | `/sync-status` |
| "It's broken" | Troubleshoot activates |

---

## Session Memory

Claude Code remembers your previous work:

```
User: "What did we do last time?"

Claude Code:
"Last session (Dec 7):
 ✅ Completed: User login, Recipe upload
 🔄 Stopped at: Comment system (50% done)

 Want me to continue?"
```

---

## Error Recovery

Claude Code automatically fixes errors up to 3 times:

```
User: "It's broken"

Claude Code:
"🔍 Diagnosing...
 Found: Missing environment variable SUPABASE_URL

 🔧 Fixing...
 ✅ Fixed! Try 'run it' again."
```

---

## Limitations vs 2-Agent Mode

| Feature | Solo Mode | 2-Agent Mode |
|---------|-----------|--------------|
| Planning | Self-managed | Cursor handles |
| Code review | Self-review only | Cursor reviews |
| Production deploy | Manual | Cursor decides |
| Progress tracking | Basic | Full PM support |
| Best for | Prototypes | Production projects |

---

## Upgrading to 2-Agent Mode

When your project grows, consider switching:

```
/setup-2agent
```

This adds the files needed for Cursor + Claude Code collaboration.
