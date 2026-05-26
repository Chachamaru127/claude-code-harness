#!/bin/bash
# config-utils.sh
# Utility for reading values from the harness configuration file
#
# Usage: source "${SCRIPT_DIR}/config-utils.sh"
#        plans_path=$(get_plans_file_path)

# Default path for the configuration file
CONFIG_FILE="${CONFIG_FILE:-.claude-code-harness.config.yaml}"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
PLAN_MANIFEST_FILE="${PLAN_MANIFEST_FILE:-plans/manifest.json}"
ACTIVE_PLAN_FILE="${ACTIVE_PLAN_FILE:-.claude/state/active-plan.json}"

yaml_get_value() {
  local query="$1"
  local file="${2:-$CONFIG_FILE}"
  local value=""

  if [ ! -f "$file" ]; then
    return 0
  fi

  if command -v yq >/dev/null 2>&1; then
    value="$(yq -r "${query} // empty" "$file" 2>/dev/null || true)"
  fi

  if [ -z "$value" ] && command -v python3 >/dev/null 2>&1; then
    value="$(python3 - "$file" "$query" <<'PY' 2>/dev/null
import sys

try:
    import yaml
except ImportError:
    raise SystemExit(0)

path = sys.argv[2].strip()
if path.startswith("."):
    path = path[1:]
if path.startswith("."):
    path = path[1:]
keys = [part for part in path.split(".") if part]

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = yaml.safe_load(fh) or {}

value = data
for key in keys:
    if isinstance(value, dict) and key in value:
        value = value[key]
    else:
        value = None
        break

if value is None:
    raise SystemExit(0)
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
)"
  fi

  printf '%s\n' "$value"
}

normalize_harness_locale() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"

  case "$value" in
    en|ja) printf '%s\n' "$value" ;;
    *) printf '%s\n' "en" ;;
  esac
}

