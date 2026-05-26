# Dual Review (--dual)

Run Claude Reviewer and Codex Reviewer in parallel to improve review quality from different model perspectives.
`--dual` is not simply a double-check; it combines TeamAgent Debate when needed to thoroughly
validate the passing threshold for authoritative spec, Plans.md, and regressions from multiple perspectives.

## Prerequisites

- Codex CLI is installed (verify with `scripts/codex-companion.sh setup --json`)
- If Codex is unavailable, fall back to Claude-only review

## Execution Flow

1. Check Codex availability

   ```bash
   CODEX_AVAILABLE="$(bash scripts/codex-companion.sh setup --json 2>/dev/null | jq -r '.ready // false')"
   ```

2. Launch Claude Reviewer via Task tool (standard review flow)

3. If Codex is available, launch `scripts/codex-companion.sh review` in parallel

   ```bash
   # Specify --base if BASE_REF is provided. Use --json to get structured output
   bash scripts/codex-companion.sh review --base "${BASE_REF:-HEAD~1}" --json
   ```

4. Wait for both results

5. Run TeamAgent Debate if any of the following apply
   - Claude and Codex verdicts diverge
   - There is a mismatch or unconfirmed item in the authoritative spec, Plans.md, or regressions
   - There is at least 1 `critical` / `major` candidate
   - `--team-debate` is specified

6. Fix the passing threshold before merging verdicts

## TeamAgent Debate

TeamAgent Debate is treated as a read-only review pass that deliberately collides different perspectives.

| Agent | Primary question |
|-------|----------|
| Spec Agent | Is the authoritative spec consistent with the implementation? |
| Plans Agent | Do `Plans.md` task / DoD / Depends match the evidence? |
| Regression Agent | Are there regressions in existing behavior, tests, distribution mirrors, CLI/skill UX? |
| Skeptic Agent | What major risks are being overlooked under the assumption that the change should pass? |

Use the Task tool in Claude Code.
Since native TeamAgent may not be available in Codex environments,
reproduce the same perspectives using Codex reviewer subagents, `codex-companion.sh review`, or explicitly separate manual passes,
and record the mode in `team_agent_mode`.

## Passing Threshold

The final `APPROVE` requires all of the following.

- Zero `critical` / `major` issues
- No contradiction with the authoritative spec or `spec_skip_reason`
- No contradiction with `Plans.md` task / DoD / Depends
- No evidence of regression in existing behavior, tests, distribution mirrors, CLI/skill UX
- Disagreements from Claude / Codex / TeamAgent are resolved, or downgraded to `minor` / `recommendation` with reasoning

## Verdict Merge Rules

Evaluate in the following order:

   - Both APPROVE → `APPROVE`
   - Either is REQUEST_CHANGES → `REQUEST_CHANGES` (adopt the stricter one)
   - TeamAgent Debate leaves a `critical` / `major`-equivalent disagreement → `REQUEST_CHANGES`
   - Authoritative spec / Plans.md / regression gate fails → `REQUEST_CHANGES`
   - `critical_issues`: merge both lists (no deduplication)
   - `major_issues`: merge both lists (no deduplication)
   - `recommendations`: deduplicate and merge

## Output Format

Add a `dual_review` field to the standard `review-result.v1` schema:

```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "dual_review": {
    "claude_verdict": "APPROVE | REQUEST_CHANGES",
    "codex_verdict": "APPROVE | REQUEST_CHANGES | unavailable | timeout",
    "merged_verdict": "APPROVE | REQUEST_CHANGES",
    "divergence_notes": "Reason when verdicts diverge. Example: Claude detected a major Performance issue, Codex found no problem"
  },
  "acceptance_bar": {
    "critical_major_zero": true,
    "spec_alignment": "pass | fail | not_applicable",
    "plans_alignment": "pass | fail | not_applicable",
    "regression_safety": "pass | fail | not_applicable",
    "verification_evidence": "pass | fail | not_applicable"
  },
  "team_debate": {
    "required": true,
    "mode": "native | codex-companion | manual-pass | unavailable",
    "agents": ["Spec Agent", "Plans Agent", "Regression Agent"],
    "disagreements": []
  },
  "critical_issues": [],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```

### Special values for `codex_verdict`

| Value | Meaning |
|----|------|
| `"unavailable"` | Codex CLI is not installed or is unavailable |
| `"timeout"` | Codex review timed out (no response within 120 seconds) |

## Fallback

- **Codex unavailable**: run Claude only and record `codex_verdict: "unavailable"`
- **Codex timeout**: adopt Claude's verdict as-is and record `codex_verdict: "timeout"`
- **Codex review output is invalid**: treat as parse failure and record `codex_verdict: "unavailable"`
- **TeamAgent unavailable**: record `team_debate.mode: "unavailable"` with reason, and perform at minimum a manual-pass for Spec / Plans / Regression

Even when Codex is unavailable / timed out, the passing threshold for authoritative spec, Plans.md, and regressions is not skipped.
If TeamAgent is unavailable and a manual-pass is also impossible, stop with `decision_needed` rather than `REQUEST_CHANGES`.

## How to write Divergence Notes

When verdicts match (`claude_verdict == codex_verdict`), set `divergence_notes` to an empty string.

When verdicts diverge, record in the following format:

```
Claude: REQUEST_CHANGES (Security - SQL injection risk)
Codex: APPROVE (same location judged as no problem)
Adopted: REQUEST_CHANGES (stricter verdict takes priority)
```
