# Codex Sandbox And Execution Policy

Last updated: 2026-05-03

This document records how Harness treats Codex sandbox and `codex exec` changes.
For Codex `0.125.0` / `0.128.0` permission profiles, managed network hardening,
`codex exec --json` telemetry, rollout tracing, `codex update`, and `--full-auto`
deprecation policy, see `docs/codex-permission-profiles-policy.md`.

## ひとことで

Harness は、remote environment ごとの sandbox 制約を `requirements.toml` の管理ポリシーとして案内します。
一方で、`codex exec` の shared flags 継承は Codex 本体の修正として受け取り、Harness wrapper では同じ flag を重ねません。

## たとえると

`requirements.toml` は、建物ごとの入館ルールです。
本社では「閲覧だけ」、開発室では「作業机への書き込みも可」、一時的な検証室では「限定的に広い権限も可」のように分けます。

`codex exec` wrapper は、その建物に入る時の受付係です。
受付係が同じ許可証を二重に渡すと、どちらが正しいか分かりにくくなります。
そのため、Codex 本体が root-level shared flags を引き継げるところは本体に任せます。

## Official References

- OpenAI Codex `rust-v0.123.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.123.0>
- Codex `remote_sandbox_config` PR: <https://github.com/openai/codex/pull/18763>
- Codex `codex exec` shared flags inheritance PR: <https://github.com/openai/codex/pull/18630>
- Codex config reference: <https://developers.openai.com/codex/config-reference>

## Scope

This policy covers two Codex `0.123.0` items:

| Upstream item | Harness surface | Harness decision |
|---------------|-----------------|------------------|
| `remote_sandbox_config` in requirements | sandbox / admin execution policy | Document as a host-specific `requirements.toml` constraint. Do not put remote host policy into the shipped user `config.toml`. |
| `codex exec` inherits root-level shared flags | Codex wrapper scripts and setup docs | Treat as Codex automatic inheritance. Keep Harness wrapper defaults explicit only where they encode Harness intent. |

## `remote_sandbox_config`

`remote_sandbox_config` belongs to Codex requirements, not normal user setup defaults.
Use it when an organization needs different allowed sandbox modes for different host classes.

Example:

```toml
allowed_sandbox_modes = ["read-only"]

[[remote_sandbox_config]]
hostname_patterns = ["devbox-*.corp.example.com"]
allowed_sandbox_modes = ["read-only", "workspace-write"]

[[remote_sandbox_config]]
hostname_patterns = ["runner-*.ci.example.com"]
allowed_sandbox_modes = ["read-only", "danger-full-access"]
```

### Comparison Table

| Remote environment | Typical requirement | Example `hostname_patterns` | Allowed sandbox modes | Harness guidance |
|--------------------|---------------------|-----------------------------|-----------------------|------------------|
| Managed developer laptop / local workstation | Prefer the global organization default | no remote override | `["read-only"]` or org default | Keep this in top-level `allowed_sandbox_modes`. Do not add a host override unless policy truly differs. |
| Remote devbox | Let agents edit the checked-out workspace, but avoid full host access | `["devbox-*.corp.example.com"]` | `["read-only", "workspace-write"]` | Use `remote_sandbox_config` so devboxes can work without weakening every host. |
| Ephemeral CI runner | Allow broader sandbox mode only for disposable automation hosts | `["runner-*.ci.example.com"]` | `["read-only", "danger-full-access"]` | Keep the pattern narrow and pair it with CI isolation. Do not use broad wildcards for persistent machines. |
| High-risk shared host | Force read-only even if users prefer a looser local config | `["shared-*.corp.example.com"]` | `["read-only"]` | Put the stricter host rule in requirements so local user config cannot weaken it. |
| Unknown host | Fall back to source precedence and top-level requirements | no match | top-level `allowed_sandbox_modes` | Treat hostname matching as best-effort classification, not device authentication. |

### Resolution Rules

- `remote_sandbox_config` is evaluated from the local hostname, preferring a fully qualified hostname when Codex can resolve one.
- Hostname matching is best-effort classification. It is useful policy routing, but it is not strong device identity.
- Each requirements source applies the first matching `remote_sandbox_config` entry before requirements are merged.
- Source precedence still matters. A lower-precedence matching host rule must not override a higher-precedence source that already constrained `allowed_sandbox_modes`.
- Harness should not copy these entries into `codex/.codex/config.toml`, because this is organization policy and belongs in requirements.

## `codex exec` Shared Flags

Codex `0.123.0` fixed `codex exec` so root-level shared flags, such as sandbox and model options, are inherited by the `exec` subcommand.

Before this upstream fix, a command shaped like this could be misleading:

```bash
codex --sandbox read-only --model gpt-5.4 exec -
```

The root CLI parsed the shared options, but the `exec` command could still start with stale or default sandbox / model settings.
Codex now merges the root selections into `exec` before dispatch.

Harness policy:

- Do not add duplicate `--approval-policy` / `--sandbox` pairs around `codex exec`.
- Prefer one source of truth per call: either root shared flags supplied by the caller, or an exec-local Harness default.
- Keep wrapper-provided sandbox flags only when they represent Harness workflow intent.
- Keep model selection out of wrappers unless a task explicitly needs a pinned model.

## Wrapper Decision For 53.2.4

No runtime wrapper behavior changes in this task.

| Wrapper | Current behavior | Decision |
|---------|------------------|----------|
| `scripts/codex-companion.sh` structured task mode | Converts Harness `task --write` into `codex exec --sandbox workspace-write`; defaults read-only when no write/sandbox intent is present; preserves explicit caller sandbox flags | Keep. This is not duplicate root shared flag forwarding. It is Harness semantic mapping for structured task execution. |
| `scripts/codex/codex-exec-wrapper.sh` | Runs `codex exec - --full-auto` after injecting hardening instructions | Legacy compatibility only. Do not copy this into new docs or new wrappers. Changing it would alter approval/sandbox behavior and needs a separate task with behavioral tests. It already avoids adding separate `--approval-policy` and `--sandbox` pairs. |
| `scripts/codex-loop.sh` local worker | Uses a full-access one-cycle background prompt for the loop runner | Keep outside this task. 53.2.4 is policy and wrapper duplication review, not a loop permission migration. |

## Verification Record

2026-04-23 checks added:

- `tests/test-claude-upstream-integration.sh` verifies this policy doc, the snapshot decision, Feature Table status, CHANGELOG mention, and wrapper comments.
- `tests/test-codex-package.sh` verifies the Codex README points users to this sandbox / exec policy.
- Existing validation keeps `.claude-plugin/settings.json` `sandbox.failIfUnavailable` and metadata endpoint denied domains intact.

## Why This Way

Sandbox restrictions are security policy.
If Harness silently rewrites them in a wrapper, users and administrators lose a clear place to reason about the effective boundary.

So Harness keeps the boundary simple:

- organization-wide and host-specific constraints live in Codex requirements;
- user/project runtime preferences live in Codex config or explicit CLI flags;
- Harness wrappers only add flags when they are expressing Harness workflow intent.

This lets Codex `0.123.0` improvements carry the shared flag inheritance, while Harness documents where each policy belongs.
