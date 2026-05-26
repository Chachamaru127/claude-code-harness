# Plans Maintenance

Last updated: 2026-03-06

`Plans.md` is the source of truth, but if extended indefinitely without maintenance, "past completion
expressions" and the "current repo state" tend to drift apart.
This document contains minimal operational rules to reduce drift.

## Lightweight Rule

1. Before starting a major new improvement phase, treat only the most recent 1–2 phases as the active zone
2. Older completed phases can optionally be moved to an archive location such as `docs/plans-history/`
3. Wording that tends to conflict with the current tree — such as "deleted" or "migration complete" — should have a correction note added when the state changes in a subsequent phase
4. When changing how README / docs / `.gitignore` / build scripts are handled, fix the wording in `Plans.md` in the same commit

## When to Archive

Consider archiving old completed phases if any of the following conditions are met:

- Understanding the current primary work in `Plans.md` requires going back 3 or more phases
- Words like "deleted" or "consolidated" create misunderstandings about the current repo
- The cost of reading historical phases on every sync-status run becomes noticeable

## Recommended Shape

- `Plans.md`: Current active phase and only the most recently completed phase
- `docs/plans-history/`: Fixed snapshots of past phases
- `docs/distribution-scope.md`: Current truth about retained items and distribution boundaries

## Phase 21 Decision

- For this phase, archiving was not performed — instead, **correcting misleading completion expressions** was prioritized
- Before the next major phase addition, it is recommended to move completed history from Phase 17 onward to `docs/plans-history/`
