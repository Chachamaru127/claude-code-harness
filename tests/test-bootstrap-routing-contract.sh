#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/bootstrap-routing-contract.md"

fail() {
  echo "test-bootstrap-routing-contract: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  if ! grep -Fq "$pattern" "$DOC"; then
    fail "expected '${pattern}' in docs/bootstrap-routing-contract.md"
  fi
}

assert_not_contains() {
  local pattern="$1"
  if grep -Fq "$pattern" "$DOC"; then
    fail "unexpected stale '${pattern}' in docs/bootstrap-routing-contract.md"
  fi
}

[ -f "$DOC" ] || fail "missing docs/bootstrap-routing-contract.md"

required_bootstrap_routes=(
  "Claude SessionStart"
  "Codex AGENTS.md"
  "OpenCode AGENTS.md"
  "Codex app"
  "Cursor"
  "GitHub Copilot CLI"
  "Antigravity CLI"
)

for route in "${required_bootstrap_routes[@]}"; do
  assert_contains "$route"
done

required_workflows=(
  '`harness-plan`'
  '`harness-work`'
  '`breezing`'
  '`harness-review`'
  '`harness-sync`'
  '`harness-setup`'
)

for workflow in "${required_workflows[@]}"; do
  assert_contains "$workflow"
done

required_prompt_fixtures=(
  'Todoアプリを作って'
  'review this PR'
  'implement all Plans.md tasks'
)

for prompt in "${required_prompt_fixtures[@]}"; do
  assert_contains "$prompt"
done

assert_contains "Golden prompts"
assert_contains "static contract fixture"
assert_contains "not runtime auto-routing proof"
assert_contains "False parity is forbidden."
assert_contains "Candidate and unsupported hosts must not inherit"
assert_contains '`not observed` means evidence is missing'
assert_contains "contract injection + post quality gate + merge gate"
assert_contains "Codex app | \`candidate\`"
assert_contains "Cursor AGENTS.md and Plugin Route"
assert_contains "tests/test-cursor-adapter-candidate.sh"
assert_contains "Cursor | \`candidate\`"
assert_contains "GitHub Copilot CLI | \`candidate\`"
assert_contains "Antigravity CLI | \`future/unsupported\`"
assert_contains 'candidate`, `not observed`'
assert_contains 'future/unsupported`, `not observed`'
assert_contains '`manual` evidence'
assert_not_contains "Cursor, Gemini, and Copilot are future/unsupported"
assert_not_contains "Phase 70 bootstrap routing contract"

echo "test-bootstrap-routing-contract: ok"
