#!/bin/bash
# test-frontmatter-integration.sh
# Phase A 完了検証テスト + 実務シナリオテスト
#
# テスト項目:
# 1. テンプレートフロントマター検証
# 2. バージョン一貫性検証
# 3. ファイル生成シミュレーション
# 4. 後方互換性テスト
# 5. エッジケーステスト

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"
REGISTRY_FILE="$TEMPLATES_DIR/template-registry.json"
VERSION_FILE="$PLUGIN_ROOT/VERSION"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  ((TESTS_PASSED++))
}

log_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  ((TESTS_FAILED++))
}

log_skip() {
  echo -e "${YELLOW}⚠️ SKIP${NC}: $1"
  ((TESTS_SKIPPED++))
}

log_info() {
  echo -e "   ℹ️  $1"
}

# ================================
# Test 1: テンプレートフロントマター存在検証
# ================================
test_template_frontmatter_exists() {
  echo ""
  echo "=== Test 1: テンプレートフロントマター存在検証 ==="
  
  local templates=(
    "CLAUDE.md.template"
    "AGENTS.md.template"
    "Plans.md.template"
    "rules/workflow.md.template"
    "rules/coding-standards.md.template"
    "rules/testing.md.template"
    "rules/plans-management.md.template"
    "rules/ui-debugging-dev-browser.md.template"
    "memory/decisions.md.template"
    "memory/patterns.md.template"
  )
  
  for template in "${templates[@]}"; do
    local file="$TEMPLATES_DIR/$template"
    if [ ! -f "$file" ]; then
      log_fail "$template: ファイルが存在しない"
      continue
    fi
    
    # フロントマター存在チェック（---で始まる）
    if head -1 "$file" | grep -q "^---$"; then
      # _harness_template フィールドチェック
      if grep -q "_harness_template:" "$file"; then
        # _harness_version フィールドチェック
        if grep -q "_harness_version:" "$file"; then
          log_pass "$template: フロントマター完備"
        else
          log_fail "$template: _harness_version が見つからない"
        fi
      else
        log_fail "$template: _harness_template が見つからない"
      fi
    else
      log_fail "$template: YAMLフロントマターが見つからない"
    fi
  done
}

# ================================
# Test 2: JSONテンプレートメタデータ検証
# ================================
test_json_template_metadata() {
  echo ""
  echo "=== Test 2: JSONテンプレートメタデータ検証 ==="
  
  local json_templates=(
    "claude/settings.local.json.template"
    "claude/settings.security.json.template"
  )
  
  for template in "${json_templates[@]}"; do
    local file="$TEMPLATES_DIR/$template"
    if [ ! -f "$file" ]; then
      log_skip "$template: ファイルが存在しない"
      continue
    fi
    
    if command -v jq >/dev/null 2>&1; then
      local harness_template harness_version
      harness_template=$(jq -r '._harness_template // empty' "$file" 2>/dev/null)
      harness_version=$(jq -r '._harness_version // empty' "$file" 2>/dev/null)
      
      if [ -n "$harness_template" ] && [ -n "$harness_version" ]; then
        log_pass "$template: メタデータ完備"
      else
        log_fail "$template: メタデータが不完全 (template: $harness_template, version: $harness_version)"
      fi
    else
      log_skip "$template: jq がないため検証スキップ"
    fi
  done
}

# ================================
# Test 3: バージョン一貫性検証
# ================================
test_version_consistency() {
  echo ""
  echo "=== Test 3: バージョン一貫性検証 ==="
  
  local plugin_version
  plugin_version=$(cat "$VERSION_FILE" | tr -d '\n')
  log_info "プラグインバージョン: $plugin_version"
  
  # registry のバージョンチェック
  if command -v jq >/dev/null 2>&1; then
    local registry_versions
    registry_versions=$(jq -r '.templates[].templateVersion' "$REGISTRY_FILE" 2>/dev/null | sort -u)
    
    local inconsistent=0
    while IFS= read -r ver; do
      if [ "$ver" != "$plugin_version" ]; then
        log_fail "template-registry.json: バージョン不一致 ($ver != $plugin_version)"
        inconsistent=1
      fi
    done <<< "$registry_versions"
    
    if [ $inconsistent -eq 0 ]; then
      log_pass "template-registry.json: 全バージョン一致 ($plugin_version)"
    fi
  else
    log_skip "template-registry.json: jq がないため検証スキップ"
  fi
  
  # テンプレートファイル内のバージョンチェック
  local md_templates=(
    "CLAUDE.md.template"
    "AGENTS.md.template"
    "Plans.md.template"
  )
  
  for template in "${md_templates[@]}"; do
    local file="$TEMPLATES_DIR/$template"
    if [ -f "$file" ]; then
      local file_version
      file_version=$(grep "_harness_version:" "$file" | head -1 | sed 's/.*: *"//' | sed 's/".*//')
      
      if [ "$file_version" = "$plugin_version" ]; then
        log_pass "$template: バージョン一致 ($file_version)"
      else
        log_fail "$template: バージョン不一致 ($file_version != $plugin_version)"
      fi
    fi
  done
}

