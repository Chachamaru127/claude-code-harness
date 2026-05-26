#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/research/github-copilot-cli-adapter.md"

fail() {
  echo "test-github-copilot-cli-candidate: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

[ -f "$DOC" ] || fail "missing $DOC"
assert_contains "$DOC" 'GitHub Copilot CLI remains `candidate`'
assert_contains "$DOC" "https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference"
assert_contains "$DOC" "plugin.json"
assert_contains "$DOC" "Superpowers evidence"
assert_contains "$DOC" "This is not Harness proof."
assert_contains "$DOC" 'real `copilot` binary is not found'
assert_contains "$DOC" "not_observed != absent"
assert_contains "$DOC" "Manual instruction profile"

echo "test-github-copilot-cli-candidate: ok"
