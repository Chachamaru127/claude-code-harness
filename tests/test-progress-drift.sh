#!/bin/bash
# tests/test-progress-drift.sh
# Phase 65.4.3 - drift detection (5 alert kinds) mechanical validation
#
# Test cases (Plans.md §65.4.3 DoD c):
#   1. scope-creep      — file edited not in Plans.md → warn
#   2. time-overrun     — elapsed > estimate × 1.5 → warn (1.5x), critical (2.0x)
#   3. repeated-failure — fail count >= 3 → critical
#   4. cost-warning     — cost ratio >= 80% → warn (80-100%), critical (100%+)
#   5. high-risk-file   — harness.toml deny path matching → critical
# Also validates that color-coded CSS exists in HTML display (DoD d)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRIFT="$ROOT_DIR/scripts/progress-detect-drift.sh"
TEMPLATE="$ROOT_DIR/templates/html/progress.html.template"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

if [[ ! -x "$DRIFT" ]]; then
  fail "drift detector not executable"
  echo "PASS=$PASS FAIL=$FAIL"; exit 1
fi
pass "drift detector exists and executable"

# ============================================================
# Case 1: scope-creep (warn)
# ============================================================

OUT="$(bash "$DRIFT" --scope-creep-files "foo.py,bar.ts" 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and
  .[0].kind == "scope-creep" and
  .[0].severity == "warn" and
  (.[0].message | test("foo.py")) and
  (.[0].suggested_action | length > 0) and
  (.[0].triggered_at | test("^\\d{4}-\\d{2}-\\d{2}T"))
' >/dev/null 2>&1; then
  pass "Case 1 (scope-creep): warn + message + action + ISO8601 timestamp"
else
  fail "Case 1: bad output. got: $OUT"
fi

# ============================================================
# Case 2: time-overrun (warn 1.5x, critical 2.0x)
# ============================================================

# 2-a: 1.5x → warn
OUT="$(bash "$DRIFT" --elapsed-min 150 --estimate-min 100 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and .[0].kind == "time-overrun" and .[0].severity == "warn"
' >/dev/null 2>&1; then
  pass "Case 2-a (time-overrun 1.5x): warn"
else
  fail "Case 2-a: bad output. got: $OUT"
fi

# 2-b: 2.0x → critical
OUT="$(bash "$DRIFT" --elapsed-min 200 --estimate-min 100 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and .[0].kind == "time-overrun" and .[0].severity == "critical"
' >/dev/null 2>&1; then
  pass "Case 2-b (time-overrun 2.0x): critical"
else
  fail "Case 2-b: bad output. got: $OUT"
fi

# 2-c: 1.0x → no alert (under threshold)
OUT="$(bash "$DRIFT" --elapsed-min 100 --estimate-min 100 2>/dev/null)"
if echo "$OUT" | jq -e 'length == 0' >/dev/null 2>&1; then
  pass "Case 2-c (time-overrun under threshold): no alert"
else
  fail "Case 2-c: should be empty. got: $OUT"
fi

# ============================================================
# Case 3: repeated-failure (critical)
# ============================================================

OUT="$(bash "$DRIFT" --repeated-failure-count 3 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and .[0].kind == "repeated-failure" and .[0].severity == "critical"
' >/dev/null 2>&1; then
  pass "Case 3 (repeated-failure 3+): critical"
else
  fail "Case 3: bad output. got: $OUT"
fi

# 3-b: 2 → no alert (under threshold)
OUT="$(bash "$DRIFT" --repeated-failure-count 2 2>/dev/null)"
if echo "$OUT" | jq -e 'length == 0' >/dev/null 2>&1; then
  pass "Case 3-b (failure 2 - under threshold): no alert"
else
  fail "Case 3-b: should be empty. got: $OUT"
fi

# ============================================================
# Case 4: cost-warning (warn 80-100%, critical 100%+)
# ============================================================

# 4-a: 90% → warn
OUT="$(bash "$DRIFT" --cost-so-far 9 --cost-limit 10 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and .[0].kind == "cost-warning" and .[0].severity == "warn"
' >/dev/null 2>&1; then
  pass "Case 4-a (cost 90%): warn"
else
  fail "Case 4-a: bad output. got: $OUT"
fi

