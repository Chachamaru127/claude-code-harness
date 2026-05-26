#!/usr/bin/env bash
# Validates that reenter-worktree.sh outputs only JSON to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_SCRIPT="${ROOT_DIR}/scripts/reenter-worktree.sh"

TMP_REPO="$(mktemp -d)"
WORKTREE_PARENT="$(mktemp -d)"
WORKTREE_DIR="${WORKTREE_PARENT}/feature-worktree"
cleanup() {
  git -C "${TMP_REPO}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
  rm -rf "${TMP_REPO}" "${WORKTREE_PARENT}"
}
trap cleanup EXIT

git -C "${TMP_REPO}" init -q
git -C "${TMP_REPO}" config user.name "Test User"
git -C "${TMP_REPO}" config user.email "test@example.com"
printf 'hello\n' > "${TMP_REPO}/README.md"
git -C "${TMP_REPO}" add README.md
git -C "${TMP_REPO}" commit -qm "init"
git -C "${TMP_REPO}" worktree add -q -b feature/reenter "${WORKTREE_DIR}" HEAD

STDOUT_FILE="$(mktemp)"
STDERR_FILE="$(mktemp)"
trap 'rm -f "${STDOUT_FILE}" "${STDERR_FILE}"; cleanup' EXIT

(
  cd "${TMP_REPO}"
  bash "${TARGET_SCRIPT}" --path "${WORKTREE_DIR}" --task-id "45.3"
) >"${STDOUT_FILE}" 2>"${STDERR_FILE}"

if ! python3 - "${STDOUT_FILE}" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
if data.get("decision") != "approve":
    raise SystemExit(1)
if data.get("task_id") != "45.3":
    raise SystemExit(1)
PY
then
  echo "FAIL: stdout could not be parsed as JSON or does not match expected values"
  echo "stdout:"
  cat "${STDOUT_FILE}"
  exit 1
fi

if ! grep -q "EnterWorktree path 再入確認" "${STDERR_FILE}"; then
  echo "FAIL: human-facing guidance is not printed to stderr"
  echo "stderr:"
  cat "${STDERR_FILE}"
  exit 1
fi

echo "PASS: reenter-worktree.sh keeps stdout JSON-only and sends guidance to stderr"
