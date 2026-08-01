#!/usr/bin/env bash
# Phase 93.3.3 — Decision Card v0 contract tests
#
# Validates:
#   (a) judgment-card.v1 schema draft-07 + enum/min-max constraints
#   (b) card prompt → record-answer POST body contract
#   (c) should-issue floor hard-stop vs ISSUE_CARD
#   (d) mem fail-open (not-configured silent / unreachable 1-line warning)
#   (e) invalid card fails validate
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/judgment-card.sh"
SCHEMA="$ROOT/templates/schemas/judgment-card.v1.json"
FIXTURE_DIR="$ROOT/tests/fixtures/judgment"

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
  printf '%s' "$output"
}

# ---- pre-flight ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "pre-flight: judgment-card.sh missing or not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: judgment-card.sh exists and is executable"

if [[ ! -f "$SCHEMA" ]]; then
  fail "pre-flight: schema missing: $SCHEMA"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: judgment-card.v1 schema exists"

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
expected = {
    "question",
    "options",
    "recommendation",
    "confidence",
    "impact",
    "diff_summary",
}
assert required == expected, f"required mismatch: {required} vs {expected}"
assert schema.get("additionalProperties") is False, "additionalProperties must be false"
props = schema.get("properties", {})
opts = props.get("options", {})
assert opts.get("minItems") == 2, "options.minItems must be 2"
assert opts.get("maxItems") == 3, "options.maxItems must be 3"
item_required = set(opts.get("items", {}).get("required", []))
assert item_required == {"id", "label", "consequence"}, f"option required mismatch: {item_required}"
conf = props.get("confidence", {})
assert conf.get("enum") == ["high", "medium", "low"], "confidence enum mismatch"
print("ok")
PY
then
  pass "(a) schema is JSON with draft-07 structure"
else
  fail "(a) schema draft-07 structure check failed"
fi

# ---- (b) validate golden cards + record-answer POST ----

VALID_CARDS=(
  "card-tradeoff.json"
  "card-dod-ambiguous.json"
)

for card_name in "${VALID_CARDS[@]}"; do
  card_path="$FIXTURE_DIR/$card_name"
  if [[ ! -f "$card_path" ]]; then
    fail "(b) missing valid card fixture: $card_name"
    continue
  fi

  assert_exit "(b) validate PASS: $card_name" 0 bash "$SCRIPT" validate "$card_path" >/dev/null

  opt_count="$(python3 - <<'PY' "$card_path"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    card = json.load(f)
print(len(card.get("options", [])))
PY
)"
  if [[ "$opt_count" -ge 2 && "$opt_count" -le 3 ]]; then
    pass "(b) options count 2-3: $card_name ($opt_count)"
  else
    fail "(b) options count out of range for $card_name: $opt_count"
  fi
done

TMP_HTTP="$(mktemp -d)"
trap 'rm -rf "$TMP_HTTP"' EXIT

HTTP_PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

python3 - <<'PY' "$TMP_HTTP" "$HTTP_PORT" &
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

capture_dir = sys.argv[1]
port = int(sys.argv[2])


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8")
        with open(f"{capture_dir}/last-body.json", "w", encoding="utf-8") as f:
            f.write(body)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}\n')

    def log_message(self, format, *args):
        return


server = HTTPServer(("127.0.0.1", port), Handler)
server.handle_request()
PY

sleep 0.2

MEM_HOME="$(mktemp -d)"
mkdir -p "$MEM_HOME/.harness-mem"

CARD="$FIXTURE_DIR/card-tradeoff.json"
set +e
record_out="$(
  HOME="$MEM_HOME" \
  HARNESS_MEM_HOST=127.0.0.1 \
  HARNESS_MEM_PORT="$HTTP_PORT" \
  bash "$SCRIPT" record-answer "$CARD" \
    --answer redis \
    --why "スケール要件を優先" \
    --project demo-project \
    --session sess-judgment-001 2>&1
)"
record_exit=$?
set -e

if [[ "$record_exit" -eq 0 ]]; then
  pass "(b) record-answer exit 0 on healthy mem"
else
  fail "(b) record-answer expected exit 0 (got ${record_exit}; output: ${record_out})"
fi

if [[ -f "$TMP_HTTP/last-body.json" ]]; then
  pass "(b) record-answer POST received"
else
  fail "(b) record-answer did not POST to fake server"
fi