# 4-b: 110% → critical
OUT="$(bash "$DRIFT" --cost-so-far 11 --cost-limit 10 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and .[0].kind == "cost-warning" and .[0].severity == "critical"
' >/dev/null 2>&1; then
  pass "Case 4-b (cost 110%): critical"
else
  fail "Case 4-b: bad output. got: $OUT"
fi

# ============================================================
# Case 5: high-risk-file (critical)
# ============================================================

OUT="$(bash "$DRIFT" --high-risk-files ".env,credentials.json" 2>/dev/null)"
if echo "$OUT" | jq -e '
  length == 1 and .[0].kind == "high-risk-file" and .[0].severity == "critical" and (.[0].message | test("\\.env"))
' >/dev/null 2>&1; then
  pass "Case 5 (high-risk-file): critical + .env mentioned"
else
  fail "Case 5: bad output. got: $OUT"
fi

# ============================================================
# Common: all input empty → empty array
# ============================================================

OUT="$(bash "$DRIFT" 2>/dev/null)"
if echo "$OUT" | jq -e 'length == 0' >/dev/null 2>&1; then
  pass "no input: returns empty array"
else
  fail "no input should return []. got: $OUT"
fi

# ============================================================
# Common: 5 alerts fired simultaneously
# ============================================================

OUT="$(bash "$DRIFT" \
  --scope-creep-files "x.py" \
  --elapsed-min 200 --estimate-min 100 \
  --repeated-failure-count 3 \
  --cost-so-far 9 --cost-limit 10 \
  --high-risk-files ".env" 2>/dev/null)"

if echo "$OUT" | jq -e 'length == 5' >/dev/null 2>&1; then
  pass "5 input all combined: alerts.length == 5"
else
  fail "expected 5 alerts. got: $(echo "$OUT" | jq 'length')"
fi

KINDS="$(echo "$OUT" | jq -r '[.[].kind] | sort | join(",")')"
EXPECTED_KINDS="cost-warning,high-risk-file,repeated-failure,scope-creep,time-overrun"
if [[ "$KINDS" == "$EXPECTED_KINDS" ]]; then
  pass "5 input: all 5 alert kinds present"
else
  fail "kinds mismatch. expected: $EXPECTED_KINDS, got: $KINDS"
fi

# ============================================================
# DoD d: HTML template has color-coded CSS
# ============================================================

if grep -q 'alert-info' "$TEMPLATE" && grep -q 'alert-warn' "$TEMPLATE" && grep -q 'alert-critical' "$TEMPLATE"; then
  pass "(d) HTML template has alert-info / alert-warn / alert-critical class definitions"
else
  fail "(d) HTML template alert color definitions insufficient"
fi

if grep -q '#FBE9E7' "$TEMPLATE" || grep -qi 'alert-crit-bg' "$TEMPLATE"; then
  pass "(d) critical color (red-toned) is defined"
else
  fail "(d) critical color not defined"
fi

# Render with alerts injected (smoke test)
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-drift-render.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

ALERTS_JSON="$(bash "$DRIFT" --repeated-failure-count 3 2>/dev/null)"
SNAP_JSON="$TMP_DIR/snap.json"
HTML="$TMP_DIR/out.html"

# Assemble minimal snapshot (embed drift results into alerts)
jq -n --argjson alerts "$ALERTS_JSON" '{
  schema: "progress-snapshot.v1",
  project: "drift-test",
  current_task: "test",
  progress_pct: 50,
  todo_tasks: [], wip_tasks: [], done_tasks: [],
  elapsed_minutes: 0,
  estimated_total_minutes: 0,
  cost_so_far_usd: 0, cost_estimate_usd: 0,
  alerts: $alerts,
  generated_at: "2026-05-10T00:00:00Z",
  _done_recent_items: [],
  _todo_count: 0, _wip_count: 0, _done_count: 0
}' > "$SNAP_JSON"

if bash "$ROOT_DIR/scripts/render-html.sh" --template progress --data "$SNAP_JSON" --out "$HTML" 2>/dev/null; then
  pass "render-html.sh works with alerts injected"
else
  fail "render with alerts failed"
fi

if grep -q 'alert-critical' "$HTML" && grep -q 'repeated-failure' "$HTML"; then
  pass "rendered HTML contains alert-critical class + repeated-failure kind"
else
  fail "rendered HTML missing alert"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-progress-drift.sh)"
echo "============================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
