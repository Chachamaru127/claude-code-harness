#!/bin/bash
# Regression checks for the WorktreeCreate shell hook.
#
# Contract (https://code.claude.com/docs/en/hooks): the hook ensures the
# worktree directory exists and prints ONLY that path on stdout. Malformed
# input emits nothing (aborts creation safely).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${ROOT_DIR}/scripts/hook-handlers/worktree-create.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

json_str() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

run_hook() {
  local payload="$1" output_file="$2" dir="${3:-${TMP_DIR}}"
  ( cd "${dir}" && printf '%s' "${payload}" | bash "${HOOK}" ) >"${output_file}" 2>/dev/null || true
}

# --- A throwaway git repo so `git worktree add` works ---
REPO="${TMP_DIR}/repo"
mkdir -p "${REPO}"
(
  cd "${REPO}"
  git init -q
  git config user.email test@test
  git config user.name test
  echo seed > README
  git add README
  git commit -qm seed
)

# === 1. decision-JSON-as-cwd must NOT be treated as a path, emits nothing ===
INVALID_CWD='{"decision":"approve","reason":"WorktreeCreate: initialized worktree state"}'
INVALID_OUT="${TMP_DIR}/invalid.out"
run_hook "{\"session_id\":\"worker-json\",\"cwd\":$(json_str "${INVALID_CWD}")}" "${INVALID_OUT}"
[ ! -s "${INVALID_OUT}" ] || fail "invalid cwd produced output: $(cat "${INVALID_OUT}")"
[ ! -e "${TMP_DIR}/${INVALID_CWD}" ] || fail "hook decision JSON was treated as a directory"

# === 2. empty cwd emits nothing ===
EMPTY_OUT="${TMP_DIR}/empty.out"
run_hook '{"session_id":"s","cwd":""}' "${EMPTY_OUT}"
[ ! -s "${EMPTY_OUT}" ] || fail "empty cwd produced output: $(cat "${EMPTY_OUT}")"

# === 3. valid repo cwd → creates worktree, prints ONLY the path ===
REAL_OUT="${TMP_DIR}/real.out"
run_hook "{\"session_id\":\"worker-123\",\"cwd\":$(json_str "${REPO}")}" "${REAL_OUT}" "${REPO}"
PRINTED="$(tr -d '\n' < "${REAL_OUT}")"
[ -n "${PRINTED}" ] || fail "valid cwd produced no path"
case "${PRINTED}" in
  \{*) fail "stdout must be a path, not JSON: ${PRINTED}" ;;
esac
[ -d "${PRINTED}" ] || fail "printed path is not a directory: ${PRINTED}"
git -C "${PRINTED}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "printed path is not a git worktree: ${PRINTED}"
[ -d "${PRINTED}/.claude/state" ] || fail "state dir not created in worktree"
[ -f "${PRINTED}/.claude/state/worktree-info.json" ] || fail "worktree-info.json not created"

python3 - "${PRINTED}/.claude/state/worktree-info.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
if data.get("worker_id") != "worker-123":
    raise SystemExit("worker_id mismatch")
if not data.get("cwd"):
    raise SystemExit("cwd missing")
PY

# === 4. idempotent: second call reuses, prints the same path ===
REAL_OUT2="${TMP_DIR}/real2.out"
run_hook "{\"session_id\":\"worker-123\",\"cwd\":$(json_str "${REPO}")}" "${REAL_OUT2}" "${REPO}"
PRINTED2="$(tr -d '\n' < "${REAL_OUT2}")"
[ "${PRINTED2}" = "${PRINTED}" ] || fail "idempotency broken: ${PRINTED2} != ${PRINTED}"

echo "PASS: WorktreeCreate shell hook creates worktree, prints path, idempotent, rejects decision JSON"
