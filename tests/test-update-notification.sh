#!/bin/bash
# test-update-notification.sh
# Validation tests for the update notification feature for existing users
#
# Test targets:
# - session-init.sh new-rule detection
# - session-init.sh stale hook configuration detection
# - template-tracker.sh needsInstall reporting
# - harness-setup update integration guidance

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

assert_script_runs() {
  local script="$1"
  local description="$2"
  TOTAL=$((TOTAL + 1))

  if [ ! -f "$PLUGIN_ROOT/$script" ]; then
    echo -e "${RED}✗${NC} $description (script not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if bash -n "$PLUGIN_ROOT/$script" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description (syntax error)"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

echo "=================================================="
echo "Update notification feature validation for existing users"
echo "=================================================="
echo ""

# ============================================
# session-init.sh validation
# ============================================
echo "## session-init.sh"
echo ""

assert_script_runs \
  "scripts/session-init.sh" \
  "session-init.sh has valid syntax"

assert_file_contains \
  "scripts/session-init.sh" \
  "QUALITY_RULES.*test-quality.md.*implementation-quality.md" \
  "Quality protection rules check logic is present"

assert_file_contains \
  "scripts/session-init.sh" \
  "MISSING_RULES_INFO" \
  "Missing-rules notification variable is present"

assert_file_contains \
  "scripts/session-init.sh" \
  "OLD_HOOKS_INFO" \
  "Stale hook configuration detection variable is present"

assert_file_contains \
  "scripts/session-init.sh" \
  "jq.*\.hooks" \
  "hooks section detection logic is present"

assert_file_contains \
  "scripts/session-init.sh" \
  "INSTALLS_COUNT" \
  "New install count processing is present"

echo ""

# ============================================
# template-tracker.sh validation
# ============================================
echo "## template-tracker.sh"
echo ""

assert_script_runs \
  "scripts/template-tracker.sh" \
  "template-tracker.sh has valid syntax"

assert_file_contains \
  "scripts/template-tracker.sh" \
  "installs_details" \
  "Install details tracking variable is present"

assert_file_contains \
  "scripts/template-tracker.sh" \
  "installsCount" \
  "installsCount output is present"

assert_file_contains \
  "scripts/template-tracker.sh" \
  "installs_count" \
  "Install count variable is present"

echo ""

# ============================================
# harness-setup / update guidance validation
# ============================================
echo "## harness-setup update guidance"
echo ""

# harness-update is currently integrated into harness-setup.
assert_file_contains \
  "skills/harness-setup/SKILL.md" \
  "harness-update.*Harness アップデート|Harness アップデート.*harness-update" \
  "harness-update role is integrated into harness-setup"

assert_file_contains \
  "skills/harness-setup/SKILL.md" \
  "harness sync|harness doctor|sync.*doctor" \
  "harness-setup contains sync and verification steps"

assert_file_contains \
  "docs/update-summary-2025-12-23-24.md" \
  "古いフック設定.*hooks|カスタムフック保護" \
  "Update history describes hook detection and protection"

assert_file_contains \
  "docs/update-summary-2025-12-23-24.md" \
  "新しいスキルを自動検出|削除されたスキルも検出" \
  "Update history describes skill diff detection"

echo ""

# ============================================
# Results summary
# ============================================
echo "=================================================="
echo "Test results"
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
