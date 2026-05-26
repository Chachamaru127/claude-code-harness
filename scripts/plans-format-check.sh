#!/bin/bash
# plans-format-check.sh
# Checks the Plans.md format; warns and suggests migration if legacy format is detected

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"

# JSON output function
output_json() {
  local status="$1"
  local message="$2"
  local migration_needed="${3:-false}"
  local issues="${4:-[]}"

  cat <<EOF
{
  "status": "$status",
  "message": "$message",
  "migration_needed": $migration_needed,
  "issues": $issues,
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$message"
  }
}
EOF
}

# Plans.md does not exist
if [ ! -f "$PLANS_FILE" ]; then
  output_json "skip" "Plans.md not found" "false"
  exit 0
fi

# Format check
ISSUES=()
MIGRATION_NEEDED=false

# 1. Check for deprecated markers (cursor:WIP, cursor:done)
if grep -qE 'cursor:(WIP|完了)' "$PLANS_FILE" 2>/dev/null; then
  MIGRATION_NEEDED=true
  ISSUES+=("\"cursor:WIP and cursor:完了 are deprecated. Please migrate to pm:依頼中 / pm:確認済.\"")
fi

# 2. Check for marker legend section
if ! grep -qE '## マーカー凡例|## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  ISSUES+=("\"Marker legend section is missing. Adding one from the template is recommended.\"")
fi

# 3. Check for valid harness markers
# Canonical writer protocol: cc:todo, cc:wip, cc:done, pm:requested, pm:approved, blocked
# Read-compatible aliases: cc:TODO, cc:WIP, cc:完了, pm:依頼中, pm:確認済, cursor:依頼中, cursor:確認済
if ! grep -qE 'cc:(TODO|WIP|todo|wip|WORK|DONE|done|完了|blocked)|pm:(依頼中|確認済|requested|approved)|cursor:(依頼中|確認済)|(^|[^A-Za-z0-9_:.-])blocked([^A-Za-z0-9_:.-]|$)' "$PLANS_FILE" 2>/dev/null; then
  # Also check legacy format (cursor:WIP/完了)
  if ! grep -qE 'cursor:(WIP|完了)' "$PLANS_FILE" 2>/dev/null; then
    ISSUES+=("\"No harness markers (cc:todo, cc:wip, etc.) found.\"")
  fi
fi

# Output results
if [ ${#ISSUES[@]} -eq 0 ]; then
  output_json "ok" "Plans.md format is up to date" "false"
else
  ISSUES_JSON=$(printf '%s,' "${ISSUES[@]}" | sed 's/,$//')
  if [ "$MIGRATION_NEEDED" = true ]; then
    output_json "migration_required" "Legacy format detected in Plans.md. Migration is available via /harness-update." "true" "[$ISSUES_JSON]"
  else
    output_json "warning" "Plans.md has improvement suggestions" "false" "[$ISSUES_JSON]"
  fi
fi
