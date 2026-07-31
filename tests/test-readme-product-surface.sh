#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "test-readme-product-surface: FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "missing '$needle' in $file"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "unexpected '$needle' in $file"
  fi
}

for file in "$ROOT_DIR/README.md" "$ROOT_DIR/README_ja.md"; do
  [ -f "$file" ] || fail "missing $file"
  assert_contains "$file" "docs/onboarding/index.md"
  assert_contains "$file" "docs/onboarding/migration.md"
  assert_contains "$file" "docs/onboarding/skill-trigger-acceptance.md"
  assert_contains "$file" "Claude Code | \`supported\`"
  assert_contains "$file" "Codex CLI | \`supported\`"
  assert_contains "$file" "Codex app | \`candidate\`"
  assert_contains "$file" "OpenCode | \`internal-compatible\`"
  assert_contains "$file" "Cursor | \`supported\`"
  assert_contains "$file" "Grok | \`supported\`"
  assert_contains "$file" "GitHub Copilot CLI | \`candidate\`"
  assert_contains "$file" "Antigravity CLI | \`future/unsupported\`"
  assert_contains "$file" "docs/images/readme/loop-"
  assert_not_contains "$file" "Hokage"
  assert_not_contains "$file" "v4.2"
  assert_not_contains "$file" "v4.0"
  assert_not_contains "$file" "docs/images/hokage/hokage-hero.jpg"
  assert_not_contains "$file" "only setup"
done

assert_contains "$ROOT_DIR/README.md" "## The problem"
assert_contains "$ROOT_DIR/README.md" "## Install in 30 seconds"
assert_contains "$ROOT_DIR/README.md" "## The loop"
assert_contains "$ROOT_DIR/README.md" "## The safety layer"
assert_contains "$ROOT_DIR/README.md" "## Decision surfaces for non-engineers"
assert_contains "$ROOT_DIR/README.md" "## Install by tool"
assert_contains "$ROOT_DIR/README.md" "## Requirements"
assert_contains "$ROOT_DIR/README.md" "## Documentation"
assert_contains "$ROOT_DIR/README.md" "## Contributing"
assert_contains "$ROOT_DIR/README.md" "## Acknowledgments"
assert_contains "$ROOT_DIR/README.md" "## License"
assert_contains "$ROOT_DIR/README.md" "Your job is not to write the"
assert_contains "$ROOT_DIR/README.md" "it is to approve or correct it"
assert_contains "$ROOT_DIR/README.md" "Harness drafts \`spec.md\` and \`Plans.md\` for you"
assert_contains "$ROOT_DIR/README.md" "Runtime floor"
assert_contains "$ROOT_DIR/README.md" "Guardrails"

assert_contains "$ROOT_DIR/README_ja.md" "## 何を解決するか"
assert_contains "$ROOT_DIR/README_ja.md" "## 30 秒で導入"
assert_contains "$ROOT_DIR/README_ja.md" "## 5 動詞のワークフロー"
assert_contains "$ROOT_DIR/README_ja.md" "## 安全の仕組み"
assert_contains "$ROOT_DIR/README_ja.md" "## 非エンジニアが判断するための画面"
assert_contains "$ROOT_DIR/README_ja.md" "## ツール別の導入"
assert_contains "$ROOT_DIR/README_ja.md" "## 動作要件"
assert_contains "$ROOT_DIR/README_ja.md" "## ドキュメント"
assert_contains "$ROOT_DIR/README_ja.md" "## コントリビュート"
assert_contains "$ROOT_DIR/README_ja.md" "## 謝辞"
assert_contains "$ROOT_DIR/README_ja.md" "## ライセンス"
assert_contains "$ROOT_DIR/README_ja.md" "あなたの仕事は計画を書くことではありません"
assert_contains "$ROOT_DIR/README_ja.md" "実行が進む前に、出てきた内容を承認するか直すことです"
assert_contains "$ROOT_DIR/README_ja.md" "実行時フロア"
assert_contains "$ROOT_DIR/README_ja.md" "ガードレール"
assert_not_contains "$ROOT_DIR/README_ja.md" "## The loop"
assert_not_contains "$ROOT_DIR/README_ja.md" "## Install by tool"
assert_not_contains "$ROOT_DIR/README_ja.md" "## The safety layer"
assert_not_contains "$ROOT_DIR/README_ja.md" "## Decision surfaces for non-engineers"

echo "test-readme-product-surface: ok"
