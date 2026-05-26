# GitHub Harness Plugin Benchmark

Last updated: 2026-03-06

This document is a dated snapshot comparing popular **Claude Code harness / workflow plugins** on GitHub,
from the perspective of **how standard operation changes after installation** of `claude-code-harness`.

- This is **not a popularity vote** — it is a **harness comparison**
- GitHub stars are used only as a criterion for selecting candidates to compare
- The primary focus is listing "what becomes standard after installation," followed by explaining the differences
- General AI coding agents (Aider, OpenHands, etc.) and curated lists are excluded from this comparison because they are **not standalone harnesses**

## Compared Repositories

As of 2026-03-06, the repositories included are those publicly available on GitHub that claim
to be "multi-step workflows / plugins / harnesses for Claude Code" and have sufficient public
information available for comparison.

| Repo | GitHub stars | Included because |
|------|--------------|------------------|
| [obra/superpowers](https://github.com/obra/superpowers) | 71,993 | The most popular workflow / skills plugin. Cannot be excluded from comparison |
| [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd) | 2,770 | A popular Claude Code harness with requirement-driven development flow as a core feature |
| [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) | 232 | This repo |

## Feature comparison table (user-facing)

Legend:

- `✅` Available as a standard flow immediately after installation
- `△` Possible with some effort, but not the primary path
- `—` Not a primary selling point

| What users care about | Claude Harness | Superpowers | cc-sdd |
|------------------------|----------------|-------------|--------|
| Plans survive as repository artifacts instead of disappearing in chat | ✅ | ✅ | ✅ |
| Implementation proceeds smoothly in the same flow after approval | ✅ | ✅ | △ |
| Review is part of the standard workflow before completion | ✅ | ✅ | △ |
| Dangerous operations are stopped by runtime guards | ✅ | △ | — |
| Verification can be repeated with the same procedure | ✅ | △ | ✅ |
| After approval, the full workflow runs end-to-end | ✅ | △ | — |

## What these differences mean

### Claude Harness

- The strongest aspects are **standardizing the workflow**, **runtime guards**, and **reproducible verification**
- Plan → Work → Review are each a distinct, well-defined path, and there is even a shortcut `/harness-work all` for running everything at once
- Best suited for those who want "the same reliable structure every time" rather than "do it well somehow"

### Superpowers

- The strongest aspects are **workflow breadth** and **clarity of the onboarding story**
- The flow from planning through implementation, review, and debugging is clear, and auto-triggers are powerful
- However, runtime rules that stop dangerous operations and reproducible verification evidence are not as central to the standard flow as in Harness

### cc-sdd

- The strongest aspect is **specification-driven discipline**
- The `Requirements -> Design -> Tasks -> Implementation` flow is clear, and dry-run / validate-gap / validate-design are available
- However, from the public-facing perspective, an independent review step and a single end-to-end command are not as prominent as in Harness

## How to present this in the README

In a README or landing page, the following framing is natural:

> If you want a wider range of workflow tools, choose Superpowers.
> If you want stronger discipline around requirements → design → tasks, choose cc-sdd.
> If you want to turn planning, implementation, review, and verification into a reliable standard flow, choose Claude Harness.

## Decision notes

- `Plans survive as repository artifacts instead of disappearing in chat`
  - Harness: `Plans.md` / `/harness-plan`
  - Superpowers: brainstorming / writing-plans workflow
  - cc-sdd: requirements / design / tasks workflow
- `Implementation proceeds smoothly in the same flow after approval`
  - Harness: `/harness-work --parallel`, Breezing, worker/reviewer flows on a standard path
  - Superpowers: parallel agent execution / subagent workflows are clearly visible publicly
  - cc-sdd: Multiple subagents confirmed in the Claude agent variant, but not always the central feature across all usage patterns
- `Review is part of the standard workflow before completion`
  - Harness: `/harness-review` and `/harness-work all`
  - Superpowers: Code review workflow is explicit
  - cc-sdd: validate commands are explicit, but code review as a standalone step is less prominently featured
- `Dangerous operations are stopped by runtime guards`
  - Harness: TypeScript guardrail engine + deny / warn rules
  - Superpowers: Workflow discipline and hooks are visible, but a compiled deny/warn runtime engine is not front-and-center
  - cc-sdd: Explicit runtime safety engine is hard to identify in the public README
- `Verification can be repeated with the same procedure`
  - Harness: Validate scripts + consistency checks + evidence pack
  - Superpowers: Verify-oriented workflows exist, but artifact pack is not prominent
  - cc-sdd: dry-run / validate-gap / validate-design are available
- `After approval, the full workflow runs end-to-end`
  - Harness: `/harness-work all`
  - Superpowers: Auto-triggered workflows exist, but a single published command with the same meaning is not prominent
  - cc-sdd: A spec-based command set exists, but a single path that bundles the full loop after approval is not prominent

## Notes

- Stars change daily, so this table is a **dated snapshot**
- This comparison focuses on "visible harness feature differences" rather than "market popularity"
- There are axes where `Superpowers > Claude Harness`. Ecosystem / adoption / workflow story strength is notable
- There are axes where `cc-sdd > Claude Harness`. The clarity of requirement-driven discipline is a strength
- When including this in a README, it is more natural to write **what type of user it suits** than to assert wins and losses

## Evidence Used

### Local evidence

- [README.md](../README.md)
- [docs/claims-audit.md](claims-audit.md)
- [docs/distribution-scope.md](distribution-scope.md)
- [docs/evidence/work-all.md](evidence/work-all.md)

### Public GitHub sources

- [obra/superpowers](https://github.com/obra/superpowers)
- [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)
- [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)
