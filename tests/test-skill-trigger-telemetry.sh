#!/usr/bin/env bash
# test-skill-trigger-telemetry.sh
# Phase 62.2.3: skill_activated.invocation_trigger telemetry test
#
# Validation points:
#   (1) 3 trigger types (human / model / skill-chain) are recorded distinctly
#   (2) opt-out (HARNESS_SKILL_TELEMETRY_DISABLE=1) prevents writes
#   (3) skill_telemetry_exclude excludes individual skills
#   (4) ledger is append-only (no deletion / overwrite)
#   (5) session_id is truncated to a 12-character prefix (privacy)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDLER="${ROOT_DIR}/scripts/skill-trigger-telemetry.sh"

[ -x "${HANDLER}" ] || chmod +x "${HANDLER}"
[ -x "${HANDLER}" ] || {
  echo "FAIL: ${HANDLER} is not executable"
  exit 1
}

# Test in temp project root for isolation
TEST_PROJECT="$(mktemp -d)"
trap 'rm -rf "${TEST_PROJECT}"' EXIT
mkdir -p "${TEST_PROJECT}/.claude/state"
LEDGER="${TEST_PROJECT}/.claude/state/skill-trigger-stats.jsonl"

# (1) Submit 3 triggers in sequence
for trigger in human model skill-chain; do
  INPUT="$(jq -nc --arg t "${trigger}" \
    '{skill_name: "harness-work", invocation_trigger: $t, session_id: "session-abcdefghijkl-rest", duration_ms: 100}')"
  printf '%s' "${INPUT}" | env CLAUDE_PROJECT_DIR="${TEST_PROJECT}" "${HANDLER}"
done

[ -f "${LEDGER}" ] || {
  echo "FAIL (1): ledger not created"
  exit 1
}

LINE_COUNT="$(wc -l < "${LEDGER}" | tr -d ' ')"
if [ "${LINE_COUNT}" -ne 3 ]; then
  echo "FAIL (1): expected 3 records, got ${LINE_COUNT}"
  cat "${LEDGER}"
  exit 1
fi

for trigger in human model skill-chain; do
  if ! grep -q "\"invocation_trigger\":\"${trigger}\"" "${LEDGER}"; then
    echo "FAIL (1): trigger ${trigger} not found in ledger"
    exit 1
  fi
done

# (2) opt-out prevents writes
INPUT='{"skill_name":"harness-work","invocation_trigger":"human","session_id":"session-x"}'
printf '%s' "${INPUT}" | env CLAUDE_PROJECT_DIR="${TEST_PROJECT}" HARNESS_SKILL_TELEMETRY_DISABLE=1 "${HANDLER}"
NEW_LINE_COUNT="$(wc -l < "${LEDGER}" | tr -d ' ')"
if [ "${NEW_LINE_COUNT}" -ne 3 ]; then
  echo "FAIL (2): opt-out should not write; got ${NEW_LINE_COUNT} (expected 3)"
  exit 1
fi

# (3) skill_telemetry_exclude excludes individual skills
cat > "${TEST_PROJECT}/.claude/settings.local.json" <<'EOF'
{
  "harness": {
    "skill_telemetry_exclude": ["harness-loop"]
  }
}
EOF
INPUT='{"skill_name":"harness-loop","invocation_trigger":"human","session_id":"session-y"}'
printf '%s' "${INPUT}" | env CLAUDE_PROJECT_DIR="${TEST_PROJECT}" "${HANDLER}"
EXCL_LINE_COUNT="$(wc -l < "${LEDGER}" | tr -d ' ')"
if [ "${EXCL_LINE_COUNT}" -ne 3 ]; then
  echo "FAIL (3): excluded skill should not be recorded; got ${EXCL_LINE_COUNT} (expected 3)"
  exit 1
fi

# Clear exclusion and verify write
INPUT='{"skill_name":"harness-review","invocation_trigger":"model","session_id":"session-z"}'
printf '%s' "${INPUT}" | env CLAUDE_PROJECT_DIR="${TEST_PROJECT}" "${HANDLER}"
NEW_LINE_COUNT="$(wc -l < "${LEDGER}" | tr -d ' ')"
if [ "${NEW_LINE_COUNT}" -ne 4 ]; then
  echo "FAIL (3b): non-excluded skill should be recorded; got ${NEW_LINE_COUNT} (expected 4)"
  exit 1
fi

# (4) append-only: existing records must not change
EXISTING_FIRST_LINE="$(head -n 1 "${LEDGER}")"
INPUT='{"skill_name":"harness-plan","invocation_trigger":"human","session_id":"session-q"}'
printf '%s' "${INPUT}" | env CLAUDE_PROJECT_DIR="${TEST_PROJECT}" "${HANDLER}"
NEW_FIRST_LINE="$(head -n 1 "${LEDGER}")"
if [ "${EXISTING_FIRST_LINE}" != "${NEW_FIRST_LINE}" ]; then
  echo "FAIL (4): append-only violation; first line changed"
  echo "  before: ${EXISTING_FIRST_LINE}"
  echo "  after: ${NEW_FIRST_LINE}"
  exit 1
fi

# (5) session_id is truncated to 12-character prefix (privacy)
TRUNCATED="$(jq -r '.session_id' < <(head -n 1 "${LEDGER}"))"
if [ "${#TRUNCATED}" -ne 12 ]; then
  echo "FAIL (5): session_id should be 12 chars, got ${#TRUNCATED} (${TRUNCATED})"
  exit 1
fi

echo "PASS: test-skill-trigger-telemetry.sh (Phase 62.2.3) — all 5 checks passed"
