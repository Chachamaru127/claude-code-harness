# Team Mode and Issue Bridge

`Plans.md` is kept as the authoritative source; GitHub Issue integration is used only in opt-in team mode.

## When to use which

- In solo development, do not use the issue bridge
- In team mode, create a single tracking issue and generate per-task sub-issue payloads under it as a dry run
- The issue bridge does not update Plans.md
- The process is dry-run only and does not make actual updates to GitHub

## Conversion rules

`scripts/plans-issue-bridge.sh` expands each task in Plans.md into the following structure:

- tracking issue
  - Parent issue for consolidation
  - Body contains a list of phases and tasks
- sub-issue
  - Individual payload per task
  - Body retains `task id`, `DoD`, `Depends`, and `Status`

## Example

```bash
scripts/plans-issue-bridge.sh --team-mode --plans Plans.md
```

Specifying `--format markdown` switches to a human-readable dry-run output.

## Benefits

- Plans.md remains the authoritative source as-is
- Team work gets an issue-based view without changing the source
- Solo development incurs no extra overhead
