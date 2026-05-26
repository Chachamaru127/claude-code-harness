#!/bin/bash
# tests/test-cross-project-groups-schema.sh
# Phase 65.3.1 - mechanical schema validation of cross-project-groups.yaml
#
# Validation cases (Plans.md §65.3.1 DoD d):
#   1. empty (groups: [])         → exit 0, json output contains "groups": []
#   2. 1 group (2 members)        → exit 0, --group returns members array
#   3. duplicate member           → exit 1, stderr contains "duplicate"
#   4. invalid schema (groups not array) → exit 1, stderr contains "must be a list"
#
# Common validation:
#   (a) load-cross-project-groups.sh is executable
#   (b) default yaml (.claude/rules/cross-project-groups.yaml) is also valid
#   (c) --group <non-existent name> exits 1
#   (d) yaml file not found exits 1

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="$ROOT_DIR/scripts/load-cross-project-groups.sh"
DEFAULT_YAML="$ROOT_DIR/.claude/rules/cross-project-groups.yaml"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ---- pre-checks ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "load-cross-project-groups.sh not executable: $SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "load-cross-project-groups.sh exists and is executable"

if [[ ! -f "$DEFAULT_YAML" ]]; then
  fail "default yaml not found: $DEFAULT_YAML"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "default yaml exists at .claude/rules/cross-project-groups.yaml"

# ---- temp fixture dir ----

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-cross-project-groups.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ============================================================
# Case 1: empty (groups: [])
# ============================================================

CASE1_YAML="$TMP_DIR/case1-empty.yaml"
cat > "$CASE1_YAML" <<'YAML'
schema_version: cross-project-group.v1
groups: []
YAML

if OUTPUT="$(bash "$SCRIPT" --yaml "$CASE1_YAML" 2>&1)"; then
  pass "Case 1 (empty groups): exit 0"
else
  fail "Case 1 (empty groups): expected exit 0, got non-zero. output: $OUTPUT"
fi

if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('groups')==[] else 1)" 2>/dev/null; then
  pass "Case 1: output contains 'groups': []"
else
  fail "Case 1: output does not contain 'groups': []. output: $OUTPUT"
fi

# ============================================================
# Case 2: 1 group with 2 members
# ============================================================


CASE2_YAML="$TMP_DIR/case2-one-group.yaml"
cat > "$CASE2_YAML" <<'YAML'
schema_version: cross-project-group.v1
groups:
  - name: TestGroup
    description: Test group with 2 members
    members:
      - project-a
      - project-b
YAML

# 2-1: full groups output
if OUTPUT="$(bash "$SCRIPT" --yaml "$CASE2_YAML" 2>&1)"; then
  pass "Case 2 (1 group, full output): exit 0"
else
  fail "Case 2 (1 group, full output): expected exit 0. output: $OUTPUT"
fi

if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if len(d.get('groups',[]))==1 and d['groups'][0]['name']=='TestGroup' else 1)" 2>/dev/null; then
  pass "Case 2: output contains 1 group named 'TestGroup'"
else
  fail "Case 2: output does not contain expected group. output: $OUTPUT"
fi

# 2-2: output members array with --group filter
if OUTPUT="$(bash "$SCRIPT" --yaml "$CASE2_YAML" --group "TestGroup" 2>&1)"; then
  pass "Case 2 (--group filter): exit 0"
else
  fail "Case 2 (--group filter): expected exit 0. output: $OUTPUT"
fi

if echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d==['project-a','project-b'] else 1)" 2>/dev/null; then
  pass "Case 2: --group filter returns correct members array"
else
  fail "Case 2: --group filter returned wrong members. output: $OUTPUT"
fi

# ============================================================
# Case 3: duplicate member (same project appears twice in a group)
# ============================================================

CASE3_YAML="$TMP_DIR/case3-duplicate-member.yaml"
cat > "$CASE3_YAML" <<'YAML'
schema_version: cross-project-group.v1
groups:
  - name: BadGroup
    members:
      - project-x
      - project-x
YAML

if bash "$SCRIPT" --yaml "$CASE3_YAML" 2>"$TMP_DIR/case3-stderr.txt" >/dev/null; then
  fail "Case 3 (duplicate member): expected exit 1, got exit 0"
else
  pass "Case 3 (duplicate member): exit 1 as expected"
fi

