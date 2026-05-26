#!/bin/bash
# session-init.sh
# SessionStart Hook: initialization processing on session start
#
# Features:
# 1. Plugin cache consistency check and sync
# 2. Skills Gate initialization
# 3. Plans.md status display
#
# Output: Outputs information to hookSpecificOutput.additionalContext in JSON format
#         → Displayed by Claude Code as system-reminder

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_SNAPSHOT_LIB="${SCRIPT_DIR}/lib/progress-snapshot.sh"
if [ -f "${PROGRESS_SNAPSHOT_LIB}" ]; then
  # shellcheck source=/dev/null
  source "${PROGRESS_SNAPSHOT_LIB}"
fi

# ===== Banner display (output to terminal via stderr) =====
VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
echo -e "\033[0;36m[claude-code-harness v${VERSION}]\033[0m Session initialized" >&2

# ===== SIMPLE mode detection =====
SIMPLE_MODE="false"
if [ -f "$SCRIPT_DIR/check-simple-mode.sh" ]; then
  # shellcheck source=./check-simple-mode.sh
  source "$SCRIPT_DIR/check-simple-mode.sh"
  if is_simple_mode; then
    SIMPLE_MODE="true"
    echo -e "\033[1;33m[WARNING]\033[0m CLAUDE_CODE_SIMPLE mode detected — skills/agents/memory disabled" >&2
  fi
fi

# ===== Read JSON input from stdin =====
INPUT=""
if [ -t 0 ]; then
  : # no input when stdin is TTY
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== agent_type / session_id detection (Claude Code v2.1.2+) =====
AGENT_TYPE=""
CC_SESSION_ID=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    AGENT_TYPE="$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)"
    CC_SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
  fi
fi

# Lightweight initialization for subagents (early return)
# - Skip plugin cache sync
# - Skip Skills Gate initialization
# - Skip Plans.md check
# - Skip template update check
# - Skip new rule file check
# - Skip old hook configuration detection
if [ "$AGENT_TYPE" = "subagent" ]; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[subagent] Lightweight initialization complete"}}
EOF
  exit 0
fi

# ===== Record hook usage =====
if [ -x "$SCRIPT_DIR/record-usage.js" ] && command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/record-usage.js" hook session-init >/dev/null 2>&1 &
fi

# Variable to accumulate output messages
OUTPUT=""

add_line() {
  OUTPUT="${OUTPUT}$1\n"
}

