#!/bin/bash
# analyze-project.sh
# プロジェクト分析スクリプト - 適応型セットアップ用
#
# Usage: ./scripts/analyze-project.sh [project_path]
# Output: JSON形式のプロジェクト分析結果
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set -euo pipefail

# Load cross-platform path utilities (if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
fi

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH"

# JSON出力用の一時ファイル（自動クリーンアップ付き）
RESULT_FILE=$(mktemp)
trap 'rm -f "$RESULT_FILE"' EXIT

# ================================
# ヘルパー関数
# ================================

json_escape() {
  echo -n "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""'
}

file_exists() {
  [ -f "$1" ] && echo "true" || echo "false"
}

dir_exists() {
  [ -d "$1" ] && echo "true" || echo "false"
}

# ================================
# 1. 技術スタック検出
# ================================

detect_tech_stack() {
  local techs=()
  local frameworks=()
  local testing=()

  # Node.js / JavaScript / TypeScript
  if [ -f "package.json" ]; then
    techs+=("nodejs")

    # TypeScript
    if [ -f "tsconfig.json" ]; then
      techs+=("typescript")
    fi

    # package.json を1回だけ読み込んでキャッシュ（I/O最適化: 12回→1回）
    local pkg_content
    pkg_content=$(cat package.json 2>/dev/null) || pkg_content=""

    # フレームワーク検出（キャッシュした内容でパターンマッチ）
    [[ "$pkg_content" == *'"react"'* ]] && frameworks+=("react")
    [[ "$pkg_content" == *'"next"'* ]] && frameworks+=("nextjs")
    [[ "$pkg_content" == *'"vue"'* ]] && frameworks+=("vue")
    [[ "$pkg_content" == *'"nuxt"'* ]] && frameworks+=("nuxt")
    [[ "$pkg_content" == *'"express"'* ]] && frameworks+=("express")
    [[ "$pkg_content" == *'"fastify"'* ]] && frameworks+=("fastify")
    [[ "$pkg_content" == *'"svelte"'* ]] && frameworks+=("svelte")

    # テストフレームワーク
    [[ "$pkg_content" == *'"jest"'* ]] && testing+=("jest")
    [[ "$pkg_content" == *'"vitest"'* ]] && testing+=("vitest")
    [[ "$pkg_content" == *'"mocha"'* ]] && testing+=("mocha")
    [[ "$pkg_content" == *'"playwright"'* ]] && testing+=("playwright")
    [[ "$pkg_content" == *'"cypress"'* ]] && testing+=("cypress")
  fi

  # Python
  if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    techs+=("python")

    if [ -f "pyproject.toml" ]; then
      # pyproject.toml を1回だけ読み込んでキャッシュ
      local pyproject_content
      pyproject_content=$(cat pyproject.toml 2>/dev/null) || pyproject_content=""

      [[ "$pyproject_content" == *"django"* ]] && frameworks+=("django")
      [[ "$pyproject_content" == *"fastapi"* ]] && frameworks+=("fastapi")
      [[ "$pyproject_content" == *"flask"* ]] && frameworks+=("flask")
      [[ "$pyproject_content" == *"pytest"* ]] && testing+=("pytest")
    fi
  fi

  # Rust
  if [ -f "Cargo.toml" ]; then
    techs+=("rust")
  fi

  # Go
  if [ -f "go.mod" ]; then
    techs+=("go")
  fi

  # Ruby
  if [ -f "Gemfile" ]; then
    techs+=("ruby")
    if grep -q "rails" Gemfile 2>/dev/null; then
      frameworks+=("rails")
    fi
    if grep -q "rspec" Gemfile 2>/dev/null; then
      testing+=("rspec")
    fi
  fi

  # Java
  if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    techs+=("java")
    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
      frameworks+=("gradle")
    fi
  fi

  # 出力
  if [ ${#techs[@]} -eq 0 ]; then
    echo "\"technologies\": [],"
  else
    echo "\"technologies\": [$(printf '"%s",' "${techs[@]}" | sed 's/,$//')],"
  fi

  if [ ${#frameworks[@]} -eq 0 ]; then
    echo "\"frameworks\": [],"
  else
    echo "\"frameworks\": [$(printf '"%s",' "${frameworks[@]}" | sed 's/,$//')],"
  fi

  if [ ${#testing[@]} -eq 0 ]; then
    echo "\"testing\": []"
  else
    echo "\"testing\": [$(printf '"%s",' "${testing[@]}" | sed 's/,$//')]"
  fi
}

# ================================
# 2. 既存コーディング規約検出
# ================================

detect_coding_standards() {
  local linters=()
  local formatters=()
  local strict_mode="false"

  # ESLint
  for eslint_file in .eslintrc .eslintrc.js .eslintrc.json .eslintrc.yml .eslintrc.yaml eslint.config.js eslint.config.mjs; do
    if [ -f "$eslint_file" ]; then
      linters+=("eslint:$eslint_file")
      break
    fi
  done

  # Prettier
  for prettier_file in .prettierrc .prettierrc.js .prettierrc.json .prettierrc.yml .prettierrc.yaml prettier.config.js; do
    if [ -f "$prettier_file" ]; then
      formatters+=("prettier:$prettier_file")
      break
    fi
  done

  # EditorConfig
  if [ -f ".editorconfig" ]; then
    formatters+=("editorconfig:.editorconfig")
  fi

  # TypeScript strict mode
  if [ -f "tsconfig.json" ]; then
    if grep -q '"strict":\s*true' tsconfig.json 2>/dev/null; then
      strict_mode="true"
    fi
  fi

  # Biome
  if [ -f "biome.json" ]; then
    linters+=("biome:biome.json")
    formatters+=("biome:biome.json")
  fi

  # Ruff (Python)
  if [ -f "ruff.toml" ] || [ -f ".ruff.toml" ]; then
    linters+=("ruff:ruff.toml")
  fi

  # Black (Python)
  if [ -f "pyproject.toml" ] && grep -q "black" pyproject.toml 2>/dev/null; then
    formatters+=("black:pyproject.toml")
  fi

  if [ ${#linters[@]} -eq 0 ]; then
    echo "\"linters\": [],"
  else
    echo "\"linters\": [$(printf '"%s",' "${linters[@]}" | sed 's/,$//')],"
  fi

  if [ ${#formatters[@]} -eq 0 ]; then
    echo "\"formatters\": [],"
  else
    echo "\"formatters\": [$(printf '"%s",' "${formatters[@]}" | sed 's/,$//')],"
  fi

  echo "\"typescript_strict\": $strict_mode"
}

# ================================
# 3. 既存ドキュメント検出
# ================================

detect_documentation() {
  local docs=()

  [ -f "README.md" ] && docs+=("README.md")
  [ -f "CONTRIBUTING.md" ] && docs+=("CONTRIBUTING.md")
  [ -f "CODE_OF_CONDUCT.md" ] && docs+=("CODE_OF_CONDUCT.md")
  [ -f "SECURITY.md" ] && docs+=("SECURITY.md")
  [ -f "CHANGELOG.md" ] && docs+=("CHANGELOG.md")
  [ -d "docs" ] && docs+=("docs/")

  if [ ${#docs[@]} -eq 0 ]; then
    echo "\"documentation\": []"
  else
    echo "\"documentation\": [$(printf '"%s",' "${docs[@]}" | sed 's/,$//')]"
  fi
}

# ================================
# 4. 既存 Claude/Cursor 設定検出
# ================================

detect_existing_setup() {
  local claude_files=()
  local cursor_files=()

  # Claude 設定
  [ -f "CLAUDE.md" ] && claude_files+=("CLAUDE.md")
  [ -f ".claude/CLAUDE.md" ] && claude_files+=(".claude/CLAUDE.md")
  [ -d ".claude/rules" ] && claude_files+=(".claude/rules/")
  [ -d ".claude/memory" ] && claude_files+=(".claude/memory/")

  # Cursor 設定
  [ -d ".cursor/commands" ] && cursor_files+=(".cursor/commands/")
  [ -d ".cursor/rules" ] && cursor_files+=(".cursor/rules/")

  # バージョンファイル
  local version="none"
  if [ -f ".claude-code-harness-version" ]; then
    version=$(grep "^version:" .claude-code-harness-version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
  fi

  if [ ${#claude_files[@]} -eq 0 ]; then
    echo "\"claude_config\": [],"
  else
    echo "\"claude_config\": [$(printf '"%s",' "${claude_files[@]}" | sed 's/,$//')],"
  fi

  if [ ${#cursor_files[@]} -eq 0 ]; then
    echo "\"cursor_config\": [],"
  else
    echo "\"cursor_config\": [$(printf '"%s",' "${cursor_files[@]}" | sed 's/,$//')],"
  fi

  echo "\"harness_version\": \"$version\""
}

# ================================
# 5. Git 情報検出
# ================================

detect_git_info() {
  if [ ! -d ".git" ]; then
    echo "\"git\": null"
    return
  fi

  # 最近のコミットプレフィックス分析
  local commit_prefixes=$(git log --oneline -50 2>/dev/null | grep -oE "^[a-f0-9]+ (feat|fix|docs|refactor|test|chore|style|perf|ci|build|revert):" | cut -d' ' -f2 | sort | uniq -c | sort -rn | head -5 || echo "")

  # ブランチ名
  local branch=$(git branch --show-current 2>/dev/null || echo "unknown")

  # コミット規約の検出
  local conventional_commits="false"
  if echo "$commit_prefixes" | grep -qE "(feat|fix|chore):" 2>/dev/null; then
    conventional_commits="true"
  fi

  echo "\"git\": {"
  echo "  \"branch\": \"$branch\","
  echo "  \"conventional_commits\": $conventional_commits"
  echo "}"
}

# ================================
# 6. 重要事項の検出（キーワードベース）
# ================================

detect_important_patterns() {
  local patterns=()

  # 検索対象ファイル（存在するもののみ）
  local search_files=""
  for f in README.md CONTRIBUTING.md AGENTS.md CLAUDE.md; do
    [ -f "$f" ] && search_files="$search_files $f"
  done

  # セキュリティ関連（日本語対応）
  if [ -f "SECURITY.md" ] || grep -riqE "security|セキュリティ|バリデーション|SQLインジェクション|認証" $search_files 2>/dev/null; then
    patterns+=("security")
  fi

  # テスト重視（日本語対応）
  if grep -riqE "test coverage|coverage.*%|must have tests|require.*test|テスト.*必須|カバレッジ|ユニットテスト" $search_files 2>/dev/null; then
    patterns+=("testing-required")
  fi

  # アクセシビリティ（日本語対応）
  if grep -riqE "accessibility|a11y|wcag|aria|アクセシビリティ|スクリーンリーダー" $search_files package.json 2>/dev/null; then
    patterns+=("accessibility")
  fi

  # パフォーマンス（日本語対応）
  if grep -riqE "performance|core web vitals|lighthouse|パフォーマンス|レスポンス.*ms|N\+1" $search_files 2>/dev/null; then
    patterns+=("performance")
  fi

  # 国際化
  if grep -riqE "i18n|internationalization|localization|国際化" $search_files package.json 2>/dev/null; then
    patterns+=("i18n")
  fi

  if [ ${#patterns[@]} -eq 0 ]; then
    echo "\"important_patterns\": []"
  else
    echo "\"important_patterns\": [$(printf '"%s",' "${patterns[@]}" | sed 's/,$//')]"
  fi
}

# ================================
# メイン: JSON 出力
# ================================

echo "{"
echo "\"project_path\": \"$(pwd)\","
echo "\"project_name\": \"$(basename "$(pwd)")\","
echo "\"analyzed_at\": \"$(date -Iseconds)\","

# 各セクション
detect_tech_stack
echo ","
detect_coding_standards
echo ","
detect_documentation
echo ","
detect_existing_setup
echo ","
detect_git_info
echo ","
detect_important_patterns

echo "}"
