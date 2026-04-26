#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD_SCRIPT="${ROOT_DIR}/scripts/codex-primary-environment-guard.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PRIMARY_REPO="${TMP_DIR}/primary"
PRIMARY_WT="${TMP_DIR}/primary-wt"

mkdir -p "${PRIMARY_REPO}"
git -C "${PRIMARY_REPO}" init -q
git -C "${PRIMARY_REPO}" config user.name "Harness Test"
git -C "${PRIMARY_REPO}" config user.email "harness@example.com"
echo "root" > "${PRIMARY_REPO}/README.md"
git -C "${PRIMARY_REPO}" add README.md
git -C "${PRIMARY_REPO}" commit -qm "init"
git -C "${PRIMARY_REPO}" worktree add -q -b feature/secondary "${PRIMARY_WT}" HEAD

PRIMARY_REPO_REAL="$(cd "${PRIMARY_REPO}" && pwd -P)"
PRIMARY_WT_REAL="$(cd "${PRIMARY_WT}" && pwd -P)"

STATE_FILE="${PRIMARY_REPO}/.claude/state/codex-primary-environment.json"

HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="${STATE_FILE}" \
  bash "${GUARD_SCRIPT}" --mode write --target-cwd "${PRIMARY_REPO}" >/tmp/codex-primary-env-1.out 2>/tmp/codex-primary-env-1.err

[ -f "${STATE_FILE}" ] || {
  echo "primary environment state file was not created"
  exit 1
}

jq -e --arg repo "${PRIMARY_REPO_REAL}" '.repo_root == $repo' "${STATE_FILE}" >/dev/null || {
  echo "state file repo_root mismatch"
  exit 1
}

HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="${STATE_FILE}" \
  bash "${GUARD_SCRIPT}" --mode write --target-cwd "${PRIMARY_REPO}" >/tmp/codex-primary-env-2.out 2>/tmp/codex-primary-env-2.err

if HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="${STATE_FILE}" \
  bash "${GUARD_SCRIPT}" --mode write --target-cwd "${PRIMARY_WT}" >/tmp/codex-primary-env-3.out 2>/tmp/codex-primary-env-3.err; then
  echo "non-primary worktree write should have been blocked"
  exit 1
fi

grep -q 'non-primary environment への write を停止しました' /tmp/codex-primary-env-3.err || {
  echo "guard must explain why non-primary write was blocked"
  exit 1
}

HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="${STATE_FILE}" \
HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1 \
  bash "${GUARD_SCRIPT}" --mode write --target-cwd "${PRIMARY_WT}" >/tmp/codex-primary-env-4.out 2>/tmp/codex-primary-env-4.err

grep -q 'override により non-primary write を許可します' /tmp/codex-primary-env-4.err || {
  echo "guard must acknowledge explicit non-primary override"
  exit 1
}

HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="${STATE_FILE}" \
HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1 \
  bash "${GUARD_SCRIPT}" --mode write --target-cwd "${PRIMARY_WT}" >/tmp/codex-primary-env-5.out 2>/tmp/codex-primary-env-5.err

jq -e --arg repo "${PRIMARY_WT_REAL}" '.repo_root == $repo' "${STATE_FILE}" >/dev/null || {
  echo "state file repo_root must move after primary reset"
  exit 1
}

grep -q 'primary environment を切り替えました' /tmp/codex-primary-env-5.err || {
  echo "guard must acknowledge primary reset"
  exit 1
}

echo "OK"
