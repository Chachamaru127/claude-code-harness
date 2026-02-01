# OpenCode Setup Reference

Setup project for opencode.ai compatibility.

## Quick Reference

- "**opencode でも使いたい**" → OpenCode setup
- "**GPT でも Harness 使いたい**" → OpenCode setup
- "**マルチ LLM 開発したい**" → OpenCode compatibility
- "**スキルも opencode で使いたい**" → Auto-handled

## Deliverables

- `.opencode/commands/` - OpenCode commands (Impl + PM)
  - `core/` - Core commands (/work, /plan-with-agent, etc.)
  - `optional/` - Optional commands
  - `pm/` - PM commands (when using OpenCode as PM)
  - `handoff/` - Handoff commands
- `.claude/skills/` - OpenCode-compatible skills
- `AGENTS.md` - OpenCode rules file (CLAUDE.md content)

---

## Execution Flow

### Step 1: Confirmation

> Generate opencode.ai compatible files?
>
> The following will be created:
> - `.opencode/commands/` - Harness commands
> - `.claude/skills/` - Harness skills
> - `AGENTS.md` - Rules file (CLAUDE.md content)
>
> Continue? (y/n)

**Wait for response**

### Step 2: Create Directories

```bash
mkdir -p .opencode/commands/core
mkdir -p .opencode/commands/optional
mkdir -p .opencode/commands/pm
mkdir -p .opencode/commands/handoff
mkdir -p .claude/skills
```

### Step 3: Copy Templates (Required)

**Must run with Bash** - do NOT let LLM self-generate content:

```bash
bash ./scripts/opencode-setup-local.sh
```

### Step 4: Verify Copy

```bash
ls -la .opencode/commands
ls -la .claude/skills
ls -la AGENTS.md
```

### Step 5: Completion Message

> OpenCode setup complete!
>
> **Generated files:**
> - `.opencode/commands/` - Harness commands
>   - `core/` - Core commands (/work, /plan-with-agent, etc.)
>   - `optional/` - Optional commands
>   - `pm/` - PM commands (/start-session, /plan-with-cc, etc.)
>   - `handoff/` - Handoff commands
> - `.claude/skills/` - Harness skills
> - `AGENTS.md` - Rules file (CLAUDE.md content)
>
> **Available skills:**
> - `notebookLM` - Document generation (NotebookLM YAML, slides)
> - `impl` - Feature implementation
> - `review` - Code review
> - `verify` - Build verification & error recovery
> - `auth` - Authentication & payments (Clerk, Stripe)
> - `deploy` - Deployment (Vercel, Netlify)
>
> **Usage (Impl mode - implement with Claude Code):**
> ```bash
> opencode
> /work
> ```
>
> **Usage (PM mode - plan management with OpenCode):**
> ```bash
> opencode
> /start-session
> /plan-with-cc
> /handoff-to-claude  # Generate request for Claude Code
> ```

---

## Notes

- If `.opencode/` directory exists, confirm before overwriting
- If `AGENTS.md` exists, create backup
- If `.claude/skills/` exists, create backup
- **Windows users**: Symlinks require admin privileges, copy recommended