count_matches() {
  local pattern="$1"
  local file="$2"
  local count
  count="$(grep -c "$pattern" "$file" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

# ===== Step 1: Plugin cache sync =====
if [ -f "$SCRIPT_DIR/sync-plugin-cache.sh" ]; then
  # Run sync quietly
  bash "$SCRIPT_DIR/sync-plugin-cache.sh" >/dev/null 2>&1 || true
fi

# ===== Step 1.5: Symlink health check (Windows compatibility) =====
# Auto-repair broken symlinks from Windows git clone
SYMLINK_INFO=""
if [ -f "$SCRIPT_DIR/fix-symlinks.sh" ]; then
  FIX_RESULT=$(bash "$SCRIPT_DIR/fix-symlinks.sh" 2>/dev/null || echo '{"fixed":0}')
  if command -v jq >/dev/null 2>&1; then
    SYMLINK_FIXED=$(echo "$FIX_RESULT" | jq -r '.fixed // 0' 2>/dev/null)
    if [ "$SYMLINK_FIXED" -gt 0 ] 2>/dev/null; then
      SYMLINK_DETAILS=$(echo "$FIX_RESULT" | jq -r '.details | join(", ")' 2>/dev/null)
      SYMLINK_INFO="🔧 Symlink auto-repair: ${SYMLINK_FIXED} repaired (${SYMLINK_DETAILS})"
      echo -e "\033[1;33m[FIX]\033[0m Broken symlinks repaired: ${SYMLINK_FIXED} skills" >&2
    fi
  fi
fi

# ===== Step 2: Skills Gate initialization =====
# Resolve to git repository root for consistency with other hooks
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
STATE_DIR="${REPO_ROOT}/.claude/state"
SKILLS_CONFIG_FILE="${STATE_DIR}/skills-config.json"
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

mkdir -p "$STATE_DIR"

# Reset session-skills-used.json (new session start)
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

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

# Clear SSOT sync flag (on new session start)
# This flag is created when /sync-ssot-from-memory runs,
# and is used to confirm SSOT sync before Plans.md cleanup
rm -f "${STATE_DIR}/.ssot-synced-this-session" 2>/dev/null || true

# Clear work warning flag (on new session start)
# This flag is used by userprompt-inject-policy.sh to warn only once
# Backward compatibility: clear both flag names
rm -f "${STATE_DIR}/.work-review-warned" 2>/dev/null || true
rm -f "${STATE_DIR}/.ultrawork-review-warned" 2>/dev/null || true

# ===== Step 2.5: Harness session initialization & CC session_id mapping =====
SESSION_FILE="${STATE_DIR}/session.json"
SESSION_MAP_FILE="${STATE_DIR}/session-map.json"
ARCHIVE_DIR="${STATE_DIR}/sessions"
mkdir -p "$ARCHIVE_DIR"

# Generate Harness session_id for new session
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HARNESS_SESSION_ID="session-$(date +%s)"

# Initialize session.json (if not exists, or if in stopped state)
INIT_NEW_SESSION="false"
if [ ! -f "$SESSION_FILE" ]; then
  INIT_NEW_SESSION="true"
elif command -v jq >/dev/null 2>&1; then
  CURRENT_STATE="$(jq -r '.state // "idle"' "$SESSION_FILE" 2>/dev/null)"
  if [ "$CURRENT_STATE" = "stopped" ] || [ "$CURRENT_STATE" = "completed" ] || [ "$CURRENT_STATE" = "failed" ]; then
    INIT_NEW_SESSION="true"
  fi
fi

if [ "$INIT_NEW_SESSION" = "true" ]; then
  cat > "$SESSION_FILE" <<SESSEOF
{
  "session_id": "$HARNESS_SESSION_ID",
  "parent_session_id": null,
  "state": "initialized",
  "started_at": "$NOW",
  "updated_at": "$NOW",
  "event_seq": 0,
  "last_event_id": ""
}
SESSEOF

  # Initialize event log
  echo "{\"type\":\"session.start\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\"}}" > "${STATE_DIR}/session.events.jsonl"
else
  # Get session_id of existing session
  if command -v jq >/dev/null 2>&1; then
    HARNESS_SESSION_ID="$(jq -r '.session_id // empty' "$SESSION_FILE" 2>/dev/null)"
  fi
fi

# Save mapping between CC session_id and Harness session_id
if [ -n "$CC_SESSION_ID" ] && [ -n "$HARNESS_SESSION_ID" ]; then
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$SESSION_MAP_FILE" ]; then
      tmp_file=$(mktemp)
      jq --arg cc_id "$CC_SESSION_ID" --arg harness_id "$HARNESS_SESSION_ID" \
         '.[$cc_id] = $harness_id' "$SESSION_MAP_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_MAP_FILE"
    else
      echo "{\"$CC_SESSION_ID\":\"$HARNESS_SESSION_ID\"}" > "$SESSION_MAP_FILE"
    fi
  fi
fi

# ===== Step 2.6: Register for inter-session communication =====
# Register self in active.json (so other sessions can recognize this session)
if [ -f "$SCRIPT_DIR/session-register.sh" ]; then
  bash "$SCRIPT_DIR/session-register.sh" "$HARNESS_SESSION_ID" 2>/dev/null || true
fi

# Load and display skills-config.json
SKILLS_INFO=""
if [ -f "$SKILLS_CONFIG_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG_FILE" 2>/dev/null)
    SKILLS_LIST=$(jq -r '.skills // [] | join(", ")' "$SKILLS_CONFIG_FILE" 2>/dev/null)

    if [ "$SKILLS_ENABLED" = "true" ] && [ -n "$SKILLS_LIST" ]; then
      SKILLS_INFO="🎯 Skills Gate: enabled (${SKILLS_LIST})"
    fi
  fi
fi

# ===== Step 3: Plans.md check =====
# Consider plansDirectory configuration
PLANS_PATH="Plans.md"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_PATH=$(get_plans_file_path)
fi

PLANS_INFO=""
if [ -f "$PLANS_PATH" ]; then
  wip_count="$(count_matches "cc:wip\\|cc:WIP\\|pm:requested\\|pm:依頼中\\|cursor:依頼中" "$PLANS_PATH")"
  todo_count="$(count_matches "cc:todo\\|cc:TODO" "$PLANS_PATH")"

  PLANS_INFO="📄 Plans.md: in-progress ${wip_count} / not-started ${todo_count}"
else
  PLANS_INFO="📄 Plans.md: not found"
fi

SNAPSHOT_INFO=""
if declare -F progress_snapshot_summary >/dev/null 2>&1; then
  SNAPSHOT_INFO="$(progress_snapshot_summary "${STATE_DIR}" 2>/dev/null || true)"
fi

# ===== Step 4: Template update check =====
TEMPLATE_INFO=""
TEMPLATE_TRACKER="$SCRIPT_DIR/template-tracker.sh"

if [ -f "$TEMPLATE_TRACKER" ] && [ -f "$SCRIPT_DIR/../templates/template-registry.json" ]; then
  # Initialize if generated-files.json does not exist
  if [ ! -f "${STATE_DIR}/generated-files.json" ]; then
    bash "$TEMPLATE_TRACKER" init >/dev/null 2>&1 || true
    TEMPLATE_INFO="📦 Template tracking: initialized"
  else
    # Update check (parse JSON output)
    CHECK_RESULT=$(bash "$TEMPLATE_TRACKER" check 2>/dev/null || echo '{"needsCheck": false}')

    if command -v jq >/dev/null 2>&1; then
      NEEDS_CHECK=$(echo "$CHECK_RESULT" | jq -r '.needsCheck // false')
      UPDATES_COUNT=$(echo "$CHECK_RESULT" | jq -r '.updatesCount // 0')
      INSTALLS_COUNT=$(echo "$CHECK_RESULT" | jq -r '.installsCount // 0')

      if [ "$NEEDS_CHECK" = "true" ]; then
        parts=()

        # Files needing update
        if [ "$UPDATES_COUNT" -gt 0 ]; then
          LOCALIZED_COUNT=$(echo "$CHECK_RESULT" | jq '[.updates[] | select(.localized == true)] | length')
          OVERWRITE_COUNT=$((UPDATES_COUNT - LOCALIZED_COUNT))

          if [ "$OVERWRITE_COUNT" -gt 0 ]; then
            parts+=("updatable: ${OVERWRITE_COUNT}")
          fi
          if [ "$LOCALIZED_COUNT" -gt 0 ]; then
            parts+=("needs-merge: ${LOCALIZED_COUNT}")
          fi
        fi

        # Files needing new install
        if [ "$INSTALLS_COUNT" -gt 0 ]; then
          parts+=("new-install: ${INSTALLS_COUNT}")
        fi

        if [ ${#parts[@]} -gt 0 ]; then
          TEMPLATE_INFO="⚠️ Template updates: $(IFS=', '; echo "${parts[*]}") → check with \`/harness-update\`"
        fi
      fi
    fi
  fi
fi

# ===== Step 5: Check for newly added rule files =====
# Notify if quality protection rules (v2.5.30+) are not installed
MISSING_RULES_INFO=""
RULES_DIR=".claude/rules"
QUALITY_RULES=("test-quality.md" "implementation-quality.md")
MISSING_RULES=()

if [ -d "$RULES_DIR" ]; then
  for rule in "${QUALITY_RULES[@]}"; do
    if [ ! -f "$RULES_DIR/$rule" ]; then
      MISSING_RULES+=("$rule")
    fi
  done

  if [ ${#MISSING_RULES[@]} -gt 0 ]; then
    MISSING_RULES_INFO="⚠️ Quality protection rules not installed: ${MISSING_RULES[*]} → can be added with \`/harness-update\`"
  fi
elif [ -f ".claude-code-harness-version" ]; then
  # Harness installed but rules directory is missing
  MISSING_RULES_INFO="⚠️ Quality protection rules not installed → can be added with \`/harness-update\`"
fi

# ===== Step 6: Detect old hook configurations =====
# Only detect hooks with "claude-code-harness" in command path (exclude user-defined hooks)
OLD_HOOKS_INFO=""
SETTINGS_FILE=".claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    # Event types used by the plugin
    PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
    OLD_HARNESS_EVENTS=()

    for event in "${PLUGIN_EVENTS[@]}"; do
      # Only when the event exists and its command contains "claude-code-harness"
      if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
        COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
        if echo "$COMMANDS" | grep -q "claude-code-harness"; then
          OLD_HARNESS_EVENTS+=("$event")
        fi
      fi
    done

    if [ ${#OLD_HARNESS_EVENTS[@]} -gt 0 ]; then
      OLD_HOOKS_INFO="⚠️ Old harness hook configuration detected: ${OLD_HARNESS_EVENTS[*]} → recommend removing with \`/harness-update\`"
    fi
  fi
fi

# ===== Build output message =====
add_line "# [claude-code-harness] Session initialized"
add_line ""

# SIMPLE mode warning (also output in additionalContext — reuse warning text from check-simple-mode.sh)
if [ "$SIMPLE_MODE" = "true" ]; then
  add_line "⚠️ **CLAUDE_CODE_SIMPLE mode detected** (CC v2.1.50+)"
  while IFS= read -r warning_line; do
    add_line "$warning_line"
  done <<< "$(simple_mode_warning ja)"
  add_line ""
fi

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
if [ -n "$HANDOFF_ARTIFACT_PATH" ]; then
  # Reject stale handoff: ignore artifacts older than 24 hours
  HANDOFF_AGE_LIMIT=86400
  if [ -f "$HANDOFF_ARTIFACT_PATH" ]; then
    HANDOFF_MTIME="$(stat -f %m "$HANDOFF_ARTIFACT_PATH" 2>/dev/null || stat -c %Y "$HANDOFF_ARTIFACT_PATH" 2>/dev/null || echo 0)"
    NOW="$(date +%s)"
    HANDOFF_AGE=$(( NOW - HANDOFF_MTIME ))
    if [ "$HANDOFF_AGE" -lt "$HANDOFF_AGE_LIMIT" ]; then
      HANDOFF_CONTEXT="$(render_handoff_context "$HANDOFF_ARTIFACT_PATH")"
    fi
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

if [ -n "$SKILLS_INFO" ]; then
  add_line "${SKILLS_INFO}"
fi

if [ -n "$TEMPLATE_INFO" ]; then
  add_line "${TEMPLATE_INFO}"
fi

if [ -n "$MISSING_RULES_INFO" ]; then
  add_line "${MISSING_RULES_INFO}"
fi

if [ -n "$OLD_HOOKS_INFO" ]; then
  add_line "${OLD_HOOKS_INFO}"
fi

if [ -n "$SYMLINK_INFO" ]; then
  add_line "${SYMLINK_INFO}"
fi

add_line ""
add_line "## Marker Legend"
add_line "| Marker | State | Description |"
add_line "|--------|-------|-------------|"
add_line "| \`cc:todo\` | not started | Impl (Claude Code) scheduled to run |"
add_line "| \`cc:wip\` | in progress | Impl is implementing |"
add_line "| \`cc:done\` | complete | Impl finished, awaiting confirmation |"
add_line "| \`cc:blocked\` | blocked | Waiting on dependent task |"
add_line "| \`pm:requested\` | requested by PM | 2-Agent workflow |"
add_line "| \`pm:approved\` | PM confirmed | 2-Agent workflow |"
add_line ""
add_line "> **Compatibility**: \`cc:TODO\` / \`cc:WIP\` / \`cc:完了\` / \`pm:依頼中\` / \`pm:確認済\` / \`cursor:*\` are readable."

# ===== JSON output =====
# Claude Code SessionStart hook accepts hookSpecificOutput in JSON format
# The additionalContext content is displayed as system-reminder

# Escape processing (for JSON)
# Newlines → \n, double quotes → \", backslashes → \\
escape_json() {
  local str="$1"
  str="${str//\\/\\\\}"      # backslash
  str="${str//\"/\\\"}"      # double quote
  str="${str//$'\n'/\\n}"    # newline
  str="${str//$'\t'/\\t}"    # tab
  echo "$str"
}

ESCAPED_OUTPUT=$(echo -e "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${ESCAPED_OUTPUT}"}}
EOF

exit 0
