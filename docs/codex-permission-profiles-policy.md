# Codex Permission Profiles Policy

Last updated: 2026-05-27

This document records how Harness treats Codex `0.125.0` and `0.128.0`
permission-profile changes through `0.134.0`, with `--profile` as the primary
selector as of 0.134.0.

## In One Sentence

Harness should guide users toward explicit Codex profiles, sandbox choices, and
managed network rules, while keeping `--full-auto` as legacy behavior only.

## Analogy

A permission profile is like a building access card.
It can say which rooms you may enter, whether you may write on the shared
whiteboard, and whether you may connect to the outside network.
Harness should label the access cards clearly instead of handing everyone an
unlabeled master key.

## Official References

- OpenAI Codex `rust-v0.134.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.134.0>
- Codex config reference: <https://developers.openai.com/codex/config-reference>

## Scope

This policy covers these upstream items:

| Upstream item | Harness decision |
|---------------|------------------|
| Permission profiles round-trip across Codex surfaces | Treat profiles as the durable policy language for user/project config and admin requirements. |
| Built-in permission profiles, sandbox profile selection, cwd controls, active-profile metadata | Prefer `--profile`, project trust, and explicit sandbox modes in docs. Do not invent flags that are absent from the installed Codex help. |
| Managed network hardening | Document network policy placement and use managed network keys only in user/project/admin config, not in Harness shipped defaults. |
| `codex exec --json` reasoning-token usage | Treat JSON usage as telemetry input for future loop reports; do not parse it in the current wrapper until the output contract is tested. |
| Rollout tracing | Keep Codex rollout trace separate from Harness AgentTrace until a mapper prevents double counting. |
| `codex update` | Prefer the built-in update command when present; keep package-manager update only as fallback. |
| `--full-auto` deprecation | Do not make it the default in new docs or new wrappers. Existing legacy wrapper usage needs a separate behavior migration test before changing runtime flags. |
| `--profile` primary (0.134.0) | Treat `--profile` as the primary selector in setup/companion/docs. Legacy profile v1 selectors are not recommended in new Harness docs. |
| `on-failure` approval mode | Do not recommend `on-failure` in new Harness docs or shipped config. Prefer explicit `--ask-for-approval on-request` or profile-driven approval unless operator docs require otherwise. |

## Verified Local CLI Surface

On 2026-05-27 this workspace had `codex-cli 0.134.0`.
Local help confirmed:

- `codex update`
- `codex --profile <CONFIG_PROFILE>` (primary selector as of 0.134.0)
- `codex exec --profile <CONFIG_PROFILE>`
- `codex --sandbox read-only|workspace-write|danger-full-access`
- `codex exec --sandbox read-only|workspace-write|danger-full-access`
- `codex --ask-for-approval untrusted|on-failure|on-request|never`
- `codex exec --json`
- `--dangerously-bypass-approvals-and-sandbox`

Local help did not show `--full-auto`, `--permission-profile`, or
`--sandbox-profile`.
Harness docs and scripts must not introduce those as supported replacement
flags.

## Config Guidance

Use Codex configuration profiles for workflow shape, and named permission
profiles for filesystem and network boundaries.
The exact profile names are user or organization policy; Harness only provides
patterns.

Example user/project config:

```toml
profile = "harness-readonly"

[profiles.harness-readonly]
sandbox_mode = "read-only"

[profiles.harness-workspace]
sandbox_mode = "workspace-write"

[permissions.harness-readonly.filesystem]
":project_roots" = { "." = "read" }

[permissions.harness-workspace.filesystem]
":project_roots" = { "." = "write", "**/.env*" = "none" }

[permissions.harness-workspace.network]
enabled = true
mode = "limited"
domains = { "github.com" = "allow", "api.github.com" = "allow", "*" = "deny" }
```

Notes:

- Keep Harness distributed `codex/.codex/config.toml` minimal.
- Do not copy organization host policy or secrets into the distributed config.
- Use `projects.<path>.trust_level = "trusted"` or `"untrusted"` for project
  trust decisions.
- Treat `danger-full-access` and
  `--dangerously-bypass-approvals-and-sandbox` as externally sandboxed
  automation options, not normal Harness defaults.
- If a config key changes in a future Codex release, update this document after
  checking `codex --help`, `codex exec --help`, and the official config
  reference.

## Managed Network Policy

Codex `0.128.0` hardened managed network behavior around deferred denials,
proxy bypass defaults, resolved targets, IPv6 host matching, and `git -C`
approval handling.

Harness should not duplicate those checks in shell wrappers.
Instead:

- place network allow/deny rules in named `permissions.<name>.network` tables;
- prefer `mode = "limited"` for Harness work profiles;
- avoid `dangerously_allow_all_unix_sockets` and
  `dangerously_allow_non_loopback_proxy` in shared examples;
- keep proxy URLs, socks URLs, and domain allowlists in user/project/admin
  config.

## Runtime Wrapper Policy

`scripts/codex/codex-exec-wrapper.sh` still contains legacy `--full-auto`
runtime usage from earlier hardening work.
Do not copy that pattern into new docs or new scripts.

Changing the wrapper default is a behavior change because it controls approval
and sandbox execution for non-interactive work.
Before changing it, add a focused test that proves the replacement command has
the same intended boundary on the installed Codex version.

Current safe migration target to investigate:

```bash
codex --ask-for-approval never --sandbox workspace-write exec -
```

This command shape uses root-level shared flags that local `codex --help`
confirmed and `codex exec` inherits in modern Codex.
It is still marked "investigate" here because the exact runtime equivalence to
legacy `--full-auto` must be proven before rollout.

## Telemetry Policy

`codex exec --json` can expose reasoning-token usage for programmatic
consumers.
Harness should treat it as structured telemetry only after tests cover the JSONL
event names and missing-field behavior.

Until then:

- do not make the wrapper parse JSON usage by default;
- do not mix JSONL telemetry with human stdout;
- send human progress to stderr when a command promises machine-readable stdout;
- keep future reasoning-token summaries in loop status artifacts, not chat-only
  text.

Codex rollout tracing is useful, but it overlaps with Harness AgentTrace.
Future adoption should map Codex trace IDs into Harness trace artifacts rather
than recording the same worker/subagent relationship twice.

## Why This Way

Permissions are a safety boundary.
If Harness silently guesses new flags or broadens sandbox behavior, users cannot
tell what the agent is allowed to do.

So Phase 58.3.1 keeps runtime changes conservative:

- docs name the current policy;
- tests prevent stale default guidance from returning;
- wrappers are changed only when local help and behavior tests prove the
  replacement.
