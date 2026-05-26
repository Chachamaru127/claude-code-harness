# `/ultrareview` and `/harness-review` Integration Policy

Policy document finalized in Phase 44.8.1.

---

## 1. `/ultrareview` Behavior

`/ultrareview` is a **built-in slash command** added in Claude Code 2.1.111.
Since Claude Code 2.1.120, `claude ultrareview [target] --json` is also available
for use from CI or scripts.

| Attribute | Details |
|------|------|
| Session type | Single-turn dedicated review session |
| Execution host | CC native (outside Harness agent) |
| Input | Current working tree diff (auto-collected) |
| Output | Inline natural language review result |
| Output schema | Undefined (CC internal format) |
| CLI entry point | `claude ultrareview [target] --json` (for CI / ad-hoc second-opinion) |
| Plans.md integration | None |
| Sprint-contract verification | None |
| Codex adversarial review | None |
| Reviewer agent invocation | None |

`/ultrareview` is the entry point for users requesting an ad-hoc review directly from CC,
and operates outside Harness's automated flow (Plan → Work → Review).
`claude ultrareview [target] --json` serves the same role — a supplementary CI entry point,
not a replacement for `/harness-review`.

---

## 2. Differences from `/harness-review`

| Aspect | `/ultrareview` | `/harness-review` |
|------|----------------|-------------------|
| Execution host | CC native | Harness skill (context: fork) |
| Session | Single-turn | Multi-step (Steps 0–4) |
| Plans.md integration | None | Yes (cc:WIP check / cc:done update) |
| Sprint-contract verification | None | Yes (`.claude/state/contracts/<task>.sprint-contract.json`) |
| Codex adversarial review | None | Yes (with `--dual` flag) |
| Reviewer agent | None | Yes (`reviewer` agent, `review-result.v1` output) |
| Output schema | Undefined | `review-result.v1` (machine-readable JSON) |
| AI Residuals scan | None | Yes (`scripts/review-ai-residuals.sh`) |
| Correction loop | None | Yes (on REQUEST_CHANGES, max 3 iterations) |
| Security-only mode | None | Yes (`--security`, OWASP Top 10) |
| UI Rubric mode | None | Yes (`--ui-rubric`, 4-axis scoring) |
| Target users | Direct user use | Lead / breezing flow automated invocation |

### 2.1 Role of `claude ultrareview [target] --json`

`claude ultrareview [target] --json` is a CLI entry point for calling CC native ad-hoc review
from non-interactive CI or local scripts.

Harness treats it as follows:

| Use case | Decision |
|------|------|
| Supplementary review in PR CI | Allowed. Treat as second-opinion |
| Alternative to `/harness-review --dual` | Not allowed. Does not replace Codex adversarial review or `review-result.v1` |
| Determining REQUEST_CHANGES correction loop | Not allowed. Output schema is not Harness-contract-compatible |
| Quick scan of a large local diff | Allowed. Treat as ad-hoc review |

---

## 3. Confirmed Policy: **(B) Prefer `/harness-review` — Do not call `/ultrareview` within Harness flow**

### 3.1 Rationale

**Alignment with Rule 5**: `.claude/rules/opus-4-7-prompt-audit.md` states:
"`/ultrareview` is the caller-side review entry point. The agent definition side uses `review-result.v1` as the contract."
The Harness Reviewer agent and harness-review skill output `review-result.v1` as their contract.
Calling `/ultrareview` internally would break the machine-readable guarantee of `review-result.v1`.

**Schema mismatch**: `/ultrareview` output is in CC internal format and does not include
the `verdict`, `critical_issues`, or `major_issues` fields of `review-result.v1`.
Harness's correction loop, commit guard, and sprint-contract verification all depend on
`review-result.v1`, and there is no justifiable benefit to introducing a schema conversion overhead.

**Separation of concerns**: `/ultrareview` is an entry point for users making ad-hoc CC requests.
Automated review within the Harness flow is covered by the `reviewer` agent (`review-result.v1`)
and `codex-companion.sh review`. The two are different in purpose and can coexist.

**Fallback safety**: If `codex-companion.sh review` is unavailable, fall back to the
`reviewer` agent (static / runtime / browser profile).
Adding `/ultrareview` would increase fallback paths and make debugging harder.

### 3.2 Usage Guide

| Scenario | Recommended command |
|--------|------------|
| Final check before PR merge (outside Harness) | `/ultrareview` |
| Supplementary second-opinion in CI | `claude ultrareview [target] --json` |
| Automated review after Harness Plan→Work | `/harness-review` (auto-invoked) |
| Review with Codex second opinion | `/harness-review --dual` |
| Security-focused audit | `/harness-review --security` |
| UI quality scoring | `/harness-review --ui-rubric` |

---

## 4. Future Considerations

- Re-evaluate `/ultrareview` once it matures as a CC built-in (next evaluation: Phase 45+)
- Using `/ultrareview` inside Harness will only be considered once a schema conversion layer
  from its output to `review-result.v1` is implemented in `scripts/codex-companion.sh`
  (currently not implemented)
- Policy changes must be made simultaneously with revisions to Rule 5 in
  `.claude/rules/opus-4-7-prompt-audit.md`

---

*Decision: Phase 44.8.1 / 2026-04-18*
