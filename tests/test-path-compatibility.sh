#!/bin/bash
# test-path-compatibility.sh
# Cross-platform path utility tests for Windows/Mac/Linux compatibility
#
# Usage: ./tests/test-path-compatibility.sh
#
# Tests:
# - OS detection
# - Path type detection (absolute vs relative)
# - Path normalization
# - Path comparison
# - Path relationship checking

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
  echo -e "${GREEN}PASS${NC}: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  echo "       Expected: $2"
  echo "       Got:      $3"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Load the path utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$HARNESS_ROOT/scripts/path-utils.sh" ]; then
  echo -e "${RED}Error${NC}: path-utils.sh not found: $HARNESS_ROOT/scripts/path-utils.sh"
  exit 1
fi

# shellcheck source=../scripts/path-utils.sh
source "$HARNESS_ROOT/scripts/path-utils.sh"

echo "=========================================="
echo "Cross-platform path utility tests"
echo "=========================================="
echo ""

# ============================================
# Test 1: OS Detection
# ============================================
echo "--- Test Suite 1: OS Detection ---"

DETECTED_OS=$(detect_os)
case "$DETECTED_OS" in
  darwin|linux|windows)
    pass "detect_os returns valid OS: $DETECTED_OS"
    ;;
  unknown)
    echo -e "${YELLOW}WARN${NC}: detect_os returned 'unknown' - this may be expected on unusual systems"
    ;;
  *)
    fail "detect_os returned unexpected value" "darwin|linux|windows|unknown" "$DETECTED_OS"
    ;;
esac

echo ""

# ============================================
# Test 2: Absolute Path Detection
# ============================================
echo "--- Test Suite 2: Absolute Path Detection ---"

# Unix absolute paths
if is_absolute_path "/home/user/project"; then
  pass "is_absolute_path: /home/user/project (Unix)"
else
  fail "is_absolute_path: /home/user/project (Unix)" "true" "false"
fi

if is_absolute_path "/"; then
  pass "is_absolute_path: / (Unix root)"
else
  fail "is_absolute_path: / (Unix root)" "true" "false"
fi

# Windows absolute paths (forward slash)
if is_absolute_path "C:/Users/name"; then
  pass "is_absolute_path: C:/Users/name (Windows forward slash)"
else
  fail "is_absolute_path: C:/Users/name (Windows forward slash)" "true" "false"
fi

# Windows absolute paths (backslash)
if is_absolute_path 'C:\Users\name'; then
  pass "is_absolute_path: C:\\Users\\name (Windows backslash)"
else
  fail "is_absolute_path: C:\\Users\\name (Windows backslash)" "true" "false"
fi

# Windows drive root
if is_absolute_path "D:/"; then
  pass "is_absolute_path: D:/ (Windows drive root)"
else
  fail "is_absolute_path: D:/ (Windows drive root)" "true" "false"
fi

# Lowercase drive letter
if is_absolute_path "c:/users/name"; then
  pass "is_absolute_path: c:/users/name (lowercase drive)"
else
  fail "is_absolute_path: c:/users/name (lowercase drive)" "true" "false"
fi

# Relative paths (should be false)
if ! is_absolute_path "relative/path"; then
  pass "is_absolute_path: relative/path (relative - should be false)"
else
  fail "is_absolute_path: relative/path" "false" "true"
fi

if ! is_absolute_path "./current/dir"; then
  pass "is_absolute_path: ./current/dir (relative - should be false)"
else
  fail "is_absolute_path: ./current/dir" "false" "true"
fi

if ! is_absolute_path "../parent/dir"; then
  pass "is_absolute_path: ../parent/dir (relative - should be false)"
else
  fail "is_absolute_path: ../parent/dir" "false" "true"
fi

echo ""

# ============================================
# Test 3: Path Normalization
# ============================================
echo "--- Test Suite 3: Path Normalization ---"

# Backslash to forward slash
RESULT=$(normalize_path 'C:\Users\name\project')
if [ "$RESULT" = "C:/Users/name/project" ]; then
  pass "normalize_path: backslash to forward slash"
else
  fail "normalize_path: backslash to forward slash" "C:/Users/name/project" "$RESULT"
fi

# Remove trailing slash
RESULT=$(normalize_path "/home/user/project/")
if [ "$RESULT" = "/home/user/project" ]; then
  pass "normalize_path: remove trailing slash"
else
  fail "normalize_path: remove trailing slash" "/home/user/project" "$RESULT"
fi

# Keep Windows drive root trailing slash
RESULT=$(normalize_path "C:/")
if [ "$RESULT" = "C:/" ]; then
  pass "normalize_path: keep Windows drive root slash"
else
  fail "normalize_path: keep Windows drive root slash" "C:/" "$RESULT"
fi

