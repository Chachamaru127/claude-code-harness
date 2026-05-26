#!/bin/bash
# test-quality-guardrails.sh
# Validation test for test tampering prevention (3-layer defense strategy)
#
# Test targets:
# - Layer 1: Rules template existence and structure
# - Layer 2: Skills quality guardrail integration
# - harness-init deployment configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test functions
assert_file_exists() {
  local file="$1"
  local description="$2"
  TOTAL=$((TOTAL + 1))

  if [ -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected file: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  TOTAL=$((TOTAL + 1))

  if [ ! -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if grep -qE "$pattern" "$PLUGIN_ROOT/$file"; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected pattern: $pattern"
    echo "  File: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

assert_json_key_exists() {
  local file="$1"
  local key="$2"
  local description="$3"
  TOTAL=$((TOTAL + 1))

  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} $description (jq not available, skipped)"
    return 0
  fi

  if [ ! -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if jq -e "$key" "$PLUGIN_ROOT/$file" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected key: $key"
    echo "  File: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

echo "=================================================="
echo "Test Tampering Prevention (3-Layer Defense Strategy) Validation"
echo "=================================================="
echo ""

# ============================================
# Layer 1: Rules template validation
# ============================================
echo "## Layer 1: Rules templates"
echo ""

# Test quality rules template existence
assert_file_exists \
  "templates/rules/test-quality.md.template" \
  "test-quality.md.template exists"

# Implementation quality rules template existence
assert_file_exists \
  "templates/rules/implementation-quality.md.template" \
  "implementation-quality.md.template exists"

# test-quality.md required content
assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "it.skip|test.skip" \
  "test-quality.md contains skip prohibition pattern"

assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "eslint|lint|disable" \
  "test-quality.md contains lint config tampering prohibition"

assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "_harness_template" \
  "test-quality.md contains frontmatter metadata"

# implementation-quality.md required content
assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "ハードコード|hardcode" \
  "implementation-quality.md contains hardcode prohibition"

assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "スタブ|stub" \
  "implementation-quality.md contains stub prohibition"

assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "_harness_template" \
  "implementation-quality.md contains frontmatter metadata"

# template-registry.json registration
assert_json_key_exists \
  "templates/template-registry.json" \
  '.templates["rules/test-quality.md.template"]' \
  "template-registry.json has test-quality.md registered"

assert_json_key_exists \
  "templates/template-registry.json" \
  '.templates["rules/implementation-quality.md.template"]' \
  "template-registry.json has implementation-quality.md registered"

echo ""

# ============================================
# Layer 2: Skills quality guardrail validation
# ============================================
echo "## Layer 2: Skills quality guardrails"
echo ""

# harness-work skill quality guardrails
assert_file_contains \
  "skills/harness-work/SKILL.md" \
  "重要停止条件|critical / major review finding" \
  "harness-work/SKILL.md has quality stop conditions"

assert_file_contains \
  "skills/harness-work/SKILL.md" \
  "テストを弱める|skip|期待値.*緩める" \
  "harness-work/SKILL.md defines test tampering prohibition"

assert_file_contains \
  "skills/harness-work/SKILL.md" \
  "DoD|Plans\\.md|sprint-contract" \
  "harness-work/SKILL.md has DoD / Plans-based implementation principles"

# harness-review / ci skill quality guardrails
assert_file_contains \
  "skills/harness-review/SKILL.md" \
  "Security, Performance, Quality|AI Residuals" \
  "harness-review/SKILL.md has quality review criteria"

assert_file_contains \
  "skills/harness-review/SKILL.md" \
  "it\\.skip|describe\\.skip|test\\.skip" \
  "harness-review/SKILL.md defines test skip detection"

assert_file_contains \
  "skills/ci/SKILL.md" \
  "承認リクエスト|Approval Request" \
  "ci/SKILL.md has approval request format"

echo ""

# ============================================
# harness-init integration validation
# ============================================
echo "## harness-init integration"
echo ""

# harness-init quality rules deployment config (after skill migration)
assert_file_contains \
  "skills/harness-setup/SKILL.md" \
  "harness-init|プロジェクト初期化|setup" \
  "harness-setup contains setup functionality equivalent to former harness-init"

# Quality rules file existence check
assert_file_contains \
  ".claude/rules/test-quality.md" \
  "テスト改ざん|Test Tampering|禁止" \
  "test-quality.md has test tampering prevention rules"

assert_file_contains \
  ".claude/rules/implementation-quality.md" \
  "形骸化|stub|placeholder" \
  "implementation-quality.md has stub/placeholder implementation prohibition"

echo ""

# ============================================
# Documentation validation
# ============================================
echo "## Documentation"
echo ""

# CLAUDE.md / AGENTS.md test tampering prevention section
assert_file_contains \
  "CLAUDE.md" \
  "テスト改ざん防止|Test Tampering Prevention" \
  "CLAUDE.md has test tampering prevention section"

# AGENTS.md is a Codex CLI project-local config, not in clean public checkout
# (see codex-cli-only.md). Only assert if present.
if [ -f "AGENTS.md" ]; then
  assert_file_contains \
    "AGENTS.md" \
    "3層防御|3-layer|第1層|第2層|第3層" \
    "AGENTS.md has 3-layer defense strategy description"
else
  echo "[skip] AGENTS.md not found (Codex CLI local config; not in public checkout)"
fi

# README.md quality assurance mentions
assert_file_contains \
  "README.md" \
  "Test tampering|Quality|品質" \
  "README.md has quality assurance mentions"

# Design documentation (historical quality guard introduction record)
# docs/update-summary-2025-12-23-24.md was a temporary summary doc at introduction.
# Now consolidated into CLAUDE.md / .claude/rules/test-quality.md / implementation-quality.md,
# so only assert if file exists.
if [ -f "docs/update-summary-2025-12-23-24.md" ]; then
  assert_file_exists \
    "docs/update-summary-2025-12-23-24.md" \
    "Quality guard introduction document exists"
else
  echo "[skip] docs/update-summary-2025-12-23-24.md not found (statement consolidated into CLAUDE.md and .claude/rules/)"
fi

echo ""

# ============================================
# Result summary
# ============================================
echo "=================================================="
echo "Test Results"
echo "=================================================="
echo ""
echo "Total: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILED test(s) failed${NC}"
  exit 1
fi
