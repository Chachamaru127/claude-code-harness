#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/research/antigravity-cli-adapter.md"

fail() {
  echo "test-antigravity-unknown-boundary: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

[ -f "$DOC" ] || fail "missing $DOC"
assert_contains "$DOC" 'Antigravity CLI remains `future/unsupported`'
assert_contains "$DOC" "https://antigravity.google/docs/plugins?app=antigravity"
assert_contains "$DOC" "https://www.antigravity.google/docs/hooks"
assert_contains "$DOC" "SPA-shell only"
assert_contains "$DOC" "command -v agy"
assert_contains "$DOC" "command -v antigravity"
assert_contains "$DOC" "not_observed != absent"
assert_contains "$DOC" 'Do not run `curl ... | bash`'
assert_contains "$DOC" "Promotion Conditions"

echo "test-antigravity-unknown-boundary: ok"