# Collapse multiple slashes
INPUT_PATH="/home//user///project"
RESULT=$(normalize_path "$INPUT_PATH")
EXPECTED="/home/user/project"
if [ "$RESULT" = "$EXPECTED" ]; then
  pass "normalize_path: collapse multiple slashes"
else
  fail "normalize_path: collapse multiple slashes" "$EXPECTED" "$RESULT"
fi

# Mixed slashes
RESULT=$(normalize_path 'C:\Users/name\project/')
if [ "$RESULT" = "C:/Users/name/project" ]; then
  pass "normalize_path: mixed slashes"
else
  fail "normalize_path: mixed slashes" "C:/Users/name/project" "$RESULT"
fi

echo ""

# ============================================
# Test 4: Path Comparison
# ============================================
echo "--- Test Suite 4: Path Comparison ---"

# Same path
if paths_equal "/home/user" "/home/user"; then
  pass "paths_equal: identical paths"
else
  fail "paths_equal: identical paths" "true" "false"
fi

# Normalized comparison
if paths_equal "/home/user/" "/home/user"; then
  pass "paths_equal: with/without trailing slash"
else
  fail "paths_equal: with/without trailing slash" "true" "false"
fi

# Windows path normalization
if paths_equal 'C:\Users\name' "C:/Users/name"; then
  pass "paths_equal: Windows backslash vs forward slash"
else
  fail "paths_equal: Windows backslash vs forward slash" "true" "false"
fi

# Different paths
if ! paths_equal "/home/user1" "/home/user2"; then
  pass "paths_equal: different paths (should be false)"
else
  fail "paths_equal: different paths" "false" "true"
fi

echo ""

# ============================================
# Test 5: Path Relationship (is_path_under)
# ============================================
echo "--- Test Suite 5: Path Relationship ---"

# Child is under parent
if is_path_under "/home/user/project/file.txt" "/home/user"; then
  pass "is_path_under: file under parent directory"
else
  fail "is_path_under: file under parent directory" "true" "false"
fi

# Direct child
if is_path_under "/home/user/project" "/home/user"; then
  pass "is_path_under: direct child directory"
else
  fail "is_path_under: direct child directory" "true" "false"
fi

# Same path
if is_path_under "/home/user" "/home/user"; then
  pass "is_path_under: same path"
else
  fail "is_path_under: same path" "true" "false"
fi

# Not under (sibling)
if ! is_path_under "/home/user2/project" "/home/user1"; then
  pass "is_path_under: sibling directories (should be false)"
else
  fail "is_path_under: sibling directories" "false" "true"
fi

# Windows paths
if is_path_under "C:/Users/name/project/file.txt" "C:/Users/name"; then
  pass "is_path_under: Windows paths"
else
  fail "is_path_under: Windows paths" "true" "false"
fi

# Mixed slash styles
if is_path_under 'C:\Users\name\project' "C:/Users/name"; then
  pass "is_path_under: mixed slash styles"
else
  fail "is_path_under: mixed slash styles" "true" "false"
fi

echo ""

# ============================================
# Test 6: Basename and Dirname
# ============================================
echo "--- Test Suite 6: Basename and Dirname ---"

# get_basename
RESULT=$(get_basename "/home/user/file.txt")
if [ "$RESULT" = "file.txt" ]; then
  pass "get_basename: /home/user/file.txt"
else
  fail "get_basename: /home/user/file.txt" "file.txt" "$RESULT"
fi

RESULT=$(get_basename 'C:\Users\name\file.txt')
if [ "$RESULT" = "file.txt" ]; then
  pass "get_basename: C:\\Users\\name\\file.txt"
else
  fail "get_basename: C:\\Users\\name\\file.txt" "file.txt" "$RESULT"
fi

# get_dirname
RESULT=$(get_dirname "/home/user/file.txt")
if [ "$RESULT" = "/home/user" ]; then
  pass "get_dirname: /home/user/file.txt"
else
  fail "get_dirname: /home/user/file.txt" "/home/user" "$RESULT"
fi

RESULT=$(get_dirname 'C:\Users\name\file.txt')
if [ "$RESULT" = "C:/Users/name" ]; then
  pass "get_dirname: C:\\Users\\name\\file.txt"
else
  fail "get_dirname: C:\\Users\\name\\file.txt" "C:/Users/name" "$RESULT"
fi

# get_extension
RESULT=$(get_extension "file.txt")
if [ "$RESULT" = "txt" ]; then
  pass "get_extension: file.txt"
else
  fail "get_extension: file.txt" "txt" "$RESULT"
fi

RESULT=$(get_extension "file.tar.gz")
if [ "$RESULT" = "gz" ]; then
  pass "get_extension: file.tar.gz"
else
  fail "get_extension: file.tar.gz" "gz" "$RESULT"
fi

RESULT=$(get_extension "no_extension")
if [ "$RESULT" = "" ]; then
  pass "get_extension: no_extension (empty)"
else
  fail "get_extension: no_extension" "" "$RESULT"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "Test result summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
