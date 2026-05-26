#!/usr/bin/env bash
# post-compact.sh
# PostCompact hook handler
# Fires after context compaction completes (counterpart to PreCompact)
# If WIP tasks exist, restores the state saved by PreCompact and injects it as a systemMessage
# If a structured handoff artifact is available, it takes priority for re-injecting high-signal key points
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON with optional systemMessage for context re-injection
# Hook event: PostCompact

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load path-utils.sh
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  source "${PARENT_DIR}/path-utils.sh"
fi

# Detect project root
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"

# File paths
STATE_DIR="${PROJECT_ROOT}/.claude/state"
COMPACTION_LOG="${STATE_DIR}/compaction-events.jsonl"
PLANS_FILE="${PROJECT_ROOT}/Plans.md"
HANDOFF_ARTIFACT="${STATE_DIR}/handoff-artifact.json"
PRECOMPACT_SNAPSHOT="${STATE_DIR}/precompact-snapshot.json"

# === Utility functions ===

ensure_state_dir() {
  mkdir -p "${STATE_DIR}" 2>/dev/null || true
  chmod 700 "${STATE_DIR}" 2>/dev/null || true
}

# JSONL rotation (trim to 400 lines when exceeding 500)
rotate_jsonl() {
  local file="$1"
  local _lines
  _lines="$(wc -l < "${file}" 2>/dev/null)" || _lines=0
  if [ "${_lines}" -gt 500 ] 2>/dev/null; then
    tail -400 "${file}" > "${file}.tmp" 2>/dev/null && \
      mv "${file}.tmp" "${file}" 2>/dev/null || true
  fi
}

get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Extract WIP tasks from Plans.md and generate a summary
get_wip_summary() {
  if [ ! -f "${PLANS_FILE}" ]; then
    return 0
  fi

  local wip_lines=""

  if command -v python3 >/dev/null 2>&1; then
    wip_lines="$(python3 -c "
import sys

plans_path = sys.argv[1]
try:
    with open(plans_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    wip_tasks = []
    for line in lines:
        stripped = line.strip()
        if 'cc:WIP' in stripped or 'cc:TODO' in stripped:
            wip_tasks.append(stripped)
    if wip_tasks:
        print('\\n'.join(wip_tasks[:20]))
except Exception:
    pass
" "${PLANS_FILE}" 2>/dev/null)" || wip_lines=""
  else
    # Fallback to grep if python3 is not available
    wip_lines="$(grep -E 'cc:WIP|cc:TODO' "${PLANS_FILE}" 2>/dev/null | head -20)" || wip_lines=""
  fi

  printf '%s' "${wip_lines}"
}

# Restore context from PreCompact snapshot
get_handoff_artifact_path() {
  if [ -f "${HANDOFF_ARTIFACT}" ]; then
    printf '%s' "${HANDOFF_ARTIFACT}"
    return 0
  fi

  if [ -f "${PRECOMPACT_SNAPSHOT}" ]; then
    printf '%s' "${PRECOMPACT_SNAPSHOT}"
    return 0
  fi

  return 0
}

get_structured_handoff_context() {
  local artifact_path="$1"
  if [ -z "${artifact_path}" ] || [ ! -f "${artifact_path}" ]; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${artifact_path}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding='utf-8'))
except Exception:
    sys.exit(0)

