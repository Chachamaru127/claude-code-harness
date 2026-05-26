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

### Option 1.2: Direct Codex Plugin (verified CLI smoke)

Codex CLI `0.132.0` can install the checked-in `.codex-plugin/plugin.json`
surface when it is packaged under a local Codex marketplace source. The current
smoke test assembles that marketplace in a temporary directory and installs it
in an isolated `CODEX_HOME`:

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
bash tests/test-codex-plugin-adapter.sh
```

This installs the `.codex-plugin/plugin.json` surface and the
`codex/.codex/skills/` mirror through Codex's plugin cache during the smoke. It
is a Codex CLI compatibility route, not Codex app proof. Keep
`scripts/setup-codex.sh --user` as the user-facing fallback path when
marketplace install is unavailable or when a user needs the existing
backup/legacy cleanup behavior.

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
Codex `0.130.0` stable (`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) also lets Bedrock auth use AWS console-login credentials from `aws login` profiles.
Harness documents that path, but does not force it into the shipped `config.toml`.

Use Bedrock only in the user or project config that actually needs it:

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

Harness does not write AWS credentials, Bedrock endpoints, provider secrets, or AWS console-login credential material.
Run `aws login` and maintain the resulting AWS profile outside Harness; Harness only points Codex at the profile name when the user opts in.
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

## Permission Profiles And Full-Auto Migration

Codex `0.125.0` carries permission profile state across TUI sessions, user turns,
MCP sandbox state, shell escalation, and app-server APIs.
Codex `0.128.0` expands this with built-in permission profiles, sandbox profile
selection, cwd controls, active-profile metadata, managed network hardening,
`codex update`, and the `--full-auto` deprecation path.

Harness policy:

- Prefer explicit `--profile` and `--sandbox` choices in user/project config.
- Keep named `permissions.<name>.filesystem` and `permissions.<name>.network`
  rules in user, project, or managed requirements config.
- Do not add `--full-auto` to new docs or new runtime entrypoints.
- Do not invent unsupported flags such as `--permission-profile` or
  `--sandbox-profile`; verify with `codex --help` and `codex exec --help`
  before documenting CLI syntax.
- Use `codex exec --json` reasoning-token data only after the JSONL contract is
  covered by tests.
- Keep Codex rollout tracing separate from Harness AgentTrace until a mapper
  avoids double counting multi-agent relationships.
- Prefer `codex update` when the command exists; use package-manager updates
  only as fallback.

The legacy `scripts/codex/codex-exec-wrapper.sh` `--full-auto` path is not a
new default. It remains a behavior-preserving compatibility path until a focused
test proves the replacement approval/sandbox command on the installed Codex
version.

Details: `docs/codex-permission-profiles-policy.md`.

## Codex 0.130.0 Workflow Policy

Codex `0.130.0` stable (`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) changes several app-server and plugin workflows.
Harness treats them as opt-in operational surfaces, not new shipped defaults.

- `codex remote-control` is the simpler top-level entrypoint for a headless remotely controllable app-server. Start it explicitly; the shipped Harness config does not enable remote-control defaults.
- App-server clients can page large threads. For long Breezing or loop runs, inspect the needed page range instead of assuming one transcript fetch is complete.
- `view_image` resolves files through selected environments in multi-environment sessions. Report the selected environment and workdir with image evidence.
- Live app-server threads pick up config changes without restart. Still verify config diffs and avoid logging secrets or provider credentials.
- Turn diffs stay accurate across `apply_patch`, including partial failures. Use them for review context, then confirm with `git diff` and tests.
- Plugin details now show bundled hooks. Harness keeps bundled hooks opt-in and checks plugin details before install or share.
- Plugin sharing exposes link metadata and discoverability controls. Treat metadata and discoverability as release surface, not decoration.
- Configurable OpenTelemetry trace metadata is useful for debugging and triage, but do not place user data, customer data, API keys, or provider credentials in trace metadata.
- Built-in MCPs are now first-class runtime servers. Keep built-in MCP ownership separate from plugin-provided MCP ownership.
- The `CODEX_HOME` environments TOML provider is a user-level environment source. Report the selected environment and keep write turns on one primary environment.
- Codex removed extra skills list roots; use the installed Harness mirror or explicit `[[skills.config]]` path-based loading instead of relying on implicit extra roots.

Details: `docs/codex-plugin-workflows-policy.md`.

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
