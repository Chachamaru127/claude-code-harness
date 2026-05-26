#!/bin/bash
# session-monitor.sh
# Collect and display project status on session start
#
# Usage: Auto-executed from SessionStart hook
# Output: Project status summary + state file generation

# Do not stop on errors (tolerate Git errors etc.)
set +e

# ================================
# Configuration
# ================================
STATE_DIR=".claude/state"
STATE_FILE="$STATE_DIR/session.json"
TOOLING_POLICY_FILE="$STATE_DIR/tooling-policy.json"
EVENT_LOG_FILE="$STATE_DIR/session.events.jsonl"
CONFIG_FILE=".claude-code-harness.config.yaml"

# Get the path to Plans.md, taking the plansDirectory setting into account
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_FILE=$(get_plans_file_path)
else
  PLANS_FILE="Plans.md"
fi

# ================================
# Helper functions
# ================================

# Calculate relative time (from seconds to "X minutes ago", "X hours ago", etc.)
relative_time() {
  local seconds=$1
  if [ "$seconds" -lt 60 ]; then
    echo "${seconds}s ago"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds / 60))m ago"
  elif [ "$seconds" -lt 86400 ]; then
    echo "$((seconds / 3600))h ago"
  else
    echo "$((seconds / 86400))d ago"
  fi
}

# Count tasks from Plans.md
count_tasks() {
  local marker=$1
  local count=0
  if [ -f "$PLANS_FILE" ]; then
    count=$(grep -c "$marker" "$PLANS_FILE" 2>/dev/null || true)
    [ -z "$count" ] && count=0
  fi
  echo "$count"
}

# ================================
# Status collection
# ================================

# Project information
PROJECT_NAME=$(basename "$(pwd)")
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Git information
if [ -d ".git" ]; then
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -z "$GIT_BRANCH" ] && GIT_BRANCH="unknown"
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$GIT_UNCOMMITTED" ] && GIT_UNCOMMITTED="0"
  GIT_LAST_COMMIT=$(git log -1 --format="%h" 2>/dev/null || echo "none")
  GIT_LAST_COMMIT_TIME=$(git log -1 --format="%ct" 2>/dev/null || echo "0")
else
  GIT_BRANCH="(no git)"
  GIT_UNCOMMITTED="0"
  GIT_LAST_COMMIT="none"
  GIT_LAST_COMMIT_TIME="0"
fi

# Plans.md information
if [ -f "$PLANS_FILE" ]; then
  PLANS_EXISTS="true"
  PLANS_MODIFIED=$(stat -f "%m" "$PLANS_FILE" 2>/dev/null || stat -c "%Y" "$PLANS_FILE" 2>/dev/null || echo "0")
  WIP_COUNT=$(( $(count_tasks "cc:wip") + $(count_tasks "cc:WIP") ))
  TODO_COUNT=$(( $(count_tasks "cc:todo") + $(count_tasks "cc:TODO") ))
  # Normalize to the English marker family; Japanese / cursor variants are treated as equivalent aliases
  PENDING_COUNT=$(( $(count_tasks "pm:requested") + $(count_tasks "pm:依頼中") + $(count_tasks "cursor:依頼中") ))
  COMPLETED_COUNT=$(( $(count_tasks "cc:done") + $(count_tasks "cc:完了") ))
else
  PLANS_EXISTS="false"
  PLANS_MODIFIED="0"
  WIP_COUNT="0"
  TODO_COUNT="0"
  PENDING_COUNT="0"
  COMPLETED_COUNT="0"
fi

# Read Orchestration configuration (simple parse)
ORCH_MAX_RETRIES="3"
ORCH_BACKOFF="10"
if [ -f "$CONFIG_FILE" ]; then
  max_retries_line=$(grep -E "max_state_retries:" "$CONFIG_FILE" 2>/dev/null | head -n 1 || true)
  backoff_line=$(grep -E "retry_backoff_seconds:" "$CONFIG_FILE" 2>/dev/null | head -n 1 || true)
  if [ -n "$max_retries_line" ]; then
    ORCH_MAX_RETRIES=$(echo "$max_retries_line" | sed 's/.*: *//' | tr -d '"' || echo "3")
  fi
  if [ -n "$backoff_line" ]; then
    ORCH_BACKOFF=$(echo "$backoff_line" | sed 's/.*: *//' | tr -d '"' || echo "10")
  fi
