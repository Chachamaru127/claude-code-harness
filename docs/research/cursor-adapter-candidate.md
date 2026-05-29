# Cursor Adapter Evidence

Status: internal-compatible evidence boundary
Checked at: 2026-05-29 JST
Phase: `Plans.md` 83.x (promoted from Phase 81 candidate skeleton)

## Conclusion

Cursor is **`internal-compatible`**.

Harness has a Cursor adapter route (`.cursor-plugin/`, `.cursor/AGENTS.md`,
`.cursor/agents/`, host-specific dist build, `scripts/setup-cursor.sh`, static
smoke tests) and **observed Desktop skill loading** (`/breezing`, workflow
skills). It does **not** have CI-gated workflow smoke that proves full Plan →
Work → Review from Cursor alone, nor runtime guard / hook / Cloud Agent parity.
The existing `docs/CURSOR_INTEGRATION.md` PM handoff path remains separate from
adapter support.

Do not promote Cursor beyond **`internal-compatible`** until CI-gated workflow
smoke and the full release/preflight claim path pass in the same tier boundary.

## Evidence Boundary

`not_observed != absent`: missing CI-gated Cursor workflow smoke is not proof
that the host cannot run Harness workflows. It is proof that Harness must not use
the public support tier yet.

## Observed Runtime Evidence (2026-05-29)

Manual Desktop observation (operator-local, not CI-gated):

| Observation | Evidence | Limit |
|---|---|---|
| Local plugin load after real-directory install | Cursor Plugins log no longer shows `loadUserLocalPlugin ... rejected: symlink target ... is outside ...` | Symlink installs are rejected by Cursor |
| Skill menu visibility | Operator confirmed `/breezing` and other workflow skills appear after Reload Window | Single-session manual proof only |
| Frontmatter normalization | `scripts/build-host-plugin-dist.sh` rewrites `user-invocable: true` → `false` for Cursor package | Claude Code slash contract preserved in Claude dist |

Pre-fix failures that informed Phase 82/83:

- Symlink install at `~/.cursor/plugins/local/claude-code-harness` → **rejected**
  (target outside `~/.cursor/plugins/local`)
- Raw repo skills with `user-invocable: true` → **dropped** by Cursor (skills
  invisible in `/` menu)

Fix applied:

```bash
bash scripts/setup-cursor.sh --check   # build + validate only
bash scripts/setup-cursor.sh           # real copy to ~/.cursor/plugins/local/
```

## Harness Evidence (This Repository)

| Artifact | What it proves | What it does not prove |
|---|---|---|
| `docs/CURSOR_INTEGRATION.md` | Cursor PM ↔ Claude Code Harness handoff workflow | Cursor adapter support |
| `.cursor-plugin/plugin.json` | Plugin manifest points at core `skills/` | Marketplace install |
| `scripts/build-host-plugin-dist.sh` | Host-specific cursor package with in-package paths | Runtime guard parity |
| `scripts/setup-cursor.sh` | Real-directory local install + `--check` validation | CI-gated Desktop workflow smoke |
| `.cursor/AGENTS.md` | Bootstrap routing guidance for plan/work/review | Automatic runtime routing |
| `.cursor/agents/*.md` | Subagent shape for worker/reviewer/advisor roles | Team execution parity with Claude Agent Teams |
| `.cursor/hooks.json` | Config shape for optional session hooks | Hook enforcement parity with Claude Code |
| `.cursor/mcp.json` | MCP config shape placeholder | MCP trust or runtime wiring |
| `tests/test-cursor-adapter-candidate.sh` | Static adapter contract + setup-cursor smoke | Full Breezing multitask proof |
| `scripts/model-routing.sh --host cursor` | Role-tier → Cursor model mapping contract | Account-specific model availability |

Superpowers reference shape (external, not Harness proof):

- `.cursor-plugin/plugin.json` may reference `skills`, `agents`, `commands`, and
  `hooks` in other repositories.
- That shape informed the Harness skeleton but does not upgrade Harness support
  tier by itself.

## Official Cursor Surfaces (Observed 2026-05-28)

Sources checked:

- https://cursor.com/docs/context/rules — project rules (`.cursor/rules`, `AGENTS.md`)
- https://cursor.com/docs/context/skills — Agent Skills discovery and invocation
- https://cursor.com/docs/context/subagents — subagent frontmatter (`model`, `readonly`, background)
- https://cursor.com/docs/agent/hooks — lifecycle hooks (session/tool events)
- https://cursor.com/docs/context/mcp — MCP server configuration
- https://cursor.com/docs/cloud-agent/api — Cloud Agent API (`mode`, `model.id`, `model.params`)
- https://cursor.com/docs/cli/overview — CLI agent with `--model` and mode flags
- https://cursor.com/docs/plugins — local plugin install under `~/.cursor/plugins/local`

