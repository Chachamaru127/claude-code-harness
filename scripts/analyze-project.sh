#!/bin/bash
# analyze-project.sh
# プロジェクト構造を分析してルールのローカライズに必要な情報を収集
#
# 出力: JSON 形式でプロジェクト情報を出力

set -e

# ================================
# 言語・フレームワーク検出
# ================================
detect_languages() {
  local languages=()

  # JavaScript/TypeScript
  if [ -f "package.json" ]; then
    if grep -q '"typescript"' package.json 2>/dev/null || [ -f "tsconfig.json" ]; then
      languages+=("typescript")
    else
      languages+=("javascript")
    fi

    # フレームワーク検出
    if grep -q '"react"' package.json 2>/dev/null; then
      languages+=("react")
    fi
    if grep -q '"vue"' package.json 2>/dev/null; then
      languages+=("vue")
    fi
    if grep -q '"next"' package.json 2>/dev/null; then
      languages+=("nextjs")
    fi
    if grep -q '"@angular' package.json 2>/dev/null; then
      languages+=("angular")
    fi
  fi

  # Python
  if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    languages+=("python")
    if [ -f "pyproject.toml" ] && grep -q "django" pyproject.toml 2>/dev/null; then
      languages+=("django")
    fi
    if [ -f "requirements.txt" ] && grep -qi "flask" requirements.txt 2>/dev/null; then
      languages+=("flask")
    fi
    if [ -f "requirements.txt" ] && grep -qi "fastapi" requirements.txt 2>/dev/null; then
      languages+=("fastapi")
    fi
  fi

  # Go
  if [ -f "go.mod" ]; then
    languages+=("go")
  fi

  # Rust
  if [ -f "Cargo.toml" ]; then
    languages+=("rust")
  fi

  # Ruby
  if [ -f "Gemfile" ]; then
    languages+=("ruby")
    if grep -q "rails" Gemfile 2>/dev/null; then
      languages+=("rails")
    fi
  fi

  # Java/Kotlin
  if [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    if [ -f "build.gradle.kts" ] || find . -name "*.kt" -maxdepth 3 2>/dev/null | head -1 | grep -q .; then
      languages+=("kotlin")
    else
      languages+=("java")
    fi
  fi

  # デフォルト
  if [ ${#languages[@]} -eq 0 ]; then
    languages+=("unknown")
  fi

  # JSON配列として出力
  printf '%s\n' "${languages[@]}" | jq -R . | jq -s .
}

# ================================
# ソースディレクトリ検出
# ================================
detect_source_dirs() {
  local src_dirs=()

  # 一般的なソースディレクトリ
  for dir in src app lib source pkg cmd internal; do
    if [ -d "$dir" ]; then
      src_dirs+=("$dir")
    fi
  done

  # Next.js の pages/app ディレクトリ
  for dir in pages app; do
    if [ -d "$dir" ] && [ -f "package.json" ] && grep -q '"next"' package.json 2>/dev/null; then
      # 重複チェック
      local exists=false
      for existing in "${src_dirs[@]}"; do
        if [ "$existing" = "$dir" ]; then
          exists=true
          break
        fi
      done
      if [ "$exists" = false ]; then
        src_dirs+=("$dir")
      fi
    fi
  done

  # Python のパッケージディレクトリ（__init__.py があるディレクトリ）
  if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    for dir in */; do
      if [ -f "${dir}__init__.py" ] && [[ "$dir" != "tests/" ]] && [[ "$dir" != "test/" ]]; then
        src_dirs+=("${dir%/}")
      fi
    done
  fi

  # デフォルト（ルート）
  if [ ${#src_dirs[@]} -eq 0 ]; then
    src_dirs+=(".")
  fi

  # JSON 配列を生成
  printf '%s\n' "${src_dirs[@]}" | jq -R . | jq -s .
}

# ================================
# テストディレクトリ検出
# ================================
detect_test_dirs() {
  local test_dirs=()

  # 一般的なテストディレクトリ
  for dir in tests test __tests__ spec e2e cypress; do
    if [ -d "$dir" ]; then
      test_dirs+=("$dir")
    fi
  done

  # src 内のテストディレクトリ
  if [ -d "src/__tests__" ]; then
    test_dirs+=("src/__tests__")
  fi

  # テストファイルのパターン検出
  local has_colocated_tests=false
  if find . -maxdepth 4 \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null | head -1 | grep -q .; then
    has_colocated_tests=true
  fi

  # JSON オブジェクトを生成
  local dirs_json="[]"
  if [ ${#test_dirs[@]} -gt 0 ]; then
    dirs_json=$(printf '%s\n' "${test_dirs[@]}" | jq -R . | jq -s .)
  fi

  echo "{\"dirs\": $dirs_json, \"has_colocated_tests\": $has_colocated_tests}"
}

# ================================
# ファイル拡張子検出
# ================================
detect_extensions() {
  local result="["
  local first=true

  # 主要な拡張子をカウント
  for ext in ts tsx js jsx py rb go rs java kt swift c cpp h hpp cs php md sh; do
    count=$(find . -maxdepth 5 -name "*.$ext" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
      if [ "$first" = true ]; then
        first=false
      else
        result+=","
      fi
      result+="{\"ext\":\"$ext\",\"count\":$count}"
    fi
  done

  result+="]"
  echo "$result"
}

# ================================
# メイン出力
# ================================
echo "{"
echo "  \"languages\": $(detect_languages),"
echo "  \"source_dirs\": $(detect_source_dirs),"
echo "  \"test_info\": $(detect_test_dirs),"
echo "  \"extensions\": $(detect_extensions),"
echo "  \"project_name\": \"$(basename "$(pwd)")\""
echo "}"
