#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX="${ROOT_DIR}/docs/onboarding/index.md"
INSTALL="${ROOT_DIR}/docs/onboarding/install.md"
README="${ROOT_DIR}/README.md"
README_JA="${ROOT_DIR}/README_ja.md"

fail() {
  echo "test-tool-first-onboarding: FAIL: $1" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing $1"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

section_for() {
  local host="$1"
  awk -v heading="### ${host} " '
    /^### / { in_section = (index($0, heading) == 1) }
    in_section { print }
  ' "$INSTALL"
}

assert_section_contains() {
  local host="$1"
  local needle="$2"
  section_for "$host" | grep -Fq "$needle" || fail "missing '$needle' in ${host} section"
}

assert_section_regex() {
  local host="$1"
  local pattern="$2"
  section_for "$host" | grep -Eq "$pattern" || fail "missing pattern '$pattern' in ${host} section"
}

assert_file "$INDEX"
assert_file "$INSTALL"

assert_contains "$INDEX" "tool you are using now"
assert_contains "$INDEX" "今使っている tool"
assert_contains "$INSTALL" "tool you are using now"
assert_contains "$INSTALL" "今使っている tool"
assert_contains "$INDEX" "not_observed != absent"
assert_contains "$INSTALL" "not_observed != absent"

HOST_TIERS=$(
  cat <<'HOSTS'
Claude Code|supported
Codex CLI|internal-compatible
Codex app|candidate
OpenCode|internal-compatible
Cursor|internal-compatible
Grok|internal-compatible
Hermes Agent|candidate
GitHub Copilot CLI|candidate
Antigravity CLI|future/unsupported
HOSTS
)

while IFS='|' read -r host tier; do
  assert_contains "$INDEX" "| ${host} | \`${tier}\` |"
  assert_contains "$INSTALL" "### ${host} (\`${tier}\`)"
  assert_section_contains "$host" "First prompt:"
  assert_section_contains "$host" "First command:"
  assert_section_contains "$host" "Verification command:"
  assert_section_contains "$host" "Success look:"
  assert_section_regex "$host" "(Install:|Unsupported reason:)"
  assert_section_regex "$host" "(Update:|Unsupported reason:)"
  assert_section_regex "$host" "(Uninstall:|Unsupported reason:)"
done <<EOF
$HOST_TIERS
EOF

assert_section_contains "Claude Code" "/plugin install claude-code-harness@claude-code-harness-marketplace"
assert_section_contains "Claude Code" "/plugin update claude-code-harness"
assert_section_contains "Codex CLI" "./scripts/setup-codex.sh --user"
assert_section_contains "Codex CLI" 'test -d "${CODEX_HOME:-$HOME/.codex}/skills/harness-plan"'
assert_section_contains "OpenCode" "scripts/setup-opencode.sh"
assert_section_contains "Codex app" "not counted as Codex CLI parity"
assert_section_contains "Cursor" 'tier stays `internal-compatible`'
assert_section_contains "Grok" 'tier stays `internal-compatible`'
assert_section_contains "Hermes Agent" "candidate symlink research only"
assert_section_contains "GitHub Copilot CLI" "no support claim is made"
assert_section_contains "Antigravity CLI" "public onboarding path does not present it as installable"

assert_contains "$README" "docs/onboarding/index.md"
assert_contains "$README_JA" "docs/onboarding/index.md"

echo "test-tool-first-onboarding: ok"
