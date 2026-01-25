#!/bin/bash
# test-project-detection.sh
# /harness-init のプロジェクト判定ロジック（3値判定）の検証スクリプト
#
# Usage: ./tests/test-project-detection.sh
#
# テストケース:
# 1. 空ディレクトリ → "new"
# 2. 既存コードあり（10+ ファイル + src/） → "existing"
# 3. テンプレのみ（package.json あり、コード 0） → "ambiguous" (template_only)
# 4. README.md のみ → "ambiguous" (readme_only)
# 5. コードファイル 3〜9 → "ambiguous" (few_files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR=$(mktemp -d)

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# カウンター
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
  echo "  期待: $2"
  echo "  実際: $3"
  FAILED=$((FAILED + 1))
}

# ================================
# 判定ロジックのシミュレーション
# ================================

detect_project_type() {
  local dir="$1"
  cd "$dir"

  # コードファイル数のカウント（node_modules, .venv, dist 除外）
  local code_count
  code_count=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.rs" -o -name "*.go" \) \
    ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/dist/*" ! -path "*/.next/*" ! -path "*/__pycache__/*" 2>/dev/null | wc -l | tr -d ' ')

  # 全ファイル数（隠しファイル除く）
  local total_files
  total_files=$(find . -type f ! -name ".*" ! -path "*/.*" 2>/dev/null | wc -l | tr -d ' ')

  # 隠しファイル/ディレクトリのみかチェック
  local visible_files
  visible_files=$(ls 2>/dev/null | wc -l | tr -d ' ')

  # ソースディレクトリの存在確認
  local has_src_dir=false
  [ -d "src" ] || [ -d "app" ] || [ -d "lib" ] && has_src_dir=true

  # パッケージマネージャファイルの存在確認
  local has_package_file=false
  [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Cargo.toml" ] || [ -f "go.mod" ] && has_package_file=true

  # 判定ロジック

  # Step 1: 空ディレクトリチェック
  if [ "$visible_files" -eq 0 ]; then
    echo "new"
    return
  fi

  # .gitignore/.git のみチェック
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

  # Step 2: 実質的なコード存在チェック
  if [ "$code_count" -ge 10 ] && [ "$has_src_dir" = true ]; then
    echo "existing"
    return
  fi

  if [ "$has_package_file" = true ] && [ "$code_count" -ge 3 ]; then
    echo "existing"
    return
  fi

  # Step 3: 曖昧ケースの分類
  if [ "$has_package_file" = true ] && [ "$code_count" -eq 0 ]; then
    echo "ambiguous:template_only"
    return
  fi

  if [ "$code_count" -ge 1 ] && [ "$code_count" -lt 10 ]; then
    echo "ambiguous:few_files"
    return
  fi

  # README.md/LICENSE のみ
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

  # 設定ファイルのみ
  echo "ambiguous:scaffold_only"
}

# ================================
# テストケース
# ================================

echo "================================"
echo "プロジェクト判定ロジック テスト"
echo "================================"
echo ""

# テスト 1: 空ディレクトリ
echo "--- Test 1: 空ディレクトリ ---"
TEST1_DIR="$TEST_DIR/test1_empty"
mkdir -p "$TEST1_DIR"
RESULT=$(detect_project_type "$TEST1_DIR")
if [ "$RESULT" = "new" ]; then
  log_pass "空ディレクトリ → new"
else
  log_fail "空ディレクトリ" "new" "$RESULT"
fi

# テスト 2: .git のみ
echo "--- Test 2: .git のみ ---"
TEST2_DIR="$TEST_DIR/test2_git_only"
mkdir -p "$TEST2_DIR/.git"
RESULT=$(detect_project_type "$TEST2_DIR")
if [ "$RESULT" = "new" ]; then
  log_pass ".git のみ → new"
else
  log_fail ".git のみ" "new" "$RESULT"
fi

# テスト 3: 既存プロジェクト（10+ ファイル + src/）
echo "--- Test 3: 既存プロジェクト（10+ ファイル + src/）---"
TEST3_DIR="$TEST_DIR/test3_existing"
mkdir -p "$TEST3_DIR/src"
for i in $(seq 1 15); do
  touch "$TEST3_DIR/src/file$i.ts"
done
touch "$TEST3_DIR/package.json"
RESULT=$(detect_project_type "$TEST3_DIR")
if [ "$RESULT" = "existing" ]; then
  log_pass "10+ ファイル + src/ → existing"
else
  log_fail "10+ ファイル + src/" "existing" "$RESULT"
fi

# テスト 4: テンプレのみ（package.json あり、コード 0）
echo "--- Test 4: テンプレのみ ---"
TEST4_DIR="$TEST_DIR/test4_template"
mkdir -p "$TEST4_DIR"
echo '{"name": "test"}' > "$TEST4_DIR/package.json"
touch "$TEST4_DIR/README.md"
RESULT=$(detect_project_type "$TEST4_DIR")
if [ "$RESULT" = "ambiguous:template_only" ]; then
  log_pass "package.json + コード 0 → ambiguous:template_only"
else
  log_fail "package.json + コード 0" "ambiguous:template_only" "$RESULT"
fi

# テスト 5: README.md のみ
echo "--- Test 5: README.md のみ ---"
TEST5_DIR="$TEST_DIR/test5_readme"
mkdir -p "$TEST5_DIR"
touch "$TEST5_DIR/README.md"
RESULT=$(detect_project_type "$TEST5_DIR")
if [ "$RESULT" = "ambiguous:readme_only" ]; then
  log_pass "README.md のみ → ambiguous:readme_only"
else
  log_fail "README.md のみ" "ambiguous:readme_only" "$RESULT"
fi

# テスト 6: コードファイル 5 個（少量）
echo "--- Test 6: コードファイル 5 個 ---"
TEST6_DIR="$TEST_DIR/test6_few_files"
mkdir -p "$TEST6_DIR"
for i in $(seq 1 5); do
  touch "$TEST6_DIR/file$i.ts"
done
RESULT=$(detect_project_type "$TEST6_DIR")
if [[ "$RESULT" == ambiguous:few_files ]]; then
  log_pass "コード 5 ファイル → ambiguous:few_files"
else
  log_fail "コード 5 ファイル" "ambiguous:few_files" "$RESULT"
fi

# テスト 7: package.json + コード 3 以上 → existing
echo "--- Test 7: package.json + コード 3 → existing ---"
TEST7_DIR="$TEST_DIR/test7_package_code"
mkdir -p "$TEST7_DIR"
echo '{"name": "test"}' > "$TEST7_DIR/package.json"
for i in $(seq 1 4); do
  touch "$TEST7_DIR/file$i.ts"
done
RESULT=$(detect_project_type "$TEST7_DIR")
if [ "$RESULT" = "existing" ]; then
  log_pass "package.json + コード 4 → existing"
else
  log_fail "package.json + コード 4" "existing" "$RESULT"
fi

# ================================
# 結果サマリー
# ================================

echo ""
echo "================================"
echo "テスト結果サマリー"
echo "================================"
echo -e "合格: ${GREEN}${PASSED}${NC}"
echo -e "失敗: ${RED}${FAILED}${NC}"

if [ "$FAILED" -gt 0 ]; then
  exit 1
else
  echo ""
  echo -e "${GREEN}すべてのテストが合格しました！${NC}"
  exit 0
fi
