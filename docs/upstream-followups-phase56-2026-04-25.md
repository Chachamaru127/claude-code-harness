# Phase 56 Follow-up Decisions - 2026-04-25

This document records the split between "implement now" and "record only" decisions
for Phase 56 follow-up tasks `56.2.1` through `56.2.4`.

## In a nutshell

Harness **follows up minimally on already-shipped surfaces only and does not add overlapping wrappers.**

## Analogy

When new road signs are added,
add what can be directly appended to existing signboards,
and defer changes that would duplicate traffic control itself.

## Official References

- Claude Code status line docs: <https://code.claude.com/docs/en/statusline>
- Claude Code hooks docs: <https://code.claude.com/docs/en/hooks>
- OpenAI Codex `rust-v0.124.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.124.0>
- OpenAI Codex config reference: <https://developers.openai.com/codex/config-reference>
- OpenAI blog, Codex App Server: <https://openai.com/index/unlocking-the-codex-harness/>

## 56.2.1 Claude Code `PostToolUse.duration_ms` and status line fields

### Current Harness surface

| Surface | Current state | Decision impact |
|---------|---------------|-----------------|
| `scripts/session-monitor.sh` | Collects project / git / Plans state on `SessionStart` only; does not receive `PostToolUse` input | Mixing `duration_ms` here would shift responsibility |
| `scripts/statusline-harness.sh` | Already reads Claude Code status line stdin JSON | `effort.level` / `thinking.enabled` can be adopted at low risk |
| `statusline-telemetry.jsonl` | Stores cost / duration / role from the status line | `effort` / `thinking` can be stored at the same granularity |

### Decision

| Upstream field | Harness decision | Why |
|----------------|------------------|-----|
| `PostToolUse.duration_ms` | **PostToolUse.duration_ms is no-op for now** | Harness's shipped Session Monitor is for `SessionStart`; there is no per-tool latency sink yet. Mixing with `cost.total_duration_ms` would make "session time" and "individual tool time" confusing |
| `effort.level` | **Adopt in statusline** | `scripts/statusline-harness.sh` already reads the status line JSON, so it can be reflected without adding extra runtime hooks |
| `thinking.enabled` | **Adopt in statusline** | Same as `effort.level` — can be safely visualized via the existing statusline surface |

### Display spec

- Display `effort:<level>` on status line line 1
- Display `think:on` when thinking is enabled, `think:off` when disabled
- Show nothing when the field is absent
- Add `effort_level` and `thinking_enabled` to the telemetry JSONL

## 56.2.2 Codex `0.124.0` stable hooks parity review

### Parity table

| Aspect | Claude Code | Codex `0.124.0` | Harness decision |
|--------|-------------|-----------------|------------------|
| Main config surface | `hooks/hooks.json` / `.claude-plugin/hooks.json` | inline `config.toml` and managed `requirements.toml` are explicitly mentioned in the release note | **Do not add to shipped `codex/.codex/config.toml`** |
| Admin policy surface | project / plugin settings + hook files | `requirements.toml` allows fixing security-sensitive policy | Keep org policy in docs; do not include in distribution defaults |
| MCP tools observation | Claude Code hook matcher handles each tool name individually | MCP tools observation explicitly mentioned in release note | Read-only diagnostic value exists, but do not duplicate Claude-side hooks |
| `apply_patch` observation | Claude side uses `Write` / `Edit` guardrails primarily | `apply_patch` observation mentioned in release note | No-op while there are no Codex-package-specific tests |
| long-running Bash observation | Claude side uses `PermissionRequest` / `PostToolUseFailure` / `Monitor` together | long-running Bash observation mentioned in release note | Do not add double log policy to Codex runtime |
| Block timing | Strong pre-execution deny / post-execution feedback | Different surface; admin requirements also involved | Parity is aligned in terms of "how to divide the same policy" |

### Decision

- **Perform parity review for Codex hooks only; make shipped config a no-op**
- Leave only comments in `codex/.codex/config.toml` explaining why additions were not made
- `requirements.toml` is organizational policy; do not speculatively write it into distribution templates
- Do not immediately duplicate the same responsibilities into Codex that Claude Code guardrails already hold

### Note on docs drift

`rust-v0.124.0` release explicitly states stable hooks and inline/managed config.
However, the current config reference still retains feature flag descriptions for `hooks.json` loading.
Harness, citing this docs drift, **records only the parity table and no-op reasoning for now, without speculative config implementation.**

## 56.2.3 `prUrlTemplate` / `--from-pr` multi-host review support

### Current boundary

| Surface | Current assumption | Decision |
|---------|--------------------|----------|
| `harness-review` | diff / file review is git-based and host-agnostic, but PR metadata auto-retrieval is not yet abstracted | Keep review core as-is; PR host abstraction comes later |
| `harness-release` | Release automation is built assuming `gh` CLI and GitHub remote | Maintain GitHub-first automation |
| footer PR links | If `prUrlTemplate` is available, human-facing links can be multi-host | Organize as **docs-only**; do not extend to automation surfaces yet |

### Decision

- `prUrlTemplate` / `--from-pr` multi-host support is limited to **docs-only**
- Keep future candidate for showing review URLs in GitHub Enterprise / GitLab / Bitbucket
- However, **GitHub CLI remains primary** for owner / branch / CI / release asset retrieval
- Do not mix non-GitHub hosts into automation until a separate task is created to split the API / auth / CI surface per host

## 56.2.4 Codex `0.124.0` multi-environment app-server and branch/workdir policy

### Current Harness policy

| Current mechanism | What it protects | Multi-environment implication |
|-------------------|------------------|-------------------------------|
| Worker `isolation: worktree` | Reduces parallel write conflicts within the same repo | Maintains branch/worktree boundary for the primary repo |
| Codex sandbox / remote policy docs | Organizes sandbox differences per remote host | Even with more environments, policy storage belongs on the requirements side |
| cherry-pick based merge | Clarifies the main branch integration boundary | Does not mix artifacts from multiple environments directly |

### Safe default

| Scenario | Safe default |
|----------|--------------|
| Want to inspect multiple environments in 1 session | Inspection is fine, but **writes are limited to 1 primary environment per turn** |
| Mixing a remote environment | Confirm the non-primary environment as read-only first, then explicitly switch for writes |
| Multiple branches / workdirs | Perform merge / cherry-pick / Plans updates only in the primary repo/worktree |
| Switching environments | Document the target repo / branch / workdir explicitly before the next write |

### Decision

- Codex App Server's multi-environment is **adopted as workflow guidance**
- Harness's own branch/workdir implementation uses single repo / primary worktree as safe default,
  and adds a **Codex pre-write primary-environment guard**
- Add **one primary environment per write turn** as safe default to `codex/README.md`
- Even with remote workspaces, start with read-only for non-primary ones

### Runtime guard

- `scripts/codex-primary-environment-guard.sh` records the first write destination as the primary environment
- Subsequent writes targeting a different worktree / different repo are stopped by default
- To temporarily allow: `HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1`
- To switch the primary itself: `HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1`
- To disable the guard only for special environments: `HARNESS_CODEX_DISABLE_PRIMARY_ENV_GUARD=1`

## Why This Way

Harness aims to balance two goals:
"not missing upstream new features" and
"not adding duplicate wrappers just because something looks convenient."

Therefore in Phase 56.2:
small follow-up was made to the already-shipped statusline,
while hooks / multi-host / multi-environment boundaries were fixed first in docs and safe defaults.
