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

# Presentation expectations follow the user-facing rewrite; host, permission,
# verification and model-choice facts remain required.
for file in "$ROOT_DIR/README.md" "$ROOT_DIR/README_ja.md"; do
  [ -f "$file" ] || fail "missing $file"
  assert_contains "$file" "docs/onboarding/index.md"
  assert_contains "$file" "docs/onboarding/migration.md"
  assert_contains "$file" "docs/onboarding/skill-trigger-acceptance.md"
  assert_contains "$file" "codex/README.md#codex-breezing-role-routing"
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

assert_contains "$ROOT_DIR/README.md" "## What you can delegate"
assert_contains "$ROOT_DIR/README.md" "## Install and start"
assert_contains "$ROOT_DIR/README.md" "## The work steps"
assert_contains "$ROOT_DIR/README.md" "## Permissions and limits"
assert_contains "$ROOT_DIR/README.md" "## What you can see during work"
assert_contains "$ROOT_DIR/README.md" "## Install by tool"
assert_contains "$ROOT_DIR/README.md" "## Requirements"
assert_contains "$ROOT_DIR/README.md" "## Documentation"
assert_contains "$ROOT_DIR/README.md" "## Contributing"
assert_contains "$ROOT_DIR/README.md" "## Acknowledgments"
assert_contains "$ROOT_DIR/README.md" "## License"
assert_contains "$ROOT_DIR/README.md" "You decide the outcome, the completion criteria"
assert_contains "$ROOT_DIR/README.md" "Approve the plan or correct it before work starts."
assert_contains "$ROOT_DIR/README.md" "Harness drafts \`spec.md\` and \`Plans.md\` for you"
assert_contains "$ROOT_DIR/README.md" "Runtime floor"
assert_contains "$ROOT_DIR/README.md" "Guardrails"
assert_contains "$ROOT_DIR/README.md" "Codex Breezing role routing"
assert_contains "$ROOT_DIR/README.md" 'Your explicit model and reasoning-effort choices take priority'
assert_contains "$ROOT_DIR/README.md" 'docs/model-routing-policy.md'
assert_contains "$ROOT_DIR/README.md" 'Changing the main conversation does not change every child agent'
assert_contains "$ROOT_DIR/README.md" 'read-only execution'
assert_contains "$ROOT_DIR/README.md" "changing defaults."

assert_contains "$ROOT_DIR/README_ja.md" "## 何を任せられるか"
assert_contains "$ROOT_DIR/README_ja.md" "## 導入して始める"
assert_contains "$ROOT_DIR/README_ja.md" "## 作業の進め方"
assert_contains "$ROOT_DIR/README_ja.md" "## 許可と制限"
assert_contains "$ROOT_DIR/README_ja.md" "## 進み具合と再開"
assert_contains "$ROOT_DIR/README_ja.md" "## ツール別の導入"
assert_contains "$ROOT_DIR/README_ja.md" "## 動作要件"
assert_contains "$ROOT_DIR/README_ja.md" "## ドキュメント"
assert_contains "$ROOT_DIR/README_ja.md" "## コントリビュート"
assert_contains "$ROOT_DIR/README_ja.md" "## 謝辞"
assert_contains "$ROOT_DIR/README_ja.md" "## ライセンス"
assert_contains "$ROOT_DIR/README_ja.md" "利用者が決めるのは、作りたい結果、完成条件、許可する操作です"
assert_contains "$ROOT_DIR/README_ja.md" "作業が始まる前に計画を承認するか、意図と違う部分を直します"
assert_contains "$ROOT_DIR/README_ja.md" "実行時フロア"
assert_contains "$ROOT_DIR/README_ja.md" "ガードレール"
assert_contains "$ROOT_DIR/README_ja.md" "Codex Breezingの担当設定"
assert_contains "$ROOT_DIR/README_ja.md" '利用者が明示したモデルと推論量は'
assert_contains "$ROOT_DIR/README_ja.md" 'docs/model-routing-policy.md'
assert_contains "$ROOT_DIR/README_ja.md" '主会話の設定を変えても、すべての子エージェントの設定が変わるわけではありません'
assert_contains "$ROOT_DIR/README_ja.md" 'companion review'
assert_contains "$ROOT_DIR/README_ja.md" "読み取り専用の実行を明示します"
assert_not_contains "$ROOT_DIR/README_ja.md" "## The work steps"
assert_not_contains "$ROOT_DIR/README_ja.md" "## Install by tool"
assert_not_contains "$ROOT_DIR/README_ja.md" "## Permissions and limits"
assert_not_contains "$ROOT_DIR/README_ja.md" "## What you can see during work"

echo "test-readme-product-surface: ok"