def normalize_text(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return " ".join(value.split())
    if isinstance(value, dict):
        for key in ("summary", "task", "title", "detail", "message", "reason", "status"):
            candidate = value.get(key)
            if isinstance(candidate, str) and candidate.strip():
                return " ".join(candidate.split())
        return ""
    if isinstance(value, list):
        parts = []
        for item in value:
            text = normalize_text(item)
            if text:
                parts.append(text)
            if len(parts) >= 3:
                break
        return "; ".join(parts)
    return str(value)

def format_list(items, limit=4):
    parts = []
    for item in items or []:
        text = normalize_text(item)
        if text:
            parts.append(text)
        if len(parts) >= limit:
            break
    return "; ".join(parts)

previous = data.get("previous_state") or {}
next_action = data.get("next_action") or {}
open_risks = data.get("open_risks") or []
failed_checks = data.get("failed_checks") or []
decision_log = data.get("decision_log") or []
context_reset = data.get("context_reset") or {}
continuity = data.get("continuity") or {}
wip_tasks = data.get("wipTasks") or []
recent_edits = data.get("recentEdits") or []

lines = ["## Structured Handoff"]

previous_summary = normalize_text(previous.get("summary"))
if previous_summary:
    lines.append(f"- Previous state: {previous_summary}")

session_state = previous.get("session_state") or {}
if isinstance(session_state, dict):
    session_bits = []
    for key in ("state", "review_status", "active_skill", "resumed_at"):
        candidate = session_state.get(key)
        if isinstance(candidate, str) and candidate.strip():
            session_bits.append(f"{key}={candidate.strip()}")
    if session_bits:
        lines.append(f"- Session state: {', '.join(session_bits)}")

plan_counts = previous.get("plan_counts") or {}
if isinstance(plan_counts, dict):
    count_bits = []
    for key in ("total", "wip", "blocked", "recent_edits"):
        candidate = plan_counts.get(key)
        if isinstance(candidate, (int, float)) and int(candidate) > 0:
            count_bits.append(f"{key}={int(candidate)}")
    if count_bits:
        lines.append(f"- Plan counts: {', '.join(count_bits)}")

next_bits = []
next_summary = normalize_text(next_action.get("summary"))
if next_summary:
    next_bits.append(next_summary)
task_id = normalize_text(next_action.get("taskId"))
task = normalize_text(next_action.get("task"))
if task_id or task:
    next_bits.append(" ".join(part for part in [task_id, task] if part).strip())
depends = normalize_text(next_action.get("depends"))
dod = normalize_text(next_action.get("dod"))
if depends:
    next_bits.append(f"depends={depends}")
if dod:
    next_bits.append(f"DoD={dod}")
if next_bits:
    lines.append(f"- Next action: {' | '.join(next_bits)}")

if open_risks:
    lines.append(f"- Open risks: {format_list(open_risks)}")
if failed_checks:
    lines.append(f"- Failed checks: {format_list(failed_checks)}")
if decision_log:
    lines.append(f"- Decision log: {format_list(decision_log, 2)}")
context_reset_summary = normalize_text(context_reset.get("summary"))
if context_reset_summary:
    lines.append(f"- Context reset: {context_reset_summary}")
continuity_summary = normalize_text(continuity.get("summary"))
if continuity_summary:
    lines.append(f"- Continuity: {continuity_summary}")
if wip_tasks:
    lines.append(f"- WIP tasks: {format_list(wip_tasks, 5)}")
if recent_edits:
    lines.append(f"- Recent edits: {format_list(recent_edits, 5)}")

print("\n".join(lines))
PY
    return 0
  fi

  return 0
}

get_precompact_context() {
  if [ ! -f "${PRECOMPACT_SNAPSHOT}" ]; then
    return 0
  fi

  local context=""

  if command -v jq >/dev/null 2>&1; then
    local wip_tasks=""
    local recent_edits=""
    wip_tasks="$(jq -r '.wipTasks // [] | join(", ")' "${PRECOMPACT_SNAPSHOT}" 2>/dev/null)" || wip_tasks=""
    recent_edits="$(jq -r '.recentEdits // [] | .[0:10] | join(", ")' "${PRECOMPACT_SNAPSHOT}" 2>/dev/null)" || recent_edits=""

    if [ -n "${wip_tasks}" ]; then
      context="Pre-compaction WIP tasks: ${wip_tasks}"
    fi
    if [ -n "${recent_edits}" ]; then
      if [ -n "${context}" ]; then
        context="${context}. Recent edits: ${recent_edits}"
      else
        context="Recent edits: ${recent_edits}"
      fi
    fi
  elif command -v python3 >/dev/null 2>&1; then
    context="$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    parts = []
    wip = d.get('wipTasks', [])
    if wip:
        parts.append('Pre-compaction WIP tasks: ' + ', '.join(wip))
    edits = d.get('recentEdits', [])[:10]
    if edits:
        parts.append('Recent edits: ' + ', '.join(edits))
    print('. '.join(parts))
except Exception:
    pass
" "${PRECOMPACT_SNAPSHOT}" 2>/dev/null)" || context=""
  fi

  printf '%s' "${context}"
}

# === Read JSON payload from stdin ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# Skip if payload is empty
if [ -z "${INPUT}" ]; then
  echo '{"decision":"approve","reason":"PostCompact: no payload"}'
  exit 0
fi

# === Context re-injection after compaction ===
ensure_state_dir
TS="$(get_timestamp)"

# Get WIP task summary
WIP_SUMMARY="$(get_wip_summary)"

