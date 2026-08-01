#!/usr/bin/env bash
# Phase 98.1.3 — judgment-ledger.sh subcommand tests (bats-compatible assertions)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/judgment-ledger.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1" >&2; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/judgment-ledger-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

LEDGER="$TMP/judgment-ledger.jsonl"
export HARNESS_JUDGMENT_LEDGER="$LEDGER"

if [[ ! -x "$SCRIPT" ]]; then
  fail "pre-flight: judgment-ledger.sh missing or not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: judgment-ledger.sh exists"

# append
if bash "$SCRIPT" append \
  --project "demo-proj" \
  --question "Redis or Postgres for cache?" \
  --answer "redis" \
  --rationale "scale" \
  --card-ref "/tmp/card.json" \
  --tags "judgment-card" \
  --id "jl-shell-001" >/dev/null 2>&1; then
  pass "append exit 0"
else
  fail "append exit 0"
fi

if [[ -f "$LEDGER" ]] && grep -q 'jl-shell-001' "$LEDGER"; then
  pass "append wrote JSONL line"
else
  fail "append wrote JSONL line"
fi

# fail-open on unwritable path
BLOCK="$TMP/blockfile"
: >"$BLOCK"
BAD_LEDGER="$BLOCK/sub/ledger.jsonl"
set +e
failopen_out="$(HARNESS_JUDGMENT_LEDGER="$BAD_LEDGER" bash "$SCRIPT" append \
  --project "demo-proj" \
  --question "q" \
  --answer "a" \
  --card-ref "c.json" 2>&1)"
failopen_rc=$?
set -e
if [[ "$failopen_rc" -eq 0 ]]; then
  pass "append fail-open exit 0 on write failure"
else
  fail "append fail-open exit 0 (rc=$failopen_rc)"
fi
if grep -q 'append skipped' <<<"$failopen_out"; then
  pass "append fail-open stderr warning"
else
  fail "append fail-open stderr warning missing"
fi

# search
bash "$SCRIPT" append --project "demo-proj" --question "postgres migration plan" --answer "defer" --card-ref "c2.json" --id "jl-002" >/dev/null
bash "$SCRIPT" append --project "demo-proj" --question "redis cluster sizing" --answer "3 nodes" --card-ref "c3.json" --id "jl-003" >/dev/null

search_out="$(bash "$SCRIPT" search --project "demo-proj" --query "redis")"
search_count="$(printf '%s\n' "$search_out" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$search_count" -eq 2 ]]; then
  pass "search returns matching records"
else
  fail "search returns matching records (got $search_count lines)"
fi

other_out="$(bash "$SCRIPT" search --project "other-proj" --query "redis")"
other_count="$(printf '%s\n' "$other_out" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$other_count" -eq 0 ]]; then
  pass "search project scope isolation"
else
  fail "search project scope isolation (got $other_count)"
fi

# recall
recall_out="$(bash "$SCRIPT" recall --project "demo-proj" --question "cache")"
if python3 - <<'PY' "$recall_out"
import json, sys
data = json.loads(sys.argv[1])
assert isinstance(data, list)
assert len(data) >= 1
assert len(data) <= 3
item = data[0]
for key in ("summary", "decision", "outcome", "decided_at", "mem_id"):
    assert key in item
assert item["mem_id"].startswith("judgment-ledger:")
print("ok")
PY
then
  pass "recall returns similar_past_decisions-shaped JSON"
else
  fail "recall returns similar_past_decisions-shaped JSON"
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi

echo "test-judgment-ledger: ok"
