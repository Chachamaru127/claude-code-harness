#!/bin/bash
# tdd-order-check.sh
# TDD is enabled by default. Emits a warning recommending test-first order (does not block).
#
# Purpose: Run after Write|Edit in PostToolUse
# Behavior:
#   - When Plans.md has a cc:WIP task (TDD is enabled by default)
#   - But skip WIP tasks that have a [skip:tdd] marker
#   - A source file (*.ts, *.tsx, *.js, *.jsx) was edited
#   - The corresponding test file (*.test.*, *.spec.*) has not yet been edited
#   -> Output a warning message (does not block)

set -euo pipefail

# Get edited file information
TOOL_INPUT="${TOOL_INPUT:-}"
FILE_PATH=""

# Extract file_path from TOOL_INPUT (supports both macOS and Linux)
if [[ -n "$TOOL_INPUT" ]]; then
    # Use jq when available (safest)
    if command -v jq &>/dev/null; then
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)
    else
        # Fallback: extract with sed (POSIX-compatible)
        FILE_PATH=$(echo "$TOOL_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null || true)
    fi
fi

# Exit if file path is absent
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Check if the file is a test file
is_test_file() {
    local file="$1"
    [[ "$file" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ ]] || \
    [[ "$file" =~ __tests__/ ]] || \
    [[ "$file" =~ /tests?/ ]]
}

# Check if the file is a source file (excluding test files)
is_source_file() {
    local file="$1"
    [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]] && ! is_test_file "$file"
}

# Check if there is an active WIP task
has_active_wip_task() {
    if [[ -f "Plans.md" ]]; then
        grep -q 'cc:WIP' Plans.md 2>/dev/null
        return $?
    fi
    return 1
}

# Check if the WIP task has a [skip:tdd] marker
is_tdd_skipped() {
    if [[ -f "Plans.md" ]]; then
        grep -q '\[skip:tdd\].*cc:WIP\|cc:WIP.*\[skip:tdd\]' Plans.md 2>/dev/null
        return $?
    fi
    return 1
}

# Check if a test file was edited during this session (simplified)
test_edited_this_session() {
    # .claude/state/session-changes.json があればチェック
    local state_file=".claude/state/session-changes.json"
    if [[ -f "$state_file" ]]; then
        grep -q '\.test\.\|\.spec\.\|__tests__' "$state_file" 2>/dev/null
        return $?
    fi
    return 1
}

# Main
main() {
    # Skip if not a source file
    if ! is_source_file "$FILE_PATH"; then
        exit 0
    fi

    # Skip if it is a test file
    if is_test_file "$FILE_PATH"; then
        exit 0
    fi

    # Skip if there is no WIP task
    if ! has_active_wip_task; then
        exit 0
    fi

    # Skip if [skip:tdd] marker is present
    if is_tdd_skipped; then
        exit 0
    fi

    # Skip if a test file has already been edited
    if test_edited_this_session; then
        exit 0
    fi

    # Output warning (does not block)
    cat << 'EOF'
{
  "decision": "approve",
  "reason": "TDD reminder",
  "systemMessage": "💡 TDD is enabled by default. Writing tests first is recommended.\n\nA source file was edited but the corresponding test file has not been edited yet.\n\nRecommendation: create the test file (*.test.ts, *.spec.ts) before implementing the source.\n\nTo skip, add the [skip:tdd] marker to the relevant task in Plans.md.\n\nThis is a warning only and does not block execution."
}
EOF
}

main
