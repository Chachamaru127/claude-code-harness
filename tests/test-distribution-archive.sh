#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_LIST="$(mktemp)"
trap 'rm -f "${ARCHIVE_LIST}"' EXIT

git -C "${ROOT_DIR}" archive --worktree-attributes --format=tar HEAD | tar -tf - > "${ARCHIVE_LIST}"

FAILED=0

require_entry() {
  local entry="$1"
  if ! grep -Fxq "${entry}" "${ARCHIVE_LIST}"; then
    echo "missing required distribution entry: ${entry}"
    FAILED=1
  fi
}

forbid_entry() {
  local entry="$1"
  if grep -Fxq "${entry}" "${ARCHIVE_LIST}"; then
    echo "forbidden distribution entry included: ${entry}"
    FAILED=1
  fi
}

forbid_prefix() {
  local prefix="$1"
  local first_match
  first_match="$(awk -v prefix="${prefix}" 'index($0, prefix) == 1 { print; exit }' "${ARCHIVE_LIST}")"
  if [ -n "${first_match}" ]; then
    echo "forbidden distribution prefix included: ${prefix} (example: ${first_match})"
    FAILED=1
  fi
}

required_entries=(
  ".claude-plugin/plugin.json"
  ".claude-plugin/hooks.json"
  ".claude-plugin/settings.json"
  "VERSION"
  "bin/harness"
  "bin/harness-darwin-amd64"
  "bin/harness-darwin-arm64"
  "bin/harness-linux-amd64"
  "bin/harness-windows-amd64.exe"
  "skills/harness-work/SKILL.md"
  "agents/worker.md"
  "hooks/hooks.json"
  "output-styles/harness-ops.md"
)

forbidden_entries=(
  "CLAUDE.md"
  "AGENTS.md"
  "Plans.md"
  "CONTRIBUTING.md"
)

forbidden_prefixes=(
  ".claude/"
  ".codex-plugin/"
  ".cursor/"
  ".private/"
  "adapters/"
  "tests/"
  "benchmarks/"
  "go/"
  "codex/"
  "opencode/"
  "skills-codex/"
  "adapters/"
  "mcp-server/"
  "harness-ui/"
  "remotion/"
  "scripts/sandbox-test/"
  "scripts/ci/"
  "scripts/evidence/"
  "docs/private/"
  "docs/research/"
  "docs/notebooklm/"
  "docs/slides/"
  "docs/presentation/"
  "docs/design/"
  "docs/social/"
)

for entry in "${required_entries[@]}"; do
  require_entry "${entry}"
done

for entry in "${forbidden_entries[@]}"; do
  forbid_entry "${entry}"
done

for prefix in "${forbidden_prefixes[@]}"; do
  forbid_prefix "${prefix}"
done

if [ "${FAILED}" -ne 0 ]; then
  exit 1
fi

echo "OK"
