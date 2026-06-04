#!/usr/bin/env bash
# test-orchestration-totals.sh
# Phase 90.1.2: lifetime accumulator + idempotent rollup.
#
# Verifies:
#   - orchestration-totals.v1 schema exists
#   - scripts/orchestration-rollup.sh aggregates a session's counted delegations
#     from the ledger into per-backend cumulative totals
#   - idempotent per session_id: rolling up the same session twice (e.g. completion
#     + session-end, or a re-run) never double-counts
#   - counts=false lines (status/setup polling) are excluded
#   - missing ledger -> skip (no crash); unwritable totals -> fail-open
#   - record-only: rollup prints nothing to stdout
#   - the live Go hook handlers invoke the rollup (task_completed.go + cleanup.go)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROLLUP="${REPO_ROOT}/scripts/orchestration-rollup.sh"
SCHEMA="${REPO_ROOT}/skills/harness-progress/schemas/orchestration-totals.v1.schema.json"
TASK_GO="${REPO_ROOT}/go/internal/hookhandler/task_completed.go"
CLEANUP_GO="${REPO_ROOT}/go/internal/session/cleanup.go"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq required for totals test"
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/orch-totals-test.XXXXXX")"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

[ -f "${SCHEMA}" ] && ok "totals schema exists" || ng "totals schema missing"
[ -f "${ROLLUP}" ] && ok "rollup script exists" || ng "rollup script missing"

if [ ! -f "${ROLLUP}" ]; then
  printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
  exit 1
fi

LEDGER="${TMP}/ledger.jsonl"
TOTALS="${TMP}/totals.json"

