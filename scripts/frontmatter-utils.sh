#!/bin/bash
# frontmatter-utils.sh
# フロントマターからメタデータを抽出するユーティリティ
#
# 使用方法:
#   source frontmatter-utils.sh
#   get_frontmatter_version "CLAUDE.md"         # バージョン取得
#   get_frontmatter_template "CLAUDE.md"        # テンプレート名取得
#   has_frontmatter "CLAUDE.md"                 # フロントマター存在チェック

# フロントマターの存在確認
has_frontmatter() {
  local file="$1"
  [ ! -f "$file" ] && return 1
  
  # ファイル先頭が --- で始まるかチェック
  head -1 "$file" | grep -q "^---$" || return 1
  
  # _harness_version または _harness_template が存在するか
  sed -n '/^---$/,/^---$/p' "$file" | grep -qE "_harness_(version|template):"
}

# フロントマターからバージョンを取得
# フロントマターがない場合は空文字を返す
get_frontmatter_version() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  local version=""

  # JSON ファイルの場合は jq で直接取得（.json または .json.template）
  if [[ "$file" == *.json ]] || [[ "$file" == *.json.template ]]; then
    if command -v jq >/dev/null 2>&1; then
      version=$(jq -r '._harness_version // empty' "$file" 2>/dev/null)
    fi
    echo "$version"
    return 0
  fi

  # YAML フロントマター存在チェック
  if ! head -1 "$file" | grep -q "^---$"; then
    echo ""
    return 1
  fi

  # YAML フロントマターから _harness_version を抽出
  version=$(sed -n '/^---$/,/^---$/p' "$file" | grep "_harness_version:" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$version"
}

# フロントマターからテンプレート名を取得
get_frontmatter_template() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  local template=""

  # JSON ファイルの場合は jq で直接取得（.json または .json.template）
  if [[ "$file" == *.json ]] || [[ "$file" == *.json.template ]]; then
    if command -v jq >/dev/null 2>&1; then
      template=$(jq -r '._harness_template // empty' "$file" 2>/dev/null)
    fi
    echo "$template"
    return 0
  fi

  # YAML フロントマター存在チェック
  if ! head -1 "$file" | grep -q "^---$"; then
    echo ""
    return 1
  fi

  # YAML フロントマターから _harness_template を抽出
  template=$(sed -n '/^---$/,/^---$/p' "$file" | grep "_harness_template:" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$template"
}

# ファイルのバージョンを取得（フロントマター優先、フォールバックあり）
# Usage: get_file_version "CLAUDE.md" "generated-files.json"
get_file_version() {
  local file="$1"
  local fallback_registry="$2"
  
  # 1. フロントマターからバージョン取得を試みる
  local version
  version=$(get_frontmatter_version "$file")
  
  if [ -n "$version" ]; then
    echo "$version"
    return 0
  fi
  
  # 2. フォールバック: generated-files.json から取得
  if [ -n "$fallback_registry" ] && [ -f "$fallback_registry" ]; then
    if command -v jq >/dev/null 2>&1; then
      version=$(jq -r ".files[\"$file\"].templateVersion // empty" "$fallback_registry" 2>/dev/null)
      if [ -n "$version" ]; then
        echo "$version"
        return 0
      fi
    fi
  fi
  
  # バージョン不明
  echo "unknown"
  return 1
}

# YAML コメント形式のバージョン取得（.yaml ファイル用）
get_yaml_comment_version() {
  local file="$1"
  
  [ ! -f "$file" ] && echo "" && return 1
  
  # # _harness_version: "x.y.z" 形式を抽出
  local version
  version=$(grep "# _harness_version:" "$file" | head -1 | sed 's/.*: *"//' | sed 's/".*//')
  
  echo "$version"
}
