# AGENTS.md — Grok Bootstrap Route (Candidate)

Status: Grok adapter **internal-compatible**. This file is bootstrap guidance, not a
public support claim. Install for non-CCH projects via
`scripts/setup-grok.sh`. Evidence boundary:
`docs/research/grok-adapter-candidate.md`.

## Support Tier

Grok is `internal-compatible` until `tests/test-grok-adapter-candidate.sh`,
`scripts/setup-grok.sh --check`, and package smoke pass together. Host-level
skill install + `grok inspect` discovery are evidence of package loading, not
Claude SessionStart / PreToolUse hook parity. `not_observed != absent`.

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
bash scripts/model-routing.sh --host grok --role worker --format json
```

Priority:

1. Explicit caller / CLI `--model` override
2. Routed default from `scripts/model-routing.sh`
3. Session inherit / host default

Do not claim Claude/Codex/Cursor hook or Agent Teams parity from Grok alone.

## Breezing (Team Execution)

Core contract (host-neutral):

- Parallel: independent Workers when file groups do not overlap
- Serial: Reviewer verdict, cherry-pick to main, Advisor escalation

Grok adapter mapping (smoke target only):

- Worker → Grok subagent / spawn with worker role routing
- Reviewer → read-only review skill / subagent
- Advisor → advisor-request.v1 only
- Multitask / background agents → optional parallel fan-out; not a support claim

## Verification

```bash
bash tests/test-grok-adapter-candidate.sh
bash tests/test-bootstrap-routing-contract.sh
bash tests/test-model-routing.sh
bash scripts/setup-grok.sh --check
```

## Install For Other Projects

```bash
# From a clone of claude-code-harness:
bash scripts/setup-grok.sh --check   # build + validate only
bash scripts/setup-grok.sh           # install plugin into ~/.grok (user scope)
```

After install, restart Grok or open a new session in any project. Skills such as
`harness-plan`, `harness-work`, `harness-review`, and `breezing` should appear
via `grok inspect` / the Skills UI.

## North Star (3 層の野望)

- L1 判断専念: AI が plan / 実装 / 比較 / 検証 evidence を準備し、人間 (operator) は最終判断のみ行う。
- L2 ツール非依存: 同一 Harness (R01-R13 guardrails + plan/work/review/release) が Claude / Codex / Cursor / Grok のどの host からでも効く。
- L3 協調 (将来の本丸): 複数ツールが同一プロジェクトを、人間をコピペ係にせず協調する。

## False Parity Facts

- FACT-1: Grok loads skills/plugins from `.grok/`, `~/.grok/`, and optional Claude/Cursor compat roots. That is not SessionStart hook parity with Claude Code.
- FACT-2: `grok plugin validate` / `grok plugin install` / `grok inspect` prove package shape and discovery, not PreToolUse deny enforcement.
- FACT-3: `not_observed != absent`. Missing workflow smoke means "not proven", not "impossible".
- FACT-4: Public wording must stay at `candidate` until CI-gated workflow smoke and release preflight treat Grok as a first-class gate.