if grep -q "duplicate" "$TMP_DIR/case3-stderr.txt" 2>/dev/null; then
  pass "Case 3: stderr contains 'duplicate'"
else
  fail "Case 3: stderr missing 'duplicate'. content: $(cat "$TMP_DIR/case3-stderr.txt")"
fi

# ============================================================
# Case 4: invalid schema (groups is not an array)
# ============================================================

CASE4_YAML="$TMP_DIR/case4-bad-schema.yaml"
cat > "$CASE4_YAML" <<'YAML'
schema_version: cross-project-group.v1
groups: "not-an-array"
YAML

if bash "$SCRIPT" --yaml "$CASE4_YAML" 2>"$TMP_DIR/case4-stderr.txt" >/dev/null; then
  fail "Case 4 (groups not array): expected exit 1, got exit 0"
else
  pass "Case 4 (groups not array): exit 1 as expected"
fi

if grep -q "must be a list" "$TMP_DIR/case4-stderr.txt" 2>/dev/null; then
  pass "Case 4: stderr contains 'must be a list'"
else
  fail "Case 4: stderr missing 'must be a list'. content: $(cat "$TMP_DIR/case4-stderr.txt")"
fi

# ============================================================
# Common validation (b): default yaml is also valid
# ============================================================

if bash "$SCRIPT" >/dev/null 2>&1; then
  pass "default yaml (.claude/rules/cross-project-groups.yaml) is valid"
else
  fail "default yaml validation failed (this is the SSOT — must always be valid)"
fi

# ============================================================
# Common validation (c): non-existent group exits 1
# ============================================================

if bash "$SCRIPT" --yaml "$CASE2_YAML" --group "DoesNotExist" 2>"$TMP_DIR/notfound-stderr.txt" >/dev/null; then
  fail "non-existent group: expected exit 1, got exit 0"
else
  pass "non-existent group: exit 1 as expected"
fi

if grep -q "group not found" "$TMP_DIR/notfound-stderr.txt" 2>/dev/null; then
  pass "non-existent group: stderr contains 'group not found'"
else
  fail "non-existent group: stderr missing 'group not found'"
fi

# ============================================================
# Common validation (d): yaml file not found exits 1
# ============================================================

if bash "$SCRIPT" --yaml "/nonexistent/path/missing.yaml" 2>"$TMP_DIR/missing-stderr.txt" >/dev/null; then
  fail "missing yaml file: expected exit 1, got exit 0"
else
  pass "missing yaml file: exit 1 as expected"
fi

if grep -q "yaml file not found" "$TMP_DIR/missing-stderr.txt" 2>/dev/null; then
  pass "missing yaml file: stderr contains 'yaml file not found'"
else
  fail "missing yaml file: stderr missing 'yaml file not found'"
fi

# ============================================================
# Common validation (e): additional schema constraint (empty name)
# ============================================================

CASE5_YAML="$TMP_DIR/case5-empty-name.yaml"
cat > "$CASE5_YAML" <<'YAML'
schema_version: cross-project-group.v1
groups:
  - name: ""
    members:
      - project-z
YAML

if bash "$SCRIPT" --yaml "$CASE5_YAML" 2>"$TMP_DIR/case5-stderr.txt" >/dev/null; then
  fail "empty name: expected exit 1, got exit 0"
else
  pass "empty name: exit 1 as expected"
fi

if grep -q "non-empty string" "$TMP_DIR/case5-stderr.txt" 2>/dev/null; then
  pass "empty name: stderr contains 'non-empty string'"
else
  fail "empty name: stderr missing expected text"
fi

# ============================================================
# Common validation (f): schema_version mismatch exits 1
# ============================================================

CASE6_YAML="$TMP_DIR/case6-wrong-version.yaml"
cat > "$CASE6_YAML" <<'YAML'
schema_version: cross-project-group.v999
groups: []
YAML

if bash "$SCRIPT" --yaml "$CASE6_YAML" 2>"$TMP_DIR/case6-stderr.txt" >/dev/null; then
  fail "wrong schema_version: expected exit 1, got exit 0"
else
  pass "wrong schema_version: exit 1 as expected"
fi

if grep -q "schema_version" "$TMP_DIR/case6-stderr.txt" 2>/dev/null; then
  pass "wrong schema_version: stderr mentions 'schema_version'"
else
  fail "wrong schema_version: stderr missing expected text"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary"
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
