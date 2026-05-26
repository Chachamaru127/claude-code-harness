# Claude Code 2.1.99-2.1.111 Impact Summary

In a nutshell:
As the Phase 44 documentation decision, after reviewing the public changelog from `2.1.99` through `2.1.111` and classifying Harness impact into `A` and `C`, the count of `B` is `0`.

Analogy:
This is a memo sorting through a newly delivered toolbox — identifying which tools can be used as-is, and which need new handles or storage made on our side.

## Baseline

- Primary source: Anthropic's public `claude-code` repository `CHANGELOG.md`
- The classifications in this document are intended to align with Phase 44 planning
- `A`: Items requiring explicit follow-up on the Harness side
- `C`: Items where Harness benefits from Claude Code's own update
- `B`: "Docs only" — zero instances this time

## Summary

| Range | Verdict | Notes |
|-------|---------|-------|
| `2.1.99`, `2.1.100`, `2.1.102`, `2.1.103`, `2.1.104`, `2.1.106` | `C` | No individual entries in the public changelog. Not targeted for Phase 44 additions. |
| `2.1.101` | `C` | Primarily UX improvements and stability fixes; no Harness-specific code additions required. |
| `2.1.105` | `A` | `PreCompact` hook and `monitors` manifest require integration on the Harness side. |
| `2.1.107` | `C` | Thinking display improvement. Harness inherits automatically. |
| `2.1.108` | `A` / `C` mixed | 1-hour prompt cache requires explicit follow-up; most other items are auto-inherited. |
| `2.1.109` | `C` | Thinking indicator improvement only. |
| `2.1.110` | `A` / `C` mixed | Permission re-evaluation changes require explicit follow-up; other items are mainly auto-inherited. |
| `2.1.111` | `A` / `C` mixed | `xhigh`, `/ultrareview`, and Auto Mode flag removal are formal follow-up targets. |

## Per-Version Breakdown

| Version | Key changes | Harness impact | Classification | Phase 44 trace |
|---------|-------------|----------------|----------------|----------------|
| `2.1.99` | No individual entries in the public changelog | Confirmed as range start only. No Harness-specific action. | `C` | - |
| `2.1.100` | No individual entries in the public changelog | No additional follow-up. | `C` | - |
| `2.1.101` | `/team-onboarding`, OS CA trust, `/ultraplan` initial environment automation, resume stabilization, etc. | Existing workflows benefit directly. No new code required in Phase 44. | `C` | - |
| `2.1.102` | No individual entries in the public changelog | No additional follow-up. | `C` | - |
| `2.1.103` | No individual entries in the public changelog | No additional follow-up. | `C` | - |
| `2.1.104` | No individual entries in the public changelog | No additional follow-up. | `C` | - |
| `2.1.105` | `PreCompact` hook, plugin `monitors` manifest, `/proactive` alias, etc. | Implementation integration required in `hooks.json` and plugin manifest. | `A` | `44.2.1`, `44.2.2` |
| `2.1.106` | No individual entries in the public changelog | No additional follow-up. | `C` | - |
| `2.1.107` | Thinking indicator improvement | Display improvement auto-inherited. | `C` | - |
| `2.1.108` | `ENABLE_PROMPT_CACHING_1H`, recap, built-in slash command discovery, etc. | 1-hour cache requires operational policy. Others are largely auto-inherited. | `A/C` | `44.6.1`, `44.7.1` |
| `2.1.109` | Extended-thinking indicator improvement | UI benefit only. No follow-up code required. | `C` | - |
| `2.1.110` | Permission deny re-evaluation fix, `PreToolUse.additionalContext` fix, `/tui`, resume/scheduled task, etc. | Guardrail re-verification and docs update required. Other UX improvements are auto-inherited. | `A/C` | `44.3.1`, `44.11.1` |
| `2.1.111` | `xhigh`, `/ultrareview`, Auto mode no longer requires flag, `/effort` slider, etc. | `xhigh` and `/ultrareview` are formal follow-up targets. Auto Mode prerequisite language also needs updating. | `A/C` | `44.5.1`, `44.8.1`, `44.11.1` |

## Key Notes

### `2.1.105`

- `PreCompact` hook is directly tied to Harness long-run protection
- `monitors` manifest changes monitor scripts from "added later" to "auto-armed at startup"
- Both create Harness-specific added value, so both are `A`

### `2.1.108`

- `ENABLE_PROMPT_CACHING_1H` is not just something we can use — it requires a policy for "which flows to enable it in"
- Therefore it leans toward `A`, accompanied by docs and policy
- On the other hand, recap and much of slash command discovery are core-level benefits, so `C`

### `2.1.110`

- The `permissions.deny` re-evaluation fix directly affects Harness guardrail descriptions and expected behavior
- It is not "CC fixed it, so we're done" — the Harness explanation and test perspective need updating, hence `A/C` mixed

### `2.1.111`

- `xhigh` is a formal follow-up target, not skipped
- `/ultrareview` is a formal follow-up target, not skipped
- `Auto mode no longer requires --enable-auto-mode` is an explicit follow-up target to prevent Auto Mode docs from becoming stale

## Why Category B Is Zero

- Versions with no public changelog entries are not forced into rows to pad the table
- Items that end at core improvements are placed in `C`
- Only items that affect Harness decisions, wording, configuration, or hooks are placed in `A`

This separation avoids creating `B` items that are "just written in the Feature Table."

## Concrete Example

Concrete example:
`xhigh` in `2.1.111` is not simply "a new effort name was added." On the Harness side it affects the reviewer/advisor thinking intensity policy and the explanation in docs, so it is treated as `A`.

## Why This Classification

Phase 44's purpose is not to "summarize the CC changelog" — it is to clarify "what Harness owns itself."
