#!/usr/bin/env bash
# codex-primary-environment-guard.sh
# Codex write 実行前に primary environment（repo/worktree）を確認し、
# 別 environment への誤書き込みを減らすためのガード。

set -euo pipefail

MODE="write"
TARGET_CWD="${PWD}"

while [ $# -gt 0 ]; do
  case "${1}" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --target-cwd)
      TARGET_CWD="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--mode write|read] [--target-cwd PATH]" >&2
      exit 2
      ;;
  esac
done

if [ "${HARNESS_CODEX_DISABLE_PRIMARY_ENV_GUARD:-0}" = "1" ]; then
  exit 0
fi

resolve_real_dir() {
  local dir="$1"
  (
    cd "$dir" >/dev/null 2>&1 &&
    pwd -P
  )
}

json_get() {
  local file="$1"
  local key="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.[$key] // ""' "$file" 2>/dev/null
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$key" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    data = {}
print(data.get(sys.argv[2], "") or "")
PY
    return 0
  fi
  return 1
}

write_state() {
  local file="$1"
  local repo_root="$2"
  local git_dir="$3"
  local branch="$4"
  local cwd="$5"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$(dirname "$file")"
  if command -v jq >/dev/null 2>&1; then
    jq -nc \
      --arg repo_root "$repo_root" \
      --arg git_dir "$git_dir" \
      --arg branch "$branch" \
      --arg cwd "$cwd" \
      --arg ts "$ts" \
      '{
        version: 1,
        repo_root: $repo_root,
        git_dir: $git_dir,
        branch: $branch,
        cwd: $cwd,
        initialized_at: $ts,
        updated_at: $ts
      }' > "$file"
    return 0
  fi

  python3 - "$file" "$repo_root" "$git_dir" "$branch" "$cwd" "$ts" <<'PY'
import json, sys
payload = {
    "version": 1,
    "repo_root": sys.argv[2],
    "git_dir": sys.argv[3],
    "branch": sys.argv[4],
    "cwd": sys.argv[5],
    "initialized_at": sys.argv[6],
    "updated_at": sys.argv[6],
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PY
}

TARGET_CWD_REAL="$(resolve_real_dir "${TARGET_CWD}")" || {
  echo "[codex-primary-environment-guard] target cwd を解決できません: ${TARGET_CWD}" >&2
  exit 2
}

TARGET_REPO_ROOT=""
TARGET_GIT_DIR=""
TARGET_BRANCH=""
if git -C "${TARGET_CWD_REAL}" rev-parse --show-toplevel >/dev/null 2>&1; then
  TARGET_REPO_ROOT="$(git -C "${TARGET_CWD_REAL}" rev-parse --show-toplevel 2>/dev/null || true)"
  TARGET_BRANCH="$(git -C "${TARGET_CWD_REAL}" branch --show-current 2>/dev/null || true)"
  RAW_GIT_DIR="$(git -C "${TARGET_CWD_REAL}" rev-parse --git-dir 2>/dev/null || true)"
  if [ -n "${RAW_GIT_DIR}" ]; then
    if [ "${RAW_GIT_DIR#/}" != "${RAW_GIT_DIR}" ]; then
      TARGET_GIT_DIR="${RAW_GIT_DIR}"
    else
      TARGET_GIT_DIR="$(resolve_real_dir "${TARGET_CWD_REAL}/${RAW_GIT_DIR}")" || TARGET_GIT_DIR="${TARGET_CWD_REAL}/${RAW_GIT_DIR}"
    fi
  fi
else
  TARGET_REPO_ROOT="${TARGET_CWD_REAL}"
  TARGET_GIT_DIR=""
  TARGET_BRANCH=""
fi

STATE_ROOT="${HARNESS_CODEX_EXECUTION_ROOT:-${TARGET_REPO_ROOT}}"
STATE_DIR="${HARNESS_CODEX_GENERAL_STATE_DIR:-${STATE_ROOT}/.claude/state}"
STATE_FILE="${HARNESS_CODEX_PRIMARY_ENV_STATE_FILE:-${STATE_DIR}/codex-primary-environment.json}"

if [ ! -f "${STATE_FILE}" ]; then
  if [ "${MODE}" = "write" ]; then
    write_state "${STATE_FILE}" "${TARGET_REPO_ROOT}" "${TARGET_GIT_DIR}" "${TARGET_BRANCH}" "${TARGET_CWD_REAL}"
    echo "[codex-primary-environment-guard] primary environment を初期化しました: ${TARGET_REPO_ROOT} (${TARGET_BRANCH:-no-branch})" >&2
  fi
  exit 0
fi

PRIMARY_REPO_ROOT="$(json_get "${STATE_FILE}" repo_root)"
PRIMARY_GIT_DIR="$(json_get "${STATE_FILE}" git_dir)"
PRIMARY_BRANCH="$(json_get "${STATE_FILE}" branch)"
PRIMARY_CWD="$(json_get "${STATE_FILE}" cwd)"

MATCHED=0
if [ -n "${TARGET_GIT_DIR}" ] && [ -n "${PRIMARY_GIT_DIR}" ]; then
  if [ "${TARGET_REPO_ROOT}" = "${PRIMARY_REPO_ROOT}" ] && [ "${TARGET_GIT_DIR}" = "${PRIMARY_GIT_DIR}" ]; then
    MATCHED=1
  fi
else
  if [ "${TARGET_CWD_REAL}" = "${PRIMARY_CWD}" ]; then
    MATCHED=1
  fi
fi

if [ "${MATCHED}" -eq 1 ]; then
  exit 0
fi

if [ "${MODE}" != "write" ]; then
  echo "[codex-primary-environment-guard] read-only access は non-primary environment でも許可します: ${TARGET_REPO_ROOT}" >&2
  exit 0
fi

if [ "${HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT:-0}" = "1" ]; then
  write_state "${STATE_FILE}" "${TARGET_REPO_ROOT}" "${TARGET_GIT_DIR}" "${TARGET_BRANCH}" "${TARGET_CWD_REAL}"
  echo "[codex-primary-environment-guard] primary environment を切り替えました: ${TARGET_REPO_ROOT} (${TARGET_BRANCH:-no-branch})" >&2
  exit 0
fi

if [ "${HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE:-0}" = "1" ]; then
  echo "[codex-primary-environment-guard] override により non-primary write を許可します: ${TARGET_REPO_ROOT} (${TARGET_BRANCH:-no-branch})" >&2
  exit 0
fi

echo "[codex-primary-environment-guard] non-primary environment への write を停止しました。" >&2
echo "  primary repo_root : ${PRIMARY_REPO_ROOT}" >&2
echo "  primary branch    : ${PRIMARY_BRANCH:-no-branch}" >&2
echo "  primary git_dir   : ${PRIMARY_GIT_DIR:-n/a}" >&2
echo "  target repo_root  : ${TARGET_REPO_ROOT}" >&2
echo "  target branch     : ${TARGET_BRANCH:-no-branch}" >&2
echo "  target git_dir    : ${TARGET_GIT_DIR:-n/a}" >&2
echo "  続行するには:" >&2
echo "    - 一時的に許可: HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1" >&2
echo "    - primary を切り替える: HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1" >&2
exit 2
