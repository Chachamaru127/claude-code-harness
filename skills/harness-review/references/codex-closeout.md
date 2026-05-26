# Quick / Codex Closeout

## In a nutshell

For small changes: fix the target, verify Codex findings in actual code, and stop once the result is clean.

## target selection decision tree

1. working tree is dirty
   - Recommended: uncommitted changes only
   - base: `HEAD`
   - include untracked files
2. PR branch / feature branch has commits
   - Recommended: `upstream..HEAD` or `origin/main..HEAD`
   - if working tree is also dirty, use AskUserQuestion to choose "uncommitted only / everything / commits only"
3. clean tree with no branch diff
   - Recommended: most recent 1 commit
   - most recent 5 commits if needed
4. user specifies `--base` / `--commit`
   - explicit specification takes priority

## Advisory rule

Codex findings are advisory.
That is, they are "reference opinions," not facts themselves.

Always do the following.

- Read the flagged location in the actual code
- Confirm reproducibility with the diff and tests
- Split into accepted findings / rejected findings
- For rejected findings, write "why not accepted"

## Stop-on-clean

stop-on-clean:
Do not add extra review solely for appearances after a clean result.

Example:

- Codex review: no major issues
- focused tests: pass
- manual spot check: pass

Stop here.
Additional heavy review is only done before a release, for security-sensitive changes, spec changes, or when the user explicitly requests it.

## Helper contract

`scripts/harness-review-closeout.sh` is a helper that fixes the execution plan for lightweight closeout.

Supported inputs:

- `--dry-run`
- `--parallel-tests`
- `--base REF`
- `--commit REF`
- `--uncommitted`
- `--test CMD`
- `--json`

Examples:

```bash
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
bash scripts/harness-review-closeout.sh --base origin/main --parallel-tests --test "bash tests/test-harness-review-governance.sh"
bash scripts/harness-review-closeout.sh --commit HEAD --json
```

When Codex is unavailable:

- fall back to full manual pass
- do not treat failure as success
- leave `codex_available:false` in the final report

## Final report

Required fields:

- review command
- tests
- accepted findings
- rejected findings
- clean result
- fallback reason

At minimum, record this in JSON.

```json
{
  "schema_version": "harness-review-closeout.v1",
  "target": "working_tree | branch_range | commit",
  "base_ref": "HEAD",
  "review_command": "bash scripts/codex-companion.sh review --base HEAD --json",
  "tests": [],
  "accepted_findings": [],
  "rejected_findings": [],
  "clean_result": true,
  "codex_available": true,
  "fallback": ""
}
```
