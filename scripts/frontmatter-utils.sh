#!/bin/bash
# frontmatter-utils.sh
# Utility for extracting metadata from frontmatter
#
# Usage:
#   source frontmatter-utils.sh
#   get_frontmatter_version "CLAUDE.md"         # Get version
#   get_frontmatter_template "CLAUDE.md"        # Get template name
#   has_frontmatter "CLAUDE.md"                 # Check for frontmatter existence

# Check for frontmatter existence
has_frontmatter() {
  local file="$1"
  [ ! -f "$file" ] && return 1

  # Check if the file starts with ---
  head -1 "$file" | grep -q "^---$" || return 1

  # Check if _harness_version or _harness_template exists
  sed -n '/^---$/,/^---$/p' "$file" | grep -qE "_harness_(version|template):"
}

# Get version from frontmatter
# Returns an empty string if there is no frontmatter
get_frontmatter_version() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  local version=""

  # For JSON files, retrieve directly with jq (.json or .json.template)
  if [[ "$file" == *.json ]] || [[ "$file" == *.json.template ]]; then
    if command -v jq >/dev/null 2>&1; then
      version=$(jq -r '._harness_version // empty' "$file" 2>/dev/null)
    fi
    echo "$version"
    return 0
  fi

  # Check for YAML frontmatter existence
  if ! head -1 "$file" | grep -q "^---$"; then
    echo ""
    return 1
  fi

  # Extract _harness_version from YAML frontmatter
  version=$(sed -n '/^---$/,/^---$/p' "$file" | grep "_harness_version:" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$version"
}

# Get template name from frontmatter
get_frontmatter_template() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  local template=""

  # For JSON files, retrieve directly with jq (.json or .json.template)
  if [[ "$file" == *.json ]] || [[ "$file" == *.json.template ]]; then
    if command -v jq >/dev/null 2>&1; then
      template=$(jq -r '._harness_template // empty' "$file" 2>/dev/null)
    fi
    echo "$template"
    return 0
  fi

  # Check for YAML frontmatter existence
  if ! head -1 "$file" | grep -q "^---$"; then
    echo ""
    return 1
  fi

  # Extract _harness_template from YAML frontmatter
  template=$(sed -n '/^---$/,/^---$/p' "$file" | grep "_harness_template:" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$template"
}

# Get the version of a file (frontmatter takes priority, with fallback)
# Usage: get_file_version "CLAUDE.md" "generated-files.json"
get_file_version() {
  local file="$1"
  local fallback_registry="$2"

  # 1. Try to get version from frontmatter
  local version
  version=$(get_frontmatter_version "$file")

  if [ -n "$version" ]; then
    echo "$version"
    return 0
  fi

  # 2. Fallback: retrieve from generated-files.json
  if [ -n "$fallback_registry" ] && [ -f "$fallback_registry" ]; then
    if command -v jq >/dev/null 2>&1; then
      version=$(jq -r ".files[\"$file\"].templateVersion // empty" "$fallback_registry" 2>/dev/null)
      if [ -n "$version" ]; then
        echo "$version"
        return 0
      fi
    fi
  fi

  # Version unknown
  echo "unknown"
  return 1
}

# Get version from YAML comment format (for .yaml files)
get_yaml_comment_version() {
  local file="$1"

  [ ! -f "$file" ] && echo "" && return 1

  # Extract the # _harness_version: "x.y.z" format
  local version
  version=$(grep "# _harness_version:" "$file" | head -1 | sed 's/.*: *"//' | sed 's/".*//')

  echo "$version"
}
