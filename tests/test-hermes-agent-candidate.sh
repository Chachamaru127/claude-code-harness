#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="${ROOT_DIR}/docs/research/hermes-agent-candidate.md"
MATRIX="${ROOT_DIR}/docs/tool-capability-matrix.md"
README="${ROOT_DIR}/README.md"
README_JA="${ROOT_DIR}/README_ja.md"
ONBOARDING="${ROOT_DIR}/docs/onboarding/index.md"

fail() {
  echo "test-hermes-agent-candidate: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '${needle}' in ${file}"
}

[ -f "$DOC" ] || fail "missing $DOC"

assert_contains "$DOC" "Hermes Agent is a **candidate** Harness host path."
assert_contains "$DOC" "CCH \`skills/\` is the SSOT"
# .agents/skills is an optional read-only distribution mirror
# (.claude/rules/skill-editing.md Client Mirror Contract), never "public".
assert_contains "$DOC" "\`.agents/skills\` is an optional read-only mirror"
if grep -Fq '`.agents/skills` is a public mirror' "$DOC"; then
  fail "'.agents/skills' must not be described as a public mirror"
fi
assert_contains "$DOC" "not a public \`supported\` claim"
assert_contains "$DOC" "Dynamic slash commands"
assert_contains "$DOC" "do not create \`cch-*\` command aliases"
assert_contains "$DOC" "not_observed != absent"
assert_contains "$DOC" "supported Hermes adapter"
assert_contains "$DOC" "Hermes 正式対応"

assert_contains "$MATRIX" "| Hermes Agent | \`candidate\` |"
assert_contains "$MATRIX" "Hermes Agent remains \`candidate\`"
assert_contains "$README" "| Hermes Agent | \`candidate\` |"
assert_contains "$README_JA" "| Hermes Agent | \`candidate\` |"
assert_contains "$ONBOARDING" "| Hermes Agent | \`candidate\` |"

# Overclaim scan: only `blocked:`-prefixed blocked-wording cells may mention
# these phrases. Broad tokens (Blocked / 主張しない / supported` claim) must
# not excuse a positive claim elsewhere on the line.
if grep -InE 'Hermes Agent.*`supported`|supported Hermes adapter|Hermes.*正式対応|正式対応.*Hermes' \
  "$README" "$README_JA" "$ONBOARDING" "$MATRIX" "$DOC" \
  | grep -Eiv 'blocked:' \
  | grep -Eq .; then
  fail "Hermes public support overclaim found"
fi

echo "test-hermes-agent-candidate: ok"
