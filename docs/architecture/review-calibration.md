# Review Calibration

Storage format and operational rules for suppressing review drift.

## Storage Locations

- `.claude/state/review-result.json`
- `.claude/state/review-calibration.jsonl`
- `.claude/state/review-few-shot-bank.json`

## Recording Rules

When `review-result.json` includes a `calibration` field, `record-review-calibration.sh`
appends one line to `review-calibration.jsonl`.

`calibration.label` must be one of the following:

- `false_positive`
- `false_negative`
- `missed_bug`
- `overstrict_rule`

Phase 61 weak-supervision observations must not be mixed into `review-calibration.jsonl`.
`weak_label`, `judge_verdict`, `eval_result`, and `counterexample` are recorded separately
in `.claude/state/elicitation/events.jsonl` as `elicitation-event.v1`.
Review calibration handles correction of Reviewer judgment drift;
the elicitation ledger serves as evidence cues for the next Advisor/Reviewer run.

## Few-Shot Updates

`build-review-few-shot-bank.sh` extracts the latest samples from the calibration log
and regenerates the few-shot JSON bank.

## Quality Posture

- Only flag critical defects as `REQUEST_CHANGES`
- Keep unsubstantiated suspicions at `minor` or `recommendation`
- Write findings concisely and concretely enough to be usable as few-shot examples later
