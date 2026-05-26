#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/research/cursor-adapter-candidate.md"
HANDOFF="${ROOT_DIR}/docs/CURSOR_INTEGRATION.md"

fail() {
  echo "test-cursor-adapter-candidate: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

[ -f "$DOC" ] || fail "missing $DOC"
assert_contains "$HANDOFF" "handoff integration, not Cursor adapter support"
assert_contains "$DOC" 'Cursor remains `candidate`'
assert_contains "$DOC" ".cursor-plugin/plugin.json"
assert_contains "$DOC" ".cursor/rules"
assert_contains "$DOC" "AGENTS.md"
assert_contains "$DOC" "sessionStart"
assert_contains "$DOC" "not_observed != absent"
assert_contains "$DOC" 'Do not add `.cursor-plugin/plugin.json`'
assert_contains "$DOC" "workflow smoke"

echo "test-cursor-adapter-candidate: ok"
