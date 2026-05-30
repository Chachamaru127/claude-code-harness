#!/usr/bin/env bash
set -euo pipefail

# Static CONTRACT test for TASK 83.10: assert the cursor execution-backend
# onboarding section exists in skills/harness-setup/SKILL.md with the required
# AI-runnable / MANUAL split, command names, paths, and rule/recipe references.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="${ROOT_DIR}/skills/harness-setup/SKILL.md"

fail() {
  echo "test-cursor-backend-onboarding: FAIL: $1" >&2
  exit 1
}

[ -f "$SKILL" ] || fail "missing ${SKILL}"

# Onboarding section heading present.
grep -q '## Cursor 実装バックエンド導入' "$SKILL" \
  || fail "missing cursor onboarding section heading"

# AI-runnable backend selection script.
grep -q 'set-impl-backend.sh' "$SKILL" \
  || fail "missing set-impl-backend.sh reference"

# MANUAL protected paths.
grep -q 'permissions.json' "$SKILL" \
  || fail "missing ~/.cursor/permissions.json reference"
grep -q '.cursorignore' "$SKILL" \
  || fail "missing .cursorignore reference"
grep -q '\*.cursor.sh' "$SKILL" \
  || fail "missing *.cursor.sh sandbox allowlist reference"

# References to the governing rule and the sandbox recipe.
grep -q 'cursor-cli-only.md' "$SKILL" \
  || fail "missing cursor-cli-only.md reference"
grep -q 'sandbox-allowlist-recipe.md' "$SKILL" \
  || fail "missing sandbox-allowlist-recipe.md reference"

# Explicit phrase marking the manual steps as user-performed (AI cannot edit).
grep -q 'ユーザー手動' "$SKILL" \
  || fail "missing user-performed manual-step marker"
grep -q 'AI が編集できない' "$SKILL" \
  || fail "missing 'AI cannot edit' boundary statement"

echo "test-cursor-backend-onboarding: ok"
