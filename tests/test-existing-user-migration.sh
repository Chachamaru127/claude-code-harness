#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/onboarding/migration.md"

fail() {
  echo "test-existing-user-migration: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

[ -f "$DOC" ] || fail "missing $DOC"
assert_contains "$DOC" 'bin/harness doctor --migration-report'
assert_contains "$DOC" "Claude plugin cache"
assert_contains "$DOC" "Claude slash entries"
assert_contains "$DOC" "harness-mem state"
assert_contains "$DOC" 'memory DB を削除しない'
assert_contains "$DOC" "explicit confirmation"
assert_contains "$DOC" "not_observed != absent"

(
  cd "$ROOT_DIR/go"
  go test ./cmd/harness -run 'TestBuildExistingUserMigrationReport|TestPrintExistingUserMigrationReport' -count=1
)

echo "test-existing-user-migration: ok"
