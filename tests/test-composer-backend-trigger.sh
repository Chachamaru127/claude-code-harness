#!/usr/bin/env bash
# Static contract test for Phase 88.2.
# Natural language "composer" requests must map to the cursor backend on both
# Claude and Codex skill surfaces.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "test-composer-backend-trigger: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "missing '${needle}' in ${file}"
}

assert_regex() {
  local file="$1"
  local pattern="$2"
  grep -Eiq "$pattern" "$file" || fail "missing /${pattern}/ in ${file}"
}

FILES=(
  "skills/harness-work/SKILL.md"
  "skills/breezing/SKILL.md"
  "skills-codex/harness-work/SKILL.md"
  "skills-codex/breezing/SKILL.md"
)

for rel in "${FILES[@]}"; do
  file="${ROOT}/${rel}"
  [ -f "$file" ] || fail "missing ${rel}"
  assert_contains "$file" "composer 2.5"
  assert_contains "$file" "コンポーザー"
  assert_regex "$file" "composer.*cursor backend|cursor backend.*composer"
  assert_contains "$file" "--backend cursor"
done

assert_contains "${ROOT}/skills/harness-work/SKILL.md" "自然言語 backend trigger"
assert_contains "${ROOT}/skills-codex/harness-work/SKILL.md" "自然言語 backend trigger"
assert_contains "${ROOT}/skills/breezing/SKILL.md" "Natural Language Backend Triggers"

echo "test-composer-backend-trigger: ok"
