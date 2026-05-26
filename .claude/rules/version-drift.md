# Version Drift Detection

## What to Check

VERSION and the version in `.claude-plugin/plugin.json` must always match.
When a mismatch is detected, suggest running `./scripts/sync-version.sh` (do not run automatically).

## Feature Table Freshness

Items marked as "planned (not yet implemented)" or "planned for implementation" in
`docs/CLAUDE-feature-table.md` should be proposed for deletion after 6 months.

## Why This Rule Is Necessary

D2 (inaccurate information) recurs even after a single fix.
Version mismatches and Feature Table rot are the most common drift patterns.
