# TeamAgent Debate

## In a nutshell

TeamAgent Debate is a read-only review pass where the same change is read from separate perspectives to reduce oversights.

## When required

Run when any of the following apply.

- The change spans multiple modules
- Touches security / auth / release / distribution / mirror
- The correspondence with the authoritative spec or `Plans.md` is ambiguous
- Regression risk is high
- Claude and Codex verdicts diverge
- Perspective-based evaluation diverged among reviewers
- The same issue was rejected in post-fix re-review two consecutive times

## Agents

| Agent | Primary question |
|---|---|
| Spec Agent | Find contradictions between the authoritative spec and the implementation diff |
| Plans Agent | Verify that `Plans.md` task / DoD / Depends correspond to the diff |
| Regression Agent | Find regressions in existing behavior, tests, distribution mirrors, CLI/skill UX |
| Skeptic Agent | Find major risks being overlooked under the assumption that the change should pass |

Minimum 2 perspectives, up to 4 when needed.
All are read-only.

## Codex fallback

Even in Codex environments where native TeamAgent is unavailable, do not skip.

Available fallbacks:

- `codex-companion.sh review`
- reviewer subagent
- explicitly separate manual-pass

Record one of the following in `team_agent_mode`.

- `native`
- `codex-companion`
- `manual-pass`
- `unavailable`

If `unavailable` and a manual-pass is also impossible, stop with `decision_needed`.

## Output

```json
{
  "team_debate": {
    "required": true,
    "mode": "manual-pass",
    "team_agent_mode": "manual-pass",
    "agents": ["Spec Agent", "Plans Agent", "Regression Agent"],
    "disagreements": [],
    "acceptance_bar": {
      "spec_alignment": "pass",
      "plans_alignment": "pass",
      "regression_safety": "pass"
    }
  }
}
```

## Passing Threshold

If a TeamAgent Debate disagreement is equivalent to critical / major, return `REQUEST_CHANGES`.
When downgrading to minor / recommendation, write the reason with evidence.
