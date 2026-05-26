#!/bin/bash
# tests/test-harness-progress.sh
# Phase 65.4.1 - mechanical verification of the harness-progress skill + progress-snapshot.v1
#
# Verification cases (Plans.md §65.4.1 DoD a-d):
#   (a) skills/harness-progress/SKILL.md exists + required frontmatter
#   (b) progress-snapshot.v1 schema is valid as a JSON Schema
#   (c) cc:WIP / cc:TODO / cc:done counts from Plans.md fixture are reflected
#   (d) snapshot HTML shows correct % display for fixture Plans.md with each status

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SKILL_MD="$ROOT_DIR/skills/harness-progress/SKILL.md"
SCHEMA="$ROOT_DIR/skills/harness-progress/schemas/progress-snapshot.v1.schema.json"
SNAPSHOT_SCRIPT="$ROOT_DIR/scripts/progress-snapshot.sh"
RENDER_SCRIPT="$ROOT_DIR/scripts/render-html.sh"
TEMPLATE="$ROOT_DIR/templates/html/progress.html.template"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ============================================================
# (a) SKILL.md exists + frontmatter
# ============================================================

if [[ -f "$SKILL_MD" ]]; then
  pass "(a) skills/harness-progress/SKILL.md exists"
else
  fail "(a) SKILL.md missing"
  echo "PASS=$PASS FAIL=$FAIL"; exit 1
fi

if grep -q "^name: harness-progress" "$SKILL_MD"; then
  pass "(a) SKILL.md frontmatter: name = harness-progress"
else
  fail "(a) SKILL.md frontmatter name missing"
fi

if grep -q "^description:" "$SKILL_MD" && grep -q "^description-en:" "$SKILL_MD"; then
  pass "(a) SKILL.md has both description + description-en"
else
  fail "(a) SKILL.md missing description / description-en"
fi

# Consistency: description == description-en (literal match)
DESC_VAL="$(awk '/^description:/{sub(/^description: */, ""); gsub(/^"|"$/, ""); print; exit}' "$SKILL_MD")"
DESC_EN="$(awk '/^description-en:/{sub(/^description-en: */, ""); gsub(/^"|"$/, ""); print; exit}' "$SKILL_MD")"
if [[ "$DESC_VAL" == "$DESC_EN" ]]; then
  pass "(a) description == description-en"
else
  fail "(a) description and description-en differ"
fi

# ============================================================
# (b) JSON Schema validity
# ============================================================

if [[ -f "$SCHEMA" ]]; then
  pass "(b) schema file exists"
else
  fail "(b) schema file missing"
fi

# JSON parse + JSON Schema field presence
if jq -e '
  ."$schema" == "https://json-schema.org/draft/2020-12/schema" and
  .title == "progress-snapshot.v1" and
  (.required | type == "array") and
  (.properties.schema.const == "progress-snapshot.v1") and
  (.properties.progress_pct.minimum == 0) and
  (.properties.progress_pct.maximum == 100)
' "$SCHEMA" >/dev/null 2>&1; then
  pass "(b) schema is valid JSON Schema 2020-12 with progress-snapshot.v1 contract"
else
  fail "(b) schema validation failed"
fi

# ============================================================
# (c)(d) Fixture Plans.md → snapshot → HTML
# ============================================================

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-progress.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# Case 1: fixture with each status (TODO 2 / WIP 1 / done 1 = total 4, 25%)
FIXTURE1="$TMP_DIR/plans1-mixed.md"
cat > "$FIXTURE1" <<'PLANS'
# Plans

| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 99.1.1 | first test task | DoD T-001 | - | cc:完了 [a1b2c3d] |
| 99.1.2 | in-progress task | DoD T-002 | - | cc:WIP |
| 99.1.3 | pending task A | DoD T-003 | - | cc:TODO |
| 99.1.4 | pending task B | DoD T-004 | - | cc:TODO |
PLANS

SNAP1="$TMP_DIR/snap1.json"
bash "$SNAPSHOT_SCRIPT" --plans "$FIXTURE1" --project "case1" > "$SNAP1"

# Schema validation: snapshot is parseable + has expected fields
if jq -e '
  .schema == "progress-snapshot.v1" and
  .project == "case1" and
  .progress_pct == 25 and
  (.todo_tasks | length == 2) and
  (.wip_tasks | length == 1) and
  (.done_tasks | length == 1) and
  (.done_tasks[0].commit == "a1b2c3d")
' "$SNAP1" >/dev/null 2>&1; then
  pass "(c) Case 1 (TODO=2 / WIP=1 / done=1): counts and 25% correct"