# ================================
# Test 4: フロントマター解析テスト
# ================================
test_frontmatter_parsing() {
  echo ""
  echo "=== Test 4: フロントマター解析テスト ==="
  
  # テスト用一時ファイル作成
  local test_file="/tmp/test_frontmatter_$$.md"
  
  cat > "$test_file" << 'MDEOF'
---
_harness_template: "test.md.template"
_harness_version: "2.5.27"
description: テスト用
paths: "**/*.ts"
---

# Test Content

This is test content.
MDEOF
  
  # フロントマター抽出テスト
  local extracted_version
  extracted_version=$(sed -n '/^---$/,/^---$/p' "$test_file" | grep "_harness_version:" | sed 's/.*: *"//' | sed 's/".*//')
  
  if [ "$extracted_version" = "2.5.27" ]; then
    log_pass "フロントマター解析: バージョン抽出成功"
  else
    log_fail "フロントマター解析: バージョン抽出失敗 (got: $extracted_version)"
  fi
  
  local extracted_template
  extracted_template=$(sed -n '/^---$/,/^---$/p' "$test_file" | grep "_harness_template:" | sed 's/.*: *"//' | sed 's/".*//')
  
  if [ "$extracted_template" = "test.md.template" ]; then
    log_pass "フロントマター解析: テンプレート名抽出成功"
  else
    log_fail "フロントマター解析: テンプレート名抽出失敗 (got: $extracted_template)"
  fi
  
  rm -f "$test_file"
}

# ================================
# Test 5: 後方互換性テスト
# ================================
test_backward_compatibility() {
  echo ""
  echo "=== Test 5: 後方互換性テスト ==="
  
  # フロントマターなしの古いファイルをシミュレート
  local old_file="/tmp/test_old_file_$$.md"
  
  cat > "$old_file" << 'MDEOF'
# Old Style CLAUDE.md

This file has no frontmatter.
MDEOF
  
  # フロントマターがない場合の検出
  if ! head -1 "$old_file" | grep -q "^---$"; then
    log_pass "後方互換性: フロントマターなしファイルを正しく検出"
  else
    log_fail "後方互換性: 誤検出（フロントマターがあると判定）"
  fi
  
  rm -f "$old_file"
  
  # template-tracker.sh が存在し動作可能か確認
  local tracker_script="$PLUGIN_ROOT/scripts/template-tracker.sh"
  if [ -f "$tracker_script" ] && [ -x "$tracker_script" ]; then
    log_pass "後方互換性: template-tracker.sh が存在し実行可能"
  else
    log_skip "後方互換性: template-tracker.sh が見つからない（フォールバック用）"
  fi
}

# ================================
# Test 6: 実務シナリオテスト
# ================================
test_practical_scenarios() {
  echo ""
  echo "=== Test 6: 実務シナリオテスト ==="
  
  # シナリオ 6.1: 新規プロジェクトへのコピーシミュレーション
  local test_project_dir="/tmp/test_project_$$"
  mkdir -p "$test_project_dir"
  
  # テンプレートをコピー
  cp "$TEMPLATES_DIR/CLAUDE.md.template" "$test_project_dir/CLAUDE.md"
  
  # コピー後もフロントマターが保持されているか
  if grep -q "_harness_template:" "$test_project_dir/CLAUDE.md" && \
     grep -q "_harness_version:" "$test_project_dir/CLAUDE.md"; then
    log_pass "シナリオ6.1: テンプレートコピー後もフロントマター保持"
  else
    log_fail "シナリオ6.1: テンプレートコピー後にフロントマター消失"
  fi
  
  # シナリオ 6.2: プレースホルダー置換シミュレーション
  sed -i.bak 's/{{PROJECT_NAME}}/test-project/g' "$test_project_dir/CLAUDE.md"
  sed -i.bak 's/{{DATE}}/2025-12-23/g' "$test_project_dir/CLAUDE.md"
  sed -i.bak 's/{{LANGUAGE}}/Japanese/g' "$test_project_dir/CLAUDE.md"
  
  # 置換後もフロントマターが保持されているか
  if grep -q "_harness_template:" "$test_project_dir/CLAUDE.md" && \
     grep -q "_harness_version:" "$test_project_dir/CLAUDE.md"; then
    log_pass "シナリオ6.2: プレースホルダー置換後もフロントマター保持"
  else
    log_fail "シナリオ6.2: プレースホルダー置換後にフロントマター消失"
  fi
  
  # シナリオ 6.3: ユーザーによるコンテンツ追加シミュレーション
  echo "" >> "$test_project_dir/CLAUDE.md"
  echo "## カスタムセクション" >> "$test_project_dir/CLAUDE.md"
  echo "ユーザーが追加したコンテンツ" >> "$test_project_dir/CLAUDE.md"
  
  # 追加後もフロントマターが保持されているか
  if grep -q "_harness_template:" "$test_project_dir/CLAUDE.md" && \
     grep -q "_harness_version:" "$test_project_dir/CLAUDE.md"; then
    log_pass "シナリオ6.3: ユーザー追記後もフロントマター保持"
  else
    log_fail "シナリオ6.3: ユーザー追記後にフロントマター消失"
  fi
  
  # クリーンアップ
  rm -rf "$test_project_dir"
}

