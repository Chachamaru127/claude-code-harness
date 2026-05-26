#!/bin/bash
# fix-proposal-injector.sh
# Notifies of pending fix proposals via the UserPromptSubmit hook,
# and applies them to Plans.md when an approve/reject prompt is received.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -f "${PARENT_DIR}/path-utils.sh" ]; then
  # shellcheck source=/dev/null
  source "${PARENT_DIR}/path-utils.sh"
fi
PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || git -C "${PARENT_DIR}/.." rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"
PENDING_FIX_PROPOSALS_FILE="${STATE_DIR}/pending-fix-proposals.jsonl"
PLANS_PATH="${PROJECT_ROOT}/Plans.md"

if [ -f "${PARENT_DIR}/config-utils.sh" ]; then
  # shellcheck source=/dev/null
  source "${PARENT_DIR}/config-utils.sh"
  _plans_path="$(get_plans_file_path 2>/dev/null)"
  if [ -n "${_plans_path:-}" ]; then
    PLANS_PATH="${PROJECT_ROOT}/${_plans_path}"
  fi
fi

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "${INPUT}" ] && exit 0
[ ! -f "${PENDING_FIX_PROPOSALS_FILE}" ] && exit 0

json_get_input() {
  local key="$1"
  local default="${2:-}"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "${INPUT}" | jq -r "${key} // \"${default}\"" 2>/dev/null || printf '%s' "${default}"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('${key#.}', '${default}'))" <<<"${INPUT}" 2>/dev/null || printf '%s' "${default}"
  else
    printf '%s' "${default}"
  fi
}

load_pending_count() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "${PENDING_FIX_PROPOSALS_FILE}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
count = 0
for raw in path.read_text().splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        row = json.loads(raw)
    except Exception:
        continue
    if row.get("status", "pending") == "pending":
        count += 1
print(count)
PY
    return
  fi
  grep -c '.' "${PENDING_FIX_PROPOSALS_FILE}" 2>/dev/null || echo "0"
}

select_proposal_json() {
  local selector="${1:-}"
  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi
  SELECTOR="${selector}" python3 - "${PENDING_FIX_PROPOSALS_FILE}" <<'PY'
import json
import os
import sys
from pathlib import Path

selector = os.environ.get("SELECTOR", "").strip()
path = Path(sys.argv[1])
candidates = []
for raw in path.read_text().splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        row = json.loads(raw)
    except Exception:
        continue
    if row.get("status", "pending") != "pending":
        continue
    candidates.append(row)

if not candidates:
    sys.exit(1)

selected = None
if selector:
    for row in candidates:
        if selector in {row.get("source_task_id"), row.get("fix_task_id")}:
            selected = row
            break
    if selected is None:
        sys.exit(2)
else:
    selected = candidates[0]

print(json.dumps(selected, ensure_ascii=False))
PY
}

consume_proposal() {
  local selector="${1:-}"
  [ -z "${selector}" ] && return 1
  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi
  SELECTOR="${selector}" python3 - "${PENDING_FIX_PROPOSALS_FILE}" <<'PY'
import json
import os
import sys
from pathlib import Path

selector = os.environ["SELECTOR"]
path = Path(sys.argv[1])
rows = []
for raw in path.read_text().splitlines():
    raw = raw.strip()
    if not raw:
        continue
    try:
        row = json.loads(raw)
    except Exception:
        continue
    if selector in {row.get("source_task_id"), row.get("fix_task_id")}:
        continue
    rows.append(row)

with path.open("w", encoding="utf-8") as fh:
    for row in rows:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
PY
}

apply_proposal_to_plans() {
  local proposal_json="$1"
  [ -z "${proposal_json}" ] && return 1
  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi
  PROPOSAL_JSON="${proposal_json}" python3 - "${PLANS_PATH}" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

plans_path = Path(sys.argv[1])
proposal = json.loads(os.environ["PROPOSAL_JSON"])

if not plans_path.exists():
    print("plans_missing")
    sys.exit(1)

text = plans_path.read_text(encoding="utf-8")
source_task_id = proposal["source_task_id"]
fix_task_id = proposal["fix_task_id"]
proposal_subject = proposal["proposal_subject"].replace("|", "/")
dod = proposal["dod"].replace("|", "/")
depends = proposal["depends"].replace("|", "/")

fix_pattern = re.compile(r"^\|\s*" + re.escape(fix_task_id) + r"\s*\|", re.MULTILINE)
if fix_pattern.search(text):
    print("already_present")
    sys.exit(0)

source_pattern = re.compile(r"^\|\s*" + re.escape(source_task_id) + r"\s*\|")
lines = text.splitlines()
new_row = f"| {fix_task_id} | {proposal_subject} | {dod} | {depends} | cc:TODO |"

for idx, line in enumerate(lines):
    if source_pattern.match(line):
        lines.insert(idx + 1, new_row)
        plans_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("applied")
        sys.exit(0)

print("source_not_found")
sys.exit(1)
PY
}

emit_system_message() {
  local message="$1"
  [ -z "${message}" ] && exit 0
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg msg "${message}" '{"systemMessage":$msg}'
  else
    local escaped="${message//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//$'\n'/\\n}"
    printf '{"systemMessage":"%s"}\n' "${escaped}"
  fi
}

path_has_symlink_component_within_root() {
  local path="${1:-}"
  local root="${2:-}"
  [ -z "${path}" ] && return 1
  [ -z "${root}" ] && return 1

  path="${path%/}"
  root="${root%/}"

  while [ -n "${path}" ]; do
    if [ -L "${path}" ]; then
      return 0
    fi
    [ "${path}" = "${root}" ] && break
    path="$(dirname "${path}")"
    [ "${path}" = "." ] && break
  done

  [ -L "${root}" ]
}

