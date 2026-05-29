# Agent Frontmatter Policy

This document records which `agents/*.md` frontmatter fields Harness treats as
runtime-enforced, advisory, or unsupported for plugin-delivered agents.

Checked against the Claude Code subagents documentation on 2026-05-05:
https://code.claude.com/docs/en/sub-agents

## Current Policy

Plugin subagents do not support these frontmatter fields:

- `hooks`
- `mcpServers`
- `permissionMode`

Claude Code ignores those fields when agents are loaded from a plugin. Harness
therefore does not keep them in `agents/worker.md`, `agents/reviewer.md`,
or `agents/advisor.md`.

If an operator needs per-agent hooks or permission mode experiments, copy the
agent into `.claude/agents/` or `~/.claude/agents/` and treat that as a local
override, not a shipped plugin contract.

## Supported Fields Used By Harness

| Field | Harness use |
|---|---|
| `name` | Stable agent identifier |
| `description` | Delegation routing hint |
| `tools` | Tool allowlist |
| `disallowedTools` | Tool denylist |
| `model` | Preferred model family or model id |
| `effort` | Reasoning effort hint |
| `maxTurns` | Turn budget |
| `color` | UI display hint |
| `memory` | Agent memory scope |
| `isolation` | `worktree` isolation for Worker |
| `initialPrompt` | First-turn operating checklist |
| `skills` | Skills preloaded into agent context |

## Current Agent Audit

| Agent | Mutating tools | Read-only intent | Notes |
|---|---:|---:|---|
| `worker` | Yes | No | Implementation worker. Uses `tools` plus Worker preflight. |
| `reviewer` | No | Yes | `Write`, `Edit`, `Bash`, and `Agent` are denied. |
| `advisor` | No | Yes | Returns `advisor-response.v1`; does not execute commands. |

`rg -n "permissionMode:|hooks:" agents/*.md` should return no matches.

## Worker Write Guard Responsibility

Worker safety is not enforced by agent-local hooks. It is layered:

1. Plugin-level hooks in `hooks/hooks.json` and `.claude-plugin/hooks.json`
   route tool use through the Harness hook entrypoints.
2. Go guardrails under `go/internal/guardrail/` make the concrete deny / ask /
   warn decisions.
3. `.claude-plugin/settings.json` and generated settings provide session-level
   permission and sandbox defaults.
4. `agents/worker.md` preflight tells the Worker to verify file scope, DoD,
   contract path, and validation commands before editing.
5. Parent session permission mode is inherited by plugin agents; agent
   frontmatter does not override it.

## Why The Fields Were Removed

Keeping ignored fields in shipped plugin agents makes the configuration look
stronger than it is. Removing them makes the real safety boundary visible:
plugin settings, plugin-level hooks, Go guardrail, and explicit Worker
preflight.
