# AGENTS.md — Cursor Bootstrap Route (Candidate)

Status: Cursor adapter **candidate**. This file is bootstrap guidance, not a
public support claim. PM handoff remains documented in
`docs/CURSOR_INTEGRATION.md`.

## Support Tier

Cursor is `candidate` until `tests/test-cursor-adapter-candidate.sh` and
workflow smoke pass together with release preflight. `not_observed != absent`.

## First Commands

| Intent | Skill / workflow | Notes |
|---|---|---|
| Plan a change | `harness-plan` | Read root `spec.md` + `Plans.md` before adding tasks |
| Implement next task | `harness-work` | Default solo; use breezing for multi-task team runs |
| Review diff / PR | `harness-review` | Independent review; do not self-approve implementation |
| Sync drift | `harness-sync` | Plans vs git vs implementation |
| Setup / init | `harness-setup` | First-time or repair bootstrap |

Golden prompt fixtures (static contract, not auto-routing proof):

- `plan this` / `計画して` → `harness-plan`
- `work on this` / `実装して` → `harness-work`
- `implement all Plans.md tasks` / `全部やって` → `breezing` or `harness-work all`
- `review this PR` / `レビューして` → `harness-review`

## Model Routing

Resolve model from Harness role tier via:

```bash
bash scripts/model-routing.sh --host cursor --role worker --format json
```

Priority:

1. Explicit Task/subagent `model` override from the caller
2. Routed default from `scripts/model-routing.sh`
3. Session inherit (`model: inherit` in subagent frontmatter)

Do not claim Claude/Codex hook or Agent Teams parity from Cursor subagents.

## Breezing (Team Execution)

Core contract (host-neutral):

- Parallel: independent Workers when file groups do not overlap
- Serial: Reviewer verdict, cherry-pick to main, Advisor escalation

Cursor adapter mapping (smoke target only):

- Worker → Task tool / `.cursor/agents/worker.md` subagent (parallel when safe)
- Reviewer → `.cursor/agents/reviewer.md` (`readonly: true`)
- Advisor → `.cursor/agents/advisor.md` on `advisor-request.v1` only
- Multitask / background agents → optional parallel fan-out; not a support claim

## Verification

```bash
bash tests/test-cursor-adapter-candidate.sh
bash tests/test-bootstrap-routing-contract.sh
bash tests/test-model-routing.sh
```
