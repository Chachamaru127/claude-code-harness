# Claude Code Harness

<p align="center">
  <img src="docs/images/claude-harness-logo-with-text.png" alt="Claude Harness" width="400">
</p>

<p align="center">
  <strong>Plan. Work. Review. Ship.</strong><br>
  <em>A disciplined delivery loop for Claude Code, with bounded paths for Codex and OpenCode.</em>
</p>

<p align="center">
  <a href="https://github.com/Chachamaru127/claude-code-harness/releases/latest"><img src="https://img.shields.io/github/v/release/Chachamaru127/claude-code-harness?display_name=tag&sort=semver" alt="Latest Release"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  <a href="docs/CLAUDE_CODE_COMPATIBILITY.md"><img src="https://img.shields.io/badge/Claude_Code-v2.1+-purple.svg" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/Skills-5_core_%2F_22_total-orange.svg" alt="Skills: 5 core verbs / 22 total">
  <img src="https://img.shields.io/badge/Core-Go_Native-00ADD8.svg" alt="Go Core">
</p>

<p align="center">
  English | <a href="README_ja.md">日本語</a>
</p>

<p align="center">
  <img src="docs/images/readme/hero-operating-loop-en.png" alt="Claude Code Harness operating loop: Spec, Plan, Work, Review, Release" width="900">
</p>

Claude Code is powerful, but raw agent work drifts: plans live in chat, tests
become optional, review happens too late, and release evidence gets rebuilt by
memory. Harness turns that into one repeatable operating path.

After install, the default changes from "ask the agent to code" to:

1. write the spec and plan,
2. implement only the approved slice,
3. verify the result,
4. review independently,
5. package evidence for PR or release.

**Claims in this README are machine-checked against the code.** CI gates verify that
implemented components are actually wired (no dead code claimed as done), that the task
ledger's dependencies stay consistent, and that the shipped binaries rebuild from source.
A feature is described here only after a gate proves it is reachable — "written" is not
"working."

## Quickstart

New users should start from the tool they already use. Existing users should
run the migration report before cleanup or reinstall.

