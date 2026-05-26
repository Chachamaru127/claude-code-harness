# Advisor Strategy

## In a Nutshell

The Advisor Strategy is an approach where
**the executor runs autonomously most of the time, and only consults an advisor in difficult situations.**

In Harness v1, this concept is first introduced via `harness-loop`.

## Analogy

Rather than a supervisor who gives detailed instructions at every step,
this approach has the person on the ground moving forward independently
and only escalating to a senior colleague when a decision feels heavy.

This way, you don't have to surface a heavyweight decision-maker at every turn,
making it easier to balance speed and safety.

## Roles

Harness has four roles:

| Role | Responsibility |
|------|----------------|
| Lead | Manages the overall flow |
| Worker / executor | Carries out implementation and fixes |
| Advisor | Provides guidance on direction only |
| Reviewer | Makes the final quality judgment |

Critically,
**the Advisor is not a replacement for the Reviewer.**

The Advisor returns guidance on "how to proceed next."
Whether to ultimately `APPROVE` or `REQUEST_CHANGES`
remains with the Reviewer, as always.

## When the Advisor Is Called

In v1, consultation is fixed to three scenarios:

1. Before the first execution of a high-risk task
2. After the same root cause fails twice in a row
3. Just before returning `PIVOT_REQUIRED` on plateau detection

High-risk tasks, in the current contract, are any of the following:

- `needs-spike`
- `security-sensitive`
- `state-migration`

To avoid repeating the same consultation,
a `trigger_hash` identifier is used.

This is a fingerprint combining
**"which task", "what reason", and "what kind of failure"**.

The same `trigger_hash` triggers at most one consultation.
Additionally, the maximum number of consultations per task is 3.

## The 3 Decisions the Advisor Returns

The advisor's response is fixed as `advisor-response.v1` JSON.
There are exactly 3 decision values:

| decision | Meaning | Harness behavior |
|----------|---------|------------------|
| `PLAN` | Reorganize the approach | Re-execute with the advice prepended to the next execution prompt |
| `CORRECTION` | Direction is correct, only a local fix is needed | Re-execute as a correction instruction |
| `STOP` | Better not to continue autonomously | Stop the loop, persist the reason in state, and escalate |

## Concrete Example

Consider running a task containing `state-migration` through `harness-loop`.

1. The loop reads the sprint contract
2. It identifies the task as high-risk
3. Before starting implementation, it consults the advisor once
4. The advisor returns `PLAN`
5. The loop prepends that advice to the next prompt and runs the executor
6. The final quality judgment after implementation is performed by the Reviewer

In other words,
the advisor does not take ownership of the implementation itself—
it only sets the direction so the executor can proceed without hesitation.

## Why Start with `harness-loop`

There are three reasons:

1. For long-running executions, calling heavyweight judgment only when stuck is especially effective
2. `run.json` and `cycles.jsonl` make it easy to keep a consultation history
3. It can be introduced without disrupting the existing Reviewer or checkpoint flow

In other words,
rather than changing every execution path all at once,
**the highest-impact, most observable entry point is chosen first.**

## Known Constraints

v1 intentionally leaves out certain things:

- Workers cannot freely spawn new subagents
- Natural-language-based confidence estimation is not yet used
- Advisor persistence stays file-based state rather than SQLite
- Phase 61 weak-supervision cues pass only the short evidence events left in `.claude/state/elicitation/events.jsonl`, not natural-language confidence estimation
- `breezing` and `harness-work` start with protocol and documentation alignment first

## Related Files

- `agents/advisor.md`
- `scripts/run-advisor-consultation.sh`
- `scripts/codex-loop.sh`
- `skills/harness-loop/SKILL.md`
- `skills/harness-loop/references/flow.md`

## Why This Approach

Harness was originally designed to stay robust by separating
"planning," "implementation," and "review."

When introducing the Advisor Strategy,
it is safer to **only raise the executor's autonomous capability**
while keeping that foundation intact.

Therefore, v1's primary change is "adding a consultation role,"
not "transferring responsibility for quality judgment."
