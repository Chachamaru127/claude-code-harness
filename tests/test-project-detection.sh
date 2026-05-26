#!/bin/bash
# test-project-detection.sh
# Validation script for /harness-init project detection logic (3-value decision)
#
# Usage: ./tests/test-project-detection.sh
#
# Test cases:
# 1. Empty directory → "new"
# 2. Existing code (10+ files + src/) → "existing"
# 3. Template only (package.json present, 0 code files) → "ambiguous" (template_only)
# 4. README.md only → "ambiguous" (readme_only)
# 5. Code files 3-9 → "ambiguous" (few_files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR=$(mktemp -d)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

log_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  echo "  Expected: $2"
  echo "  Actual:   $3"
  FAILED=$((FAILED + 1))
}

# ================================
# Detection logic simulation
# ================================

detect_project_type() {
  local dir="$1"
  cd "$dir"

  # Count code files (exclude node_modules, .venv, dist)
  local code_count
  code_count=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
    ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/dist/*" ! -path "*/.next/*" ! -path "*/__pycache__/*" 2>/dev/null | wc -l | tr -d ' ')

  # Total file count (excluding hidden files)
  local total_files
  total_files=$(find . -type f ! -name ".*" ! -path "*/.*" 2>/dev/null | wc -l | tr -d ' ')

  # Check if only hidden files/directories exist
  local visible_files
  visible_files=$(ls 2>/dev/null | wc -l | tr -d ' ')

  # Check for source directory existence
  local has_src_dir=false
  [ -d "src" ] || [ -d "app" ] || [ -d "lib" ] && has_src_dir=true

  # Check for package manager file existence
  local has_package_file=false
  [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Cargo.toml" ] || [ -f "go.mod" ] && has_package_file=true

  # Detection logic

  # Step 1: Empty directory check
  if [ "$visible_files" -eq 0 ]; then
    echo "new"
    return
  fi

  # Check for .gitignore/.git only
  local only_git=true
  for f in $(ls -A 2>/dev/null); do
    if [ "$f" != ".git" ] && [ "$f" != ".gitignore" ]; then
      only_git=false
      break
    fi
  done
  if [ "$only_git" = true ]; then
    echo "new"
    return
  fi

  # Step 2: Substantial code existence check
  if [ "$code_count" -ge 10 ] && [ "$has_src_dir" = true ]; then
    echo "existing"
    return
  fi

  if [ "$has_package_file" = true ] && [ "$code_count" -ge 3 ]; then
    echo "existing"
    return
  fi

  # Step 3: Ambiguous case classification
  if [ "$has_package_file" = true ] && [ "$code_count" -eq 0 ]; then
    echo "ambiguous:template_only"
    return
  fi

  if [ "$code_count" -ge 1 ] && [ "$code_count" -lt 10 ]; then
    echo "ambiguous:few_files"
    return
  fi

  # README.md/LICENSE only
  local readme_only=true
  for f in $(ls 2>/dev/null); do
    if [ "$f" != "README.md" ] && [ "$f" != "LICENSE" ] && [ "$f" != "LICENSE.md" ]; then
      readme_only=false
      break
    fi
  done
  if [ "$readme_only" = true ]; then
    echo "ambiguous:readme_only"
    return
  fi

  # Config files only
  echo "ambiguous:scaffold_only"
}

# ================================
# Test cases
# ================================

echo "================================"
echo "Project Detection Logic Tests"
echo "================================"
echo ""

# Test 1: Empty directory
echo "--- Test 1: Empty directory ---"
TEST1_DIR="$TEST_DIR/test1_empty"
mkdir -p "$TEST1_DIR"
RESULT=$(detect_project_type "$TEST1_DIR")
if [ "$RESULT" = "new" ]; then
  log_pass "Empty directory → new"
else
  log_fail "Empty directory" "new" "$RESULT"
fi

# Test 2: .git only
echo "--- Test 2: .git only ---"
TEST2_DIR="$TEST_DIR/test2_git_only"
mkdir -p "$TEST2_DIR/.git"
RESULT=$(detect_project_type "$TEST2_DIR")
if [ "$RESULT" = "new" ]; then
  log_pass ".git only → new"
else
  log_fail ".git only" "new" "$RESULT"
fi

# Test 3: Existing project (10+ files + src/)
echo "--- Test 3: Existing project (10+ files + src/) ---"
TEST3_DIR="$TEST_DIR/test3_existing"
mkdir -p "$TEST3_DIR/src"
for i in $(seq 1 15); do
  touch "$TEST3_DIR/src/file$i.ts"
done
touch "$TEST3_DIR/package.json"
RESULT=$(detect_project_type "$TEST3_DIR")
if [ "$RESULT" = "existing" ]; then
  log_pass "10+ files + src/ → existing"
else
  log_fail "10+ files + src/" "existing" "$RESULT"
fi

# Test 4: Template only (package.json present, 0 code files)
echo "--- Test 4: Template only ---"
TEST4_DIR="$TEST_DIR/test4_template"
mkdir -p "$TEST4_DIR"
echo '{"name": "test"}' > "$TEST4_DIR/package.json"
touch "$TEST4_DIR/README.md"
RESULT=$(detect_project_type "$TEST4_DIR")
if [ "$RESULT" = "ambiguous:template_only" ]; then
  log_pass "package.json + 0 code files → ambiguous:template_only"
else
  log_fail "package.json + 0 code files" "ambiguous:template_only" "$RESULT"
fi

# Test 5: README.md only
echo "--- Test 5: README.md only ---"
TEST5_DIR="$TEST_DIR/test5_readme"
mkdir -p "$TEST5_DIR"
touch "$TEST5_DIR/README.md"
RESULT=$(detect_project_type "$TEST5_DIR")
if [ "$RESULT" = "ambiguous:readme_only" ]; then
  log_pass "README.md only → ambiguous:readme_only"
else
  log_fail "README.md only" "ambiguous:readme_only" "$RESULT"
fi

# Test 6: 5 code files (few)
echo "--- Test 6: 5 code files ---"
TEST6_DIR="$TEST_DIR/test6_few_files"
mkdir -p "$TEST6_DIR"
for i in $(seq 1 5); do
  touch "$TEST6_DIR/file$i.ts"
done
RESULT=$(detect_project_type "$TEST6_DIR")
if [[ "$RESULT" == ambiguous:few_files ]]; then
  log_pass "5 code files → ambiguous:few_files"
else
  log_fail "5 code files" "ambiguous:few_files" "$RESULT"
fi

# Test 7: package.json + 3+ code files → existing
echo "--- Test 7: package.json + 3 code files → existing ---"
TEST7_DIR="$TEST_DIR/test7_package_code"
mkdir -p "$TEST7_DIR"
echo '{"name": "test"}' > "$TEST7_DIR/package.json"
for i in $(seq 1 4); do
  touch "$TEST7_DIR/file$i.ts"
done
RESULT=$(detect_project_type "$TEST7_DIR")
if [ "$RESULT" = "existing" ]; then
  log_pass "package.json + 4 code files → existing"
else
  log_fail "package.json + 4 code files" "existing" "$RESULT"
fi

# ================================
# Result summary
# ================================

echo ""
echo "================================"
echo "Test Result Summary"
echo "================================"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -gt 0 ]; then
  exit 1
else
  echo ""
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
