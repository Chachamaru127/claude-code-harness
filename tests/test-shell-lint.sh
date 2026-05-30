#!/bin/bash
# ShellCheck gate for release, setup, CI, and distribution smoke scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

cd "$PROJECT_ROOT"

command -v shellcheck >/dev/null 2>&1 || fail "shellcheck is not available"

targets=(
  "scripts/release-preflight.sh"
  "scripts/setup-codex.sh"
  "scripts/setup-opencode.sh"
  "scripts/set-impl-backend.sh"
  "scripts/resolve-impl-backend.sh"
  "scripts/cursor-companion.sh"
  "scripts/ci/check-checklist-sync.sh"
  "scripts/ci/check-consistency.sh"
  "scripts/ci/check-template-registry.sh"
  "scripts/ci/check-version-bump.sh"
  "scripts/ci/diagnose-and-fix.sh"
  "tests/test-distribution-archive.sh"
  "tests/test-release-preflight.sh"
  "tests/test-format-lint.sh"
  "tests/test-shell-lint.sh"
)

for target in "${targets[@]}"; do
  [ -f "$target" ] || fail "missing shellcheck target: $target"
done

shellcheck --severity=error "${targets[@]}"

echo "PASS: shellcheck high-risk subset has no error-level findings"
