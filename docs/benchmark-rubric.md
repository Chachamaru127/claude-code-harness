# Benchmark Rubric

Last updated: 2026-03-06

This document is a rerunnable rubric for comparing `claude-code-harness` against other tools.
It separates static evidence from executed evidence, rather than relying on README impressions.

## Evidence Classes

| Class | Examples | When to use |
|------|----|-----------|
| Static evidence | README, repo tree, hooks definitions, tests, docs, package metadata | Comparing presence of mechanisms, design clarity, distribution paths |
| Executed evidence | Test run, smoke run, benchmark logs, evidence pack, CI artifact | Comparing whether claims are reproducible, whether guardrails actually work |

## Scoring Axes

| Axis | Weight | What to inspect |
|------|--------|-----------------|
| Runtime enforcement | 25 | Hooks, guardrails, deny/warn behavior, lifecycle automation |
| Verification and test credibility | 25 | Unit/integration tests, consistency checks, evidence pack, CI coverage |
| Onboarding and operator clarity | 20 | Install flow, docs completeness, claim consistency, quickstart quality |
| Scope discipline and maintainability | 15 | Distribution boundary, compatibility story, residue management |
| Positioning and adoption proof | 15 | Public narrative, stars/users, reproducible showcase, differentiation |

Total: 100 points

## Review Flow

1. Gather static evidence
2. List the claims that require executed evidence
3. Separate claims that have been verified from those on hold
4. Score each axis, documenting the type of evidence
5. Write strengths and weaknesses separately — e.g., "strong design but unproven" or "strong market but thin runtime enforcement"

## Required Output Format

Comparison reports must include at minimum:

- Date/time of comparison
- Target repositories / versions / commit or default branch snapshot
- List of commands executed
- Distinction between static evidence and executed evidence
- Score per axis
- Items that could not be fully reproduced

## Reusable Template

```md
# Benchmark Report

- Compared at:
- Repositories / versions:
- Commands executed:

## Static evidence

- Repo structure:
- Docs and claims:
- Guardrails / hooks / tests:

## Executed evidence

- Validation commands:
- Benchmark or smoke runs:
- Evidence artifacts:

## Scores

| Axis | Score | Evidence type | Notes |
|------|-------|---------------|-------|
| Runtime enforcement |  | Static / Executed |  |
| Verification and test credibility |  | Static / Executed |  |
| Onboarding and operator clarity |  | Static / Executed |  |
| Scope discipline and maintainability |  | Static / Executed |  |
| Positioning and adoption proof |  | Static / Executed |  |

## Unverified or blocked items

- None

## Harness-specific Notes

- Strong claims like `/harness-work all` become high-scoring only when execution evidence in `docs/evidence/work-all.md` is complete
- Retained items like `commands/` or `mcp-server/` are not deducted — **only deduct when the explanation is vague**
- When README claims and tests/CI/distribution boundaries don't align, lower `Onboarding and operator clarity`
```
