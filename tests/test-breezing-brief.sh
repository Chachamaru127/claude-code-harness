#!/usr/bin/env bash
# Phase 93.3.1 — Brief Composer v0 contract tests
#
# Validates:
#   (a) brief-card.v1 schema is valid JSON with draft-07 structure
#   (b) golden cards pass validate and have 3-7 subtasks
#   (c) confirm no → DISPATCH: 0; confirm yes → subtask count
#   (d) classify structured vs free-text inputs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/breezing-brief.sh"
SCHEMA="$ROOT/templates/schemas/brief-card.v1.json"
FIXTURE_DIR="$ROOT/tests/fixtures/brief"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1" >&2; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected '${expected}', got '${actual}')"
  fi
}

assert_exit() {
  local label="$1"
  local expected_exit="$2"
  shift 2
  set +e
  local output
  output="$("$@" 2>&1)"
  local exit_code=$?
  set -e
  if [[ "$exit_code" -eq "$expected_exit" ]]; then
    pass "$label"
  else
    fail "$label (expected exit ${expected_exit}, got ${exit_code}; output: ${output})"
    printf '%s' "$output"
    return
  fi
  # Keep command stdout separate from pass/fail lines for $(...) capture.
  printf '%s' "$output"
}

# ---- pre-flight ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "pre-flight: breezing-brief.sh missing or not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: breezing-brief.sh exists and is executable"

if [[ ! -f "$SCHEMA" ]]; then
  fail "pre-flight: schema missing: $SCHEMA"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: brief-card.v1 schema exists"

# ---- (a) schema draft-07 structure ----

if python3 - <<'PY' "$SCHEMA"
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    schema = json.load(f)

assert isinstance(schema, dict), "schema root must be object"
assert schema.get("$schema") == "http://json-schema.org/draft-07/schema#", "$schema must be draft-07"
assert schema.get("type") == "object", "type must be object"
required = set(schema.get("required", []))
expected = {"goal", "subtasks", "scope_files", "risk_notes", "confidence"}
assert required == expected, f"required mismatch: {required} vs {expected}"
assert schema.get("additionalProperties") is False, "additionalProperties must be false"
props = schema.get("properties", {})
assert "subtasks" in props and props["subtasks"].get("minItems") == 3
assert props["subtasks"].get("maxItems") == 7
conf = props.get("confidence", {})
assert conf.get("enum") == ["high", "medium", "low"]
print("ok")
PY
then
  pass "(a) schema is JSON with draft-07 structure"
else
  fail "(a) schema draft-07 structure check failed"
fi

# ---- (b) golden cards validate + subtask count ----

GOLDEN_CARDS=(
  "card-login-auth.json"
  "card-rate-limit.json"
  "card-dashboard.json"
)

for card_name in "${GOLDEN_CARDS[@]}"; do
  card_path="$FIXTURE_DIR/$card_name"
  if [[ ! -f "$card_path" ]]; then
    fail "(b) missing golden card: $card_name"
    continue
  fi

  assert_exit "(b) validate PASS: $card_name" 0 bash "$SCRIPT" validate "$card_path" >/dev/null

  count="$(python3 - <<'PY' "$card_path"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    card = json.load(f)
print(len(card.get("subtasks", [])))
PY
)"
  if [[ "$count" -ge 3 && "$count" -le 7 ]]; then
    pass "(b) subtasks count 3-7: $card_name ($count)"
  else
    fail "(b) subtasks count out of range for $card_name: $count"
  fi
done

# ---- (c) confirm yes/no dispatch contract ----

CARD="$FIXTURE_DIR/card-login-auth.json"
SUBTASK_COUNT="$(python3 - <<'PY' "$CARD"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    print(len(json.load(f)["subtasks"]))
PY
)"

out_no="$(assert_exit "(c) confirm no exit 0" 0 bash "$SCRIPT" confirm no "$CARD")"
assert_eq "(c) confirm no → DISPATCH: 0" "DISPATCH: 0" "$out_no"

out_yes="$(assert_exit "(c) confirm yes exit 0" 0 bash "$SCRIPT" confirm yes "$CARD")"
assert_eq "(c) confirm yes → subtask count" "DISPATCH: ${SUBTASK_COUNT}" "$out_yes"

# ---- (d) classify structured vs free-text ----

STRUCTURED_CASES=(
  ""
  "all"
  "3-6"
  "--cursor all"
  "--parallel 2 all"
  "--no-review-gate all"
)

for args in "${STRUCTURED_CASES[@]}"; do
  label="(d) classify structured: '${args:-<empty>}'"
  out="$(assert_exit "$label" 0 bash "$SCRIPT" classify "$args")"
  assert_eq "$label → structured" "structured" "$out"
done

FREE_TEXT_CASES=(
  "input-login-auth.txt"
  "input-rate-limit.txt"
  "input-dashboard.txt"
)

for input_file in "${FREE_TEXT_CASES[@]}"; do
  input_path="$FIXTURE_DIR/$input_file"
  if [[ ! -f "$input_path" ]]; then
    fail "(d) missing free-text fixture: $input_file"
    continue
  fi
  text="$(tr -d '\n' < "$input_path")"
  label="(d) classify free-text: $input_file"
  out="$(assert_exit "$label" 0 bash "$SCRIPT" classify "$text")"
  assert_eq "$label → free-text" "free-text" "$out"
done

# ---- summary ----

echo ""
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "Failures:" >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi

echo "test-breezing-brief: ok"
