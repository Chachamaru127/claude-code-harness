#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/tool-capability-matrix.md"

fail() {
  echo "test-tool-capability-matrix: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  if ! grep -Fq "$pattern" "$DOC"; then
    fail "expected '${pattern}' in docs/tool-capability-matrix.md"
  fi
}

[ -f "$DOC" ] || fail "missing docs/tool-capability-matrix.md"

required_capabilities=(
  '`skill_loading`'
  '`bootstrap_notice`'
  '`prompt_routing`'
  '`pre_use_guard`'
  '`post_use_gate`'
  '`review_artifact`'
  '`memory_bridge`'
)

for capability in "${required_capabilities[@]}"; do
  assert_contains "$capability"
done

required_hosts=(
  "Claude Code"
  "Codex CLI"
  "Codex app"
  "OpenCode"
  "Cursor"
  "GitHub Copilot CLI"
  "Antigravity CLI"
)

for host in "${required_hosts[@]}"; do
  assert_contains "$host"
done

tier_rows=(
  "| Claude Code | \`supported\` |"
  "| Codex CLI | \`internal-compatible\` |"
  "| Codex app | \`candidate\` |"
  "| OpenCode | \`internal-compatible\` |"
  "| Cursor | \`candidate\` |"
  "| GitHub Copilot CLI | \`candidate\` |"
  "| Antigravity CLI | \`future/unsupported\` |"
)

for host_row in "${tier_rows[@]}"; do
  assert_contains "$host_row"
done

assert_contains "False parity is forbidden."
assert_contains "contract injection + post quality gate + merge gate"
assert_contains "not a marketing support matrix"
assert_contains "OpenCode is currently a"
assert_contains "packaging and instruction surface"
assert_contains "CI-gated direct plugin marketplace/install smoke"
assert_contains "isolated \`CODEX_HOME\`"
assert_contains "real OpenCode binary runtime bootstrap parity is not proven"
assert_contains "not_observed != absent"
assert_contains "Candidate"
assert_contains "do not inherit the safety or"
assert_contains "bootstrap claims of supported hosts."
assert_contains "Antigravity CLI is \`future/unsupported\` for public claim."
assert_contains "tests/test-cursor-adapter-candidate.sh"
assert_contains "Cursor Breezing multitask mapping is a smoke target"

echo "test-tool-capability-matrix: ok"