# ================================
# Test 7: registry 整合性テスト
# ================================
test_registry_integrity() {
  echo ""
  echo "=== Test 7: template-registry.json 整合性テスト ==="
  
  if ! command -v jq >/dev/null 2>&1; then
    log_skip "jq がないため検証スキップ"
    return
  fi
  
  # JSON構文チェック
  if jq empty "$REGISTRY_FILE" 2>/dev/null; then
    log_pass "registry: JSON構文正常"
  else
    log_fail "registry: JSON構文エラー"
    return
  fi
  
  # 登録されたテンプレートが実在するかチェック
  local missing_templates=0
  while IFS= read -r template_key; do
    local template_file="$TEMPLATES_DIR/$template_key"
    if [ ! -f "$template_file" ]; then
      log_fail "registry: $template_key が存在しない"
      missing_templates=1
    fi
  done < <(jq -r '.templates | keys[]' "$REGISTRY_FILE")
  
  if [ $missing_templates -eq 0 ]; then
    log_pass "registry: 全登録テンプレートが存在"
  fi
  
  # tracked: true のテンプレートにフロントマターがあるかチェック
  local tracked_without_frontmatter=0
  while IFS= read -r template_key; do
    local template_file="$TEMPLATES_DIR/$template_key"
    if [ -f "$template_file" ]; then
      # .md テンプレートのみチェック
      if [[ "$template_key" == *.md.template ]]; then
        if ! grep -q "_harness_template:" "$template_file"; then
          log_fail "registry: $template_key (tracked=true) にフロントマターがない"
          tracked_without_frontmatter=1
        fi
      fi
    fi
  done < <(jq -r '.templates | to_entries | map(select(.value.tracked == true)) | .[].key' "$REGISTRY_FILE")
  
  if [ $tracked_without_frontmatter -eq 0 ]; then
    log_pass "registry: 全 tracked テンプレートにフロントマター完備"
  fi
}

# ================================
# Test 8: エッジケーステスト
# ================================
test_edge_cases() {
  echo ""
  echo "=== Test 8: エッジケーステスト ==="
  
  # エッジケース 8.1: 空のフロントマター
  local edge1="/tmp/edge_empty_frontmatter_$$.md"
  cat > "$edge1" << 'MDEOF'
---
---

# Content
MDEOF
  
  if ! grep -q "_harness_version:" "$edge1"; then
    log_pass "エッジ8.1: 空フロントマターの検出成功"
  else
    log_fail "エッジ8.1: 空フロントマターの検出失敗"
  fi
  rm -f "$edge1"
  
  # エッジケース 8.2: フロントマターっぽいがYAMLじゃない
  local edge2="/tmp/edge_fake_frontmatter_$$.md"
  cat > "$edge2" << 'MDEOF'
---
This is not YAML, just dashes
---

# Content
MDEOF
  
  if ! grep -q "_harness_version:" "$edge2"; then
    log_pass "エッジ8.2: 偽フロントマターの検出成功"
  else
    log_fail "エッジ8.2: 偽フロントマターの検出失敗"
  fi
  rm -f "$edge2"
  
  # エッジケース 8.3: バージョン形式検証
  local valid_version_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'
  local plugin_version
  plugin_version=$(cat "$VERSION_FILE" | tr -d '\n')
  
  if [[ "$plugin_version" =~ $valid_version_pattern ]]; then
    log_pass "エッジ8.3: バージョン形式正常 ($plugin_version)"
  else
    log_fail "エッジ8.3: バージョン形式異常 ($plugin_version)"
  fi
}

# ================================
# メイン実行
# ================================
main() {
  echo "========================================"
  echo "Frontmatter Integration Test Suite"
  echo "========================================"
  echo "Plugin Root: $PLUGIN_ROOT"
  echo "Templates Dir: $TEMPLATES_DIR"
  echo ""
  
  # 前提条件チェック
  if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "ERROR: Templates directory not found: $TEMPLATES_DIR"
    exit 1
  fi
  
  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "ERROR: Registry file not found: $REGISTRY_FILE"
    exit 1
  fi
  
  # テスト実行
  test_template_frontmatter_exists
  test_json_template_metadata
  test_version_consistency
  test_frontmatter_parsing
  test_backward_compatibility
  test_practical_scenarios
  test_registry_integrity
  test_edge_cases
  
  # 結果サマリー
  echo ""
  echo "========================================"
  echo "Test Results Summary"
  echo "========================================"
  echo -e "${GREEN}PASSED${NC}: $TESTS_PASSED"
  echo -e "${RED}FAILED${NC}: $TESTS_FAILED"
  echo -e "${YELLOW}SKIPPED${NC}: $TESTS_SKIPPED"
  echo ""
  
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
  else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  fi
}

main "$@"
