#!/usr/bin/env bash
#
# reenter-worktree.sh
# Helper for agent spawn to re-enter an existing worktree using the EnterWorktree path argument
# added in CC 2.1.105. Used when a Worker needs to re-enter a worktree it previously left,
# e.g. in Breezing's fix loop (amend after REQUEST_CHANGES).
#
# Usage: ./scripts/reenter-worktree.sh --path <worktree-path> [--task-id <id>]
#
# Prerequisites:
#   - <worktree-path> must exist in git worktree list
#   - CC 2.1.105 or higher (EnterWorktree path argument support)
#
# Output (JSON):
#   {"decision":"approve","worktree_path":"<path>","task_id":"<id>"}
#   or
#   {"decision":"deny","reason":"<message>"}

set -euo pipefail

WORKTREE_PATH=""
TASK_ID=""

canonicalize_path() {
    local target="$1"
    if [[ -d "$target" ]]; then
        (
            cd "$target" >/dev/null 2>&1 && pwd -P
        )
        return
    fi
    printf '%s\n' "$target"
}

usage() {
    echo "Usage: $0 --path <worktree-path> [--task-id <id>]" >&2
    exit 1
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            [[ $# -lt 2 ]] && { echo "Error: --path requires a value" >&2; usage; }
            WORKTREE_PATH="$2"
            shift 2
            ;;
        --task-id)
            [[ $# -lt 2 ]] && { echo "Error: --task-id requires a value" >&2; usage; }
            TASK_ID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage
            ;;
    esac
done

if [[ -z "$WORKTREE_PATH" ]]; then
    echo "Error: --path is required" >&2
    usage
fi

# Check that the worktree path exists
if [[ ! -d "$WORKTREE_PATH" ]]; then
    printf '{"decision":"deny","reason":"worktree path does not exist: %s"}\n' "$WORKTREE_PATH"
    exit 1
fi

CANONICAL_WORKTREE_PATH="$(canonicalize_path "$WORKTREE_PATH")"

# Confirm registration via git worktree list
if ! git worktree list --porcelain 2>/dev/null | awk '/^worktree / {sub(/^worktree /, ""); print}' | while IFS= read -r listed_path; do
    [[ "$(canonicalize_path "$listed_path")" == "$CANONICAL_WORKTREE_PATH" ]] && exit 0
done; then
    printf '{"decision":"deny","reason":"path is not a registered git worktree: %s"}\n' "$WORKTREE_PATH"
    exit 1
fi

# Check .claude/state/worktree-info.json inside the worktree (created by Breezing Worker)
WORKTREE_INFO="${WORKTREE_PATH}/.claude/state/worktree-info.json"
if [[ -f "$WORKTREE_INFO" ]] && command -v jq >/dev/null 2>&1; then
    REGISTERED_WORKER_ID="$(jq -r '.worker_id // ""' "$WORKTREE_INFO" 2>/dev/null || echo "")"
else
    REGISTERED_WORKER_ID=""
fi

print_guidance() {
    cat >&2 <<EOF
# EnterWorktree path re-entry confirmation

## Worktree information
- path:      $WORKTREE_PATH
- task_id:   ${TASK_ID:-"(not specified)"}
- worker_id: ${REGISTERED_WORKER_ID:-"(not available)"}

## CC 2.1.105+: How to use in agent definitions

To specify an existing worktree in the isolation field of the Agent tool,
pass the path parameter to EnterWorktree as follows:

  isolation: "worktree"
  worktreePath: "$WORKTREE_PATH"

Used when Harness breezing Lead resumes a worker via SendMessage,
re-entering the same worktree.

## Validation from script
- git worktree list: OK (path registration confirmed)
- Directory exists: OK
EOF
}

print_guidance

# JSON output
if command -v jq >/dev/null 2>&1; then
    jq -nc \
        --arg decision "approve" \
        --arg worktree_path "$WORKTREE_PATH" \
        --arg task_id "${TASK_ID:-""}" \
        --arg worker_id "${REGISTERED_WORKER_ID:-""}" \
        '{"decision":$decision,"worktree_path":$worktree_path,"task_id":$task_id,"worker_id":$worker_id}'
else
    printf '{"decision":"approve","worktree_path":"%s","task_id":"%s"}\n' \
        "${WORKTREE_PATH//\"/\\\"}" \
        "${TASK_ID//\"/\\\"}"
fi