if path_has_symlink_component_within_root "${STATE_DIR}" "${PROJECT_ROOT}" || [ -L "${PENDING_FIX_PROPOSALS_FILE}" ]; then
  emit_system_message "⚠️ fix proposal state path is a symlink; aborting."
  exit 0
fi

if [ -e "${PLANS_PATH}" ] && path_has_symlink_component_within_root "${PLANS_PATH}" "${PROJECT_ROOT}"; then
  emit_system_message "⚠️ Plans.md path is a symlink; cannot apply fix proposal."
  exit 0
fi

PROMPT="$(json_get_input ".prompt" "")"
FIRST_LINE="$(printf '%s' "${PROMPT}" | head -n1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
LOWER_LINE="$(printf '%s' "${FIRST_LINE}" | tr '[:upper:]' '[:lower:]')"
PENDING_COUNT="$(load_pending_count)"
[ "${PENDING_COUNT}" = "0" ] && exit 0

ACTION=""
TARGET_ID=""

case "${LOWER_LINE}" in
  "approve fix"|"approve fix "*)
    ACTION="approve"
    TARGET_ID="${FIRST_LINE#approve fix }"
    [ "${TARGET_ID}" = "${FIRST_LINE}" ] && TARGET_ID=""
    ;;
  "reject fix"|"reject fix "*)
    ACTION="reject"
    TARGET_ID="${FIRST_LINE#reject fix }"
    [ "${TARGET_ID}" = "${FIRST_LINE}" ] && TARGET_ID=""
    ;;
  "yes")
    ACTION="approve"
    ;;
  "no")
    ACTION="reject"
    ;;
esac

if [ -n "${ACTION}" ] && [ -z "${TARGET_ID}" ] && [ "${PENDING_COUNT}" != "1" ]; then
  emit_system_message "⚠️ There are ${PENDING_COUNT} pending fix proposals. Use 'approve fix <task_id>' or 'reject fix <task_id>' to specify a target."
  exit 0
fi

SELECT_STATUS=0
PROPOSAL_JSON="$(select_proposal_json "${TARGET_ID}")" || SELECT_STATUS=$?

if [ "${SELECT_STATUS}" -eq 2 ] && [ -n "${TARGET_ID}" ]; then
  emit_system_message "⚠️ The specified fix proposal was not found: ${TARGET_ID}"
  exit 0
fi

[ "${SELECT_STATUS}" -ne 0 ] && exit 0
[ -z "${PROPOSAL_JSON}" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  SOURCE_TASK_ID="$(printf '%s' "${PROPOSAL_JSON}" | jq -r '.source_task_id // ""' 2>/dev/null)"
  FIX_TASK_ID="$(printf '%s' "${PROPOSAL_JSON}" | jq -r '.fix_task_id // ""' 2>/dev/null)"
  PROPOSAL_SUBJECT="$(printf '%s' "${PROPOSAL_JSON}" | jq -r '.proposal_subject // ""' 2>/dev/null)"
  PROPOSAL_DOD="$(printf '%s' "${PROPOSAL_JSON}" | jq -r '.dod // ""' 2>/dev/null)"
  FAILURE_CATEGORY="$(printf '%s' "${PROPOSAL_JSON}" | jq -r '.failure_category // ""' 2>/dev/null)"
  RECOMMENDED_ACTION="$(printf '%s' "${PROPOSAL_JSON}" | jq -r '.recommended_action // ""' 2>/dev/null)"
else
  SOURCE_TASK_ID=""
  FIX_TASK_ID=""
  PROPOSAL_SUBJECT=""
  PROPOSAL_DOD=""
  FAILURE_CATEGORY=""
  RECOMMENDED_ACTION=""
fi

if [ "${ACTION}" = "approve" ]; then
  APPLY_RESULT="$(apply_proposal_to_plans "${PROPOSAL_JSON}" 2>/dev/null)"
  case "${APPLY_RESULT}" in
    applied|already_present)
      consume_proposal "${SOURCE_TASK_ID}" >/dev/null 2>&1 || true
      emit_system_message "✅ fix proposal applied: ${FIX_TASK_ID}\nContent: ${PROPOSAL_SUBJECT}"
      exit 0
      ;;
    plans_missing)
      emit_system_message "⚠️ Could not apply fix proposal. Plans.md not found."
      exit 0
      ;;
    *)
      emit_system_message "⚠️ Failed to apply fix proposal. Source task ${SOURCE_TASK_ID} not found in Plans.md."
      exit 0
      ;;
  esac
fi

if [ "${ACTION}" = "reject" ]; then
  consume_proposal "${SOURCE_TASK_ID}" >/dev/null 2>&1 || true
  emit_system_message "ℹ️ fix proposal rejected: ${FIX_TASK_ID}"
  exit 0
fi

REMINDER="[FIX PROPOSAL] There are pending fix task proposals (${PENDING_COUNT})\n"
REMINDER="${REMINDER}Target: ${FIX_TASK_ID} — ${PROPOSAL_SUBJECT}\n"
REMINDER="${REMINDER}Failure category: ${FAILURE_CATEGORY}\n"
REMINDER="${REMINDER}DoD: ${PROPOSAL_DOD}\n"
if [ -n "${RECOMMENDED_ACTION}" ]; then
  REMINDER="${REMINDER}Recommended action: ${RECOMMENDED_ACTION}\n"
fi
REMINDER="${REMINDER}Approve: approve fix ${SOURCE_TASK_ID}\n"
REMINDER="${REMINDER}Reject: reject fix ${SOURCE_TASK_ID}"
emit_system_message "${REMINDER}"
exit 0