else
  fail "(c) Case 1: snapshot incorrect. content: $(cat "$SNAP1")"
fi

if jq -e '.current_task | test("in-progress task")' "$SNAP1" >/dev/null; then
  pass "(c) Case 1: current_task = first WIP item"
else
  fail "(c) Case 1: current_task wrong"
fi

# Render to HTML
HTML1="$TMP_DIR/html1.html"
if bash "$RENDER_SCRIPT" --template progress --data "$SNAP1" --out "$HTML1" 2>"$TMP_DIR/r1-stderr.txt"; then
  pass "(d) Case 1: HTML render exit 0"
else
  fail "(d) Case 1: render failed. stderr: $(cat "$TMP_DIR/r1-stderr.txt")"
fi

if grep -q "25%" "$HTML1" && grep -q ">1</strong>" "$HTML1" && grep -q "done" "$HTML1"; then
  pass "(d) Case 1: HTML contains 25% and done count"
else
  fail "(d) Case 1: HTML missing expected count display"
fi

# Case 2: all done (100%)
FIXTURE2="$TMP_DIR/plans2-all-done.md"
cat > "$FIXTURE2" <<'PLANS'
# Plans

| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 1 | task 1 | dod | - | cc:完了 [aaaaaaa] |
| 2 | task 2 | dod | - | cc:完了 [bbbbbbb] |
PLANS

SNAP2="$TMP_DIR/snap2.json"
bash "$SNAPSHOT_SCRIPT" --plans "$FIXTURE2" --project "case2" > "$SNAP2"

if jq -e '.progress_pct == 100 and (.done_tasks | length == 2) and .current_task == ""' "$SNAP2" >/dev/null; then
  pass "(c) Case 2 (all done): progress_pct=100, current_task empty"
else
  fail "(c) Case 2: incorrect"
fi

# Case 3: zero tasks (0%)
FIXTURE3="$TMP_DIR/plans3-empty.md"
cat > "$FIXTURE3" <<'PLANS'
# Plans

| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
PLANS

SNAP3="$TMP_DIR/snap3.json"
bash "$SNAPSHOT_SCRIPT" --plans "$FIXTURE3" --project "case3" > "$SNAP3"

if jq -e '.progress_pct == 0 and (.todo_tasks | length == 0) and (.wip_tasks | length == 0) and (.done_tasks | length == 0)' "$SNAP3" >/dev/null; then
  pass "(c) Case 3 (empty Plans.md): progress_pct=0, all arrays empty"
else
  fail "(c) Case 3: incorrect"
fi

# Case 4: pm:* status is ignored (only TODO/WIP/done counted)
FIXTURE4="$TMP_DIR/plans4-pm-mixed.md"
cat > "$FIXTURE4" <<'PLANS'
# Plans

| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 1 | task 1 | dod | - | cc:完了 [aaaaaaa] |
| 2 | task 2 | dod | - | pm:依頼中 |
| 3 | task 3 | dod | - | pm:確認済 |
| 4 | task 4 | dod | - | cc:TODO |
PLANS

SNAP4="$TMP_DIR/snap4.json"
bash "$SNAPSHOT_SCRIPT" --plans "$FIXTURE4" --project "case4" > "$SNAP4"

if jq -e '.progress_pct == 50 and (.done_tasks | length == 1) and (.todo_tasks | length == 1) and (.wip_tasks | length == 0)' "$SNAP4" >/dev/null; then
  pass "(c) Case 4 (pm:* mixed): pm:* ignored, 50% (1/2) calculated correctly"
else
  fail "(c) Case 4: incorrect. snapshot: $(cat "$SNAP4")"
fi

# ============================================================
# Common: missing Plans.md → exit 1
# ============================================================

if bash "$SNAPSHOT_SCRIPT" --plans "/nonexistent/Plans.md" --project "x" >/dev/null 2>"$TMP_DIR/missing-stderr.txt"; then
  fail "missing Plans.md: expected exit 1"
else
  pass "missing Plans.md: exit 1 as expected"
fi

if grep -q "Plans.md not found" "$TMP_DIR/missing-stderr.txt"; then
  pass "missing Plans.md: stderr contains 'Plans.md not found'"
else
  fail "missing Plans.md: stderr missing expected text"
fi

# ============================================================
# Common: missing args → exit 2
# ============================================================

if bash "$SNAPSHOT_SCRIPT" --plans Plans.md >/dev/null 2>&1; then
  fail "missing --project: expected exit 2"
else
  pass "missing --project: exit non-zero as expected"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-harness-progress.sh)"
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