# Session A: 2 codex (counts=true), 1 cursor (counts=true), 1 codex status (counts=false)
cat >"${LEDGER}" <<'EOF'
{"ts":"2026-06-03T00:00:00Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"sess-A","counts":true}
{"ts":"2026-06-03T00:00:01Z","backend":"codex","subcommand":"review","write":false,"exit_code":null,"duration_ms":null,"session_id":"sess-A","counts":true}
{"ts":"2026-06-03T00:00:02Z","backend":"cursor","subcommand":"task","write":true,"exit_code":0,"duration_ms":120,"session_id":"sess-A","counts":true}
{"ts":"2026-06-03T00:00:03Z","backend":"codex","subcommand":"status","write":false,"exit_code":null,"duration_ms":null,"session_id":"sess-A","counts":false}
EOF

run_rollup() {
  HARNESS_ORCHESTRATION_LEDGER="${LEDGER}" HARNESS_ORCHESTRATION_TOTALS="${TOTALS}" \
    bash "${ROLLUP}" "$1"
}

# 1. first rollup of sess-A
out="$(run_rollup sess-A 2>/dev/null)"
rc=$?
[ "${rc}" -eq 0 ] && ok "rollup sess-A exit 0" || ng "rollup sess-A rc=${rc}"
[ -z "${out}" ] && ok "rollup is record-only (no stdout)" || ng "rollup printed stdout: [${out}]"

if [ -f "${TOTALS}" ]; then
  ok "totals file created"
  [ "$(jq -r '.totals.codex' "${TOTALS}")" = "2" ] && ok "codex total=2 (status excluded)" || ng "codex total ($(jq -r '.totals.codex' "${TOTALS}"))"
  [ "$(jq -r '.totals.cursor' "${TOTALS}")" = "1" ] && ok "cursor total=1" || ng "cursor total ($(jq -r '.totals.cursor' "${TOTALS}"))"
  [ "$(jq -r '.rolled_up_sessions | length' "${TOTALS}")" = "1" ] && ok "1 session rolled up" || ng "rolled_up count"
else
  ng "totals file not created"
fi

# 2. idempotent: roll up sess-A again -> unchanged
run_rollup sess-A >/dev/null 2>&1
[ "$(jq -r '.totals.codex' "${TOTALS}")" = "2" ] && ok "idempotent: codex still 2" || ng "idempotent codex ($(jq -r '.totals.codex' "${TOTALS}"))"
[ "$(jq -r '.totals.cursor' "${TOTALS}")" = "1" ] && ok "idempotent: cursor still 1" || ng "idempotent cursor"
[ "$(jq -r '.rolled_up_sessions | length' "${TOTALS}")" = "1" ] && ok "idempotent: still 1 session" || ng "idempotent session count"

# 3. second session adds on top
cat >>"${LEDGER}" <<'EOF'
{"ts":"2026-06-03T01:00:00Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"sess-B","counts":true}
EOF
run_rollup sess-B >/dev/null 2>&1
[ "$(jq -r '.totals.codex' "${TOTALS}")" = "3" ] && ok "sess-B adds: codex=3" || ng "sess-B codex ($(jq -r '.totals.codex' "${TOTALS}"))"
[ "$(jq -r '.rolled_up_sessions | length' "${TOTALS}")" = "2" ] && ok "2 sessions rolled up" || ng "2 sessions"

# 4. missing ledger -> skip, no crash
NOLEDGER="${TMP}/none.jsonl"
NOTOTALS="${TMP}/none-totals.json"
HARNESS_ORCHESTRATION_LEDGER="${NOLEDGER}" HARNESS_ORCHESTRATION_TOTALS="${NOTOTALS}" \
  bash "${ROLLUP}" sess-X >/dev/null 2>&1
mrc=$?
[ "${mrc}" -eq 0 ] && ok "missing ledger: exit 0 (skip)" || ng "missing ledger rc=${mrc}"

# 5. fail-open: unwritable totals path
BLOCK="${TMP}/blockfile"
: >"${BLOCK}"
HARNESS_ORCHESTRATION_LEDGER="${LEDGER}" HARNESS_ORCHESTRATION_TOTALS="${BLOCK}/sub/totals.json" \
  bash "${ROLLUP}" sess-A >/dev/null 2>&1
frc=$?
[ "${frc}" -eq 0 ] && ok "fail-open: unwritable totals exit 0" || ng "fail-open rc=${frc}"

# 5b. delta reconciliation: a re-rollup after MORE same-session delegations adds
#     only the new ones (the mid-session rollup gap). Hermetic: own ledger/totals.
DLEDGER="${TMP}/delta-ledger.jsonl"
DTOTALS="${TMP}/delta-totals.json"
cat >"${DLEDGER}" <<'EOF'
{"ts":"2026-06-03T02:00:00Z","backend":"cursor","subcommand":"task","write":true,"exit_code":0,"duration_ms":50,"session_id":"sess-D","counts":true}
{"ts":"2026-06-03T02:00:01Z","backend":"cursor","subcommand":"review","write":false,"exit_code":0,"duration_ms":40,"session_id":"sess-D","counts":true}
EOF
run_delta() {
  HARNESS_ORCHESTRATION_LEDGER="${DLEDGER}" HARNESS_ORCHESTRATION_TOTALS="${DTOTALS}" \
    bash "${ROLLUP}" sess-D >/dev/null 2>&1
}
# first rollup captures the session at count 2
run_delta
[ "$(jq -r '.totals.cursor' "${DTOTALS}")" = "2" ] && ok "delta: initial cursor=2" || ng "delta initial ($(jq -r '.totals.cursor' "${DTOTALS}"))"
# one more counted same-session delegation appears AFTER the first rollup
cat >>"${DLEDGER}" <<'EOF'
{"ts":"2026-06-03T02:00:02Z","backend":"cursor","subcommand":"task","write":true,"exit_code":0,"duration_ms":60,"session_id":"sess-D","counts":true}
EOF
# re-rollup must add only the tail (2 -> 3): NOT skipped (stay 2), NOT re-added whole (5)
run_delta
[ "$(jq -r '.totals.cursor' "${DTOTALS}")" = "3" ] && ok "delta: re-rollup adds tail cursor 2->3" || ng "delta re-rollup ($(jq -r '.totals.cursor' "${DTOTALS}"))"
[ "$(jq -r '.rolled_up_sessions | length' "${DTOTALS}")" = "1" ] && ok "delta: session still listed once" || ng "delta session count ($(jq -r '.rolled_up_sessions | length' "${DTOTALS}"))"
# the per-session snapshot now reflects the current ledger count
[ "$(jq -r '.session_counts["sess-D"].cursor' "${DTOTALS}")" = "3" ] && ok "delta: session_counts snapshot updated to 3" || ng "delta snapshot ($(jq -r '.session_counts["sess-D"].cursor' "${DTOTALS}"))"
# re-rollup again with no new delegations -> stays 3 (no-double-count preserved)
run_delta
[ "$(jq -r '.totals.cursor' "${DTOTALS}")" = "3" ] && ok "delta: no new delegations stays 3 (no-double-count)" || ng "delta no-op ($(jq -r '.totals.cursor' "${DTOTALS}"))"

# 5c. migration-safe: an old totals file lacking session_counts is read without
#     error, and a session already in rolled_up_sessions is NOT double-counted.
MLEDGER="${TMP}/mig-ledger.jsonl"
MTOTALS="${TMP}/mig-totals.json"
cat >"${MLEDGER}" <<'EOF'
{"ts":"2026-06-03T03:00:00Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"sess-M","counts":true}
{"ts":"2026-06-03T03:00:01Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"sess-M","counts":true}
EOF
# pre-fix totals file: sess-M already folded codex=2 into totals, no session_counts field
cat >"${MTOTALS}" <<'EOF'
{"version":1,"totals":{"codex":2},"rolled_up_sessions":["sess-M"],"first_seen":"2026-06-03T03:00:00Z","last_seen":"2026-06-03T03:00:00Z"}
EOF
HARNESS_ORCHESTRATION_LEDGER="${MLEDGER}" HARNESS_ORCHESTRATION_TOTALS="${MTOTALS}" \
  bash "${ROLLUP}" sess-M >/dev/null 2>&1
migrc=$?
[ "${migrc}" -eq 0 ] && ok "migration: old totals read without error (exit 0)" || ng "migration rc=${migrc}"
[ "$(jq -r '.totals.codex' "${MTOTALS}")" = "2" ] && ok "migration: already-counted session not double-counted (stays 2)" || ng "migration double-count ($(jq -r '.totals.codex' "${MTOTALS}"))"
# after migration the snapshot is seeded, so a further delegation is captured as a delta
cat >>"${MLEDGER}" <<'EOF'
{"ts":"2026-06-03T03:00:02Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"sess-M","counts":true}
EOF
HARNESS_ORCHESTRATION_LEDGER="${MLEDGER}" HARNESS_ORCHESTRATION_TOTALS="${MTOTALS}" \
  bash "${ROLLUP}" sess-M >/dev/null 2>&1
[ "$(jq -r '.totals.codex' "${MTOTALS}")" = "3" ] && ok "migration: post-seed tail captured (codex 2->3)" || ng "migration post-seed ($(jq -r '.totals.codex' "${MTOTALS}"))"

# 6. live Go handlers invoke the rollup (via the orchestration package)
if [ -f "${TASK_GO}" ] && grep -q 'orchestration\.Run' "${TASK_GO}"; then
  ok "task_completed.go invokes orchestration.Run (all-done)"
else
  ng "task_completed.go does not invoke orchestration.Run"
fi
if [ -f "${CLEANUP_GO}" ] && grep -q 'orchestration\.Run' "${CLEANUP_GO}"; then
  ok "cleanup.go invokes orchestration.Run (session-end safety net)"
else
  ng "cleanup.go does not invoke orchestration.Run"
fi
# and the orchestration package actually drives the rollup script
ROLLUP_GO="${REPO_ROOT}/go/internal/orchestration/rollup.go"
if [ -f "${ROLLUP_GO}" ] && grep -q 'orchestration-rollup.sh' "${ROLLUP_GO}"; then
  ok "orchestration package execs orchestration-rollup.sh"
else
  ng "orchestration package does not reference the rollup script"
fi

printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
