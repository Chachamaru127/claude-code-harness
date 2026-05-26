# Task Budgets (Public Beta) Research Memo

Phase 44.10.1 — Created: 2026-04-18

This document summarizes the spec for **Task Budgets (public beta)** added to the Anthropic API,
analyzes the conflict with Harness's existing control mechanisms,
and records the **rationale for deferring adoption in this Phase and the criteria for future re-evaluation**.

---

## 1. Task Budgets API spec summary

> **Note**: The following summary is based on the public beta spec as of 2026-04-18.
> For accurate field names, schemas, and error codes, refer to the official Anthropic documentation.
> Uncertain items such as field names are marked with `(estimated)`.

### 1-1. Overview

Task Budgets is a set of parameters added to the Anthropic API's Messages API or Agents API
that declaratively specifies the resource limits a single agent invocation (or task) can consume.

By passing token consumption and cost as pre-constraints,
the goal is to prevent agent runaway and unexpected high charges at the API layer.

### 1-2. Input parameters (estimated)

The following are estimated from Anthropic public information and known similar features,
as the official documentation is not yet finalized for this beta stage.

| Parameter name | Type | Description |
|---------------|------|-------------|
| `max_input_tokens` (estimated) | integer | Maximum input tokens a single task can consume |
| `max_output_tokens` (estimated) | integer | Maximum output tokens a single task can generate |
| `max_cost_usd` (estimated) | number | Maximum cost cap in USD |

These parameters appear to be specified inside a `task_budget` object (estimated) in the API request.

```json
// Structure example (estimated — refer to Anthropic docs for actual field names)
{
  "model": "claude-opus-4-7",
  "messages": [...],
  "task_budget": {
    "max_input_tokens": 100000,
    "max_output_tokens": 8000,
    "max_cost_usd": 2.00
  }
}
```

### 1-3. Output / error format (estimated)

When the limit is exceeded, a `budget_exhausted` error is expected to be returned,
distinct from a normal streaming completion.

```json
// Error response example (estimated)
{
  "type": "error",
  "error": {
    "type": "budget_exhausted",
    "message": "Task budget exceeded: max_cost_usd limit reached",
    "exhausted_budget": "max_cost_usd"
  }
}
```

When running an agent loop, the loop receiving this error must handle it
as an "early termination due to budget exhaustion."

### 1-4. Current status

- **Public beta** — limited availability to select users/API tiers
- GA (general availability) date not announced (as of 2026-04-18)
- Schema backward compatibility is not guaranteed (as with all betas)

---

## 2. Conflict analysis with existing Harness mechanisms

The "resource limits" capability provided by Task Budgets overlaps with concepts
that Harness already implements via multiple custom mechanisms.
The following table maps the conflict points.

| Existing Harness mechanism | Location | Control target | Overlap with Task Budgets |
|--------------------------|----------|----------------|--------------------------|
| Advisor consultation limit (max 3) | Advisor consultation decision in `agents/worker.md` | Number of times Worker can call Advisor | Low (different purpose) |
| `maxTurns` | `agents/worker.md` frontmatter (Worker: 100, Reviewer: 50) | Agent turn count limit | Medium (indirectly limits token consumption) |
| `effort` frontmatter | `agents/worker.md`, each skill frontmatter | Thinking intensity (low/medium/high) | Medium (affects output token consumption) |
| `/cost` per-model breakdown | Built-in CC (v2.1.92) | Cost visualization (post-hoc review) | Low (post-hoc review, not a pre-constraint) |
| `scripts/detect-review-plateau.sh` | `skills/harness-loop` Step 6 | Review loop stall detection | Low (quality gate, not cost control) |
| harness-loop `--max-cycles N` | `skills/harness-loop` | Loop cycle count cap (default 8) | Medium (indirectly limits overall session consumption) |
| Advisor `STOP` decision | `agents/worker.md`, `skills/harness-loop` Advisor Strategy | Manual escalation for risky tasks | Low (quality gate, not cost control) |

### 2-1. Highest conflict points

**`maxTurns` vs `max_input_tokens` / `max_output_tokens`**:

- `maxTurns: 100` limits Worker turn count, indirectly reducing token consumption
- `max_input_tokens` more directly limits token count
- However, `maxTurns` is primarily "loop control" while `max_input_tokens` is primarily "cost control"

**`harness-loop --max-cycles` vs `max_cost_usd`**:

- `--max-cycles N` indirectly controls costs of long sessions via cycle count
- `max_cost_usd` directly controls cost in dollar terms
- `--max-cycles 8` (default) is a coarse method that limits without knowing actual costs,
  while Task Budgets' `max_cost_usd` is more precise

### 2-2. Non-conflicting areas

The following are Harness-specific concepts that Task Budgets cannot replace:

- `plateau detection` — quality loop stall (quality gate, not cost control)
- Advisor consultation limit — number of policy consultations (governance, not cost control)
- `effort` level — thinking quality adjustment (cost/quality tradeoff, not cost reduction per se)

---

## 3. "Which skill" and "at what granularity" if adopted

This section outlines candidate granularities and locations for future Task Budgets adoption.

### 3-1. Per-task budget (limit per Worker spawn)

