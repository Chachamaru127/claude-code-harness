#!/bin/bash
# tests/test-cross-project-flag.sh
# Phase 65.3.5 - skill integration validation of --cross-project-group flag
#
# Validation cases (Plans.md §65.3.5 DoD e):
#   1. flag absent - SKILL.md describes both default (project-only) and
#                    alt (cross-project) Step 2
#   2. valid group - load-cross-project-groups.sh --group <valid> returns
#                    member array (D43 Option α)
#   3. invalid group - --group <invalid> exits 1, stderr "group not found"
#   4. empty group  - groups: [{name: X, members: []}] with --group X → []

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOADER="$ROOT_DIR/scripts/load-cross-project-groups.sh"
PLAN_BRIEF_SKILL="$ROOT_DIR/skills/harness-plan-brief/SKILL.md"
ACCEPT_SKILL="$ROOT_DIR/skills/harness-accept/SKILL.md"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$LOADER" ]]; then
  fail "load-cross-project-groups.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "load-cross-project-groups.sh exists and executable"

for f in "$PLAN_BRIEF_SKILL" "$ACCEPT_SKILL"; do
  if [[ ! -f "$f" ]]; then
    fail "skill file missing: $f"
    echo "PASS=$PASS FAIL=$FAIL"
    exit 1
  fi
done
pass "both SKILL.md files present"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-cross-project-flag.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ============================================================
# Case 1: flag absent - SKILL.md has both default + alt Step 2 descriptions
# ============================================================

# Plan Brief
if grep -q "Step 2: harness-mem を \*\*project-only\*\* で検索する (default)" "$PLAN_BRIEF_SKILL"; then
  pass "Case 1-a (plan-brief): default Step 2 (project-only) heading present"
else
  fail "Case 1-a: plan-brief default Step 2 heading missing or changed"
fi

if grep -q "Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)" "$PLAN_BRIEF_SKILL"; then
  pass "Case 1-b (plan-brief): alt Step 2 (cross-project) heading present"
else
  fail "Case 1-b: plan-brief alt Step 2 heading missing"
fi

if grep -q -- "--cross-project-group <name>" "$PLAN_BRIEF_SKILL"; then
  pass "Case 1-c (plan-brief): --cross-project-group flag mentioned"
else
  fail "Case 1-c: --cross-project-group flag not documented in plan-brief"
fi

# Accept
if grep -q "Step 2: harness-mem を \*\*project-only\*\* で検索し、Plan Brief 側 record を取得 (default)" "$ACCEPT_SKILL"; then
  pass "Case 1-d (accept): default Step 2 heading present"
else
  fail "Case 1-d: accept default Step 2 heading missing or changed"
fi

if grep -q "Step 2 (alt): cross-project search (Phase 65.3.5 opt-in)" "$ACCEPT_SKILL"; then
  pass "Case 1-e (accept): alt Step 2 heading present"
else
  fail "Case 1-e: accept alt Step 2 heading missing"
fi

if grep -q -- "--cross-project-group <name>" "$ACCEPT_SKILL"; then
  pass "Case 1-f (accept): --cross-project-group flag mentioned"
else
  fail "Case 1-f: --cross-project-group flag not documented in accept"
fi

# ============================================================
# Case 2: valid group - returns members array
# ============================================================

YAML2="$TMP_DIR/groups2-valid.yaml"
cat > "$YAML2" <<'YAML'
schema_version: cross-project-group.v1
groups:
  - name: TestPersonalTools
    description: Test group with 3 members
    members:
      - my-cli
      - my-dotfiles
      - my-scripts
YAML

OUTPUT="$(bash "$LOADER" --yaml "$YAML2" --group "TestPersonalTools" 2>"$TMP_DIR/c2-stderr.txt")"
# JSON is output in Python json.dumps default format (with separators and spaces)
if echo "$OUTPUT" | python3 -c "import json,sys; arr=json.load(sys.stdin); sys.exit(0 if arr==['my-cli','my-dotfiles','my-scripts'] else 1)"; then
  pass "Case 2 (valid group): exit 0, members array returned (parsed: my-cli/my-dotfiles/my-scripts)"
else
  fail "Case 2: unexpected output. got: $OUTPUT"
fi

if bash "$LOADER" --yaml "$YAML2" --group "TestPersonalTools" >/dev/null 2>&1; then
  pass "Case 2 (valid group): exit 0 confirmed"
else
  fail "Case 2: unexpected non-zero exit"
fi

# ============================================================
# Case 3: invalid group - exit 1, stderr "group not found"
# ============================================================

if bash "$LOADER" --yaml "$YAML2" --group "DoesNotExist" >/dev/null 2>"$TMP_DIR/c3-stderr.txt"; then
  fail "Case 3 (invalid group): expected exit 1, got 0"
else
  pass "Case 3 (invalid group): exit 1 as expected"
fi

if grep -q "group not found" "$TMP_DIR/c3-stderr.txt"; then
  pass "Case 3: stderr contains 'group not found'"
else
  fail "Case 3: stderr missing expected text. got: $(cat "$TMP_DIR/c3-stderr.txt")"
fi

# ============================================================
# Case 4: empty group - members: [] exits 0, [] returned
# ============================================================

YAML4="$TMP_DIR/groups4-empty-members.yaml"
cat > "$YAML4" <<'YAML'
schema_version: cross-project-group.v1
groups:
  - name: EmptyGroup
    description: Group with no members
    members: []
YAML

OUTPUT="$(bash "$LOADER" --yaml "$YAML4" --group "EmptyGroup" 2>"$TMP_DIR/c4-stderr.txt")"
if [[ "$OUTPUT" == "[]" ]]; then
  pass "Case 4 (empty members): exit 0, [] returned"
else
  fail "Case 4: unexpected output. got: $OUTPUT (expected: [])"
fi

if bash "$LOADER" --yaml "$YAML4" --group "EmptyGroup" >/dev/null 2>&1; then
  pass "Case 4 (empty members): exit 0 confirmed"
else
  fail "Case 4: unexpected non-zero exit"
fi

# ============================================================
# Common: does SKILL.md explicitly reference D43 Option α?
# ============================================================

if grep -q "D43 Option α" "$PLAN_BRIEF_SKILL"; then
  pass "plan-brief: D43 Option α reference present"
else
  fail "plan-brief: D43 Option α reference missing"
fi

if grep -q "D43" "$ACCEPT_SKILL"; then
  pass "accept: D43 reference present"
else
  fail "accept: D43 reference missing"
fi

# ============================================================
# Common: is there an instruction to use --with-redaction for cross-project results?
# ============================================================

if grep -q -- "--with-redaction" "$PLAN_BRIEF_SKILL"; then
  pass "plan-brief: --with-redaction flag instruction present (D43 judgment 4)"
else
  fail "plan-brief: --with-redaction flag instruction missing"
fi

if grep -q -- "--with-redaction" "$ACCEPT_SKILL"; then
  pass "accept: --with-redaction flag instruction present"
else
  fail "accept: --with-redaction flag instruction missing"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-cross-project-flag.sh)"
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
