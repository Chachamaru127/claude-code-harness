#!/usr/bin/env bash
#
# Guard the harness-plan planning quality contract across shipped skill mirrors.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "test-harness-plan-quality: FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [ -f "$path" ] || fail "missing file: $path"
}

assert_absent() {
  local path="$1"
  local needle="$2"
  if grep -qF "$needle" "$path"; then
    fail "$path should not contain: $needle"
  fi
}

assert_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -qF "$needle" "$path"; then
    fail "$path missing: $needle"
  fi
}

surfaces=(
  "skills/harness-plan"
  "codex/.codex/skills/harness-plan"
  "opencode/skills/harness-plan"
)

for surface in "${surfaces[@]}"; do
  skill="$surface/SKILL.md"
  create_ref="$surface/references/create.md"
  quality_ref="$surface/references/planning-quality.md"

  assert_file "$skill"
  assert_file "$create_ref"
  assert_file "$quality_ref"

  assert_contains "$skill" "Research-backed task planning"
  assert_contains "$skill" "purpose: \"Create and maintain evidence-backed Plans.md task contracts\""
  assert_contains "$skill" "argument-hint: \"[create|add|update|sync|sync --no-retro|--ci]\""
  assert_contains "$skill" "### 標準の計画品質契約"
  assert_contains "$skill" "See [references/planning-quality.md]"
  assert_contains "$skill" "Product / Architecture / QA / Skeptic"
  assert_contains "$skill" "Required / Recommended / Optional / Reject"

  assert_absent "$skill" "/harness-plan maxplan"
  assert_absent "$skill" "argument-hint: \"[create|maxplan"
  assert_absent "$skill" "### maxplan"

  assert_contains "$create_ref" "## Step 3: 計画品質チェック"
  assert_contains "$create_ref" "references/planning-quality.md"
  assert_contains "$create_ref" "Product Fit、Evidence Strength、User Value、Implementation Feasibility、Regression Safety、Strategic Leverage"
  assert_contains "$create_ref" "`harness-mem` の DB は直接読まない"

  assert_contains "$quality_ref" "これは独立サブコマンドではない"
  assert_contains "$quality_ref" "WebSearch"
  assert_contains "$quality_ref" "cross-project 検索は、ユーザーが明示した場合だけ使う"
  assert_contains "$quality_ref" "harness-mem の DB を直接読む前提にしない"
  assert_contains "$quality_ref" "Product / Strategy"
  assert_contains "$quality_ref" "Architecture / Implementation"
  assert_contains "$quality_ref" "QA / Regression"
  assert_contains "$quality_ref" "Skeptic"
  assert_contains "$quality_ref" "Implementation Feasibility"
  assert_contains "$quality_ref" "Regression Safety"
  assert_contains "$quality_ref" "導入先プロダクトの核に直結"
  assert_absent "$quality_ref" "Harness の核に直結"
  assert_contains "$quality_ref" "Evidence Strength が 2 以下なら Required 禁止"
  assert_contains "$quality_ref" "Regression Safety が 2 以下なら、先に spike / spec / test を置く"
  assert_contains "$quality_ref" '## Step 7: `$easy` 報告'
done

[ ! -e skills/harness-plan/references/maxplan.md ] || fail "maxplan reference must not exist in SSOT"

diff -qr --exclude='.DS_Store' skills/harness-plan codex/.codex/skills/harness-plan >/dev/null \
  || fail "codex harness-plan mirror drifted"
diff -qr --exclude='.DS_Store' skills/harness-plan opencode/skills/harness-plan >/dev/null \
  || fail "opencode harness-plan mirror drifted"

echo "test-harness-plan-quality: ok"
