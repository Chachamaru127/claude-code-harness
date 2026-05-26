#!/bin/bash
# breezing-signal-injector.sh
# Reads unconsumed signals from breezing-signals.jsonl in the UserPromptSubmit hook
# and injects them as a systemMessage.
#
# Usage: called automatically (UserPromptSubmit hook)
# Input: stdin JSON from Claude Code hooks (UserPromptSubmit)
# Output: JSON with optional systemMessage

set +e  # Do not stop on errors

# === Detect project root ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh" 2>/dev/null || true
fi
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${PARENT_DIR}/.." && pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"

# === Check whether a breezing session exists ===
ACTIVE_FILE="${STATE_DIR}/breezing-active.json"
if [ ! -f "${ACTIVE_FILE}" ]; then
  # Skip when outside a breezing session
  exit 0
fi

# === Check whether the signals file exists ===
SIGNALS_FILE="${STATE_DIR}/breezing-signals.jsonl"
if [ ! -f "${SIGNALS_FILE}" ]; then
  exit 0
fi

# === Read unconsumed signals ===
# Lines where consumed_at is null or absent are treated as unconsumed
UNCONSUMED_SIGNALS=""
if command -v jq >/dev/null 2>&1; then
  # jq で consumed_at が null のシグナルを抽出
  UNCONSUMED_SIGNALS="$(grep -v '^$' "${SIGNALS_FILE}" 2>/dev/null | \
    while IFS= read -r line; do
      consumed="$(printf '%s' "${line}" | jq -r '.consumed_at // "null"' 2>/dev/null)"
      if [ "${consumed}" = "null" ]; then
        printf '%s\n' "${line}"
      fi
    done)" || UNCONSUMED_SIGNALS=""
elif command -v python3 >/dev/null 2>&1; then
  UNCONSUMED_SIGNALS="$(python3 -c "
import json, sys
lines = []
try:
    with open('${SIGNALS_FILE}', 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if d.get('consumed_at') is None:
                    lines.append(line)
            except:
                pass
print('\n'.join(lines))
" 2>/dev/null)" || UNCONSUMED_SIGNALS=""
fi

if [ -z "${UNCONSUMED_SIGNALS}" ]; then
  # No unconsumed signals
  exit 0
fi

# === Format signals into message form ===
SYSTEM_MESSAGE=""
SIGNAL_COUNT=0

while IFS= read -r signal_line; do
  [ -z "${signal_line}" ] && continue

  SIGNAL_COUNT=$((SIGNAL_COUNT + 1))
  signal_type=""
  signal_ts=""

  if command -v jq >/dev/null 2>&1; then
    signal_type="$(printf '%s' "${signal_line}" | jq -r '.signal // .type // "unknown"' 2>/dev/null)" || signal_type="unknown"
    signal_ts="$(printf '%s' "${signal_line}" | jq -r '.timestamp // ""' 2>/dev/null)" || signal_ts=""
  fi

  case "${signal_type}" in
    ci_failure_detected)
      conclusion=""
      trigger_cmd=""
      if command -v jq >/dev/null 2>&1; then
        conclusion="$(printf '%s' "${signal_line}" | jq -r '.conclusion // "unknown"' 2>/dev/null)"
        trigger_cmd="$(printf '%s' "${signal_line}" | jq -r '.trigger_command // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:ci_failure_detected] CI failed (${conclusion}). Trigger: ${trigger_cmd}. Consider using the ci-cd-fixer agent for automatic repair.\n"
      ;;
    retake_requested)
      reason=""
      task_id=""
      if command -v jq >/dev/null 2>&1; then
        reason="$(printf '%s' "${signal_line}" | jq -r '.reason // ""' 2>/dev/null)"
        task_id="$(printf '%s' "${signal_line}" | jq -r '.task_id // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:retake_requested] Redo requested for task #${task_id}. Reason: ${reason}\n"
      ;;
    reviewer_approved)
      task_id=""
      if command -v jq >/dev/null 2>&1; then
        task_id="$(printf '%s' "${signal_line}" | jq -r '.task_id // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:reviewer_approved] Task #${task_id} has been approved by the reviewer.\n"
      ;;
    escalation_required)
      reason=""
      task_id=""
      if command -v jq >/dev/null 2>&1; then
        reason="$(printf '%s' "${signal_line}" | jq -r '.reason // ""' 2>/dev/null)"
        task_id="$(printf '%s' "${signal_line}" | jq -r '.task_id // ""' 2>/dev/null)"
      fi
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:escalation_required] Escalation required for task #${task_id}. Reason: ${reason}\n"
      ;;
    *)
      # Forward unknown signals as-is
      SYSTEM_MESSAGE="${SYSTEM_MESSAGE}[SIGNAL:${signal_type}] ${signal_line}\n"
      ;;
  esac
done <<< "${UNCONSUMED_SIGNALS}"

if [ -z "${SYSTEM_MESSAGE}" ] || [ "${SIGNAL_COUNT}" -eq 0 ]; then
  exit 0
fi

# === Mark signals as consumed by setting consumed_at ===
# Atomic update: overwrite by writing consumed_at to a new file
CONSUMED_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LOCK_DIR="${STATE_DIR}/.breezing-signals.lock"

_lock_acquired=0
for _i in $(seq 1 20); do
  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    _lock_acquired=1
    break
  fi
  sleep 0.1
done

if [ "${_lock_acquired}" -eq 1 ]; then
  TMP_NEW_SIGNALS="$(mktemp /tmp/breezing-signals-new.XXXXXX)"

  if command -v jq >/dev/null 2>&1; then
    # Rewrite all signals with consumed_at attached
    while IFS= read -r line; do
      [ -z "${line}" ] && continue
      consumed="$(printf '%s' "${line}" | jq -r '.consumed_at // "null"' 2>/dev/null)"
      if [ "${consumed}" = "null" ]; then
        printf '%s' "${line}" | jq -c --arg ts "${CONSUMED_TS}" '. + {consumed_at: $ts}' 2>/dev/null >> "${TMP_NEW_SIGNALS}" || printf '%s\n' "${line}" >> "${TMP_NEW_SIGNALS}"
      else
        printf '%s\n' "${line}" >> "${TMP_NEW_SIGNALS}"
      fi
    done < "${SIGNALS_FILE}"

    mv "${TMP_NEW_SIGNALS}" "${SIGNALS_FILE}" 2>/dev/null || rm -f "${TMP_NEW_SIGNALS}"
  else
    rm -f "${TMP_NEW_SIGNALS}"
  fi

  rmdir "${LOCK_DIR}" 2>/dev/null || true
fi

# === Output as systemMessage ===
HEADER="[breezing-signal-injector] ${SIGNAL_COUNT} unconsumed signal(s):\n"
FULL_MESSAGE="${HEADER}${SYSTEM_MESSAGE}"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg msg "${FULL_MESSAGE}" '{"systemMessage": $msg}'
else
  # Simple escape when jq is not available
  _escaped="${FULL_MESSAGE//\\/\\\\}"
  _escaped="${_escaped//\"/\\\"}"
  printf '{"systemMessage":"%s"}\n' "${_escaped}"
fi

exit 0