| Path | Start |
|---|---|
| New user | [Tool-first onboarding](docs/onboarding/index.md) |
| Existing user | [Migration check](docs/onboarding/migration.md) |
| Claude Code fast path | [Install in 30 seconds](#install-in-30-seconds) |
| Trigger proof | [Skill trigger gate](docs/onboarding/skill-trigger-acceptance.md) |

## Install in 30 Seconds

```bash
claude
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace
/harness-setup
```

Next command: run `/harness-plan` with one small request.

```bash
/harness-plan Improve the README onboarding flow
```

## First 15 Minutes

1. Install through your tool route.
2. Run `/harness-setup` or the equivalent setup script.
3. Run `/harness-plan` with a small request; Harness writes the `spec.md` and
   `Plans.md` drafts for you to check. Small typo, docs, and status updates stay
   lightweight.
4. Approve the generated contract or reply with the correction you want.
5. Run the smallest approved task, for example `/harness-work 1.1.1`.
6. Run `/harness-review` and keep the verification output.

Your job is not to hand-write the plan. It is to approve or correct the
generated contract before execution continues.

## How It Works

Harness adds a source-of-truth loop around agent work.
The 5 verb skills keep that surface small: plan, work, review, sync, release.

1. You describe the outcome in normal language.
2. `/harness-plan` drafts or updates `spec.md` and `Plans.md` with scope,
   acceptance criteria, unknowns, and stop conditions.
3. Non-trivial planning records `team_validation_mode` and validates the plan
   through team/sub-agent or manual-pass perspectives for spec/Plans alignment,
   memory reuse, product fit, security fit, and works-in-practice.
4. Harness treats those files as the source of truth. Data the agent has not
   seen stays `unknown` instead of being silently invented.
5. `/harness-work` implements the approved slice with TDD and verification.
6. `/harness-review` separates review from implementation.
7. `/harness-release` packages only verified evidence.

## Commands

| Command | What happens inside |
|---------|---------------------|
| `/harness-setup` | Installs project guidance, command surfaces, hooks, and checks so the workflow starts from one known baseline. |
| `/harness-plan` | Turns intent into `spec.md` and `Plans.md`, including scope, acceptance criteria, dependencies, unknowns, stop conditions, and non-trivial planning validation. |
| `/harness-work` | Executes one approved task or range, adds tests when required, runs verification, and keeps work inside the plan. |
| `/harness-work all` | Runs the approved plan through implementation and review paths; use after the plan is clear and the repo baseline is known. |
| `/harness-review` | Reviews the result separately from implementation and treats major findings as blockers. |
| `/harness-release` | Checks release readiness, CHANGELOG/tag boundaries, and evidence packaging after implementation and review are complete. |
| `bin/harness doctor --migration-report` | Inventories old plugin caches, Codex skills, OpenCode files, symlinks, and memory state without deleting data. |

## Basic Workflow

| Stage | Output | Gate |
|-------|--------|------|
| Investigate | Evidence and unknowns | Do not promote unobserved data into claims. |
| Plan | `spec.md` + `Plans.md` | User approves or corrects the generated contract. |
| Work | Code and tests | TDD required when the task says so. |
| Review | Independent verdict | Major findings block completion. |
| PR | Evidence pack | PR ready is not release ready. |
| Release | Tag/release artifacts | Release preflight must pass on the release path. |

### Non-engineer decision surfaces

Three single-screen HTML views surface the decision at each phase, so a non-engineer
sponsor can judge without reading code:

- **Plan Brief** (`harness-plan-brief`) — understanding, options, risks, and acceptance
  criteria before implementation. Offered when a plan is finalized.
- **Progress** (`harness-progress`) — WIP/TODO/done counts and drift alerts during work.
  Auto-regenerated on a PostToolUse hook.
- **Acceptance** (`harness-accept`) — per-criterion pass/fail with a ship/wait/reject
  recommendation before release.

## Install By Tool

| Tool | Tier | Route |
|---|---|---|
| Claude Code | `supported` | Claude plugin marketplace, then `/harness-setup`. |
| Codex CLI | `internal-compatible` | `scripts/setup-codex.sh --user`; direct plugin smoke is tracked separately. |
| Codex app | `candidate` | Candidate smoke only; do not reuse Codex CLI proof. |
| OpenCode | `internal-compatible` | `scripts/setup-opencode.sh`; runtime parity is not claimed. |
| Cursor | `internal-compatible` | `scripts/setup-cursor.sh` real-directory local install; top support tier still gated on workflow smoke. |
| Grok | `internal-compatible` | `scripts/setup-grok.sh` plugin package install/check; workflow smoke and Claude hook parity not claimed. |
| Hermes Agent | `candidate` | Manual symlink research route only; dynamic slash discovery observed locally, runtime parity not claimed. |
| GitHub Copilot CLI | `candidate` | Manual profile research only. |
| Antigravity CLI | `future/unsupported` | No end-user install route in this phase. |

## Existing User Migration

Run `bin/harness doctor --migration-report` before changing an existing setup.
The report inventories stale Claude plugin caches, duplicate Codex skills, old
symlinks, OpenCode backup paths, and harness-mem state without deleting
anything.

## Support Boundary

**Four install routes ≠ four hosts at the public top tier.** Setup scripts mean
each tool has an **entry path**, not a shared product guarantee. Public
**正式対応** maps only to EN tier `supported`. Today that tier is **Claude Code
only**. Other rows in the install table stay at their listed tier
(`internal-compatible` or `candidate`) until H1–H8 pass on one claim path
(`docs/spec/planning-and-host-adapter.md`; Phase 111).

| EN tier | JP public wording (safe) |
|---|---|
| `supported` | 正式対応 |
| `internal-compatible` | 互換利用可 / 制限付き対応 |
| `candidate` | 試験対応 / プレビュー |
| `future/unsupported` | 非対応 / 将来検討 |

Harness can describe candidate paths, but it does not inherit support claims
from Superpowers, Hermes Agent, or any other project. A host only moves up when
Harness has its own bootstrap, trigger, runtime, and release evidence.

`not_observed != absent`: missing local proof means "not proven here", not
"impossible" and not "supported".

## Requirements

- Claude Code v2.1+ for the supported Claude path.
- A project repository with write access for local setup.
- No Node.js is required for the Go-native guardrail engine.
- Optional [harness-mem](https://github.com/Chachamaru127/harness-mem) for
  cross-session memory when configured and healthy.

## Advanced

Use these after the basic trigger path is visible.

| Capability | What it adds | Boundary |
|------------|--------------|----------|
| Breezing | Planner/Critic/Worker style team execution for larger task lists. | Still gated by plan quality and review. |
| Codex companion review | Schema-backed Codex second opinion through `scripts/codex-companion.sh`. | Raw `codex exec` is not the Harness companion path. |
| OpenCode bootstrap | Mirrors Harness guidance into OpenCode-compatible surfaces. | Real runtime parity is not claimed. |
| harness-mem | Project-scoped memory and recall across sessions. | Optional companion; purge remains explicit. |
| auto-approve (experimental) | `HARNESS_AUTO_APPROVE=on` currently records the enablement gate and prereq check result in the orchestration ledger only. Approval prompts are not skipped. | Default OFF. Strict env value (`on` only). Gated on Phase 92.1.1 / 92.2.3 / 96.1.2 prereqs for ledger instrumentation; approval automation is deferred until HOTL governance verification (Phase 101 U0-U7 evidence). |

## Documentation

| Resource | Description |
|----------|-------------|
| [Tool-first onboarding](docs/onboarding/index.md) | Where to start by host tool. |
| [Install routes](docs/onboarding/install.md) | Per-tool setup and support-tier boundaries. |
| [Migration check](docs/onboarding/migration.md) | Existing-user impact, compatibility, and rollback path. |
| [Skill trigger gate](docs/onboarding/skill-trigger-acceptance.md) | How install success is verified. |
| [Capability matrix](docs/tool-capability-matrix.md) | Supported, internal-compatible, candidate, and unsupported host claims. |
| [Claude Code Compatibility](docs/CLAUDE_CODE_COMPATIBILITY.md) | Current Claude Code requirements and compatibility notes. |
| [Cursor Integration](docs/CURSOR_INTEGRATION.md) | Cursor handoff boundary and internal-compatible adapter notes. |
| [Distribution Scope](docs/distribution-scope.md) | Included vs compatibility vs development-only paths. |
| [Hardening parity](docs/hardening-parity.md) | Runtime safety differences between Claude hooks and Codex gates. |
| [Work All Evidence Pack](docs/evidence/work-all.md) | Success/failure verification contract for full-plan execution. |
| [Language / i18n](docs/i18n.md) | How to switch output language (English default, Japanese opt-in). |
| [Changelog](CHANGELOG.md) | User-facing version history. |

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Acknowledgments

- [AI Masao](https://note.com/masa_wunder) - Hierarchical skill design
- [Beagle](https://github.com/beagleworks) - Test tampering prevention patterns

## License

MIT License. See [LICENSE.md](LICENSE.md).
