# Codex Plugin Policy

Always use the **official plugin `openai/codex-plugin-cc`** to call Codex.

## Basic Policy

Direct calls to raw `codex exec` are prohibited. Use one of the following two methods to call Codex:

1. **`scripts/codex-companion.sh`** — for calls from within Harness skills and agents
2. **`/codex:*` commands** — for ad-hoc use in user-facing interactions

## Prohibited Actions

- Direct calls to `codex exec` (except within `skills-codex/`; see exceptions below)
- Using `mcp__codex__codex` (the MCP server has been deprecated)
- Searching for the Codex MCP via ToolSearch
- Re-registering the MCP server via `claude mcp add codex`

## MCP Block (v2.1.78+)

The legacy MCP tool is blocked via the `deny` rule in settings.json (already configured):

```json
{
  "permissions": {
    "deny": ["mcp__codex__*"]
  }
}
```

## Correct Usage

### Task delegation (implementation, debugging, investigation)

```bash
# Delegate a write-enabled task
bash scripts/codex-companion.sh task --write "Fix the bug"

# Via stdin (for large prompts)
cat "$PROMPT_FILE" | bash scripts/codex-companion.sh task --write

# Resume the previous thread
bash scripts/codex-companion.sh task --resume-last --write "Continue where you left off"
```

### Review

```bash
# Review the working tree
bash scripts/codex-companion.sh review

# Review from a specific base ref
bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"

# Adversarial review (challenging design decisions)
bash scripts/codex-companion.sh adversarial-review
```

### Setup and job management

```bash
# Check whether Codex is available
bash scripts/codex-companion.sh setup --json

# Check running jobs
bash scripts/codex-companion.sh status

# Retrieve job results
bash scripts/codex-companion.sh result <job-id>

# Cancel a job
bash scripts/codex-companion.sh cancel <job-id>
```

### /codex:* commands (user interaction)

```
/codex:setup              — Verify Codex CLI setup
/codex:rescue             — Delegate a task (investigation, implementation, debugging)
/codex:review             — Code review
/codex:adversarial-review — Adversarial review
/codex:status             — Check job status
/codex:result             — Retrieve job results
/codex:cancel             — Cancel a job
```

## Verdict mapping (official plugin ↔ Harness)

The review output of the official plugin uses a different schema from Harness. Conversion rules:

| Official plugin | Harness | Notes |
|---|---|---|
| `approve` | `APPROVE` | |
| `needs-attention` | `REQUEST_CHANGES` | |
| `findings[].severity: critical` | `critical_issues[]` | affects verdict |
| `findings[].severity: high` | `major_issues[]` | affects verdict |
| `findings[].severity: medium/low` | `recommendations[]` | does not affect verdict |

## Exception: Codex native skills

Skills inside `skills-codex/` **run within the Codex CLI itself**, so
native Codex APIs such as `spawn_agent` / `wait_agent` / `send_input` / `close_agent`
may continue to be used. However, review calls are recommended to go through the companion.

## Features provided by the official plugin

| Feature | Description |
|------|------|
| Job management | Start, resume, cancel, and retrieve results for threads |
| App Server Protocol | Reliable Codex communication via JSON-RPC over TCP |
| Structured output | Structured review conforming to `review-output.schema.json` |
| Stop Review Gate | Automatic review gate at session termination |
| GPT-5.4 Prompting | Optimized prompt guidance for Codex |
