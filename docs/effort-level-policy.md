# Effort Level Policy

## Overview

Defines the correspondence between the CC frontmatter `effort` field and the Anthropic API effort
parameter, and the adoption policy within Harness.

## CC Frontmatter and API Effort Correspondence Matrix

`max` was deprecated in CC v2.1.72, and `xhigh` was added in v2.1.111.

| CC frontmatter `effort` value | Effective API effort | Behavior with Opus 4.7 | Behavior with non-Opus 4.7 |
|----------------------------|------------------|-------------------|---------------------|
| `low` | low | low | low |
| `medium` | medium | medium | medium |
| `high` | high | high | high |
| `xhigh` | xhigh (extended thinking) | xhigh (maximum thinking budget) | Falls back to `high` (noted in changelog) |

**Notes**:
- `xhigh` was added to frontmatter in CC v2.1.111 (see `CLAUDE-feature-table.md` / `cc-2.1.99-2.1.111-impact.md`)
- `max` was deprecated in CC v2.1.72. Writing it in frontmatter has no effect
- When `xhigh` is specified with non-Opus 4.7 models (e.g., Sonnet series), CC automatically downgrades to `high`

### Whether xhigh can be passed to the API via CC

**Verdict: Adopted (evidence that xhigh is accepted in frontmatter)**

Basis:
1. The v2.1.111 section in `docs/CLAUDE-feature-table.md` records `xhigh effort` as `A: explicit follow-up target`
2. The Opus 4.7 section in the same file also records `xhigh effort` as `A: explicit follow-up target`
3. `docs/cc-2.1.99-2.1.111-impact.md` documents the addition of `xhigh` in v2.1.111
4. Harness's `opus-4-7-prompt-audit.md` defines "`xhigh`: the reasoning intensity chosen by the caller"

When `xhigh` is written in frontmatter, CC sends a request to the Anthropic API with extended thinking enabled.
With non-Opus 4.7 models, it silently downgrades to `high` equivalent. It does not reject or error.

## Harness adoption policy

| Flow | Adopted effort | Reason |
|--------|------------|------|
| Plan | `high` | Good balance of speed and organization |
| Work (Worker agent) | `high` | Implementation benefits more from iterative verification than deep thinking |
| Review (Reviewer agent, harness-review) | `xhigh` | Incremental thinking yields results for comparison, counterargument, and gap detection |
| Advisor | `xhigh` | Prioritize precision of PLAN / CORRECTION / STOP judgments |
| Release / Setup | `high` | Primarily about procedure adherence; always using `xhigh` is excessive |

### Frontmatter update targets

| File | Before | After | Reason |
|--------|--------|--------|------|
| `agents/reviewer.md` | `effort: medium` | `effort: xhigh` | Adopting xhigh for review |
| `agents/advisor.md` | `effort: high` | `effort: xhigh` | Adopting xhigh for advisor |
| `skills/harness-review/SKILL.md` | `effort: high` | Unchanged | Skill effort is overridden by the caller, so keep high |

## Operational rules

1. **Prioritize review and advisory as targets for `xhigh`**
   Reason: Bug detection and counterargument benefit more from incremental thinking than implementation itself.

2. **Keep work at the default `high`**
   Reason: For implementation, fast iterative verification often outperforms long deliberation.

3. **Document "falls back to `high` on non-Opus 4.7" in docs**
   Reason: Users may misunderstand "I wrote `xhigh` but it doesn't seem to be working."

4. **Do not uniformly set all skills / agents to `xhigh`**
   Reason: Cost and latency increase unnecessarily. Use different efforts based on role.

5. **Treat `${CLAUDE_EFFORT}` as read-only**
   Reason: Since Claude Code 2.1.120, the current effort level can be referenced from skill content.
   However, this is information for reading the effort chosen by the caller — it is not a mechanism
   for the skill to override effort on its own.

### `${CLAUDE_EFFORT}` guidance

`CLAUDE_EFFORT` is a variable for referencing the currently effective effort level from skill content.

Acceptable usage:

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, report only confirmed blockers.
If effort is xhigh, include adversarial checks and edge cases.
```

Patterns to avoid:

- Requesting "always switch to xhigh" from skill content
- Treating environments where `CLAUDE_EFFORT` is empty as failures
- Ignoring the effort specified by the user / parent workflow

Harness policy:

- Leave the choice of effort to the caller.
- Skills use `CLAUDE_EFFORT` only for descriptions, branching, and adjusting output granularity.
- For internally invoked skills like media / announcement types, clarify the invocation contract
  (`user-invocable` / `disable-model-invocation`) rather than effort.

## Deferred rationale (things not adopted)

The following are not adopted. Reasons for deferral are provided.

| Item | Reason for deferral |
|------|-----------|
| Setting Worker agent to `xhigh` | Implementation loops benefit more from fast iteration than deep thinking. The incremental cost of xhigh does not yield proportional quality improvement |
| Setting Setup / Release skills to `xhigh` | These primarily involve procedure adherence; recall matters more than judgment |
| Reviving `max` | Deprecated in CC v2.1.72. `xhigh` is its successor |

## Notes

- `xhigh` is not "a magic that makes it smarter" — it provides more space for deeper thinking
- With vague instructions, deeper thinking only makes the output more precisely wrong
- On non-Opus 4.7 models, specifying `xhigh` falls back to `high` equivalent, so the expected effect may not appear
- `opus-4-7-prompt-audit.md` acceptance condition 5: `xhigh` is "the reasoning intensity chosen by the caller" and is not something agent prompts infer from free-text markers

## Related files

- `docs/CLAUDE-feature-table.md` — Feature list for v2.1.111 / Opus 4.7
- `docs/cc-2.1.99-2.1.111-impact.md` — Details on xhigh addition
- `docs/claude-code-setup-mcp-telemetry-provider.md` — `${CLAUDE_EFFORT}` and setup guidance
- `.claude/rules/opus-4-7-prompt-audit.md` — xhigh operational knob definition
- `agents/reviewer.md` — Reviewer effort setting
- `agents/advisor.md` — Advisor effort setting
