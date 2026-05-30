#!/usr/bin/env bash
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
  "${ROOT_DIR}/.cursor-plugin/plugin.json"
  "${ROOT_DIR}/docs/research/github-copilot-cli-adapter.md"
  "${ROOT_DIR}/docs/research/antigravity-cli-adapter.md"
)

fail() {
  echo "test-support-claim-wording: FAIL: $1" >&2
  exit 1
}

for file in "${PUBLIC_FILES[@]}"; do
  [ -f "$file" ] || fail "missing ${file}"

  if grep -Eiq '(Codex App|Codex app|Cursor|GitHub Copilot CLI|Copilot CLI|Antigravity CLI|Antigravity).{0,80}([^[:alpha:]]supported([^[:alpha:]]|$)|サポート済み|サポート対象|対応済み)' "$file"; then
    fail "candidate/unsupported host appears supported in ${file}"
  fi

  if grep -Eiq '(^|[^[:alpha:]])supported([^[:alpha:]]|$).{0,80}(Codex App|Codex app|Cursor|GitHub Copilot CLI|Copilot CLI|Antigravity CLI|Antigravity)|(サポート済み|サポート対象|対応済み).{0,80}(Codex App|Codex app|Cursor|GitHub Copilot CLI|Copilot CLI|Antigravity CLI|Antigravity)' "$file"; then
    fail "support wording implies candidate/unsupported host support in ${file}"
  fi
done

echo "test-support-claim-wording: ok"
