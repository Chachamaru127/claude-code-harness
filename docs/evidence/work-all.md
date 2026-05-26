# `/harness-work all` Evidence Pack

Last updated: 2026-03-06

This evidence pack is the minimal set for verifying the claims of `/harness-work all` by checking "what artifacts remain after execution."
The current assumption is a new contract: completion requires passing through the `sprint-contract` and an independent review artifact, not just a Worker self-check.

## What is included

| Scenario | Goal | Expected result |
|----------|------|-----------------|
| success | Complete a small TODO repo with `work all` | Tests turn green and new commits are left behind |
| failure | Feed an impossible task and verify the quality gate | Tests remain failing; no new commits are created |

## Fixtures

- `tests/fixtures/work-all-success/`
- `tests/fixtures/work-all-failure/`

Both are set up so that `npm test` fails at baseline.

## Smoke vs Full

| Mode | Command | What it does |
|------|---------|--------------|
| CI smoke | `./scripts/evidence/run-work-all-smoke.sh` | Verifies fixture integrity and baseline failure, and leaves a Claude execution command preview |
| Local full | `./scripts/evidence/run-work-all-success.sh --full` | Runs the success scenario via the Claude CLI; completes the artifact with a replay overlay when rate-limited |
| Local full (strict) | `./scripts/evidence/run-work-all-success.sh --full --strict-live` | Proves success using only a live Claude run, without replay |
| Local full | `./scripts/evidence/run-work-all-failure.sh --full` | Runs the failure scenario via the Claude CLI and verifies that no new commits appear |

Artifacts are saved by default to `out/evidence/work-all/`.

## Prerequisites for full runs

- `claude --version` must succeed (required for strict live)
- Must be authenticated in Claude Code
- Must be run from the repo root

Full mode uses the following command internally:

```bash
claude --plugin-dir /path/to/claude-code-harness \
  --dangerously-skip-permissions \
  --output-format json \
  --no-session-persistence \
  -p "$(cat PROMPT.md)"
```

## Saved artifacts

- `baseline-test.log`
- `claude-stdout.json`
- `claude-stderr.log`
- `elapsed-seconds.txt`
- `git-status.txt`
- `git-diff-stat.txt`
- `git-diff.patch`
- `git-log.txt`
- `commit-count.txt`
- `result.txt`
- `execution-mode.txt`
- `sprint-contract.json` or contract generation log
- `review-result.json`
- `fallback-reason.txt`
- `rate-limit-detected.txt`
- `replay.log` (when a rate limit fallback occurs)

## Interpretation

- In the success scenario, `post_test_status=0` and `final_commits > baseline_commits` is evidence that "execution completed and reached a commit" in the minimal scenario
- Additionally, `review-result.json` being `APPROVE` is evidence that "completion passed an independent review"
- In the failure scenario, `post_test_status!=0` and `final_commits == baseline_commits` is evidence that, at minimum, "failure was not concealed and no commit was made"
- Even if test tampering occurs in the failure fixture, it remains in the diff artifact, making it easy to review how the quality gate behaved

## Live vs Replay

- `execution_mode=live` means an artifact where the Claude CLI ran the success scenario to completion as-is
- `execution_mode=replay-after-rate-limit` means Claude execution was stopped by a rate limit, and the replay overlay bundled with the fixture was applied to produce a happy-path artifact
- To publicly claim "proven with a live Claude run," obtain a separate `--strict-live` success artifact
