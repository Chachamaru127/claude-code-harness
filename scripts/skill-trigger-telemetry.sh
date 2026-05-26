#!/usr/bin/env bash
# skill-trigger-telemetry.sh
# Phase 62.2.3: skill_activated.invocation_trigger を local ledger に記録
#
# Input:  stdin JSON (Claude Code 2.1.126+ skill_activated OTel event)
#   {
#     "skill_name": "harness-work",
#     "invocation_trigger": "human|model|skill-chain",
#     "session_id": "session-abc123",
#     "duration_ms": 1234     // optional
#   }
# Output: stdout は no-op (silent)
# Side effect: .claude/state/skill-trigger-stats.jsonl に append-only 記録
#
# Privacy / retention / opt-out: docs/skill-telemetry-policy.md を参照

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"
LEDGER="${STATE_DIR}/skill-trigger-stats.jsonl"

# opt-out: disable via environment variable
if [ "${HARNESS_SKILL_TELEMETRY_DISABLE:-0}" = "1" ]; then
  exit 0
fi

mkdir -p "${STATE_DIR}"

INPUT="$(cat)"

if [ -z "${INPUT}" ]; then
  exit 0
fi

# Parse fields. silent skip if input is malformed.
SKILL_NAME="$(printf '%s' "${INPUT}" | jq -r '.skill_name // ""' 2>/dev/null || echo "")"
TRIGGER="$(printf '%s' "${INPUT}" | jq -r '.invocation_trigger // ""' 2>/dev/null || echo "")"
SESSION_ID_RAW="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""' 2>/dev/null || echo "")"
DURATION_MS="$(printf '%s' "${INPUT}" | jq -r '.duration_ms // 0' 2>/dev/null || echo "0")"

if [ -z "${SKILL_NAME}" ] || [ -z "${TRIGGER}" ]; then
  exit 0
fi

# trigger を allowlist に絞る (privacy: 想定外の field 値を記録しない)
case "${TRIGGER}" in
  human|model|skill-chain) ;;
  *)
    # Record unexpected triggers as "other" (value is fixed to maintain ledger consistency)
    TRIGGER="other"
    ;;
esac

# Truncate session_id to 12-character prefix (privacy minimization)
SESSION_ID="${SESSION_ID_RAW:0:12}"

# skill exclude list (read from settings.local.json)
SETTINGS_LOCAL="${PROJECT_ROOT}/.claude/settings.local.json"
if [ -f "${SETTINGS_LOCAL}" ]; then
  EXCLUDED="$(jq -r --arg s "${SKILL_NAME}" '.harness.skill_telemetry_exclude // [] | map(select(. == $s)) | length' "${SETTINGS_LOCAL}" 2>/dev/null || echo "0")"
  if [ "${EXCLUDED}" != "0" ]; then
    exit 0
  fi
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

RECORD="$(jq -nc \
  --arg timestamp "${TIMESTAMP}" \
  --arg skill_name "${SKILL_NAME}" \
  --arg trigger "${TRIGGER}" \
  --arg session_id "${SESSION_ID}" \
  --argjson duration_ms "${DURATION_MS}" \
  '{timestamp:$timestamp, skill_name:$skill_name, invocation_trigger:$trigger, session_id:$session_id, duration_ms:$duration_ms}')"

printf '%s\n' "${RECORD}" >> "${LEDGER}"
