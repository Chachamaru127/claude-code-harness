# Tool-First Onboarding

Start here by choosing the tool you are using now (今使っている tool).
Claude Code Harness is still Claude-first, but Phase 73 makes the entry point
explicit for every host so users do not mistake a candidate route for a proven
install path.

Detailed commands live in [install.md](install.md). Existing users should run
the report-first migration path in [migration.md](migration.md) before cleanup.

## Support Tier Rule

Public wording must keep these tiers unchanged:

| Tool | Phase 73 tier | Start here |
|---|---|---|
| Claude Code | `supported` | Use the Claude plugin install path in [install.md](install.md#claude-code-supported). |
| Codex CLI | `internal-compatible` | Use `scripts/setup-codex.sh --user` in [install.md](install.md#codex-cli-internal-compatible). |
| Codex app | `candidate` | Use the candidate smoke checklist in [install.md](install.md#codex-app-candidate); do not reuse Codex CLI proof. |
| OpenCode | `internal-compatible` | Use `scripts/setup-opencode.sh` in [install.md](install.md#opencode-internal-compatible). |
| Cursor | `internal-compatible` | Use `scripts/setup-cursor.sh` in [install.md](install.md#cursor-internal-compatible); PM handoff docs remain separate from adapter install. |
| Grok | `internal-compatible` | Use `scripts/setup-grok.sh` in [install.md](install.md#grok-internal-compatible); package install and skill discovery only, not Claude hook parity. |
| Hermes Agent | `candidate` | Use the candidate boundary in [install.md](install.md#hermes-agent-candidate); manual symlink research only. |
| GitHub Copilot CLI | `candidate` | Use the candidate boundary in [install.md](install.md#github-copilot-cli-candidate). |
| Antigravity CLI | `future/unsupported` | Use the unsupported boundary in [install.md](install.md#antigravity-cli-futureunsupported). |

`not_observed != absent`: missing local runtime evidence means the capability is
not observed in the current artifact set. It does not prove the capability is
absent.

**Four install routes ≠ four hosts at the public top tier.** Public **正式対応**
maps only to EN `supported` (Claude Code only today). Use 互換利用可 for
`internal-compatible` and 試験対応 for `candidate`. Do not apply 正式対応 to
non-Claude rows until H1–H8 pass (`docs/spec/planning-and-host-adapter.md`).

| EN tier | JP public wording |
|---|---|
| `supported` | 正式対応 |
| `internal-compatible` | 互換利用可 / 制限付き対応 |
| `candidate` | 試験対応 / プレビュー |
| `future/unsupported` | 非対応 / 将来検討 |

## Choose The Route

| If you are using... | Do this first | Do not claim |
|---|---|---|
| Claude Code | Install the marketplace plugin, then run `/harness-setup`. | Generic multi-host support beyond proven gates. |
| Codex CLI | Run `scripts/setup-codex.sh --user`, restart Codex, then invoke `$harness-plan`. | Direct Codex plugin install or Codex app parity. |
| OpenCode | Run `scripts/setup-opencode.sh`, start OpenCode, then ask for `harness-plan`. | Claude hook parity or runtime auto-routing parity. |
| Codex app | Record candidate smoke evidence only. | That app behavior is proven by Codex CLI docs or help output. |
| Cursor | Run `scripts/setup-cursor.sh`, reload Cursor, then invoke `/breezing` or `/harness-plan`. | Top-tier Cursor adapter or Claude hook parity. |
| Grok | Run `scripts/setup-grok.sh`, restart Grok, then invoke `/harness-plan` or `/breezing`. | Public top-tier claim for the Grok adapter; Claude SessionStart/PreToolUse parity. |
| Hermes Agent | Treat manual symlink exposure as candidate research only. | Public Hermes support, Claude hook parity, or runtime workflow parity. |
| GitHub Copilot CLI | Treat it as CLI capability research only. | Harness bootstrap support. |
| Antigravity CLI | Keep it out of end-user install flow. | Install support, setup support, or adapter support. |

## First Successful Session

A route is usable only when it has all of these:

- first prompt,
- first command,
- verification command,
- success look,
- support tier and known asymmetry.

For candidate and unsupported hosts, the success look is not "installed". It is
"the boundary stayed honest": evidence is recorded as `candidate`,
`future/unsupported`, `manual`, or `not observed`.
