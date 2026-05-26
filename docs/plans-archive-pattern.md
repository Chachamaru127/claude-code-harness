# Plans.md Archive Pattern

The SSOT for the archive operation pattern that cuts completed Phases from Plans.md (project root)
into `.claude/memory/archive/Plans-*.md`, and for maintaining test consistency.
Introduced in Phase 64 (after v4.8.0).

## Why this pattern is needed

Plans.md, as the project work plan, grows in line count as completed Phases accumulate.
The auto-cleanup hook prompts for archiving when it exceeds 200 lines, but past archive attempts
revealed two problems:

1. **Test incompatibility**: `tests/test-claude-upstream-integration.sh` permanently requires
   Phase 51-58 detailed task lines in Plans.md (hardcoded grep in 10+ places), and archiving
   caused tests to fail
2. **Archive file commit omission**: `.claude/memory/archive/` is under gitignore, so archive
   list links in Plans.md were dead links on GitHub

This pattern is designed to solve both issues at once and make archiving functional.

## Archive naming convention

```
.claude/memory/archive/Plans-YYYY-MM-DD-phaseNN-MM.md
```

- `YYYY-MM-DD`: Archive execution date
- `phaseNN-MM`: Phase range being cut out (e.g., `phase47-61`)

Example: `Plans-2026-05-08-phase47-61.md`

## Archive file format

```markdown
# Plans Archive — Phase 47 / 48 / ... / 61

Archived on YYYY-MM-DD from Plans.md (lines XX-YY).

- Phase 47: Short description
- Phase 48: Short description
- ...

---

## Phase 47: ...
[Copy as-is from original Plans.md]
```

The opening archive metadata (Archived on, line range, Phase summary list) is required.
The content of each Phase is transcribed verbatim from Plans.md.

## Plans.md updates

When executing an archive, update 3 points in the Plans.md header:

1. **Last archive / previous archive**: Advance the date and link by one step

   ```markdown
   Last archived: 2026-05-08 (Phase 47-61 → `.claude/memory/archive/Plans-2026-05-08-phase47-61.md`)
   Previous archive: 2026-04-19 (Phase 44 + 45 + 46 → `.claude/memory/archive/Plans-2026-04-19-phase44-46.md`)
   ```

2. **Add new entry to the front of the archive list in the `## Archive` section**: Link to archive file + one-line summary

3. **Delete all Phases in the archive range**: Remove the corresponding line range from the file

## Test consistency: grep_plans_or_archive helper

Helper introduced in Phase 64.1.1. Placed as a library in `tests/lib/grep_plans_or_archive.sh`,
sourced by `tests/test-claude-upstream-integration.sh`.

```bash
grep_plans_or_archive 'PATTERN' || {
  echo "Plans.md (or archive) is missing the expected PATTERN reference"
  exit 1
}
```

### Behavior specification (4 states)

| Situation | Helper return code | Meaning |
|------|--------------------|------|
| Pattern matches only Plans.md | `0` (success) | Normal state before archiving |
| Pattern matches only archive | `0` (success) | State after archiving. Gone from Plans.md but remains in archive |
| Matches both | `0` (success) | Mixed state during transition |
| Matches neither | `1` (failure) | Truly gone. Test reports failure with exit 1 |

`tests/test-grep-plans-or-archive.sh` fixes these 4 states in unit tests.

### Test override (for unit tests)

The helper supports overriding target paths via environment variables:

```bash
export GPOA_PLANS_FILE="${TMPDIR}/Plans.md"
export GPOA_ARCHIVE_DIR="${TMPDIR}/archive"
```

Production code (= test-claude-upstream-integration.sh) does not override — it auto-resolves from ROOT_DIR.

## Git tracking configuration (.gitignore exception)

To make archives visible in CI, `.claude/memory/` is conditionally tracked:

```gitignore
.claude/*
!.claude/rules/
!.claude/output-styles/
!.claude/memory/
.claude/memory/*
!.claude/memory/archive/
.claude/memory/archive/*
!.claude/memory/archive/Plans-*.md
```

This exception means:

- ✅ Plans archives like `Plans-2026-05-08-phase47-61.md` are tracked
- ❌ Other archives like session-logs and codex-learnings remain ignored
- ❌ `.claude/state/` etc. remain ignored

## Standard procedure (operator checklist)

### Prerequisites
- Plans.md exceeds 200 lines and the auto-cleanup hook is prompting for archiving
- The Phase range to cut out is clear (e.g., a series of consecutive Phases completed 7+ days ago)
- `tests/lib/grep_plans_or_archive.sh` exists in the repo (Phase 64.1.1+)

### Execution
1. `cp Plans.md Plans.md.bak.$(date +%s)` to backup
2. Create archive file at `.claude/memory/archive/Plans-YYYY-MM-DD-phaseNN-MM.md` (in the format above)
3. Delete the corresponding Phase range from Plans.md
4. Update the archive list in the Plans.md header
5. `bash tests/test-claude-upstream-integration.sh` to verify archive-aware grep works
6. `./tests/validate-plugin.sh` to confirm 48/48 PASS
7. `bash scripts/ci/check-consistency.sh` for all-pass
8. `bash scripts/check-residue.sh` to confirm 0 items
9. Delete backup (`rm Plans.md.bak.*`)
10. `git add Plans.md .claude/memory/archive/Plans-YYYY-MM-DD-*.md` to stage
11. Commit + push

### Retroactive validation (per `.claude/rules/migration-policy.md` Rule 4)

Confirm tests PASS on both the commit just before archiving and the current HEAD after archiving:

```bash
# Test on current HEAD
bash tests/test-claude-upstream-integration.sh

# Test on pre-archive commit
git stash push -u
git checkout <archive-prior-sha> -- Plans.md tests/test-claude-upstream-integration.sh
bash tests/test-claude-upstream-integration.sh
git checkout HEAD -- Plans.md tests/test-claude-upstream-integration.sh
git stash pop
```

Both passing is evidence that the helper is robust against archive transitions.

## Known operational notes

### settings.json drift (under ongoing investigation)

During Phase 64 implementation, we observed 3 times that the `deniedDomains` in
`.claude-plugin/settings.json` reverts to a state where the 6 paste-site entries are deleted.
Cause unknown. Outside the scope of Phase 64; tracked as a separate issue.

### Retroactive tracking of past archives

The `.gitignore` exception `!.claude/memory/archive/Plans-*.md` glob targets all Plans archives
for tracking, but past local archives (like `Plans-2025-12-25.md`) may contain sensitive information
and must not be included in the initial commit. Review each archive individually, then add via
separate PRs one by one.

## Related files

- `tests/lib/grep_plans_or_archive.sh` — Helper implementation
- `tests/test-claude-upstream-integration.sh` — Production test that sources the helper for archive-aware grep
- `tests/test-grep-plans-or-archive.sh` — 4-state unit test for the helper
- `.gitignore` (line 25-32) — Git tracking configuration for archives
- `.claude/rules/migration-policy.md` — Rule 4 for retroactive validation (theoretical basis for this pattern)
- `.claude/rules/test-quality.md` — Test tampering prohibition rules (including exception approval procedures)