Observed adapter-relevant mechanics:

| Surface | Harness mapping | Notes |
|---|---|---|
| Rules / `AGENTS.md` | Bootstrap notice + prompt routing | Same conceptual layer as Codex `AGENTS.md`, different enforcement |
| Skills | Core workflow skills via plugin `skills/` path | Cursor drops `user-invocable: true` skills; Cursor package normalizes to `false` |
| Local plugins | `scripts/setup-cursor.sh` → real directory copy | Symlinks whose target is outside `~/.cursor/plugins/local` are rejected |
| Subagents | Worker / Reviewer / Advisor adapter roles | `model: inherit` or explicit model slug; `readonly` for review |
| Task / background agents | Breezing parallel worker smoke target only | Core keeps review + cherry-pick serial |
| Hooks | Optional sessionStart / preflight gate | Secret-free config-shape validation only in static smoke |
| MCP | Optional harness-mem / tool bridge | Trust policy applies; no secret reads in smoke |
| Cloud Agent API | Optional paid/auth evidence | Not required for internal-compatible local Desktop evidence |
| CLI `--model` | Explicit override surface | Outranks routed default when caller sets it |

Not observed in this repo's smoke (2026-05-29):

- CI-gated Desktop workflow smoke with transcript artifact
- Cloud Agent API workflow smoke with auth
- Multitask mode proof for full Breezing cherry-pick loop
- Hook runtime block parity with Claude PreToolUse

## Separation: PM Handoff vs Adapter Support

| Concern | PM handoff (`CURSOR_INTEGRATION.md`) | Adapter route (this doc) |
|---|---|---|
| Primary user | Cursor plans/reviews, Claude implements | Operator stays in Cursor for Plan → Work → Review |
| Bootstrap | Shared `Plans.md` + Cursor command templates | `.cursor-plugin/` + `.cursor/AGENTS.md` + skills/agents |
| Parallelism | Out of scope | Maps to subagents / background agents / multitask (smoke target) |
| Support claim | Never implies Cursor adapter support | `internal-compatible` only; not a public support-tier claim |
| Verification | Branch + marker sanity | `bash tests/test-cursor-adapter-candidate.sh` + `bash scripts/setup-cursor.sh --check` |

## Tier Boundaries

| Tier | Cursor status | Allowed wording | Blocked wording |
|---|---|---|---|
| `internal-compatible` | **current** | experimental/internal compatibility, setup-cursor install, observed Desktop skill loading | marketing Cursor as production-ready |
| production tier | not yet | — | public adapter claim beyond internal-compatible |
| `candidate` | superseded for Cursor (Phase 83) | historical Phase 81 research only | current tier label |

## Promotion To Production Tier (Remaining Conditions)

The public support tier requires all of the following in the same claim path
before this host may be described as production-ready:

1. CI-gated workflow smoke proves at least one of `harness-plan`, `harness-work`,
   or `harness-review` routing from Cursor with transcript or CI artifact.
2. Release preflight and support-wording gates pass with the upgraded tier.
3. README/onboarding wording still separates handoff integration from adapter
   support and preserves the false-parity rule.
4. Breezing Cursor mapping remains a smoke target, not a public parity claim.
5. Optional Cloud Agent API smoke recorded separately; failure does not block
   local Desktop internal-compatible evidence if tier wording stays honest.

Residual risks after Phase 83:

- Explicit subagent `model` override wins; team/admin/plan unavailable models
  fall back silently unless smoke catches them.
- Multitask / background agent behavior may differ from Claude Agent Teams.
- MCP and hooks can affect external sends; config-shape tests do not prove runtime
  policy enforcement.
- Manual Desktop skill-loading proof can regress when Cursor Desktop import or
  duplicate skill paths are re-enabled.

## Verification Commands

```bash
bash tests/test-cursor-adapter-candidate.sh
bash scripts/setup-cursor.sh --check
bash tests/test-bootstrap-routing-contract.sh
bash tests/test-tool-capability-matrix.sh
bash tests/test-model-routing.sh
bash tests/test-support-claim-wording.sh
```

Optional runtime smoke when Cursor CLI is installed:

```bash
HARNESS_CURSOR_ADAPTER_SMOKE_REQUIRED=1 bash tests/test-cursor-adapter-candidate.sh
```