# Restore, prioritizing the structured handoff artifact
HANDOFF_ARTIFACT_PATH="$(get_handoff_artifact_path)"
STRUCTURED_HANDOFF_CONTEXT="$(get_structured_handoff_context "${HANDOFF_ARTIFACT_PATH}")"

# Lightweight snapshot restore for compatibility
PRECOMPACT_CONTEXT="$(get_precompact_context)"

# === Event logging ===
log_entry=""
if command -v jq >/dev/null 2>&1; then
  log_entry="$(jq -nc \
    --arg event "post_compact" \
    --arg has_wip "$([ -n "${WIP_SUMMARY}" ] && echo "true" || echo "false")" \
    --arg has_snapshot "$([ -f "${PRECOMPACT_SNAPSHOT}" ] && echo "true" || echo "false")" \
    --arg has_handoff "$([ -f "${HANDOFF_ARTIFACT}" ] && echo "true" || echo "false")" \
    --arg timestamp "${TS}" \
    '{event:$event, has_wip:$has_wip, has_snapshot:$has_snapshot, has_handoff:$has_handoff, timestamp:$timestamp}')"
elif command -v python3 >/dev/null 2>&1; then
  log_entry="$(python3 -c "
import json, sys
print(json.dumps({
    'event': 'post_compact',
    'has_wip': sys.argv[1],
    'has_snapshot': sys.argv[2],
    'has_handoff': sys.argv[3],
    'timestamp': sys.argv[4]
}, ensure_ascii=False))
" "$([ -n "${WIP_SUMMARY}" ] && echo "true" || echo "false")" "$([ -f "${PRECOMPACT_SNAPSHOT}" ] && echo "true" || echo "false")" "$([ -f "${HANDOFF_ARTIFACT}" ] && echo "true" || echo "false")" "${TS}" 2>/dev/null)" || log_entry=""
fi

if [ -n "${log_entry}" ]; then
  echo "${log_entry}" >> "${COMPACTION_LOG}" 2>/dev/null || true
  rotate_jsonl "${COMPACTION_LOG}"
fi

# === Response generation ===

# Build systemMessage
# Restore WIP info saved by PreCompact so the model can track task state even after compaction
SYSTEM_MESSAGE=""

if [ -z "${STRUCTURED_HANDOFF_CONTEXT}" ] && [ -n "${WIP_SUMMARY}" ]; then
  SYSTEM_MESSAGE="[PostCompact Re-injection] Context was just compacted. The following WIP/TODO tasks are active in Plans.md:
${WIP_SUMMARY}"
fi

if [ -n "${STRUCTURED_HANDOFF_CONTEXT}" ]; then
  if [ -n "${SYSTEM_MESSAGE}" ]; then
    SYSTEM_MESSAGE="${SYSTEM_MESSAGE}

${STRUCTURED_HANDOFF_CONTEXT}"
  else
    SYSTEM_MESSAGE="[PostCompact Re-injection] Context was just compacted.
${STRUCTURED_HANDOFF_CONTEXT}"
  fi
fi

if [ -z "${STRUCTURED_HANDOFF_CONTEXT}" ] && [ -n "${PRECOMPACT_CONTEXT}" ]; then
  if [ -n "${SYSTEM_MESSAGE}" ]; then
    SYSTEM_MESSAGE="${SYSTEM_MESSAGE}

${PRECOMPACT_CONTEXT}"
  else
    SYSTEM_MESSAGE="[PostCompact Re-injection] Context was just compacted. ${PRECOMPACT_CONTEXT}"
  fi
fi

# Include additionalContext in the response when present (existing tests/consumers read .additionalContext)
if [ -n "${SYSTEM_MESSAGE}" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg reason "PostCompact: WIP context re-injected via additionalContext" \
      --arg ctx "${SYSTEM_MESSAGE}" \
      '{"decision":"approve","reason":$reason,"additionalContext":$ctx}'
  else
    # Fallback when jq is not available
    _escaped_msg="${SYSTEM_MESSAGE//\\/\\\\}"
    _escaped_msg="${_escaped_msg//\"/\\\"}"
    _escaped_msg="${_escaped_msg//$'\n'/\\n}"
    printf '{"decision":"approve","reason":"PostCompact: WIP context re-injected via additionalContext","additionalContext":"%s"}\n' "${_escaped_msg}"
  fi
else
  echo '{"decision":"approve","reason":"PostCompact: no WIP tasks to re-inject"}'
fi

exit 0
