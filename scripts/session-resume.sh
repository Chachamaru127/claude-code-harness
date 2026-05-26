#!/bin/bash
# session-resume.sh
# SessionStart Hook (resume): Automatic restoration of Harness session state
#
# Called automatically when the Claude Code /resume command is executed;
# restores Harness session state (session.json, session.events.jsonl).
#
# Input: JSON from stdin (containing session_id, source, etc.)
# Output: Information written to hookSpecificOutput.additionalContext in JSON format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_SNAPSHOT_LIB="${SCRIPT_DIR}/lib/progress-snapshot.sh"
if [ -f "${PROGRESS_SNAPSHOT_LIB}" ]; then
  # shellcheck source=/dev/null
  source "${PROGRESS_SNAPSHOT_LIB}"
fi

# ===== Banner display =====
VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
echo -e "\033[0;36m[claude-code-harness v${VERSION}]\033[0m Session resumed" >&2

# ===== Read JSON input from stdin =====
INPUT=""
if [ -t 0 ]; then
  :
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== Get Claude Code session_id =====
CC_SESSION_ID=""
if [ -n "$INPUT" ] && command -v jq >/dev/null 2>&1; then
  CC_SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
fi

# ===== Harness state directory (unified relative to repo root) =====
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
STATE_DIR="${REPO_ROOT}/.claude/state"
SESSION_FILE="$STATE_DIR/session.json"
EVENT_LOG_FILE="$STATE_DIR/session.events.jsonl"
ARCHIVE_DIR="$STATE_DIR/sessions"
SESSION_MAP_FILE="$STATE_DIR/session-map.json"
PROJECT_ROOT="${PROJECT_ROOT:-$REPO_ROOT}"
CONFIG_FILE="${CONFIG_FILE:-${REPO_ROOT}/.claude-code-harness.config.yaml}"
PLANS_PATH="${REPO_ROOT}/Plans.md"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  # shellcheck source=./config-utils.sh
  source "${SCRIPT_DIR}/config-utils.sh"
  resolved_plans_path="$(get_plans_file_path 2>/dev/null || printf 'Plans.md')"
  case "$resolved_plans_path" in
    /*) PLANS_PATH="$resolved_plans_path" ;;
    *) PLANS_PATH="${REPO_ROOT}/${resolved_plans_path}" ;;
  esac
fi

mkdir -p "$STATE_DIR" "$ARCHIVE_DIR"

RESUME_CONTEXT_FILE="${STATE_DIR}/memory-resume-context.md"
RESUME_PENDING_FLAG="${STATE_DIR}/.memory-resume-pending"
RESUME_PROCESSING_FLAG="${STATE_DIR}/.memory-resume-processing"
RESUME_MAX_BYTES="${HARNESS_MEM_RESUME_MAX_BYTES:-32768}"
HANDOFF_ARTIFACT_FILE="${STATE_DIR}/handoff-artifact.json"
LEGACY_PRECOMPACT_SNAPSHOT_FILE="${STATE_DIR}/precompact-snapshot.json"

case "$RESUME_MAX_BYTES" in
  ''|*[!0-9]*) RESUME_MAX_BYTES=32768 ;;
esac
if [ "$RESUME_MAX_BYTES" -gt 65536 ]; then
  RESUME_MAX_BYTES=65536
fi
if [ "$RESUME_MAX_BYTES" -lt 4096 ]; then
  RESUME_MAX_BYTES=4096
fi

# ===== Accumulate output messages =====
OUTPUT=""
add_line() {
  OUTPUT="${OUTPUT}$1\n"
}

count_task_matches() {
  local pattern="$1"
  local file="$2"

  awk -v pattern="$pattern" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function is_task_line(line, fields, first_cell) {
      if (line ~ /^[[:space:]]*[-*+][[:space:]]+\[[ xX]\]/) {
        return 1
      }
      if (line !~ /^[[:space:]]*\|/) {
        return 0
      }
      split(line, fields, /\|/)
      first_cell = trim(fields[2])
      gsub(/`/, "", first_cell)
      if (first_cell == "" || first_cell == "Task" || first_cell ~ /^[-]+$/) {
        return 0
      }
      if (first_cell ~ /^(pm|cc|cursor):/) {
        return 0
      }
      return 1
    }
    is_task_line($0) && $0 ~ pattern { count++ }
    END { print count + 0 }
  ' "$file" 2>/dev/null || printf '0\n'
}

consume_memory_resume_context() {
  local file="$1"
  local max_bytes="$2"
  local total=0
  local line=""
  local line_bytes=0
  local out=""

  if [ ! -f "$file" ]; then
    return 0
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line_bytes="$(printf '%s\n' "$line" | wc -c | tr -d '[:space:]')"
    case "$line_bytes" in
      ''|*[!0-9]*) line_bytes=0 ;;
    esac
    if [ $((total + line_bytes)) -gt "$max_bytes" ]; then
      break
    fi
    out="${out}${line}
"
    total=$((total + line_bytes))
  done < "$file"

  rm -f "$RESUME_PENDING_FLAG" "$RESUME_PROCESSING_FLAG" "$RESUME_CONTEXT_FILE" 2>/dev/null || true
  printf '%s' "$out"
}

get_handoff_artifact_path() {
  if [ -f "$HANDOFF_ARTIFACT_FILE" ]; then
    printf '%s' "$HANDOFF_ARTIFACT_FILE"
    return 0
  fi

  if [ -f "$LEGACY_PRECOMPACT_SNAPSHOT_FILE" ]; then
    printf '%s' "$LEGACY_PRECOMPACT_SNAPSHOT_FILE"
    return 0
  fi

  return 0
}

render_handoff_context() {
  local artifact_path="$1"
  if [ -z "$artifact_path" ] || [ ! -f "$artifact_path" ]; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$artifact_path" <<'PY'
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

sync_handoff_session_metadata() {
  local artifact_path="$1"
  local session_file="$2"
  [ -n "$artifact_path" ] || return 0
  [ -f "$artifact_path" ] || return 0
  [ -n "$session_file" ] || return 0
  [ -f "$session_file" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local context_reset_summary
  local context_reset_recommended
  local continuity_summary
  local continuity_effort
  local continuity_plugin_first
  local continuity_resume_aware
  local tmp_file

  context_reset_summary="$(jq -r '.context_reset.summary // empty' "$artifact_path" 2>/dev/null || true)"
  context_reset_recommended="$(jq -r '.context_reset.recommended // false' "$artifact_path" 2>/dev/null || echo false)"
  continuity_summary="$(jq -r '.continuity.summary // empty' "$artifact_path" 2>/dev/null || true)"
  continuity_effort="$(jq -r '.continuity.effort_hint // empty' "$artifact_path" 2>/dev/null || true)"
  continuity_plugin_first="$(jq -r '.continuity.plugin_first_workflow // false' "$artifact_path" 2>/dev/null || echo false)"
  continuity_resume_aware="$(jq -r '.continuity.resume_aware_effort_continuity // false' "$artifact_path" 2>/dev/null || echo false)"

  tmp_file="$(mktemp)"
  jq \
    --arg artifact_path "$artifact_path" \
    --arg context_reset_summary "$context_reset_summary" \
    --arg continuity_summary "$continuity_summary" \
    --arg continuity_effort "$continuity_effort" \
    --argjson context_reset_recommended "$context_reset_recommended" \
    --argjson continuity_plugin_first "$continuity_plugin_first" \
    --argjson continuity_resume_aware "$continuity_resume_aware" \
    '
    .harness = (.harness // {}) |
    .harness.last_handoff_artifact = $artifact_path |
    .harness.context_reset = {
      summary: $context_reset_summary,
      recommended: $context_reset_recommended
    } |
    .harness.continuity = {
      summary: $continuity_summary,
      effort_hint: $continuity_effort,
      plugin_first_workflow: $continuity_plugin_first,
      resume_aware_effort_continuity: $continuity_resume_aware
    }
    ' "$session_file" > "$tmp_file" && mv "$tmp_file" "$session_file"
}

# ===== Session restore logic =====
RESTORED="false"
RESTORED_SESSION_ID=""
RESTORE_METHOD=""

# Method 1: Look up via session mapping
if [ -n "$CC_SESSION_ID" ] && [ -f "$SESSION_MAP_FILE" ] && command -v jq >/dev/null 2>&1; then
  HARNESS_SESSION_ID="$(jq -r --arg cc_id "$CC_SESSION_ID" '.[$cc_id] // empty' "$SESSION_MAP_FILE" 2>/dev/null)"

  if [ -n "$HARNESS_SESSION_ID" ]; then
    ARCHIVE_SESSION="$ARCHIVE_DIR/${HARNESS_SESSION_ID}.json"
    ARCHIVE_EVENTS="$ARCHIVE_DIR/${HARNESS_SESSION_ID}.events.jsonl"

    if [ -f "$ARCHIVE_SESSION" ]; then
      cp "$ARCHIVE_SESSION" "$SESSION_FILE"
      [ -f "$ARCHIVE_EVENTS" ] && cp "$ARCHIVE_EVENTS" "$EVENT_LOG_FILE"

      # Update state to initialized and record a resume event
      NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      if command -v jq >/dev/null 2>&1; then
        tmp_file=$(mktemp)
        jq --arg state "initialized" \
           --arg resumed_at "$NOW" \
           '.state = $state | .resumed_at = $resumed_at' \
           "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"
      fi

      # Record resume event
      echo "{\"type\":\"session.resume\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\",\"method\":\"mapping\"}}" >> "$EVENT_LOG_FILE"

      RESTORED="true"
      RESTORED_SESSION_ID="$HARNESS_SESSION_ID"
      RESTORE_METHOD="mapping"
    fi
  fi
fi

# Method 2: Automatically restore the latest stopped session (when no mapping exists)
if [ "$RESTORED" = "false" ]; then
  LATEST_ARCHIVE=$(ls -t "$ARCHIVE_DIR"/*.json 2>/dev/null | head -n 1 || true)

  if [ -n "$LATEST_ARCHIVE" ] && [ -f "$LATEST_ARCHIVE" ]; then
    HARNESS_SESSION_ID=$(basename "$LATEST_ARCHIVE" .json)
    ARCHIVE_EVENTS="$ARCHIVE_DIR/${HARNESS_SESSION_ID}.events.jsonl"

    cp "$LATEST_ARCHIVE" "$SESSION_FILE"
    [ -f "$ARCHIVE_EVENTS" ] && cp "$ARCHIVE_EVENTS" "$EVENT_LOG_FILE"

    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if command -v jq >/dev/null 2>&1; then
      tmp_file=$(mktemp)
      jq --arg state "initialized" \
         --arg resumed_at "$NOW" \
         '.state = $state | .resumed_at = $resumed_at' \
         "$SESSION_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_FILE"
    fi

    echo "{\"type\":\"session.resume\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\",\"method\":\"latest\"}}" >> "$EVENT_LOG_FILE"

    RESTORED="true"
    RESTORED_SESSION_ID="$HARNESS_SESSION_ID"
    RESTORE_METHOD="latest"
  fi
fi

# Method 3: Initialize a new session when there is nothing to restore
if [ "$RESTORED" = "false" ]; then
  # Perform initialization equivalent to session-init.sh
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  NEW_SESSION_ID="session-$(date +%s)"

  cat > "$SESSION_FILE" <<EOF
{
  "session_id": "$NEW_SESSION_ID",
  "parent_session_id": null,
  "state": "initialized",
  "started_at": "$NOW",
  "updated_at": "$NOW",
  "resumed_at": "$NOW",
  "event_seq": 0,
  "last_event_id": ""
}
EOF

  echo "{\"type\":\"session.start\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\",\"note\":\"no_archive_found\"}}" > "$EVENT_LOG_FILE"

  RESTORED_SESSION_ID="$NEW_SESSION_ID"
  RESTORE_METHOD="new"
fi

# ===== Save mapping with Claude Code session_id =====
if [ -n "$CC_SESSION_ID" ] && [ -n "$RESTORED_SESSION_ID" ]; then
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$SESSION_MAP_FILE" ]; then
      tmp_file=$(mktemp)
      jq --arg cc_id "$CC_SESSION_ID" --arg harness_id "$RESTORED_SESSION_ID" \
         '.[$cc_id] = $harness_id' "$SESSION_MAP_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_MAP_FILE"
    else
      echo "{\"$CC_SESSION_ID\":\"$RESTORED_SESSION_ID\"}" > "$SESSION_MAP_FILE"
    fi
  fi
fi

# ===== Register for inter-session communication =====
# Register self in active.json (so other sessions can recognize this session)
if [ -f "$SCRIPT_DIR/session-register.sh" ]; then
  bash "$SCRIPT_DIR/session-register.sh" "$RESTORED_SESSION_ID" 2>/dev/null || true
fi

# ===== Skills Gate initialization (same as session-init.sh) =====
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

# ===== Clear SSOT sync flag (on new session / restored session start) =====
# This flag is created when /sync-ssot-from-memory runs,
# and is used to confirm SSOT sync before Plans.md cleanup
rm -f "${STATE_DIR}/.ssot-synced-this-session" 2>/dev/null || true

# Clear ultrawork warning flag (on session restore)
# This flag is used by userprompt-inject-policy.sh to warn only once.
# Clearing it on restore ensures the warning is shown again on the first prompt after restore.
# Backward compatibility: clear both flag names
rm -f "${STATE_DIR}/.work-review-warned" 2>/dev/null || true
rm -f "${STATE_DIR}/.ultrawork-review-warned" 2>/dev/null || true

# ===== Plans.md check =====
PLANS_INFO=""
if [ -f "$PLANS_PATH" ]; then
  wip_count="$(count_task_matches "(cc:(wip|WIP)|pm:(requested|依頼中)|cursor:依頼中)" "$PLANS_PATH")"
  todo_count="$(count_task_matches "cc:(todo|TODO)" "$PLANS_PATH")"
  PLANS_INFO="📄 Plans.md: in-progress ${wip_count} / not-started ${todo_count}"
else
  PLANS_INFO="📄 Plans.md: not found"
fi

SNAPSHOT_INFO=""
if declare -F progress_snapshot_summary >/dev/null 2>&1; then
  SNAPSHOT_INFO="$(progress_snapshot_summary "${STATE_DIR}" 2>/dev/null || true)"
fi

# ===== Detect active_skill (check whether skill restart is needed) =====
ACTIVE_SKILL_INFO=""
if [ -f "$SESSION_FILE" ] && command -v jq >/dev/null 2>&1; then
  ACTIVE_SKILL=$(jq -r '.active_skill // empty' "$SESSION_FILE" 2>/dev/null)
  ACTIVE_SKILL_STARTED=$(jq -r '.active_skill_started_at // "unknown"' "$SESSION_FILE" 2>/dev/null)

  if [ -n "$ACTIVE_SKILL" ]; then
    ACTIVE_SKILL_INFO="
## ⚠️ MANDATORY: ${ACTIVE_SKILL} Session Recovery

**\`/${ACTIVE_SKILL}\` was running in the previous session (started: ${ACTIVE_SKILL_STARTED})**

**Required actions:**
1. Restart the skill with \`/${ACTIVE_SKILL} continue\`
2. Do not start implementation directly without restarting the skill
3. The review_status guard will not function without skill context

If the skill is not restarted:
- Review enforcement will not work
- Learnings from previous failures will not be carried over
- Completion checks will be incomplete
"
  fi
fi

# ===== Detect work mode and re-inject mandatory harness-review =====
WORK_INFO=""
WORK_FILE="${STATE_DIR}/work-active.json"
# Backward compatibility: fall back to ultrawork-active.json if work-active.json is absent
if [ ! -f "$WORK_FILE" ]; then
  WORK_FILE="${STATE_DIR}/ultrawork-active.json"
fi
if [ -f "$WORK_FILE" ] && command -v jq >/dev/null 2>&1; then
  REVIEW_STATUS=$(jq -r '.review_status // "pending"' "$WORK_FILE" 2>/dev/null)
  STARTED_AT=$(jq -r '.started_at // "unknown"' "$WORK_FILE" 2>/dev/null)

  case "$REVIEW_STATUS" in
    "passed")
      WORK_INFO="⚡ **work mode active** (started: ${STARTED_AT})\n   ✅ review_status: passed → ready for completion"
      ;;
    "failed")
      WORK_INFO="⚡ **work mode active** (started: ${STARTED_AT})\n   ❌ review_status: failed → fix and re-run /harness-review"
      ;;
    *)
      WORK_INFO="⚡ **work mode active** (started: ${STARTED_AT})\n   ⚠️ review_status: pending → **obtain APPROVE from /harness-review before completing**"
      ;;
  esac
fi

# ===== Build output message =====
add_line "# [claude-code-harness] Session restored"
add_line ""

case "$RESTORE_METHOD" in
  "mapping")
    add_line "✅ Session state restored (found via mapping)"
    add_line "   Harness Session: ${RESTORED_SESSION_ID}"
    ;;
  "latest")
    add_line "✅ Latest session state restored"
    add_line "   Harness Session: ${RESTORED_SESSION_ID}"
    ;;
  "new")
    add_line "ℹ️ No session to restore — initialized a new session"
    add_line "   Harness Session: ${RESTORED_SESSION_ID}"
    ;;
esac

add_line ""

MEMORY_CONTEXT=""
if [ -f "$RESUME_PENDING_FLAG" ] || [ -f "$RESUME_CONTEXT_FILE" ]; then
  MEMORY_CONTEXT="$(consume_memory_resume_context "$RESUME_CONTEXT_FILE" "$RESUME_MAX_BYTES")"
fi

if [ -n "$MEMORY_CONTEXT" ]; then
  OUTPUT="${OUTPUT}${MEMORY_CONTEXT}"
  case "$MEMORY_CONTEXT" in
    *$'\n') ;;
    *) OUTPUT="${OUTPUT}\n" ;;
  esac
  add_line ""
fi

HANDOFF_CONTEXT=""
HANDOFF_ARTIFACT_PATH="$(get_handoff_artifact_path)"
if [ -n "$HANDOFF_ARTIFACT_PATH" ] && [ -f "$HANDOFF_ARTIFACT_PATH" ]; then
  # Reject stale handoff: ignore artifacts older than 24 hours (same policy as session-init.sh)
  HANDOFF_AGE_LIMIT=86400
  HANDOFF_MTIME="$(stat -f %m "$HANDOFF_ARTIFACT_PATH" 2>/dev/null || stat -c %Y "$HANDOFF_ARTIFACT_PATH" 2>/dev/null || echo 0)"
  NOW="$(date +%s)"
  HANDOFF_AGE=$(( NOW - HANDOFF_MTIME ))
  if [ "$HANDOFF_AGE" -lt "$HANDOFF_AGE_LIMIT" ]; then
    HANDOFF_CONTEXT="$(render_handoff_context "$HANDOFF_ARTIFACT_PATH")"
  fi
fi

if [ -n "$HANDOFF_CONTEXT" ]; then
  OUTPUT="${OUTPUT}${HANDOFF_CONTEXT}"
  case "$HANDOFF_CONTEXT" in
    *$'\n') ;;
    *) OUTPUT="${OUTPUT}\n" ;;
  esac
  add_line ""
fi

sync_handoff_session_metadata "$HANDOFF_ARTIFACT_PATH" "$SESSION_FILE"

add_line "${PLANS_INFO}"

if [ -n "${SNAPSHOT_INFO}" ]; then
  add_line "${SNAPSHOT_INFO}"
fi

# Add active_skill restart instruction (displayed with highest priority)
if [ -n "$ACTIVE_SKILL_INFO" ]; then
  add_line ""
  add_line "$ACTIVE_SKILL_INFO"
fi

# Add ultrawork mode information
if [ -n "$WORK_INFO" ]; then
  add_line ""
  add_line "$WORK_INFO"
fi

# ===== JSON output =====
ESCAPED_OUTPUT=$(echo -e "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${ESCAPED_OUTPUT}"}}
EOF

exit 0
