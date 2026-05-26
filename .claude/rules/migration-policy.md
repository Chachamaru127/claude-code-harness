# Migration Residue Policy

Policy for operating Harness **exclusion-based verification (residue checks for deleted concepts)**.
Defines the operational rules for `deleted-concepts.yaml` + `check-residue.sh`
introduced in Phase 40 (v4.1.0).

## Why This Rule Is Necessary

Immediately after the v4.0.0 "Hokage" release, the full migration from TypeScript to Go was supposed to be "complete."
Yet in the two days following the release, 13 "relics from the old era" were found one after another:
file paths that should have been deleted still appearing in test scripts, old version names remaining in documentation,
a README saying Node.js was required — none of these could be found through individual reviews or "does X exist?" style checks.

After a major migration, verifying that old things are truly gone requires
a reverse-direction check: "does the deleted thing still remain?" (exclusion-based verification).
If this rule is followed, the same mistake will not recur in future major migrations.

## 5 Rules

### Rule 1: Always update deleted-concepts.yaml during a major version migration

"The PR that deletes X" and "the PR that adds X to deleted-concepts.yaml" must be
submitted at the same time. Delays are prohibited.

**Why**: If the yaml update is deferred after deletion, another PR may introduce
a reference to X in the interim without being noticed before merge. Bundling the yaml update
with the deletion PR makes "deletion = adding to scan targets" a single indivisible transaction.

### Rule 2: The update timing is "at the same time as the deletion PR"

The strong form of Rule 1. For example: if submitting a PR to delete the TypeScript guardrail engine,
add `"TypeScript guardrail engine"` to `deleted_concepts` in the same PR.

"I deleted it" and "I made it a scan target" must always be completed together. Either one alone is only half done.

### Rule 3: The allowlist is operated under 3 principles

The following may be included in the `allowlist` field of deleted-concepts.yaml:

- **Historical description**: CHANGELOG.md and `.claude/memory/archive/` are always on the allowlist.
  Recording "something like this existed in the past" is a legitimate mention, not a relic.
- **Migration guide**: Documents like `docs/MIGRATION-*.md` that write old → new comparisons.
  Mentioning old names in a comparison table is intentional writing.
- **Individual context**: Cases where a mention of an old concept in a specific document is **intentionally legitimate**.
  Example: `.claude/rules/v3-architecture.md` is a historical record of v3 architecture,
  so it naturally contains `"Harness v3"`.

The allowlist is applied as a prefix match. **Keep the granularity of entries minimal**.
Adding all of `CHANGELOG.md` to the allowlist is legitimate, but
adding the entire `docs/` directory is excessive and renders the scanner meaningless.

### Rule 4: Always perform retroactive validation (scanning past commits)

After adding a new deleted-concepts.yaml entry, **go back to past commits and
run the scanner to confirm that residue is detected as expected**:

```bash
git checkout <past-commit>
bash scripts/check-residue.sh
# → Expected number of findings detected (must be 1 or more)
git checkout -
```

This verifies "whether the yaml can actually detect the problem."
If nothing is detected, the allowlist may be too broad, or the pattern may be wrong.
The goal is to catch false allowlists that would accidentally pass early on.

### Rule 5: Maintain zero false positives (current HEAD always produces 0 findings)

When the scanner is run against the current HEAD, **the finding count must always be 0**.
If findings are detected, handle them with one of the following:

1. **True residue** — fix immediately (modify the file to remove the old reference)
2. **Should be in the allowlist as a historical description, etc.** — update the yaml
3. **Misclassification** (the yaml pattern accidentally matches) — remove from yaml

Both CI (section 9 of validate-plugin.sh) and the release preflight (Phase 0 of harness-release)
perform automatic checks, so **zero findings before merge is guaranteed**.

## Appendix: The 13 v3 Residue Cases from This Session (v4.0.0 → v4.0.1)

The cases that motivated Phase 40. **The story of why this feature was born.**

### How They Were Discovered

The v4.0.0 "Hokage" release (2026-04-09) was a complete migration from TypeScript implementation
to Go native implementation. The migration itself was completed, but **TypeScript-era references
remained as residue scattered throughout test scripts, documentation, and SKILL.md**.
These were discovered accidentally through the following paths:

1. Test execution failure → validate-plugin.sh / check-consistency.sh fails
2. User notices in the slash palette → "Harness v3" in SKILL.md frontmatter
3. Found during code review → v3 narrative in agents/*.md
4. Found during documentation review → `core/` engine mention in README.md

The problem is that they were "found by accident." Without a system, the same thing will happen in the next release.

### Classification of the 13 Cases

| Category | Count | Representative example |
|---------|------|--------|
| Deleted path references | 2 | `core/src/guardrails/rules.ts` |
| Deleted concept terms | 3 | "TypeScript guardrail engine" |
| SKILL.md version suffix | 2 | `# Harness Work (v3)` |
| Legacy runtime requirements | 1 | "Node.js 18+ is installed" |
| Historical table | 1 | `core/` in README file tree |
| Other (individual formatting bugs) | 4 | README duplicate lines, language drift |

### Lessons Learned

All 13 cases were undetectable by **inclusion-based verification** ("does X exist?" style checks).
This is because confirming "X is not remaining" requires prior knowledge that "X was deleted."

The perspective of **exclusion-based verification** ("is the deleted X still remaining?") is required.
Phase 40 was created to build that perspective into the Harness verification layer.

## Related Files

- `.claude/rules/deleted-concepts.yaml` — SSOT catalog of deleted paths/concepts
- `scripts/check-residue.sh` — Scanner implementation (keep false positives at 0 immediately)
- `go/cmd/harness/doctor.go` — `bin/harness doctor --residue` flag
- `tests/validate-plugin.sh` — Section 9: Migration residue check (CI gate)
- `skills/harness-release/SKILL.md` — Phase 0 preflight step 2 (release gate)