read_i18n_language_from_config() {
  local file="${1:-$CONFIG_FILE}"
  local value=""

  if [ ! -f "$file" ]; then
    return 0
  fi

  value="$(yaml_get_value '.i18n.language' "$file")"

  # Fallback for environments without yq/PyYAML — handles simple YAML from standard templates.
  if [ -z "$value" ]; then
    value="$(awk '
      function trim(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        return s
      }
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        raw = $0
        trimmed = trim(raw)
        if (raw ~ /^[^[:space:]][^:]*:/) {
          in_i18n = (trimmed ~ /^i18n:[[:space:]]*($|#)/)
          next
        }
        if (in_i18n && raw ~ /^[[:space:]]+language:[[:space:]]*/) {
          sub(/^[[:space:]]*language:[[:space:]]*/, "", raw)
          sub(/[[:space:]]+#.*$/, "", raw)
          raw = trim(raw)
          gsub(/"/, "", raw)
          gsub(/\047/, "", raw)
          print raw
          exit
        }
      }
    ' "$file" 2>/dev/null || true)"
  fi

  printf '%s\n' "$value"
}

get_harness_locale() {
  local explicit_locale="${1:-}"
  local config_locale=""

  if [ -n "$explicit_locale" ]; then
    normalize_harness_locale "$explicit_locale"
    return 0
  fi

  config_locale="$(read_i18n_language_from_config "$CONFIG_FILE")"
  if [ -n "$config_locale" ]; then
    normalize_harness_locale "$config_locale"
    return 0
  fi

  if [ -n "${CLAUDE_CODE_HARNESS_LANG:-}" ]; then
    normalize_harness_locale "$CLAUDE_CODE_HARNESS_LANG"
    return 0
  fi

  printf '%s\n' "en"
}

# Validate plansDirectory (security)
# Reject absolute paths, parent directory references, and symlink escapes
validate_plans_directory() {
  local value="$1"
  local default="."

  # Empty value → default
  [ -z "$value" ] && echo "$default" && return 0

  # Security: reject absolute paths
  case "$value" in
    /*) echo "$default" && return 0 ;;
  esac

  # Security: reject parent directory references (..)
  case "$value" in
    *..*)  echo "$default" && return 0 ;;
  esac

  # Security: detect symlink escapes (when realpath is available)
  if command -v realpath >/dev/null 2>&1 && [ -e "$value" ]; then
    local project_root
    local resolved_path
    project_root=$(realpath "." 2>/dev/null) || project_root=$(pwd)
    resolved_path=$(realpath "$value" 2>/dev/null)

    if [ -n "$resolved_path" ]; then
      # Verify the resolved path is within the project root
      case "$resolved_path" in
        "$project_root"/*) ;; # OK: inside project
        "$project_root") ;;   # OK: project root itself
        *) echo "$default" && return 0 ;; # NG: outside project
      esac
    fi
  fi

  echo "$value"
}

# Get plansDirectory setting (default: ".")
get_plans_directory() {
  local default="."

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "$default"
    return 0
  fi

  local value=""
  value="$(yaml_get_value '.plansDirectory' "$CONFIG_FILE")"

  # Fallback to grep + sed if yq/Python did not return a value
  if [ -z "$value" ]; then
    value=$(grep "^plansDirectory:" "$CONFIG_FILE" 2>/dev/null | sed 's/^plansDirectory:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")
  fi

  # Validate before returning
  validate_plans_directory "$value"
}

validate_plan_name() {
  local name="$1"
  case "$name" in
    ''|*[!A-Za-z0-9_.-]*|.*|*-|*.)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

validate_plan_relative_path() {
  local value="$1"

  python3 - "$PROJECT_ROOT" "$value" <<'PY' 2>/dev/null
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
raw = sys.argv[2].strip()
if not raw:
    raise SystemExit(1)
candidate = Path(raw)
if candidate.is_absolute():
    raise SystemExit(1)
if any(part == ".." for part in candidate.parts):
    raise SystemExit(1)
resolved = (root / candidate).resolve(strict=False)
if resolved != root and root not in resolved.parents:
    raise SystemExit(1)
print(raw)
PY
}

read_plan_from_manifest() {
  local plan_name="$1"
  local manifest="${PROJECT_ROOT}/${PLAN_MANIFEST_FILE}"

  [ -f "$manifest" ] || return 1
  validate_plan_name "$plan_name" || return 1

  python3 - "$manifest" "$plan_name" <<'PY' 2>/dev/null
import json
import sys

manifest_path, plan_name = sys.argv[1:3]
with open(manifest_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
plans = data.get("plans", {})
entry = plans.get(plan_name)
if isinstance(entry, str):
    print(entry)
elif isinstance(entry, dict) and isinstance(entry.get("path"), str):
    print(entry["path"])
else:
    raise SystemExit(1)
PY
}

resolve_named_plan_file_path() {
  local plan_name="$1"
  local raw_path=""
  local validated=""

  raw_path="$(read_plan_from_manifest "$plan_name")" || return 1
  validated="$(validate_plan_relative_path "$raw_path")" || return 1
  printf '%s\n' "$validated"
}

get_active_plan_name() {
  local active_file="${PROJECT_ROOT}/${ACTIVE_PLAN_FILE}"
  [ -f "$active_file" ] || return 0

  python3 - "$active_file" <<'PY' 2>/dev/null
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
value = data.get("active_plan", "")
if isinstance(value, str):
    print(value)
PY
}

get_selected_plan_name() {
  if [ -n "${HARNESS_PLAN_NAME:-}" ]; then
    printf '%s\n' "$HARNESS_PLAN_NAME"
    return 0
  fi

  local active_plan=""
  active_plan="$(get_active_plan_name)"
  if [ -n "$active_plan" ]; then
    printf '%s\n' "$active_plan"
    return 0
  fi

  printf '%s\n' "default"
}

get_legacy_plans_file_path() {
  local plans_dir
  plans_dir=$(get_plans_directory)

  # Search for Plans.md in the directory (case-insensitive)
  for f in Plans.md plans.md PLANS.md PLANS.MD; do
    local full_path="${plans_dir}/${f}"
    # Omit "./" when plans_dir is "."
    [ "$plans_dir" = "." ] && full_path="$f"

    if [ -f "$full_path" ]; then
      echo "$full_path"
      return 0
    fi
  done

  # Return default path when not found
  local default_path="${plans_dir}/Plans.md"
  [ "$plans_dir" = "." ] && default_path="Plans.md"
  echo "$default_path"
}

# Get the full path to Plans.md
get_plans_file_path() {
  if [ -n "${HARNESS_PLAN_FILE:-}" ]; then
    validate_plan_relative_path "$HARNESS_PLAN_FILE"
    return $?
  fi

  local selected_plan=""
  selected_plan="$(get_selected_plan_name)"
  if [ "$selected_plan" != "default" ] || [ -f "${PROJECT_ROOT}/${PLAN_MANIFEST_FILE}" ]; then
    resolve_named_plan_file_path "$selected_plan"
    return $?
  fi

  get_legacy_plans_file_path
}

# Check whether Plans.md exists
plans_file_exists() {
  local plans_path
  plans_path=$(get_plans_file_path)
  [ -f "$plans_path" ]
}

normalize_boolean() {
  local value="$1"
  local default="$2"
  case "${value}" in
    true|TRUE|True|yes|YES|Yes|on|ON|On|1) echo "true" ;;
    false|FALSE|False|no|NO|No|off|OFF|Off|0) echo "false" ;;
    *) echo "$default" ;;
  esac
}

normalize_integer() {
  local value="$1"
  local default="$2"
  case "${value}" in
    ''|*[!0-9]*) echo "$default" ;;
    *) echo "$value" ;;
  esac
}

advisor_config_value() {
  local key="$1"
  local default="$2"
  local value=""
  value="$(yaml_get_value ".advisor.${key}" "$CONFIG_FILE")"
  if [ -z "$value" ]; then
    printf '%s\n' "$default"
    return 0
  fi
  printf '%s\n' "$value"
}

get_advisor_enabled() {
  normalize_boolean "$(advisor_config_value "enabled" "true")" "true"
}

get_advisor_mode() {
  advisor_config_value "mode" "on-demand"
}

get_advisor_max_consults_per_task() {
  normalize_integer "$(advisor_config_value "max_consults_per_task" "3")" "3"
}

get_advisor_retry_threshold() {
  normalize_integer "$(advisor_config_value "retry_threshold" "2")" "2"
}

get_advisor_consult_before_user_escalation() {
  normalize_boolean "$(advisor_config_value "consult_before_user_escalation" "true")" "true"
}

get_advisor_claude_model() {
  advisor_config_value "claude_model" "opus"
}

get_advisor_codex_model() {
  advisor_config_value "codex_model" "gpt-5.4"
}

get_advisor_state_dir() {
  printf '%s\n' "${PROJECT_ROOT}/.claude/state/advisor"
}

get_advisor_history_file() {
  printf '%s/history.jsonl\n' "$(get_advisor_state_dir)"
}

get_advisor_last_request_file() {
  printf '%s/last-request.json\n' "$(get_advisor_state_dir)"
}

get_advisor_last_response_file() {
  printf '%s/last-response.json\n' "$(get_advisor_state_dir)"
}

ensure_advisor_state_files() {
  local state_dir history_file request_file response_file
  state_dir="$(get_advisor_state_dir)"
  history_file="$(get_advisor_history_file)"
  request_file="$(get_advisor_last_request_file)"
  response_file="$(get_advisor_last_response_file)"

  mkdir -p "${state_dir}"
  [ -f "${history_file}" ] || : > "${history_file}"
  [ -f "${request_file}" ] || printf '{}\n' > "${request_file}"
  [ -f "${response_file}" ] || printf '{}\n' > "${response_file}"
}
