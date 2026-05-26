# Claude Code Setup: MCP, Telemetry, Provider Guidance

Last updated: 2026-05-05

Operational guide for the setup / MCP / telemetry / provider features added in Claude Code 2.1.120+.

## In one sentence

Harness guides you to Claude Code's new features without hiding them, but does not replace
the meaning of official settings.
MCP always-load, telemetry, providers, Windows shell, and deferred tools are each opted-in
in small, purpose-specific ways.

## Analogy

Claude Code is a toolbox and Harness is a work procedure guide.
Rather than modifying the contents of the toolbox on its own, Harness guides "for this task,
have this tool ready."

## Setup checklist

| Item | Harness guidance |
|------|------------------|
| `${CLAUDE_EFFORT}` | Use only when referencing the current effort in skill content. Keep the effort decision on the caller side |
| MCP `alwaysLoad` | Set `true` only for a small number of essential tools needed every turn. Keep large servers as deferred |
| `claude plugin prune` | Isolated dependency cleanup after plugin uninstall. Use `--dry-run` first |
| `claude project purge` | Strong cleanup that removes project state. Use `--dry-run` or `--interactive` first |
| `ANTHROPIC_BEDROCK_SERVICE_TIER` | Only Bedrock users set this in the provider environment. Do not include in Harness defaults |
| `claude_code.skill_activated.invocation_trigger` | In telemetry, distinguish the reason for skill activation |
| PowerShell primary shell | On Windows, guide with PowerShell primary as the assumption; avoid Bash-only examples |
| Forked skills / subagents deferred tools | For workflows that need deferred tools on the first turn, write in a way that allows explicit tool discovery |

## Effort guidance

`${CLAUDE_EFFORT}` is a variable for referencing the current effort level from within skill content.
This is not for "the skill deciding its own effort," but for "using the current effort level
in descriptions or branching logic."

Acceptable usage:

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, keep the review to confirmed blockers.
If effort is xhigh, include adversarial checks.
```

Patterns to avoid:

- Requesting "always switch to xhigh" from within skill content
- Ignoring the effort specification from the user / parent workflow
- Treating `${CLAUDE_EFFORT}` as a failure condition when it is empty

## MCP `alwaysLoad`

MCP tool search defers loading tool schemas to conserve context.
`alwaysLoad: true` exempts a server from this deferral and makes tools visible from session start.

When to use:

- Small, core tool servers used every turn
- Servers that are always needed on the first move of a workflow
- A small number of servers where delayed discovery via tool search degrades work quality

When to avoid:

- Servers with many tools
- Integrations used only occasionally
- Database / observability servers with large schemas

Example:

```json
{
  "mcpServers": {
    "core-tools": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "alwaysLoad": true
    }
  }
}
```

## Plugin cleanup

`claude plugin prune` removes plugins that were automatically installed as plugin dependencies
but are no longer needed. It is not intended to remove plugins that were installed directly by the user.

Recommended:

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

In Harness setup, present this as guidance after uninstall.
Do not run unconditionally during initial setup or release procedures.

## Project state cleanup

`claude project purge [path]` is a strong cleanup command that deletes transcripts, tasks,
file history, and config entries that Claude Code holds for a project.

Recommended:

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

When to use:

- Archiving a project
- Clearing old local state before a team handoff
- When project path / owner has changed and old state is in the way

When to avoid:

- There is still work in progress
- Transcripts or task queues need to be preserved as evidence
- You just want to "make it lighter" without having confirmed what to delete

## Provider guidance

`ANTHROPIC_BEDROCK_SERVICE_TIER` is treated as an environment variable related to provider-side
tuning when using Bedrock.
Do not include a default value in Harness plugin defaults, templates, or shared project settings.

Reason:

- Not needed for users who do not use Bedrock
- The correct value changes by team / account / region
- Provider settings are close to the user / organization responsibility boundary

Bedrock guidance must not mix Claude Code's `CLAUDE_CODE_USE_BEDROCK` / `ANTHROPIC_*` env vars
with Codex provider settings.

## Telemetry guidance

`claude_code.skill_activated.invocation_trigger` is a telemetry attribute for seeing how a skill
was launched.

Representative values:

| Value | Meaning |
|----|------|
| `user-slash` | User explicitly launched as a slash command |
| `claude-proactive` | Claude launched proactively from context |
| `nested-skill` | Launched internally from another skill / workflow |

In Harness, `user-invocable: false` skills like media / announcement types must not assume
`claude-proactive` invocation.
Expected invocation is `user-slash` or `nested-skill`.

## Windows shell guidance

On Windows, when the PowerShell tool is enabled, treat it as the primary shell.
Avoid guidance that assumes Git Bash exclusively.

Writing style:

- Include `pwsh` / PowerShell examples alongside POSIX examples
- Do not limit to POSIX-only `export`
- Be aware of differences in path separators and quoting

## Forked skills / subagents and deferred tools

`context: fork` skills and subagents also need deferred tools.
In workflow content, do not be vague about which tools are needed on the first turn;
make tool discovery explicit where needed.

Examples:

- If WebFetch is needed, include it in allowed-tools / tools
- If an MCP tool is needed, specify the server name and purpose
- Write steps for searching and verifying, assuming tools might not be visible on the first turn

This reduces the chance of incorrectly deciding "the tool I expected to use isn't available"
at the first judgment in a forked context.

## Sources

- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Claude Code MCP docs: https://code.claude.com/docs/en/mcp
- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
