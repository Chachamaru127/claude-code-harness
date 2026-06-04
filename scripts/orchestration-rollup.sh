#!/usr/bin/env bash
# orchestration-rollup.sh — roll a session's delegations into the lifetime accumulator
#
# Phase 90.1.2 (spec.md "Orchestration Visibility Contract"): recording is
# cumulative. This script aggregates the counted delegations of ONE session from
# the ledger and merges them into per-backend lifetime totals.
#
# Usage:
#   bash scripts/orchestration-rollup.sh [session_id]
#
# Invoked from the live Go hook handlers at full-session completion
# (task_completed.go) and again at session end (cleanup.go) as a safety net.
# Each rollup reconciles the session's contribution to the lifetime totals by the
# DELTA between its current ledger count and the amount already folded in (tracked
# per session in session_counts). So running it from both points — or repeatedly,
# even mid-session — adds each delegation exactly once: a re-run with no new
# delegations is a no-op, and a re-run after more delegations adds only the tail.
#
# Contract:
#   - record-only: prints nothing to stdout (it is not a display surface).
#   - delta-reconciled: re-rollup adds (current − previously-counted) per backend;
#     no new delegations => no-op (no double-count); a grown ledger => tail added.
#   - migration-safe: a pre-reconciliation totals file lacks session_counts; a
#     session already in rolled_up_sessions is then treated as fully counted
#     (delta 0) so an old file is never double-counted on its next rollup.
#   - fail-open: any error exits 0 without touching the caller's flow.
#   - missing/empty ledger: skip (exit 0).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/lib/orchestration-ledger.sh" ]; then
  # shellcheck source=scripts/lib/orchestration-ledger.sh
  . "${SCRIPT_DIR}/lib/orchestration-ledger.sh" 2>/dev/null || true
fi

main() {
  command -v jq >/dev/null 2>&1 || return 0

  local session_id="${1:-}"
  if [ -z "${session_id}" ]; then
    if command -v __orch_session_id >/dev/null 2>&1; then
      session_id="$(__orch_session_id)"
    fi
  fi
  [ -n "${session_id}" ] || return 0

  local ledger totals now
  if command -v __orch_ledger_path >/dev/null 2>&1; then
    ledger="$(__orch_ledger_path)"
  else
    ledger="${HARNESS_ORCHESTRATION_LEDGER:-}"
  fi
  if command -v __orch_totals_path >/dev/null 2>&1; then
    totals="$(__orch_totals_path)"
  else
    totals="${HARNESS_ORCHESTRATION_TOTALS:-}"
  fi
  [ -n "${ledger}" ] || return 0
  [ -n "${totals}" ] || return 0

  # Missing ledger -> nothing to roll up.
  [ -f "${ledger}" ] || return 0

  now="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo '')"

  # Per-backend counts for this session (counted delegations only).
  local session_counts
  session_counts="$(jq -s --arg sid "${session_id}" \
    '[.[] | select(.session_id == $sid and .counts == true)]
     | group_by(.backend)
     | map({key: .[0].backend, value: length})
     | from_entries' \
    "${ledger}" 2>/dev/null || echo '{}')"
  [ -n "${session_counts}" ] || session_counts='{}'

  # Existing totals or default skeleton.
  local existing
  existing="$(cat "${totals}" 2>/dev/null || true)"
  [ -n "${existing}" ] || existing='{"version":1,"totals":{},"rolled_up_sessions":[],"session_counts":{},"first_seen":null,"last_seen":null}'

  local dir
  dir="$(dirname "${totals}")"
  mkdir -p "${dir}" 2>/dev/null || return 0

  local tmp merged
  tmp="$(mktemp "${dir}/.orch-totals.XXXXXX" 2>/dev/null || true)"
  [ -n "${tmp}" ] || return 0

  # Delta reconciliation: fold only (current ledger count − amount already counted)
  # for this session into the per-backend totals, then snapshot the new count in
  # session_counts. $prev is the previously-counted split:
  #   - session_counts[$sid] when present (the normal path);
  #   - else, for a pre-reconciliation file where the session is already in
  #     rolled_up_sessions, $sc itself (treat it as fully counted => delta 0, so an
  #     old file is migration-safe and never double-counted);
  #   - else {} (a brand-new session => delta is its full current count).
  merged="$(printf '%s' "${existing}" | jq \
    --arg sid "${session_id}" \
    --arg now "${now}" \
    --argjson sc "${session_counts}" \
    '. as $root
     | ($root.session_counts[$sid]
        // (if ($root.rolled_up_sessions | index($sid)) then $sc else {} end)) as $prev
     | .version = (.version // 1)
     | .totals = (reduce (($sc + $prev) | keys_unsorted[]) as $k (.totals // {};
         .[$k] = (((.[$k]) // 0) + (($sc[$k]) // 0) - (($prev[$k]) // 0))))
     | .session_counts = ((.session_counts // {}) | .[$sid] = $sc)
     | .rolled_up_sessions = (if (.rolled_up_sessions | index($sid)) then (.rolled_up_sessions // [])
                              else ((.rolled_up_sessions // []) + [$sid]) end)
     | .first_seen = (.first_seen // $now)
     | .last_seen = $now' 2>/dev/null || true)"

  if [ -z "${merged}" ]; then
    rm -f "${tmp}" 2>/dev/null || true
    return 0
  fi

  printf '%s\n' "${merged}" >"${tmp}" 2>/dev/null || { rm -f "${tmp}" 2>/dev/null || true; return 0; }
  mv "${tmp}" "${totals}" 2>/dev/null || { rm -f "${tmp}" 2>/dev/null || true; return 0; }
  return 0
}

main "$@" || true
exit 0