fi

# Previous session information
LAST_SESSION_TIME="0"
if [ -f "$STATE_FILE" ]; then
  LAST_SESSION_TIME=$(cat "$STATE_FILE" | grep -o '"started_at":"[^"]*"' | cut -d'"' -f4 | xargs -I{} date -j -f "%Y-%m-%dT%H:%M:%SZ" "{}" "+%s" 2>/dev/null || echo "0")
fi

# ================================
# State file generation
# ================================
# Security: refuse if STATE_DIR or its parent is a symlink (prevents symlink-based overwrites)
if [ -L "$STATE_DIR" ] || [ -L "$(dirname "$STATE_DIR")" ]; then
  echo "[session-monitor] Warning: symlink detected in state directory path, aborting" >&2
  exit 0
fi
mkdir -p "$STATE_DIR"

# Attempt to resume if an existing session has not yet ended
EXISTING_SESSION_ID=""
EXISTING_ENDED_AT=""
EXISTING_RESUME_TOKEN=""
EXISTING_EVENT_SEQ="0"
RESUME_MODE="false"
FORK_MODE="${HARNESS_SESSION_FORK:-false}"

if [ -f "$STATE_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    EXISTING_SESSION_ID=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
    EXISTING_ENDED_AT=$(jq -r '.ended_at // empty' "$STATE_FILE" 2>/dev/null)
    EXISTING_RESUME_TOKEN=$(jq -r '.resume_token // empty' "$STATE_FILE" 2>/dev/null)
    EXISTING_EVENT_SEQ=$(jq -r '.event_seq // 0' "$STATE_FILE" 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    # Security: avoid eval — extract all fields in one python3 call with tab separation
    _py_session="$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    data = {}
fields = [
    str(data.get("session_id", "")),
    str(data.get("ended_at", "") or ""),
    str(data.get("resume_token", "") or ""),
    str(data.get("event_seq", 0))
]
print("\t".join(fields))
' "$STATE_FILE" 2>/dev/null)"
    if [ -n "$_py_session" ]; then
      IFS=$'\t' read -r EXISTING_SESSION_ID EXISTING_ENDED_AT EXISTING_RESUME_TOKEN EXISTING_EVENT_SEQ <<< "$_py_session"
    fi
    unset _py_session
  fi
fi

if [ -n "$EXISTING_SESSION_ID" ] && [ -z "$EXISTING_ENDED_AT" ]; then
  RESUME_MODE="true"
fi

if [ "$FORK_MODE" = "true" ] && [ -n "$EXISTING_SESSION_ID" ]; then
  RESUME_MODE="false"
fi

# Initialize event log
touch "$EVENT_LOG_FILE" 2>/dev/null || true

gen_session_id() {
  uuidgen 2>/dev/null || echo "session-$(date +%s)"
}

gen_resume_token() {
  uuidgen 2>/dev/null || echo "resume-$(date +%s)"
}

append_event() {
  local event_type="$1"
  local event_state="$2"
  local event_time="$3"
  local event_data="$4"

  local seq
  local event_id

  if command -v jq >/dev/null 2>&1; then
    seq=$(jq -r '.event_seq // 0' "$STATE_FILE" 2>/dev/null)
    seq=$((seq + 1))
    event_id=$(printf "event-%06d" "$seq")
    tmp_file=$(mktemp 2>/dev/null || echo "")
    if [ -n "$tmp_file" ]; then
      jq --arg state "$event_state" \
         --arg updated_at "$event_time" \
         --arg event_id "$event_id" \
         --argjson event_seq "$seq" \
         '.state = $state | .updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
         "$STATE_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$STATE_FILE"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    event_id=$(python3 - <<PY 2>/dev/null
import json
import sys
try:
    data = json.load(open("$STATE_FILE"))
except Exception:
    data = {}
seq = int(data.get("event_seq", 0)) + 1
data["event_seq"] = seq
data["state"] = "$event_state"
data["updated_at"] = "$event_time"
data["last_event_id"] = f"event-{seq:06d}"
with open("$STATE_FILE", "w") as f:
    json.dump(data, f, indent=2)
print(f"event-{seq:06d}")
PY
)
  else
    event_id="event-000001"
  fi

  if [ -n "$event_id" ]; then
    if [ -n "$event_data" ]; then
      echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\",\"data\":$event_data}" >> "$EVENT_LOG_FILE"
    else
      echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\"}" >> "$EVENT_LOG_FILE"
    fi
  fi
}

# Permission hardening: session.json contains resume_token,
# restrict file permissions to owner-only (rw-------)
OLD_UMASK=$(umask)
umask 077

if [ "$RESUME_MODE" = "true" ] && [ -f "$STATE_FILE" ]; then
  # Update existing session (resume)
  if command -v jq >/dev/null 2>&1; then
    tmp_file=$(mktemp)
    jq --arg cwd "$(pwd)" \
       --arg project "$PROJECT_NAME" \
       --arg updated_at "$CURRENT_TIME" \
       --arg resumed_at "$CURRENT_TIME" \
       --argjson uncommitted "$GIT_UNCOMMITTED" \
       --arg branch "$GIT_BRANCH" \
       --arg last_commit "$GIT_LAST_COMMIT" \
       --argjson plans_exists "$PLANS_EXISTS" \
       --argjson plans_modified "$PLANS_MODIFIED" \
       --argjson wip "$WIP_COUNT" \
       --argjson todo "$TODO_COUNT" \
       --argjson pending "$PENDING_COUNT" \
       --argjson completed "$COMPLETED_COUNT" \
       --argjson orchestration_max_retries "$ORCH_MAX_RETRIES" \
       --argjson orchestration_backoff "$ORCH_BACKOFF" \
       '.state_version = 1 |
        .cwd = $cwd |
        .project_name = $project |
        .updated_at = $updated_at |
        .resumed_at = $resumed_at |
        .git.branch = $branch |
        .git.uncommitted_changes = $uncommitted |
        .git.last_commit = $last_commit |
        .plans.exists = $plans_exists |
        .plans.last_modified = $plans_modified |
        .plans.wip_tasks = $wip |
        .plans.todo_tasks = $todo |
        .plans.pending_tasks = $pending |
        .plans.completed_tasks = $completed |
        .orchestration.max_state_retries = $orchestration_max_retries |
        .orchestration.retry_backoff_seconds = $orchestration_backoff' \
       "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
  fi

  # Ensure resume_token file is owner-readable only (re-apply after update)
  chmod 600 "$STATE_FILE" 2>/dev/null || true

  append_event "session.resume" "initialized" "$CURRENT_TIME" ""
else
  # New session or fork
  NEW_SESSION_ID="$(gen_session_id)"
  RESUME_TOKEN="$(gen_resume_token)"
  PARENT_SESSION_ID="null"

  if [ "$FORK_MODE" = "true" ] && [ -n "$EXISTING_SESSION_ID" ]; then
    PARENT_SESSION_ID="\"$EXISTING_SESSION_ID\""
  fi

  cat > "$STATE_FILE" << EOF
{
  "session_id": "$NEW_SESSION_ID",
  "parent_session_id": $PARENT_SESSION_ID,
  "state": "initialized",
  "state_version": 1,
  "started_at": "$CURRENT_TIME",
  "updated_at": "$CURRENT_TIME",
  "resume_token": "$RESUME_TOKEN",
  "event_seq": 0,
  "last_event_id": "",
  "fork_count": 0,
  "orchestration": {
    "max_state_retries": $ORCH_MAX_RETRIES,
    "retry_backoff_seconds": $ORCH_BACKOFF
  },
  "cwd": "$(pwd)",
  "project_name": "$PROJECT_NAME",
  "prompt_seq": 0,
  "git": {
    "branch": "$GIT_BRANCH",
    "uncommitted_changes": $GIT_UNCOMMITTED,
    "last_commit": "$GIT_LAST_COMMIT"
  },
  "plans": {
    "exists": $PLANS_EXISTS,
    "last_modified": $PLANS_MODIFIED,
    "wip_tasks": $WIP_COUNT,
    "todo_tasks": $TODO_COUNT,
    "pending_tasks": $PENDING_COUNT,
    "completed_tasks": $COMPLETED_COUNT
  },
  "changes_this_session": []
}
EOF

  # Ensure resume_token file is owner-readable only
  chmod 600 "$STATE_FILE" 2>/dev/null || true

  if [ "$FORK_MODE" = "true" ] && [ -n "$EXISTING_SESSION_ID" ]; then
    append_event "session.fork" "initialized" "$CURRENT_TIME" "{\"parent_session_id\":\"$EXISTING_SESSION_ID\"}"
  else
    append_event "session.start" "initialized" "$CURRENT_TIME" ""
  fi
fi

# Restore original umask
umask "$OLD_UMASK"

# Resume / Fork info (for display)
RESUME_INFO=""
FORK_INFO=""
if [ "$RESUME_MODE" = "true" ]; then
  RESUME_INFO="↩ resume: previous session continued"
fi
if [ "$FORK_MODE" = "true" ] && [ -n "$EXISTING_SESSION_ID" ]; then
  FORK_INFO="🍴 fork: parent ${EXISTING_SESSION_ID}"
fi

# ================================
# Tooling Policy file generation
# ================================

# Determine LSP availability (installation status of official LSP plugins)
LSP_AVAILABLE="false"
LSP_PLUGINS=""
PLUGIN_LIST=""
PLUGIN_COUNT="unknown"
PLUGIN_ENABLED_ESTIMATE="unknown"
PLUGIN_SOURCE=""

# Known official LSP plugin names (marketplace)
# Supports all 10 official plugin types
OFFICIAL_LSP_PLUGINS="typescript-lsp pyright-lsp rust-analyzer-lsp gopls-lsp clangd-lsp jdtls-lsp swift-lsp lua-lsp php-lsp csharp-lsp"

if command -v claude >/dev/null 2>&1; then
  # Check installed plugins via claude plugin list
  PLUGIN_LIST=$(claude plugin list 2>/dev/null || true)
  INSTALLED_PLUGINS=$(echo "$PLUGIN_LIST" | grep -o '[a-z-]*lsp' || true)

  # Check whether at least one official LSP plugin is installed
  for plugin in $OFFICIAL_LSP_PLUGINS; do
    if echo "$INSTALLED_PLUGINS" | grep -q "$plugin"; then
      LSP_AVAILABLE="true"
      LSP_PLUGINS="$LSP_PLUGINS $plugin"
    fi
  done

  # Estimate plugin count
  if [ -n "$PLUGIN_LIST" ]; then
    PLUGIN_COUNT=$(echo "$PLUGIN_LIST" | grep -E '^[[:space:]]*[a-z0-9][a-z0-9-]*@' | wc -l | tr -d ' ')
    PLUGIN_DISABLED=$(echo "$PLUGIN_LIST" | grep -Ei 'disabled|inactive' | grep -E '^[[:space:]]*[a-z0-9]' | wc -l | tr -d ' ')
    if [ -n "$PLUGIN_COUNT" ] && [ "$PLUGIN_COUNT" -gt 0 ]; then
      if [ -n "$PLUGIN_DISABLED" ] && [ "$PLUGIN_DISABLED" -gt 0 ] 2>/dev/null; then
        PLUGIN_ENABLED_ESTIMATE=$((PLUGIN_COUNT - PLUGIN_DISABLED))
      else
        PLUGIN_ENABLED_ESTIMATE="$PLUGIN_COUNT"
      fi
      PLUGIN_SOURCE="claude plugin list"
    fi
  fi
fi

# ================================
# Context Budget (estimate)
# ================================
CONTEXT_BUDGET_ENABLED="true"
CONTEXT_MAX_ENABLED_MCPS="10"
CONTEXT_MAX_INSTALLED_PLUGINS="10"

read_context_value() {
  local key="$1"
  local default="$2"
  local value=""
  if [ -f "$CONFIG_FILE" ]; then
    value=$(awk -v k="$key" '
      $0 ~ /^context_budget:/ {in=1; next}
      in && $0 ~ /^[^[:space:]]/ {in=0}
      in && $1 == k":" {print $2; exit}
    ' "$CONFIG_FILE" 2>/dev/null)
  fi
  value="${value%\"}"
  value="${value#\"}"
  [ -z "$value" ] && value="$default"
  echo "$value"
}

normalize_bool() {
  case "$1" in
    true|false) echo "$1" ;;
    *) echo "$2" ;;
  esac
}

CONTEXT_BUDGET_ENABLED="$(normalize_bool "$(read_context_value enabled true)" true)"
CONTEXT_MAX_ENABLED_MCPS="$(read_context_value max_enabled_mcps 10)"
CONTEXT_MAX_INSTALLED_PLUGINS="$(read_context_value max_installed_plugins 10)"
if ! echo "$CONTEXT_MAX_ENABLED_MCPS" | grep -Eq '^[0-9]+$'; then
  CONTEXT_MAX_ENABLED_MCPS=10
fi
if ! echo "$CONTEXT_MAX_INSTALLED_PLUGINS" | grep -Eq '^[0-9]+$'; then
  CONTEXT_MAX_INSTALLED_PLUGINS=10
fi

MCP_SERVER_NAMES=""
MCP_DISABLED_NAMES=""
MCP_SOURCES=""
MCP_CONFIGURED="unknown"
MCP_DISABLED="unknown"
MCP_ENABLED_ESTIMATE="unknown"

collect_mcp_servers() {
  local file="$1"
  local names=""
  [ -f "$file" ] || return 0
  MCP_SOURCES="$MCP_SOURCES $file"
  if command -v jq >/dev/null 2>&1; then
    names=$(jq -r '.mcpServers | keys[]?' "$file" 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    names=$(python3 - "$file" <<'PY' 2>/dev/null
import json
import sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    data = {}
servers = data.get("mcpServers") or {}
if isinstance(servers, dict):
    for k in servers.keys():
        print(k)
PY
)
  fi
  if [ -n "$names" ]; then
    MCP_SERVER_NAMES="$MCP_SERVER_NAMES $names"
  fi
  return 0
}

collect_disabled_mcps() {
  local file="$1"
  [ -f "$file" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi
  local cwd
  cwd="$(pwd)"
  local names
  names=$(jq -r --arg cwd "$cwd" '
    def arr(x): if x == null then [] elif (x|type)=="array" then x else [] end;
    def proj_disabled:
      if (.projects | type) == "object" then
        arr(.projects[$cwd].disabledMcpServers)
      elif (.projects | type) == "array" then
        arr((.projects[]? | select(.path==$cwd) | .disabledMcpServers))
      else [] end;
    (arr(.disabledMcpServers) + proj_disabled) | .[]?
  ' "$file" 2>/dev/null)
  if [ -n "$names" ]; then
    MCP_DISABLED_NAMES="$MCP_DISABLED_NAMES $names"
  fi
  return 0
}

collect_mcp_servers ".mcp.json"
collect_mcp_servers ".claude/mcp.json"
collect_mcp_servers "$HOME/.claude/mcp.json"
collect_disabled_mcps "$HOME/.claude.json"

if [ -n "$MCP_SERVER_NAMES" ]; then
  MCP_CONFIGURED=$(printf "%s\n" $MCP_SERVER_NAMES | sort -u | wc -l | tr -d ' ')
fi
if [ -n "$MCP_DISABLED_NAMES" ]; then
  MCP_DISABLED=$(printf "%s\n" $MCP_DISABLED_NAMES | sort -u | wc -l | tr -d ' ')
fi
if [ "$MCP_CONFIGURED" != "unknown" ] && [ "$MCP_DISABLED" != "unknown" ]; then
  if [ "$MCP_DISABLED" -le "$MCP_CONFIGURED" ] 2>/dev/null; then
    MCP_ENABLED_ESTIMATE=$((MCP_CONFIGURED - MCP_DISABLED))
  fi
fi

MCP_SOURCES_JSON="[]"
if command -v jq >/dev/null 2>&1 && [ -n "$MCP_SOURCES" ]; then
  MCP_SOURCES_JSON=$(printf "%s\n" $MCP_SOURCES | jq -R . | jq -s '.' 2>/dev/null || echo "[]")
fi

# Format numbers/NULL for JSON
json_number_or_null() {
  local value="$1"
  if [ -z "$value" ] || [ "$value" = "unknown" ]; then
    echo "null"
  else
    echo "$value"
  fi
}

format_count() {
  local value="$1"
  if [ -z "$value" ] || [ "$value" = "unknown" ]; then
    echo "?"
  else
    echo "$value"
  fi
}

# Generate skills index (name + description)
SKILLS_INDEX="[]"
if [ -d "skills" ]; then
  # Collect skills in JSON format (prefer jq; fall back to python if unavailable)
  if command -v jq >/dev/null 2>&1; then
    SKILLS_INDEX=$(
      find skills -name 'doc.md' -type f 2>/dev/null | while read -r doc_file; do
        skill_name=$(dirname "$doc_file" | sed 's|skills/||')
        description=$(grep -m 1 '^description:' "$doc_file" 2>/dev/null | sed 's/^description: *//' || echo "")
        [ -z "$description" ] && description="No description"
        printf '{"name":"%s","description":"%s"}\n' "$skill_name" "$description"
      done | jq -s '.' 2>/dev/null || echo "[]"
    )
  elif command -v python3 >/dev/null 2>&1; then
    SKILLS_INDEX=$(
      find skills -name 'doc.md' -type f 2>/dev/null | python3 - <<'PY' 2>/dev/null
import sys, json, re, os
skills = []
for line in sys.stdin:
    doc_file = line.strip()
    skill_name = os.path.dirname(doc_file).replace("skills/", "", 1)
    description = "No description"
    try:
        with open(doc_file, "r") as f:
            for fline in f:
                if fline.startswith("description:"):
                    description = fline.replace("description:", "").strip()
                    break
    except Exception:
        pass
    skills.append({"name": skill_name, "description": description})
print(json.dumps(skills))
PY
    )
  fi
fi

# Map LSP availability by file extension (abbreviated)
LSP_BY_EXT="{}"
if [ "$LSP_AVAILABLE" = "true" ]; then
  # When official LSP plugins are installed, map them to their supported file extensions
  if echo "$LSP_PLUGINS" | grep -q "typescript-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"ts": true, "tsx": true, "js": true, "jsx": true}' 2>/dev/null || echo '{"ts":true,"tsx":true,"js":true,"jsx":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "pyright-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"py": true}' 2>/dev/null || echo '{"py":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "rust-analyzer-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"rs": true}' 2>/dev/null || echo '{"rs":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "gopls-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"go": true}' 2>/dev/null || echo '{"go":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "clangd-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"c": true, "cpp": true, "h": true, "hpp": true}' 2>/dev/null || echo '{"c":true,"cpp":true,"h":true,"hpp":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "jdtls-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"java": true}' 2>/dev/null || echo '{"java":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "swift-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"swift": true}' 2>/dev/null || echo '{"swift":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "lua-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"lua": true}' 2>/dev/null || echo '{"lua":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "php-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"php": true}' 2>/dev/null || echo '{"php":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "csharp-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"cs": true}' 2>/dev/null || echo '{"cs":true}')
  fi
fi

# Generate tooling-policy.json
cat > "$TOOLING_POLICY_FILE" << EOF
{
  "lsp": {
    "available": $LSP_AVAILABLE,
    "plugins": "$LSP_PLUGINS",
    "available_by_ext": $LSP_BY_EXT,
    "last_used_prompt_seq": 0,
    "last_used_tool_name": "",
    "used_since_last_prompt": false
  },
  "plugins": {
    "installed": $(json_number_or_null "$PLUGIN_COUNT"),
    "enabled_estimate": $(json_number_or_null "$PLUGIN_ENABLED_ESTIMATE"),
    "source": "$PLUGIN_SOURCE"
  },
  "mcp": {
    "configured": $(json_number_or_null "$MCP_CONFIGURED"),
    "disabled": $(json_number_or_null "$MCP_DISABLED"),
    "enabled_estimate": $(json_number_or_null "$MCP_ENABLED_ESTIMATE"),
    "sources": $MCP_SOURCES_JSON
  },
  "context_budget": {
    "enabled": $CONTEXT_BUDGET_ENABLED,
    "max_enabled_mcps": $CONTEXT_MAX_ENABLED_MCPS,
    "max_installed_plugins": $CONTEXT_MAX_INSTALLED_PLUGINS
  },
  "skills": {
    "index": $SKILLS_INDEX,
    "decision_required": false
  }
}
EOF

# ================================
# Summary output
# ================================
echo ""
echo "📊 Session started - project status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📂 Project: $PROJECT_NAME"
echo "🔀 Branch: $GIT_BRANCH"

if [ "$GIT_UNCOMMITTED" -gt 0 ]; then
  echo "📝 Uncommitted: ${GIT_UNCOMMITTED} file(s)"
fi

if [ "$PLANS_EXISTS" = "true" ]; then
  TOTAL_ACTIVE=$((WIP_COUNT + TODO_COUNT + PENDING_COUNT))
  if [ "$TOTAL_ACTIVE" -gt 0 ]; then
    echo "📋 Plans.md: WIP ${WIP_COUNT} / TODO $((TODO_COUNT + PENDING_COUNT))"
  fi
fi

if [ "$CONTEXT_BUDGET_ENABLED" = "true" ]; then
  MCP_CONFIG_LABEL="$(format_count "$MCP_CONFIGURED")"
  MCP_ENABLED_LABEL="$(format_count "$MCP_ENABLED_ESTIMATE")"
  PLUGIN_LABEL="$(format_count "$PLUGIN_ENABLED_ESTIMATE")"
  echo "🧠 Context budget (estimate): MCP ${MCP_ENABLED_LABEL}/${MCP_CONFIG_LABEL}, Plugins ${PLUGIN_LABEL}"

  if [ "$MCP_ENABLED_ESTIMATE" != "unknown" ] && [ "$MCP_ENABLED_ESTIMATE" -gt "$CONTEXT_MAX_ENABLED_MCPS" ] 2>/dev/null; then
    echo "⚠️ Estimated enabled MCP count exceeds limit (${MCP_ENABLED_ESTIMATE}/${CONTEXT_MAX_ENABLED_MCPS})"
  fi

  if [ "$PLUGIN_ENABLED_ESTIMATE" != "unknown" ] && [ "$PLUGIN_ENABLED_ESTIMATE" -gt "$CONTEXT_MAX_INSTALLED_PLUGINS" ] 2>/dev/null; then
    echo "⚠️ Estimated plugin count exceeds limit (${PLUGIN_ENABLED_ESTIMATE}/${CONTEXT_MAX_INSTALLED_PLUGINS})"
  fi
fi

if [ -n "$LAST_SESSION_TIME" ] && [ "$LAST_SESSION_TIME" != "0" ] && [ "$LAST_SESSION_TIME" -gt 0 ] 2>/dev/null; then
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_SESSION_TIME))
  echo "⏰ Previous session: $(relative_time $DIFF)"
fi

if [ -n "$RESUME_INFO" ]; then
  echo "$RESUME_INFO"
fi

if [ -n "$FORK_INFO" ]; then
  echo "$FORK_INFO"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