| Item | Details |
|------|---------|
| Where to apply | At Agent invocation in `agents/worker.md` / at Codex spawn via `scripts/codex-companion.sh` |
| Granularity | Add a `task_budget` section to the sprint-contract, specifying limits per task |
| Benefits | Prevents a single heavy task from consuming the entire budget |
| Challenges | Requires accurate budget estimation per task. Underestimation causes mid-task cutoff |
| Implementation point | Add `task_budget` section generation logic to `scripts/generate-sprint-contract.js` |

### 3-2. Per-session budget (limit for an entire breezing session)

| Item | Details |
|------|---------|
| Where to apply | At loop start in `skills/harness-loop/SKILL.md`, or in `skills/harness-work` breezing mode |
| Granularity | Set `max_cost_usd` for the entire session; stop the loop and report on budget exhaustion |
| Benefits | Clearly defines cost ceiling for long sessions. More precise than `--max-cycles` |
| Challenges | Requires graceful handling logic when budget is exhausted mid-session |
| Implementation point | Add a step to check remaining budget before `[Step 9] Next wake-up reservation` in `harness-loop` |

### 3-3. Per-day budget (daily cap per user)

| Item | Details |
|------|---------|
| Where to apply | Above the Harness layer (Anthropic dashboard API usage limits or user-side external control) |
| Granularity | Alert / auto-stop when daily cumulative cost exceeds threshold |
| Benefits | Reliable prevention of unexpected high charges |
| Challenges | Difficult to implement in Harness (requires cross-session state management). Needs harness-mem integration |
| Implementation point | Daily cost accumulation via `harness_mem_record_checkpoint` with a check on `harness-loop` launch |

---

## 4. Decision not to adopt in this Phase + rationale

**Decision: Defer Task Budgets implementation for Phase 44.**

### Reason 1: API stability uncertain due to public beta status

Task Budgets is in public beta as of 2026-04-18.
Schema backward compatibility is not guaranteed, and field names and behavior may change before GA.
Integrating a beta API into Harness's core controls (sprint-contract generation, harness-loop)
creates a risk where Anthropic-side changes directly cause Harness breaking changes.

### Reason 2: Existing `maxTurns` + `--max-cycles` + Advisor STOP already covers 80%

| Risk to protect against | Existing countermeasure |
|------------------------|------------------------|
| Single Worker runaway | Cut off with `maxTurns: 100` |
| Long session excessive consumption | Stop with `--max-cycles 8` (default) |
| Quality loop stall | `detect-review-plateau.sh` + `PIVOT_REQUIRED` |
| Excessive consultation on high-risk tasks | Advisor consultation limit of max 3 |

While Task Budgets' "direct control in dollar terms" is convenient,
actual cost runaway is preventable with the combination of existing control mechanisms.

### Reason 3: Phase 44 priority allocation

Phase 44 scope is centered on:

- Resolving plugin agent exposure
- Phase 45 sync.go fix
- PreCompact hook implementation
- Task Budgets: **research and documentation only** (this task) is the Phase 44 goal

It is higher priority to complete the confirmed scope above
than to invest remaining Phase 44 resources in Task Budgets implementation.

### Reason 4: Integration design with harness-mem is undecided

Per-day budget style daily accumulation management requires integration with `harness-mem`'s checkpoint feature.
Implementing without a finalized integration design would create technical debt
when `harness-mem`'s design changes later.
A separate research task is needed to design this correctly, which is out of Phase 44's scope.

---

## 5. Re-evaluation timing in the next cycle

Re-evaluate when any of the following trigger conditions is met.

| Trigger | Details | Evaluation phase |
|---------|---------|-----------------|
| Task Budgets promoted to GA | When Anthropic officially announces GA, re-check schema and decide on adoption | Phase 45+, after GA confirmation |
| Actual cost overrun occurs that `maxTurns` alone cannot prevent | If high charges occur before hitting `maxTurns` limit during Harness operation | Raise an emergency task as soon as it occurs |
| `harness-mem` cumulative record design finalized | If harness-mem's daily aggregation feature is implemented and stable, start per-day budget implementation | Phase 45+ |
| Anthropic publishes recommended implementation patterns for Harness | If official docs or blog shows Task Budgets + agent framework integration examples | Within 1 Phase of confirmation |

### Verification items at re-evaluation

Check the following at re-evaluation:

1. Whether field names match the estimates in this document (e.g., `max_input_tokens`)
2. Whether graceful handling of `budget_exhausted` errors can be integrated into the sprint-contract loop
3. Determine which of the 3 granularities (per-task / per-session / per-day) to start with
4. Whether adding a `task_budget` section to `scripts/generate-sprint-contract.js` is technically feasible

---

## Reference files

- `agents/worker.md` — Advisor consultation limit / `maxTurns` / `effort` frontmatter
- `docs/CLAUDE-feature-table.md` — `task budgets` entry (around line 210, `A: Explicit follow-up target`)
- `skills/harness-loop/SKILL.md` — `--max-cycles` / plateau detection / Advisor Strategy
- `.claude/rules/opus-4-7-prompt-audit.md` — 2.1.111 operational knob definitions
