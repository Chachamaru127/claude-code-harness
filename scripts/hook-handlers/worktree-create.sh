#!/bin/bash
# worktree-create.sh — WorktreeCreate hook handler (shell fallback)
#
# Claude Code WorktreeCreate hook contract
# (https://code.claude.com/docs/en/hooks):
#   - This hook "replaces default git behavior".
#   - A command hook must ensure the worktree directory exists and print ONLY
#     that directory path on stdout.
#   - Missing path or non-zero exit aborts worktree creation.
#
# Emitting a decision JSON (the legacy behavior) makes the runtime treat the
# JSON text as a path → "returned a path that is not a directory".
#
# Defensive about non-determinism: never assume the worktree exists or does
# not. Reuse a valid existing worktree; otherwise create one. On unrecoverable
# ambiguity, emit nothing (aborts creation safely) rather than corrupt state.
#
# 入力 (stdin JSON): session_id, cwd, hook_event_name, tool_input

set -euo pipefail

# === stdin から JSON ペイロードを読み取り ===
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

# No payload: emit nothing, let the runtime fall back to default git behavior.
[ -z "${INPUT}" ] && exit 0

looks_like_hook_decision_json() {
  local value
  value="$(printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  case "${value}" in
    \{*) ;;
    *) return 1 ;;
  esac
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "${value}" | jq -e 'type == "object" and has("decision") and has("reason")' >/dev/null 2>&1
    return $?
  fi
  case "${value}" in
    *'"decision"'*'"reason"'*) return 0 ;;
    *) return 1 ;;
  esac
}

# === フィールド抽出 ===
SESSION_ID=""
CWD=""
TOOL_WORKTREE_PATH=""

if command -v jq >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | jq -r '[
    (.session_id // ""),
    (.cwd // ""),
    (.tool_input.worktreePath // .tool_input.path // .tool_input.worktree_path // "")
  ] | @tsv' 2>/dev/null || true)"
  if [ -n "${_parsed}" ]; then
    IFS=$'\t' read -r SESSION_ID CWD TOOL_WORKTREE_PATH <<< "${_parsed}"
  fi
  unset _parsed
elif command -v python3 >/dev/null 2>&1; then
  _parsed="$(printf '%s' "${INPUT}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input') or {}
    print(d.get('session_id', ''))
    print(d.get('cwd', ''))
    print(ti.get('worktreePath') or ti.get('path') or ti.get('worktree_path') or '')
except Exception:
    print(''); print(''); print('')
" 2>/dev/null || true)"
  SESSION_ID="$(printf '%s' "${_parsed}" | sed -n '1p')"
  CWD="$(printf '%s' "${_parsed}" | sed -n '2p')"
  TOOL_WORKTREE_PATH="$(printf '%s' "${_parsed}" | sed -n '3p')"
  unset _parsed
fi

# Malformed cwd (empty or the legacy decision-JSON-as-cwd bug): abort safely.
[ -z "${CWD}" ] && exit 0
if looks_like_hook_decision_json "${CWD}"; then
  exit 0
fi

# === worktree パスを決定 ===
sanitize_slug() {
  printf '%s' "$1" | sed 's#[ /\\.:]#-#g; s/^-*//; s/-*$//'
}

if [ -n "${TOOL_WORKTREE_PATH}" ] && ! looks_like_hook_decision_json "${TOOL_WORKTREE_PATH}"; then
  TARGET="${TOOL_WORKTREE_PATH}"
else
  SLUG="$(sanitize_slug "${SESSION_ID}")"
  [ -z "${SLUG}" ] && SLUG="worker"
  TARGET="${CWD}/.harness-worktrees/${SLUG}"
fi

# resolve_dir canonicalizes an existing directory (follows symlinks) without
# changing the caller's working directory (uses a subshell).
resolve_dir() {
  ( cd "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"
}

is_git_worktree() {
  [ -e "$1" ] || return 1
  # --is-inside-work-tree is true for ANY path inside a checkout, so a repo
  # subdirectory would be misreported as a reusable worktree. Require git's
  # toplevel to equal the path itself (a worktree root).
  local top
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ -n "${top}" ] || return 1
  [ "$(resolve_dir "${top}")" = "$(resolve_dir "$1")" ]
}

origin_default_ref() {
  local ref
  ref="$(git -C "${CWD}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "${ref}" ]; then printf '%s' "${ref}"; return 0; fi
  for name in origin/main origin/master; do
    if git -C "${CWD}" rev-parse --verify --quiet "${name}" >/dev/null 2>&1; then
      printf '%s' "${name}"; return 0
    fi
  done
  printf ''
}

# === worktree を確保（reuse or create）===
if ! is_git_worktree "${TARGET}"; then
  # Pre-existing non-empty non-worktree dir: never clobber, report as-is.
  if [ -d "${TARGET}" ] && [ -n "$(ls -A "${TARGET}" 2>/dev/null)" ]; then
    : # fall through and report TARGET below
  else
    # Empty placeholder would block `git worktree add`; remove it.
    [ -d "${TARGET}" ] && rmdir "${TARGET}" 2>/dev/null || true

    BRANCH="harness/worker/$(sanitize_slug "$(basename "${TARGET}")")"
    BASE="$(origin_default_ref)"
    if [ -n "${BASE}" ]; then
      git -C "${CWD}" worktree add -b "${BRANCH}" "${TARGET}" "${BASE}" >/dev/null 2>&1 \
        || git -C "${CWD}" worktree add "${TARGET}" "${BRANCH}" >/dev/null 2>&1 || true
    else
      git -C "${CWD}" worktree add -b "${BRANCH}" "${TARGET}" >/dev/null 2>&1 \
        || git -C "${CWD}" worktree add "${TARGET}" "${BRANCH}" >/dev/null 2>&1 || true
    fi

    # If creation failed, abort safely (emit nothing).
    if ! is_git_worktree "${TARGET}"; then
      echo "[claude-code-harness] worktree-create: failed to create ${TARGET}" >&2
      exit 0
    fi
  fi
fi

# === worktree 内に .claude/state/ を初期化（best-effort, idempotent）===
WORKTREE_STATE_DIR="${TARGET}/.claude/state"
mkdir -p "${WORKTREE_STATE_DIR}" 2>/dev/null || true
WORKTREE_INFO_FILE="${WORKTREE_STATE_DIR}/worktree-info.json"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg worker_id "${SESSION_ID}" \
    --arg created_at "${CREATED_AT}" \
    --arg cwd "${TARGET}" \
    '{"worker_id":$worker_id,"created_at":$created_at,"cwd":$cwd}' \
    > "${WORKTREE_INFO_FILE}" 2>/dev/null || true
else
  printf '{"worker_id":"%s","created_at":"%s","cwd":"%s"}\n' \
    "${SESSION_ID//\"/\\\"}" "${CREATED_AT}" "${TARGET//\"/\\\"}" \
    > "${WORKTREE_INFO_FILE}" 2>/dev/null || true
fi

# === Contract: print ONLY the worktree directory path on stdout ===
printf '%s\n' "${TARGET}"
exit 0
