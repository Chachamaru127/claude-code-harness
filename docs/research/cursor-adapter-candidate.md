# Cursor Adapter Candidate

Status: candidate evidence boundary
Checked at: 2026-05-28 JST
Phase: `Plans.md` 81.1

## Conclusion

Cursor remains `candidate`.

Harness now has a Cursor adapter skeleton (`.cursor-plugin/`, `.cursor/AGENTS.md`,
`.cursor/agents/`, hooks/MCP config shape) and static smoke tests, but it does not
have verified workflow smoke that proves Plan → Work → Review from Cursor alone.
The existing `docs/CURSOR_INTEGRATION.md` PM handoff path is separate from adapter
support.

## Evidence Boundary

`not_observed != absent`: missing Cursor runtime smoke is not proof that Cursor
cannot support Harness. It is proof that Harness must not claim support yet.

Do not promote Cursor beyond the `candidate` tier until:

- host-specific bootstrap smoke passes,
- release preflight consumes the adapter route,
- README/onboarding wording still separates handoff integration from adapter
  support.

## Harness Evidence (This Repository)

| Artifact | What it proves | What it does not prove |
|---|---|---|
| `docs/CURSOR_INTEGRATION.md` | Cursor PM ↔ Claude Code Harness handoff workflow | Cursor adapter support |
| `.cursor-plugin/plugin.json` | Plugin manifest points at core `skills/` | Marketplace install or runtime skill loading |
| `.cursor/AGENTS.md` | Bootstrap routing guidance for plan/work/review | Automatic runtime routing |
| `.cursor/agents/*.md` | Subagent shape for worker/reviewer/advisor roles | Team execution parity with Claude Agent Teams |
| `.cursor/hooks.json` | Config shape for optional session hooks | Hook enforcement parity with Claude Code |
| `.cursor/mcp.json` | MCP config shape placeholder | MCP trust or runtime wiring |
| `tests/test-cursor-adapter-candidate.sh` | Static adapter contract + optional CLI smoke | Full Breezing multitask proof |
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

Observed adapter-relevant mechanics:

| Surface | Harness mapping | Notes |
|---|---|---|
| Rules / `AGENTS.md` | Bootstrap notice + prompt routing | Same conceptual layer as Codex `AGENTS.md`, different enforcement |
| Skills | Core workflow skills via plugin `skills/` path | Skill tool / `$skill` style invocation varies by host |
| Subagents | Worker / Reviewer / Advisor adapter roles | `model: inherit` or explicit model slug; `readonly` for review |
| Task / background agents | Breezing parallel worker smoke target only | Core keeps review + cherry-pick serial |
| Hooks | Optional sessionStart / preflight gate | Secret-free config-shape validation only in static smoke |
| MCP | Optional harness-mem / tool bridge | Trust policy applies; no secret reads in smoke |
| Cloud Agent API | Optional paid/auth evidence | Not required for local Desktop/CLI static gate |
| CLI `--model` | Explicit override surface | Outranks routed default when caller sets it |

Not observed in this repo's smoke (2026-05-28):

- Cursor Desktop plugin marketplace install transcript for this manifest
- Cloud Agent API workflow smoke with auth
- Multitask mode proof for full Breezing cherry-pick loop
- Hook runtime block parity with Claude PreToolUse

## Separation: PM Handoff vs Adapter Support

| Concern | PM handoff (`CURSOR_INTEGRATION.md`) | Adapter candidate (this doc) |
|---|---|---|
| Primary user | Cursor plans/reviews, Claude implements | Operator stays in Cursor for Plan → Work → Review |
| Bootstrap | Shared `Plans.md` + Cursor command templates | `.cursor-plugin/` + `.cursor/AGENTS.md` + skills/agents |
| Parallelism | Out of scope | Maps to subagents / background agents / multitask (smoke target) |
| Support claim | Never implies Cursor adapter support | Remains `candidate` until smoke + preflight pass |
| Verification | Branch + marker sanity | `bash tests/test-cursor-adapter-candidate.sh` |

## Promotion Conditions

Cursor can move beyond `candidate` only after all of the following in the same
claim path:

1. Current official docs captured with extractable evidence (this doc + tests).
2. Harness-specific Cursor bootstrap route consumed by setup or release preflight.
3. Workflow smoke proves at least one of `harness-plan`, `harness-work`, or
   `harness-review` routing from Cursor with transcript or CI artifact.
4. Breezing Cursor mapping recorded as smoke target, not as public parity claim.
5. `tests/test-support-claim-wording.sh` still passes (no public Cursor tier
   claim beyond `candidate`).
6. Optional Cloud Agent API smoke recorded separately; failure does not block
   local Desktop/CLI candidate evidence if tier wording stays honest.

Residual risks after Phase 81:

- Explicit subagent `model` override wins; team/admin/plan unavailable models
  fall back silently unless smoke catches them.
- Multitask / background agent behavior may differ from Claude Agent Teams.
- MCP and hooks can affect external sends; config-shape tests do not prove runtime
  policy enforcement.

## Verification Commands

```bash
bash tests/test-cursor-adapter-candidate.sh
bash tests/test-bootstrap-routing-contract.sh
bash tests/test-tool-capability-matrix.sh
bash tests/test-model-routing.sh
bash tests/test-support-claim-wording.sh
```

Optional runtime smoke when Cursor CLI is installed:

```bash
HARNESS_CURSOR_ADAPTER_SMOKE_REQUIRED=1 bash tests/test-cursor-adapter-candidate.sh
```
