#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "test-opencode-setup: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$file"; then
    fail "expected '${pattern}' in ${file}"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "unexpected '${pattern}' in ${file}"
  fi
}

assert_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    fail "expected file: ${file}"
  fi
}

assert_absent() {
  local path="$1"
  if [ -e "$path" ]; then
    fail "expected absent path: ${path}"
  fi
}

assert_contains "${ROOT_DIR}/opencode/README.md" '.opencode/skills/<name>/SKILL.md'
assert_contains "${ROOT_DIR}/opencode/README.md" '.opencode/plugins/harness-bootstrap.mjs'
assert_contains "${ROOT_DIR}/opencode/README.md" 'Skills-Primary'
assert_contains "${ROOT_DIR}/opencode/README.md" 'development-only and distribution-excluded'
assert_not_contains "${ROOT_DIR}/opencode/README.md" 'cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/'
assert_not_contains "${ROOT_DIR}/opencode/README.md" 'cd claude-code-harness/mcp-server'

assert_contains "${ROOT_DIR}/scripts/setup-opencode.sh" '.opencode/skills'
assert_contains "${ROOT_DIR}/scripts/setup-opencode.sh" '.opencode/plugins/harness-bootstrap.mjs'
assert_contains "${ROOT_DIR}/scripts/setup-opencode.sh" 'verify_installation'
assert_contains "${ROOT_DIR}/scripts/setup-opencode.sh" 'mcp-server/ is development-only'
assert_not_contains "${ROOT_DIR}/scripts/setup-opencode.sh" 'mkdir -p "$PROJECT_DIR/.claude/skills"'
assert_not_contains "${ROOT_DIR}/scripts/setup-opencode.sh" 'Skills copied to .claude/skills/'
assert_not_contains "${ROOT_DIR}/scripts/setup-opencode.sh" 'Do you want to setup MCP server?'

assert_contains "${ROOT_DIR}/scripts/opencode-setup-local.sh" '.opencode/skills'
assert_contains "${ROOT_DIR}/scripts/opencode-setup-local.sh" '.opencode/plugins/harness-bootstrap.mjs'
assert_contains "${ROOT_DIR}/scripts/opencode-setup-local.sh" 'OpenCode-native skills'
assert_not_contains "${ROOT_DIR}/scripts/opencode-setup-local.sh" 'mkdir -p "$PROJECT_DIR/.claude/skills"'
assert_not_contains "${ROOT_DIR}/scripts/opencode-setup-local.sh" 'cp -r "$PLUGIN_DIR/opencode/skills/"* "$PROJECT_DIR/.claude/skills/"'

assert_contains "${ROOT_DIR}/scripts/build-opencode.js" '.opencode/skills/<name>/SKILL.md'
assert_contains "${ROOT_DIR}/scripts/build-opencode.js" 'development-only and distribution-excluded'
assert_not_contains "${ROOT_DIR}/scripts/build-opencode.js" 'cp -r claude-code-harness/opencode/skills/ your-project/.claude/skills/'
assert_not_contains "${ROOT_DIR}/scripts/build-opencode.js" 'cd claude-code-harness/mcp-server'

node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "${ROOT_DIR}/opencode/opencode.json" >/dev/null

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT
PROJECT_DIR="${TMP_ROOT}/project"
mkdir -p "${PROJECT_DIR}"

(
  cd "${PROJECT_DIR}"
  CLAUDE_PLUGIN_ROOT="${ROOT_DIR}" bash "${ROOT_DIR}/scripts/opencode-setup-local.sh" >/tmp/opencode-setup-local.$$ 2>&1
)

assert_file "${PROJECT_DIR}/.opencode/skills/breezing/SKILL.md"
assert_file "${PROJECT_DIR}/.opencode/skills/harness-plan/SKILL.md"
assert_file "${PROJECT_DIR}/.opencode/plugins/harness-bootstrap.mjs"
assert_file "${PROJECT_DIR}/AGENTS.md"
assert_file "${PROJECT_DIR}/opencode.json"
assert_absent "${PROJECT_DIR}/.claude/skills"

node -e "
  const fs = require('fs');
  const config = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
  if (!Array.isArray(config.instructions) || !config.instructions.includes('AGENTS.md')) process.exit(1);
  if (!config.permission || !config.permission.skill || config.permission.skill['*'] !== 'allow') process.exit(1);
  if (JSON.stringify(config).includes('mcp-server')) process.exit(1);
" "${PROJECT_DIR}/opencode.json"

echo "test-opencode-setup: ok"
