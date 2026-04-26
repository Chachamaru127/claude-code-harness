# Harness for Codex CLI

Codex CLI compatible distribution of Claude Code Harness.

## Setup

### Option 0: Path-based loading (experimental; verify on your Codex build)

No file copy needed. Add skill paths directly to `config.toml`:

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git

# Add to ~/.codex/config.toml (or .codex/config.toml for project-local):
cat >> "${CODEX_HOME:-$HOME/.codex}/config.toml" <<TOML

# Harness skills (path-based, no copy needed)
[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-work"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-plan"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-sync"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-review"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-release"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-setup"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/breezing"
enabled = true

[[skills.config]]
path = "$(pwd)/claude-code-harness/codex/.codex/skills/harness-loop"
enabled = true
TOML
```

If your Codex build picks up `[[skills.config]]`, `git pull` updates them in place.
Because support can drift by Codex build, verify this on a fresh Codex process before using it as the only onboarding path for end users.

### Option 1: Script (recommended, user-based)

```bash
# Default: install to CODEX_HOME (user-based)
/path/to/claude-code-harness/scripts/setup-codex.sh --user
```

This is the reliable default for end users today.
After updating Harness, rerun the same script to sync `~/.codex/skills` to the latest `harness-*` bundle.

Project-local install is still available:

```bash
/path/to/claude-code-harness/scripts/setup-codex.sh --project
```

### Option 1.5: Claude Code (in-session)

If you use Claude Code Harness, run:

```bash
/setup codex
```

### Option 2: Manual (user-based)

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
BACKUP_ROOT="$CODEX_HOME/backups/manual-codex-setup"
mkdir -p "$CODEX_HOME/skills" "$CODEX_HOME/rules" "$BACKUP_ROOT"

# Prevent duplicate skill listings from legacy backup/archive directories.
for legacy in "$CODEX_HOME/skills"/_archived "$CODEX_HOME/skills"/*.backup.*; do
  [ -e "$legacy" ] || continue
  mv "$legacy" "$BACKUP_ROOT/"
done

for entry in claude-code-harness/codex/.codex/skills/*; do
  name="$(basename "$entry")"
  case "$name" in
    _archived|*.backup.*) continue ;;
  esac
  rm -rf "$CODEX_HOME/skills/$name"
  cp -R "$entry" "$CODEX_HOME/skills/"
done
cp -R claude-code-harness/codex/.codex/rules/* "$CODEX_HOME/rules/"
cp claude-code-harness/codex/.codex/config.toml "$CODEX_HOME/config.toml"
```

## Codex Multi-Agent Defaults

- `features.multi_agent = true`
- Harness role declarations are installed under `[agents.*]`
- Setup scripts always ensure `multi_agent` + role defaults in target `config.toml`
- Setup scripts keep backups in `$CODEX_HOME/backups/*` and move removed Harness skills out of `skills/` so Codex does not keep listing stale commands

## Provider And Model Policy

Codex `0.123.0` adds a built-in `amazon-bedrock` provider with AWS profile support.
Harness documents that path, but does not force it into the shipped `config.toml`.

Use Bedrock only in the user or project config that actually needs it:

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

Harness does not write AWS credentials, Bedrock endpoints, or provider secrets.
Claude Code Bedrock settings such as `CLAUDE_CODE_USE_BEDROCK`, Anthropic model overrides, and `modelOverrides` are separate from Codex `model_provider`.

Codex `0.123.0` also refreshes bundled model metadata, including the current `gpt-5.4` default.
Harness therefore leaves `model` unset in the distributed Codex config and avoids old fixed model samples such as `gpt-5.2-codex`.
Pin `model = "gpt-5.4"` only in your own config when reproducibility or an organization allowlist requires it.

Details: `docs/codex-provider-setup-policy.md`.

## MCP Diagnostics And Plugin Loading

Codex `0.123.0` keeps the normal `/mcp` view fast and adds `/mcp verbose` for full MCP diagnostics.

Use this split:

- Run `/mcp` for the usual lightweight server status check.
- Run `/mcp verbose` only when a server is missing, a startup error is unclear, or you need to inspect diagnostics, resources, and resource templates.

Codex plugin MCP loading accepts both supported `.mcp.json` shapes:

```json
{
  "mcpServers": {
    "docs": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
```

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

Prefer `mcpServers` for new plugin files because it is easier to share with other tools.
Keep existing top-level server map files when they already work.
This is Codex plugin loading guidance, not Claude Code `claude mcp` or `.claude/mcp.json` guidance.

Details: `docs/codex-mcp-diagnostics.md`.

## Sandbox And Exec Policy

Codex `0.123.0` adds host-specific `remote_sandbox_config` requirements for remote environments.
Use this in admin-managed `requirements.toml` when different hosts need different allowed sandbox modes.
Do not copy organization host policy into the shipped Harness `codex/.codex/config.toml`.

Example shape:

```toml
allowed_sandbox_modes = ["read-only"]

[[remote_sandbox_config]]
hostname_patterns = ["devbox-*.corp.example.com"]
allowed_sandbox_modes = ["read-only", "workspace-write"]

[[remote_sandbox_config]]
hostname_patterns = ["runner-*.ci.example.com"]
allowed_sandbox_modes = ["read-only", "danger-full-access"]
```

Use a narrow hostname pattern for each remote class:

- remote devboxes usually allow `workspace-write`;
- ephemeral CI runners may allow broader modes only when the host is disposable and isolated;
- shared or unknown hosts should fall back to stricter top-level `allowed_sandbox_modes`.

Codex `0.123.0` also makes `codex exec` inherit root-level shared flags such as sandbox and model options.
Harness therefore avoids adding duplicate `--approval-policy` / `--sandbox` pairs in wrapper docs.
`scripts/codex-companion.sh` still maps Harness `task --write` to an exec-local `--sandbox workspace-write`, because that is Harness workflow intent rather than duplicate root flag forwarding.

Details: `docs/codex-sandbox-execution-policy.md`.

## Runtime Behavior

- `$harness-plan`, `$harness-sync`, `$harness-work`, `$breezing`, `$harness-review`, and `$harness-loop` are the primary Codex-facing workflow surfaces.
- Codex should be driven from the `harness-*` skill names, not legacy aliases like `$work`, `$plan-with-agent`, or `$verify`.
- `$harness-work` and `$breezing` use Codex native multi-agent orchestration.
- `$harness-loop` uses a real background runner behind `harness codex-loop start/status/stop`.
- `$harness-loop` defaults to a Breezing executor: each cycle runs the current ready batch, not just one task.
- `$harness-loop --max-workers N` caps the ready batch concurrency; `--max-workers max` uses all currently ready tasks in the selected range.
- `$harness-loop --executor task` is the escape hatch for the older one-task-per-cycle local worker path.
- Native flow uses `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`.
- `breezing` keeps Lead/Worker/Reviewer separation while reusing Codex-native subagents instead of older teammate-only wording.

## Multi-Environment Safe Default

Codex `0.124.0` lets one app-server session choose an environment and working directory per turn.
Harness keeps a narrower operational default so branch and worktree boundaries stay understandable.

- Use one primary environment per write turn.
- Treat non-primary or remote environments as read-only until you explicitly switch the write target.
- Keep branch updates, cherry-picks, and Plans.md status changes in the primary repo/worktree only.
- When you switch environment, restate the target repo, branch, and workdir before the next write.

Harness now adds a primary-environment write guard on Codex write paths.
The first write target becomes the primary repo/worktree for that execution root.
If a later write points at a different worktree or repo, Harness stops it unless you opt in explicitly.

- Temporary override: `HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1`
- Move the primary target: `HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1`
- Disable the guard entirely: `HARNESS_CODEX_DISABLE_PRIMARY_ENV_GUARD=1`

This keeps multi-environment exploration available without weakening Harness's single-repo merge discipline.
Details: `docs/upstream-followups-phase56-2026-04-25.md`.

## Realtime Handoff And Silence Policy

Codex `0.123.0` lets background agents receive transcript deltas during realtime handoff.
Harness treats those deltas as context, not as a reason to post extra progress messages.

Use this split:

- `$harness-loop` should normally report once per ready batch cycle, plus blocked / validation / review / advisor stop events.
- `$harness-loop` may also surface Breezing Lead progress feed updates when task completion counts change inside the batch.
- `$breezing` should normally report once per completed task through the Lead progress feed.
- Worker / Advisor / Reviewer agents should stay silent when transcript deltas do not change task status, review verdict, or advisor decision.
- Advisor / reviewer drift, plateau, and contract readiness failures are never hidden by silence policy.

Detailed progress belongs in `harness codex-loop status --json`, runner logs, job logs, and review artifacts.
The chat should show the decisions a user can act on.

## State Path

Harness runtime state is written under:

```text
${CODEX_HOME:-~/.codex}/state/harness/
```

## Rules

`$CODEX_HOME/rules/harness.rules` provides command guardrails.

## Notes

- Codex reads skills from `$CODEX_HOME/skills/<skill-name>/SKILL.md`.
- Project-local `.codex/skills` overrides user-level skills.
