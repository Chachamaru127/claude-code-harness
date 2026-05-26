# Harness for OpenCode

This directory contains the opencode.ai-compatible distribution of Claude Code
Harness.

## Language Policy

English is the default for distributed docs and setup output. Japanese remains
available as an explicit opt-in through `i18n.language: ja`,
`CLAUDE_CODE_HARNESS_LANG=ja`, and the Japanese setup templates under
`templates/locales/ja/`.

OpenCode-specific docs should stay in English by default. Do not mix Japanese
instructions into this file unless the section is explicitly about the Japanese
opt-in path.

## Setup

Skills-Primary setup means OpenCode loads Harness workflows from
`.opencode/skills/<name>/SKILL.md`. The `.opencode/commands/` directory is
compatibility-only for older slash-command flows.

The setup also installs `.opencode/plugins/harness-bootstrap.mjs`. This plugin
adds first-message Harness bootstrap context, registers the local skills path
without duplicate entries, and keeps the OpenCode route at
`internal-compatible` until runtime smoke is available.

### Option 1: One-Command Setup (Recommended)

You can set up OpenCode support even if Claude Code is not installed:

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/setup-opencode.sh | bash
```

To set up Unified Memory as well:

```bash
cd your-project
/path/to/claude-code-harness/scripts/harness-mem setup --platform opencode
```

### Option 2: Setup From Claude Code

If you already use Claude Code Harness, run:

```bash
# Run inside Claude Code
/opencode-setup
```

### Option 3: Manual Setup

```bash
# Clone Harness
git clone https://github.com/Chachamaru127/claude-code-harness.git

# Copy OpenCode-native skills (Skills-Primary setup)
mkdir -p your-project/.opencode/skills
cp -r claude-code-harness/opencode/skills/* your-project/.opencode/skills/

# Copy project rules and config
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
cp claude-code-harness/opencode/opencode.json your-project/opencode.json

# Copy the bootstrap plugin
mkdir -p your-project/.opencode/plugins
cp claude-code-harness/opencode/plugins/harness-bootstrap.mjs your-project/.opencode/plugins/

# Optional compatibility commands, if you still use slash-command workflows
mkdir -p your-project/.opencode/commands
cp -r claude-code-harness/opencode/commands/* your-project/.opencode/commands/
```

## MCP Server Status

`mcp-server/` is development-only and distribution-excluded. It may exist in
source checkouts for experiments and maintenance, but it is not part of the
default OpenCode consumer setup.

The default `opencode.json` enables OpenCode's native skill discovery and does
not point at a Harness MCP server path. Only add an MCP entry if you are
developing that optional server from a source checkout and can provide the
actual command path yourself.

If you also use the unified memory daemon:

```bash
# Start the memory daemon
./scripts/harness-memd start

# Check health
./scripts/harness-mem-client.sh health
```

You can also run diagnostics through `harness-mem`:

```bash
/path/to/claude-code-harness/scripts/harness-mem doctor --platform opencode --fix
```

## Available Commands

Skills are the primary OpenCode surface. Commands are compatibility helpers for
older or PM-oriented slash-command workflows.

| Command | Description |
|---------|-------------|
| `/harness-init` | Project setup |
| `/plan-with-agent` | Create a development plan |
| `/work` | Execute tasks |
| `/harness-review` | Review code |
| `/sync-status` | Check progress |
| `/handoff-to-opencode` | Generate a completion report for the OpenCode PM |

## PM Mode

When OpenCode acts as the project manager:

| Command | Description |
|---------|-------------|
| `/start-session` | Start a session and inspect context |
| `/plan-with-cc` | Create a plan, including evals when needed |
| `/project-overview` | Understand the project structure |
| `/handoff-to-claude` | Generate a request for Claude Code |
| `/review-cc-work` | Review and approve Claude Code work |

### Workflow

```
OpenCode (PM)                    Claude Code (Impl)
    |                                   |
    | /start-session                    |
    | /plan-with-cc                     |
    | /handoff-to-claude -------------> |
    |                                   | /work
    |                                   | /handoff-to-opencode
    | <-------------------------------- |
    | /review-cc-work                   |
    |    |-- approve -> next task ----> |
    |    `-- request_changes --------> |
```

## Development-Only MCP Tools

The optional development-only MCP server can expose these tools when a source
checkout owner builds and wires it manually:

| Tool | Description |
|------|-------------|
| `harness_workflow_plan` | Create a plan |
| `harness_workflow_work` | Execute tasks |
| `harness_workflow_review` | Review code |
| `harness_session_broadcast` | Send cross-session notifications |
| `harness_status` | Check status |
| `harness_mem_resume_pack` | Fetch resume context |
| `harness_mem_search` | Search shared memory |
| `harness_mem_record_checkpoint` | Record a checkpoint |
| `harness_mem_finalize_session` | Finalize a session |

## Usage

```bash
# Start OpenCode
cd your-project
opencode

# Ask OpenCode to use the installed skills
Use the harness-plan skill to create a plan
Use the harness-work skill to execute the next task
Use the harness-review skill to review code
```

## Limitations

- OpenCode does not use the Claude Code plugin system under `.claude-plugin/`.
- The bootstrap plugin lives in `opencode/plugins/harness-bootstrap.mjs` and is
  copied to `.opencode/plugins/harness-bootstrap.mjs`.
- Runtime native-skill smoke is not claimed when the `opencode` binary is not
  available; the tier stays `internal-compatible`.
- Skill frontmatter is generated for OpenCode's native skill contract:
  `name` and `description` are required, while bilingual
  `description-en` / `description-ja` metadata stays in the Claude Code and
  Codex source surfaces.
- OpenCode discovers the installed skills from
  `.opencode/skills/<name>/SKILL.md`.

## Links

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
- [OpenCode Commands](https://opencode.ai/docs/commands/)
