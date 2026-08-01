#!/usr/bin/env bash
# test-orchestration-scorecard.sh
# Phase 90.1.3: scorecard aggregator + tri-state.
#
# Verifies:
#   - orchestration-scorecard.v1 schema exists
#   - scripts/orchestration-scorecard.sh merges current-session ledger counts and
#     lifetime totals into a scorecard JSON
#   - per-backend tri-state: used (count>0) / available (configured, unused) /
#     not-configured (binary absent)
#   - claude is the host (never counted as a delegation)
#   - degrade to "no delegations observed" when nothing is recorded
#   - --format terminal yields a compact non-empty summary

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CARD="${REPO_ROOT}/scripts/orchestration-scorecard.sh"
SCHEMA="${REPO_ROOT}/skills/harness-progress/schemas/orchestration-scorecard.v1.schema.json"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq required"; exit 0; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/orch-card-test.XXXXXX")"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

[ -f "${SCHEMA}" ] && ok "scorecard schema exists" || ng "scorecard schema missing"
[ -f "${CARD}" ] && ok "scorecard script exists" || ng "scorecard script missing"
if [ ! -f "${CARD}" ]; then printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"; exit 1; fi

LEDGER="${TMP}/ledger.jsonl"
TOTALS="${TMP}/totals.json"
cat >"${LEDGER}" <<'EOF'
{"ts":"2026-06-03T00:00:00Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"S","counts":true}
{"ts":"2026-06-03T00:00:01Z","backend":"codex","subcommand":"review","write":false,"exit_code":null,"duration_ms":null,"session_id":"S","counts":true}
{"ts":"2026-06-03T00:00:02Z","backend":"cursor","subcommand":"task","write":true,"exit_code":0,"duration_ms":120,"session_id":"S","counts":true}
{"ts":"2026-06-03T00:00:03Z","backend":"codex","subcommand":"status","write":false,"exit_code":null,"duration_ms":null,"session_id":"S","counts":false}
{"ts":"2026-06-03T00:00:04Z","backend":"codex","subcommand":"task","write":true,"exit_code":null,"duration_ms":null,"session_id":"OTHER","counts":true}
EOF
cat >"${TOTALS}" <<'EOF'
{"version":1,"totals":{"codex":10,"cursor":4},"rolled_up_sessions":["S","old"],"first_seen":"2026-06-01T00:00:00Z","last_seen":"2026-06-03T00:00:00Z"}
EOF

run_card() {
  HARNESS_ORCHESTRATION_LEDGER="${LEDGER}" HARNESS_ORCHESTRATION_TOTALS="${TOTALS}" \
    HARNESS_ORCH_FORCE_AVAIL="${FORCE_AVAIL:-codex,cursor}" \
    bash "${CARD}" "$@"
}

# 1. JSON session counts (status excluded, OTHER session excluded)
json="$(run_card --format json S 2>/dev/null)"
echo "${json}" | jq -e . >/dev/null 2>&1 && ok "emits valid JSON" || ng "invalid JSON"
[ "$(echo "${json}" | jq -r '.session.codex.count')" = "2" ] && ok "session codex=2 (status & other-session excluded)" || ng "session codex ($(echo "${json}" | jq -r '.session.codex.count'))"
[ "$(echo "${json}" | jq -r '.session.cursor.count')" = "1" ] && ok "session cursor=1" || ng "session cursor"
[ "$(echo "${json}" | jq -r '.session.non_claude_delegations')" = "3" ] && ok "session non_claude_delegations=3" || ng "session non_claude_delegations"

# 2. tri-state used (count>0)
[ "$(echo "${json}" | jq -r '.session.codex.status')" = "used" ] && ok "codex status=used" || ng "codex status"
[ "$(echo "${json}" | jq -r '.session.cursor.status')" = "used" ] && ok "cursor status=used" || ng "cursor status"
# claude is host
[ "$(echo "${json}" | jq -r '.session.claude.status')" = "host" ] && ok "claude status=host" || ng "claude status"

# 3. lifetime from totals
[ "$(echo "${json}" | jq -r '.lifetime.codex.count')" = "10" ] && ok "lifetime codex=10" || ng "lifetime codex"
[ "$(echo "${json}" | jq -r '.lifetime.cursor.count')" = "4" ] && ok "lifetime cursor=4" || ng "lifetime cursor"

# 4. observed=true with data
[ "$(echo "${json}" | jq -r '.observed')" = "true" ] && ok "observed=true with data" || ng "observed flag"

# 5. backends_engaged: claude(host) + codex + cursor = 3
[ "$(echo "${json}" | jq -r '.session.backends_engaged')" = "3" ] && ok "backends_engaged=3" || ng "backends_engaged ($(echo "${json}" | jq -r '.session.backends_engaged'))"

# 6. tri-state available (configured but unused this session) — session Z has no lines
jsonZ="$(run_card --format json Z 2>/dev/null)"
[ "$(echo "${jsonZ}" | jq -r '.session.codex.status')" = "available" ] && ok "unused+configured -> available" || ng "available status ($(echo "${jsonZ}" | jq -r '.session.codex.status'))"

# 7. tri-state not-configured (binary absent)
jsonNC="$(FORCE_AVAIL=none run_card --format json Z 2>/dev/null)"
[ "$(echo "${jsonNC}" | jq -r '.session.codex.status')" = "not-configured" ] && ok "binary absent -> not-configured" || ng "not-configured status ($(echo "${jsonNC}" | jq -r '.session.codex.status'))"

# 8. degrade: missing ledger + totals
NL="${TMP}/none.jsonl"; NT="${TMP}/none.json"
deg="$(HARNESS_ORCHESTRATION_LEDGER="${NL}" HARNESS_ORCHESTRATION_TOTALS="${NT}" HARNESS_ORCH_FORCE_AVAIL=none bash "${CARD}" --format json Z 2>/dev/null)"
[ "$(echo "${deg}" | jq -r '.observed')" = "false" ] && ok "degrade observed=false" || ng "degrade observed"
deg_note="$(jq -r '.note' <<<"${deg}")"
grep -qi 'no delegations observed' <<<"${deg_note}" && ok "degrade note present" || ng "degrade note"

# 9. terminal format compact + non-empty
term="$(run_card --format terminal S 2>/dev/null)"
lc="$(printf '%s\n' "${term}" | grep -c . )"
[ -n "${term}" ] && [ "${lc}" -ge 2 ] && [ "${lc}" -le 8 ] && ok "terminal format compact (${lc} lines)" || ng "terminal format (${lc} lines)"
grep -qiE 'codex|cursor' <<<"${term}" && ok "terminal mentions backends" || ng "terminal content"

printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
