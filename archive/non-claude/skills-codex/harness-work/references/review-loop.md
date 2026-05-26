# Codex Review Loop

Codex review follows the same verdict contract as Claude-side `harness-work`.

## Order

1. Run companion structured review when available.
2. Run AI Residuals JSON scan:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh" --base-ref "${BASE_REF}" --include-untracked
```

3. Fall back to a read-only reviewer agent only when companion review is not
   available.

## Verdict Threshold

`critical` or `major` means `REQUEST_CHANGES`. `minor` and `recommendation` do
not affect approval.

## Worker Repair

When a spawned Worker needs changes, resume it and use `send_input` with the
critical/major findings only. Then wait again and rerun review.