if [[ -f "$TMP_HTTP/last-body.json" ]]; then
  python3 - <<'PY' "$TMP_HTTP/last-body.json" "$CARD"
import json
import sys

body_path, card_path = sys.argv[1], sys.argv[2]
with open(body_path, encoding="utf-8") as f:
    body = json.load(f)
with open(card_path, encoding="utf-8") as f:
    card = json.load(f)

required = {"session_id", "title", "content", "tags"}
missing = required - set(body.keys())
assert not missing, f"missing POST fields: {sorted(missing)}"
assert body["session_id"] == "sess-judgment-001"
assert body["tags"] == ["judgment-card"]

question = card["question"]
expected_prefix = f"judgment: {question[:60]}"
assert body["title"] == expected_prefix, f"title mismatch: {body['title']!r}"

content = json.loads(body["content"])
assert content["answer"] == "redis"
assert content["why"] == "スケール要件を優先"
assert content["card"]["question"] == question
print("ok")
PY
  if [[ $? -eq 0 ]]; then
    pass "(b) record-answer POST body has session_id/title/content/tags"
  else
    fail "(b) record-answer POST body contract failed"
  fi
fi

# ---- (c) should-issue floor vs card ----

out_floor="$(assert_exit "(c) floor category → HARD_STOP exit 2" 2 \
  bash "$SCRIPT" should-issue --reason tradeoff --floor-category egress)"
assert_eq "(c) floor output" "HARD_STOP: floor (egress)" "$out_floor"

for reason in dod-ambiguous scope-exceeded tradeoff; do
  out_issue="$(assert_exit "(c) reason ${reason} → ISSUE_CARD exit 0" 0 \
    bash "$SCRIPT" should-issue --reason "$reason")"
  assert_eq "(c) ${reason} output" "ISSUE_CARD" "$out_issue"
done

out_no="$(assert_exit "(c) unknown reason → NO_CARD exit 1" 1 \
  bash "$SCRIPT" should-issue --reason 'not-a-reason')"
assert_eq "(c) unknown reason output" "NO_CARD: reason not in enum" "$out_no"

# ---- (d) mem fail-open ----

CLOSED_PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
port = s.getsockname()[1]
s.close()
print(port)
PY
)"

set +e
unreach_out="$(
  HOME="$MEM_HOME" \
  HARNESS_MEM_HOST=127.0.0.1 \
  HARNESS_MEM_PORT="$CLOSED_PORT" \
  bash "$SCRIPT" record-answer "$CARD" \
    --answer redis \
    --why "test unreachable" \
    --project demo-project \
    --session sess-unreach 2>&1
)"
unreach_exit=$?
set -e

if [[ "$unreach_exit" -eq 0 ]]; then
  pass "(d) unreachable record-answer exit 0"
else
  fail "(d) unreachable expected exit 0 (got ${unreach_exit})"
fi

if grep -qx 'judgment-card: record skipped (unreachable)' <<<"$unreach_out"; then
  pass "(d) unreachable emits 1-line warning"
else
  fail "(d) unreachable warning missing (output: ${unreach_out})"
fi

EMPTY_HOME="$(mktemp -d)"
set +e
nc_out="$(
  HOME="$EMPTY_HOME" \
  HARNESS_MEM_HOST=127.0.0.1 \
  HARNESS_MEM_PORT="$CLOSED_PORT" \
  bash "$SCRIPT" record-answer "$CARD" \
    --answer redis \
    --why "test not configured" \
    --project demo-project \
    --session sess-nc 2>&1
)"
nc_exit=$?
set -e

if [[ "$nc_exit" -eq 0 ]]; then
  pass "(d) not-configured record-answer exit 0"
else
  fail "(d) not-configured expected exit 0 (got ${nc_exit})"
fi

if [[ -z "${nc_out//[$'\t ']/}" ]]; then
  pass "(d) not-configured emits no warning"
else
  fail "(d) not-configured should be silent (output: ${nc_out})"
fi

# ---- (e) invalid card fails validate ----

INVALID="$FIXTURE_DIR/card-invalid-one-option.json"
if [[ ! -f "$INVALID" ]]; then
  fail "(e) missing invalid card fixture"
else
  assert_exit "(e) invalid card validate exit 1" 1 bash "$SCRIPT" validate "$INVALID" >/dev/null
fi

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

echo "test-judgment-card: ok"
