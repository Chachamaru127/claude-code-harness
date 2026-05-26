#!/bin/bash
# tests/test-progress-regen.sh
# Phase 65.4.2 - PostToolUse hook auto-regeneration + 60s rate limit validation
#
# Test cases (Plans.md §65.4.2 DoD a-e):
#   1. first run   - no state file → execute regen + create state file
#   2. within 60s  - state file present (last regen 30s ago) → skip
#   3. over 60s    - state file present (last regen 90s ago) → execute regen
#   4. invalid hook input - must not crash even with empty stdin
#   + dual sync validation (.claude-plugin/hooks.json and hooks/hooks.json match)
#   + JSON validity validation

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HANDLER="$ROOT_DIR/scripts/hook-handlers/posttool-progress-regen.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

if [[ ! -x "$HANDLER" ]]; then
  fail "posttool-progress-regen.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"; exit 1
fi
pass "handler exists and is executable"

# isolated test project root
TMP_PROJ="$(mktemp -d "${TMPDIR:-/tmp}/test-progress-regen.XXXXXX")"
trap 'rm -rf "$TMP_PROJ"' EXIT

mkdir -p "$TMP_PROJ/.claude/state"
mkdir -p "$TMP_PROJ/out"

cat > "$TMP_PROJ/Plans.md" <<'PLANS'
# Plans

| Task | Content | DoD | Depends | Status |
|------|---------|-----|---------|--------|
| 99.1.1 | done task | dod | - | cc:完了 [a1b2c3d] |
| 99.1.2 | in-progress | dod | - | cc:WIP |
PLANS

STATE_FILE="$TMP_PROJ/.claude/state/progress-last-regen.txt"

# ============================================================
# Case 1: first run — no state file → regen + create state file
# ============================================================

rm -f "$STATE_FILE"
OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>"$TMP_PROJ/c1-stderr.txt")"

if echo "$OUT" | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "Case 1 (first run): JSON {ok:true} returned"
else
  fail "Case 1: bad JSON. got: $OUT"
fi

if echo "$OUT" | jq -e '.regenerated == true' >/dev/null 2>&1; then
  pass "Case 1 (first run): regenerated:true marker"
else
  fail "Case 1: regenerated marker missing. got: $OUT"
fi

# wait for background regen to complete
sleep 1

if [[ -f "$STATE_FILE" ]]; then
  pass "Case 1 (first run): state file created"
else
  fail "Case 1: state file not created"
fi

# state file contains epoch seconds (integer)
LAST_VAL="$(cat "$STATE_FILE" 2>/dev/null || echo "")"
if [[ "$LAST_VAL" =~ ^[0-9]+$ ]]; then
  pass "Case 1 (first run): state file content is epoch seconds (integer)"
else
  fail "Case 1: state file content is not epoch. got: $LAST_VAL"
fi

# ============================================================
# Case 2: within 60s — state file present (last 30s ago) → skip
# ============================================================

# write epoch from 30s ago into state file
NOW="$(date +%s)"
echo $((NOW - 30)) > "$STATE_FILE"

OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>"$TMP_PROJ/c2-stderr.txt")"

if echo "$OUT" | jq -e '.skipped == "rate-limit"' >/dev/null 2>&1; then
  pass "Case 2 (30s ago): skipped:rate-limit"
else
  fail "Case 2: rate-limit skip not triggered. got: $OUT"
fi

# state file should not be modified
LAST_VAL_AFTER="$(cat "$STATE_FILE")"
if [[ "$LAST_VAL_AFTER" == "$((NOW - 30))" ]]; then
  pass "Case 2 (rate-limit): state file not updated"
else
  fail "Case 2: state file was updated (should have been skipped). before=$((NOW - 30)) after=$LAST_VAL_AFTER"
fi

# ============================================================
# Case 3: over 60s — state file present (last 90s ago) → regen
# ============================================================

NOW="$(date +%s)"
echo $((NOW - 90)) > "$STATE_FILE"

OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>"$TMP_PROJ/c3-stderr.txt")"

if echo "$OUT" | jq -e '.regenerated == true' >/dev/null 2>&1; then
  pass "Case 3 (90s ago): regen executed"
else
  fail "Case 3: regenerated marker missing. got: $OUT"
fi

sleep 1

LAST_VAL_C3="$(cat "$STATE_FILE")"
if [[ "$LAST_VAL_C3" -gt "$((NOW - 90))" ]]; then
  pass "Case 3 (90s ago): state file updated"
else
  fail "Case 3: state file not updated. before=$((NOW - 90)) after=$LAST_VAL_C3"
fi

# ============================================================
# Case 4: invalid hook input — empty stdin / EOF / large input
# ============================================================

# 4-a: empty stdin
OUT="$(echo -n "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>/dev/null)"
if echo "$OUT" | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "Case 4-a (empty stdin): {ok:true} returned (no crash)"
else
  fail "Case 4-a: crashed or bad output. got: $OUT"
fi

# 4-b: invalid JSON stdin
OUT="$(echo "not-json{garbage" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>/dev/null)"
if echo "$OUT" | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "Case 4-b (garbage stdin): {ok:true} returned (handler discards stdin)"
else
  fail "Case 4-b: bad output. got: $OUT"
fi

# 4-c: no Plans.md → no-plans-md skipped
TMP_PROJ_NO_PLANS="$(mktemp -d "${TMPDIR:-/tmp}/test-progress-no-plans.XXXXXX")"
trap "rm -rf '$TMP_PROJ' '$TMP_PROJ_NO_PLANS'" EXIT
mkdir -p "$TMP_PROJ_NO_PLANS/.claude/state"
OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ_NO_PLANS" bash "$HANDLER" 2>/dev/null)"
if echo "$OUT" | jq -e '.skipped == "no-plans-md"' >/dev/null 2>&1; then
  pass "Case 4-c (no Plans.md): skipped:no-plans-md"
else
  fail "Case 4-c: bad output. got: $OUT"
fi

# ============================================================
# Common: dual hooks.json sync (P29 contract)
# ============================================================

if diff -q "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json" >/dev/null 2>&1; then
  pass "dual hooks.json sync: .claude-plugin and hooks/ are identical"
else
  fail "dual hooks.json sync violation: 2 files differ"
fi

# JSON validity
for f in "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json"; do
  if jq -e . "$f" >/dev/null 2>&1; then
    pass "$(basename "$(dirname "$f")")/hooks.json: JSON valid"
  else
    fail "$(basename "$(dirname "$f")")/hooks.json: JSON invalid"
  fi
done

# posttool-progress-regen.sh entry must exist in both files
for f in "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json"; do
  if grep -q "posttool-progress-regen.sh" "$f"; then
    pass "$(basename "$(dirname "$f")")/hooks.json: posttool-progress-regen.sh entry present"
  else
    fail "$(basename "$(dirname "$f")")/hooks.json: hook entry missing"
  fi
done

# Verify entry is registered under PostToolUse (jq path query)
for f in "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json"; do
  if jq -e '
    .hooks.PostToolUse | map(.hooks[]?.command? // "" | tostring)
    | flatten
    | map(select(test("posttool-progress-regen")))
    | length > 0
  ' "$f" >/dev/null 2>&1; then
    pass "$(basename "$(dirname "$f")")/hooks.json: registered under PostToolUse"
  else
    fail "$(basename "$(dirname "$f")")/hooks.json: not registered under PostToolUse"
  fi
done

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-progress-regen.sh)"
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
