> **Internal fork** — This is a private, customized fork of [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) maintained by our engineering team. See [docs/FORK_NOTES.md](docs/FORK_NOTES.md) and [docs/PROJECT_SCOPE.md](docs/PROJECT_SCOPE.md) for scope and assumptions.

# AI Engineering Harness (Internal)

An internal Claude Code-first AI Engineering Harness for disciplined, evidence-based delivery.

**Status:** Fork cleanup in progress. Not yet rolled out to production.

---

## What It Does

Harness enforces a repeatable operating path around Claude Code agent work:

```
spec → plan → work → review → release
```

- **Guardrails** — fail-closed hooks block destructive operations before they run (no force push, no secrets, no production deploy automation).
- **Evidence-based review** — review runs independently from implementation; major findings block completion.
- **Company-specific safety policy** — deny rules and hook guards are configured for our internal risk posture, not a generic public default.

The goal is to turn "ask the agent to code" into a repeatable, auditable loop with a human approval gate at plan time and review time.

---

## What v1 Supports

- **Claude Code only.** This fork targets Claude Code exclusively.

## What v1 Does Not Support

The following runtimes are archived and out of scope:

- Codex CLI
- OpenCode
- Cursor
- GitHub Copilot CLI
- Antigravity

Archived surfaces live under `archive/`. See [docs/PROJECT_SCOPE.md](docs/PROJECT_SCOPE.md) for the full active vs. archived component list.

---

## Commands

The intended short-form command surface is listed below. Where a short alias is not yet wired, the existing harness skill is the current entry point.

| Intended alias | Current skill | Description |
|---|---|---|
| `/setup` | `/harness-setup` | Install project guidance, hooks, and checks. One-time per repo. |
| `/plan` | `/harness-plan` | Turn intent into `spec.md` and `Plans.md`. User approves before work starts. |
| `/work` | `/harness-work` | Implement one approved task or range. Stays inside the plan. |
| `/review` | `/harness-review` | Independent review after implementation. Major findings block completion. |
| `/release` | `/harness-release` | Check readiness, CHANGELOG/tag boundaries, and evidence packaging. |
| `/status` | `/harness-sync` | Check alignment between Plans.md, git state, and implementation. _(alias planned)_ |

Short aliases (`/plan`, `/work`, etc.) are planned convenience wrappers. Until they are wired, use the `/harness-*` forms directly.

---

## Basic Workflow

| Stage | Output | Gate |
|---|---|---|
| Plan | `spec.md` + `Plans.md` | User approves or corrects the generated contract before work starts. |
| Work | Code and tests | TDD required when the task calls for it. Stays inside the approved slice. |
| Review | Independent verdict | Major findings block completion. |
| Release | Tag and release artifacts | Release preflight must pass. Evidence must be present. |

---

## Safety Philosophy

- **Fail-closed.** When a guardrail cannot determine intent, it blocks and asks rather than proceeding.
- **No secrets.** Hooks prevent credentials and tokens from appearing in commits or agent context.
- **No force push.** `git push --force` is denied at the hook layer and requires explicit human override.
- **No production deploy automation.** Harness does not wire deploy steps. Release prepares evidence; a human initiates the deploy.
- **Review before release.** The review stage is structurally separate from implementation and must complete before release packaging begins.

---

## Requirements

- Claude Code v2.1+
- A project repository with write access for local setup
- No Node.js required (guardrail engine is Go-native)

---

## Documentation

| Document | Description |
|---|---|
| [docs/PROJECT_SCOPE.md](docs/PROJECT_SCOPE.md) | Active vs. archived components, v1 scope boundaries. |
| [docs/FORK_NOTES.md](docs/FORK_NOTES.md) | What was changed from upstream and why. |
| [docs/REPO_INVENTORY.md](docs/REPO_INVENTORY.md) | Full file-level inventory of the repository. |
| [docs/NAMING_PLAN.md](docs/NAMING_PLAN.md) | Internal naming conventions and cleanup plan. |
| [docs/JAPANESE_TEXT_CLEANUP.md](docs/JAPANESE_TEXT_CLEANUP.md) | Status of Japanese text removal across the codebase. |
| [CHANGELOG.md](CHANGELOG.md) | Version history. |

---

## Acknowledgments

- [AI Masao](https://note.com/masa_wunder) — Hierarchical skill design
- [Beagle](https://github.com/beagleworks) — Test tampering prevention patterns

## License

MIT License. See [LICENSE.md](LICENSE.md).
