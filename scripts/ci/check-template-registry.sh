#!/bin/bash
# check-template-registry.sh
# CI: templates/ と template-registry.json の整合性チェック
#
# チェック項目:
# 1. templates/ 内の *.template ファイルが registry に登録されているか
# 2. registry 内のファイルが templates/ に存在するか
# 3. templateVersion が有効な形式か

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$PLUGIN_ROOT/templates/template-registry.json"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"

echo "=== Template Registry Consistency Check ==="
echo ""

ERRORS=0

# jq の存在確認
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq is not installed. Skipping detailed checks."
  exit 0
fi

# registry ファイルの存在確認
if [ ! -f "$REGISTRY_FILE" ]; then
  echo "❌ template-registry.json not found"
  exit 1
fi

# JSON 構文チェック
if ! jq empty "$REGISTRY_FILE" 2>/dev/null; then
  echo "❌ template-registry.json has invalid JSON syntax"
  exit 1
fi
echo "✅ template-registry.json: valid JSON"

# 1. templates/ 内のファイルが registry に登録されているかチェック
echo ""
echo "--- Check 1: Template files in registry ---"

TEMPLATE_FILES=$(find "$TEMPLATES_DIR" -name "*.template" -type f | sort)
MISSING_IN_REGISTRY=0

for template_path in $TEMPLATE_FILES; do
  # templates/ からの相対パスを取得
  rel_path="${template_path#$TEMPLATES_DIR/}"

  # registry に存在するか確認
  if ! jq -e ".templates[\"$rel_path\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
    echo "❌ Missing in registry: $rel_path"
    MISSING_IN_REGISTRY=$((MISSING_IN_REGISTRY + 1))
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$MISSING_IN_REGISTRY" -eq 0 ]; then
  echo "✅ All template files are registered"
else
  echo "⚠️  $MISSING_IN_REGISTRY file(s) missing in registry"
fi

# 2. registry 内のファイルが templates/ に存在するかチェック
echo ""
echo "--- Check 2: Registry entries exist in templates/ ---"

MISSING_FILES=0
REGISTRY_KEYS=$(jq -r '.templates | keys[]' "$REGISTRY_FILE")

for key in $REGISTRY_KEYS; do
  template_path="$TEMPLATES_DIR/$key"
  if [ ! -f "$template_path" ]; then
    echo "❌ Template not found: $key"
    MISSING_FILES=$((MISSING_FILES + 1))
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$MISSING_FILES" -eq 0 ]; then
  echo "✅ All registry entries have corresponding template files"
else
  echo "⚠️  $MISSING_FILES registry entry/entries have no template file"
fi

# 3. templateVersion 形式チェック
echo ""
echo "--- Check 3: Template version format ---"

INVALID_VERSIONS=0

for key in $REGISTRY_KEYS; do
  version=$(jq -r ".templates[\"$key\"].templateVersion // \"\"" "$REGISTRY_FILE")

  if [ -z "$version" ]; then
    echo "❌ Missing version: $key"
    INVALID_VERSIONS=$((INVALID_VERSIONS + 1))
    ERRORS=$((ERRORS + 1))
  elif ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Invalid version format: $key (got: $version)"
    INVALID_VERSIONS=$((INVALID_VERSIONS + 1))
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$INVALID_VERSIONS" -eq 0 ]; then
  echo "✅ All template versions are valid"
else
  echo "⚠️  $INVALID_VERSIONS invalid version(s) found"
fi

# 4. output パスの重複チェック
echo ""
echo "--- Check 4: No duplicate output paths ---"

DUPLICATE_OUTPUTS=$(jq -r '.templates | to_entries | map(.value.output) | group_by(.) | map(select(length > 1)) | flatten | .[]' "$REGISTRY_FILE" 2>/dev/null)

if [ -n "$DUPLICATE_OUTPUTS" ]; then
  echo "❌ Duplicate output paths found:"
  echo "$DUPLICATE_OUTPUTS"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ No duplicate output paths"
fi

# 結果サマリー
echo ""
echo "=== Summary ==="
TOTAL_TEMPLATES=$(echo "$TEMPLATE_FILES" | wc -l | tr -d ' ')
REGISTRY_COUNT=$(jq '.templates | length' "$REGISTRY_FILE")
TRACKED_COUNT=$(jq '[.templates | to_entries[] | select(.value.tracked == true)] | length' "$REGISTRY_FILE")

echo "Templates in directory: $TOTAL_TEMPLATES"
echo "Entries in registry: $REGISTRY_COUNT"
echo "Tracked files: $TRACKED_COUNT"
echo ""

if [ "$ERRORS" -eq 0 ]; then
  echo "✅ All checks passed!"
  exit 0
else
  echo "❌ $ERRORS error(s) found"
  exit 1
fi
