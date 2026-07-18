#!/usr/bin/env bash
# Blocks public surfaces from claiming non-Claude hosts as publicly
# "supported" (or Japanese 正式対応 / 対応済み / サポート対象) near a
# non-public host name. Claude Code is intentionally omitted (only public
# supported host today); Codex CLI / Cursor / Grok stay internal-compatible
# and must not receive a bare public "supported" claim.
#
# Detection model (neutralize-then-scan):
#   1. Collect lines where a non-public host name and a support word appear
#      within 100 characters of each other.
#   2. Remove only explicit denial phrases that consume the support word
#      itself (e.g. "not a public `supported` claim",
#      "blocked: supported Hermes adapter", "正式対応ではない").
#   3. If a support word still sits near a host name, fail with the line.
#
# A denial-looking token elsewhere on the line (not proven / blocked /
# support wording / 未主張) must NOT excuse a positive claim such as
# "supported, but runtime floor parity is not proven".
# Contract fixtures: tests/test-support-claim-wording-selftest.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_FILES=(
  "${ROOT_DIR}/README.md"
  "${ROOT_DIR}/README_ja.md"
  "${ROOT_DIR}/docs/onboarding/index.md"
  "${ROOT_DIR}/docs/onboarding/install.md"
  "${ROOT_DIR}/docs/onboarding/migration.md"
  "${ROOT_DIR}/docs/onboarding/skill-trigger-acceptance.md"
  "${ROOT_DIR}/docs/CURSOR_INTEGRATION.md"
  "${ROOT_DIR}/docs/research/cursor-adapter-candidate.md"
  "${ROOT_DIR}/docs/research/grok-adapter-candidate.md"
  "${ROOT_DIR}/docs/research/hermes-agent-candidate.md"
  "${ROOT_DIR}/.cursor-plugin/plugin.json"
  "${ROOT_DIR}/.grok-plugin/plugin.json"
  "${ROOT_DIR}/docs/research/github-copilot-cli-adapter.md"
  "${ROOT_DIR}/docs/research/antigravity-cli-adapter.md"
  "${ROOT_DIR}/docs/tool-capability-matrix.md"
)

# Self-test hook: scan explicit files instead of the public surface list.
if [ "$#" -gt 0 ]; then
  PUBLIC_FILES=("$@")
fi

fail() {
  echo "test-support-claim-wording: FAIL: $1" >&2
  exit 1
}

# Patterns are lowercase: matching happens case-insensitively (grep -i) and
# on a lowercased copy of each candidate line.
NON_PUBLIC_HOSTS='codex app|cursor|grok|hermes agent|hermes|github copilot cli|copilot cli|antigravity cli|antigravity'
SUPPORT_WORDS='[^[:alpha:]]supported([^[:alpha:]]|$)|サポート済み|サポート対象|対応済み|正式対応'
PROXIMITY="(${NON_PUBLIC_HOSTS}).{0,100}(${SUPPORT_WORDS})|(${SUPPORT_WORDS}).{0,100}(${NON_PUBLIC_HOSTS})"

# Every pattern must consume the support word it excuses and nothing more:
# no pattern may span free text wide enough to swallow a host name together
# with an unrelated later claim. "blocked:" neutralizes only a closed
# blocked-wording table cell (up to the next "|"); in prose it stays live.
# "do not promote <host> to public supported" is a tight prohibition idiom:
# the span ends at the support word and cannot hide a later claim.
neutralize_denials() {
  sed -E \
    -e 's/not a public[[:space:]]+`?supported`?([[:space:]]+claim)?//g' \
    -e 's/no public[[:space:]]+`?supported`?([[:space:]]+claim)?//g' \
    -e 's/not( yet)?( publicly)?[[:space:]]+`?supported`?//g' \
    -e 's/do not promote[[:space:]][^.|]{0,40}to public[[:space:]]+`?supported`?//g' \
    -e 's/blocked:[^|]*[|]/|/g' \
    -e 's/(正式対応|サポート済み|サポート対象|対応済み)(で|と)はない//g' \
    -e 's/(正式対応|サポート済み|サポート対象|対応済み)(を|は|と)?(主張|表明)しない//g' \
    -e 's/(正式対応|サポート済み|サポート対象|対応済み)にしない//g'
}

# Lines are padded with one space on both ends so that `[^[:alpha:]]` matches
# a support word at line start/end without `(^|...)` alternations, which
# backtrack badly on long single-line JSON files.
violations=0
for file in "${PUBLIC_FILES[@]}"; do
  [ -f "$file" ] || fail "missing ${file}"

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    lineno="${hit%%:*}"
    text="${hit#*:}"
    lowered="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
    stripped="$(printf '%s' "$lowered" | neutralize_denials)"
    if printf ' %s \n' "$stripped" | grep -Eq "$PROXIMITY"; then
      echo "test-support-claim-wording: overclaim ${file}:${lineno}:${text}" >&2
      violations=$((violations + 1))
    fi
  done < <(sed -e 's/^/ /' -e 's/$/ /' "$file" | grep -Ein "$PROXIMITY" || true)
done

if [ "$violations" -gt 0 ]; then
  fail "${violations} public support overclaim(s): candidate/unsupported host appears supported"
fi

# Positive pins: public surfaces still name Claude as supported and the other
# hosts at their release/v5.1.0 tiers (Grok / Cursor must not regress).
assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '${needle}' in ${file}"
}

assert_contains "${ROOT_DIR}/README.md" "| Claude Code | \`supported\` |"
assert_contains "${ROOT_DIR}/README.md" "| Cursor | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/README.md" "| Grok | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/README.md" "| Hermes Agent | \`candidate\` |"
assert_contains "${ROOT_DIR}/docs/onboarding/index.md" "| Grok | \`internal-compatible\` |"
assert_contains "${ROOT_DIR}/docs/onboarding/index.md" "| Hermes Agent | \`candidate\` |"

echo "test-support-claim-wording: ok"
