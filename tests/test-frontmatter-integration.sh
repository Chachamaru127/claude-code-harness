#!/bin/bash
# test-frontmatter-integration.sh
# Phase A completion verification tests + practical scenario tests
#
# Test items:
# 1. Template frontmatter verification
# 2. Version consistency verification
# 3. File generation simulation
# 4. Backward compatibility test
# 5. Edge case test

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$PLUGIN_ROOT/templates"
REGISTRY_FILE="$TEMPLATES_DIR/template-registry.json"
VERSION_FILE="$PLUGIN_ROOT/VERSION"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
  echo -e "${YELLOW}⚠️ SKIP${NC}: $1"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_info() {
  echo -e "   ℹ️  $1"
}

# ================================
# Test 1: Template frontmatter existence verification
# ================================
test_template_frontmatter_exists() {
  echo ""
  echo "=== Test 1: Template frontmatter existence verification ==="

  local templates=(
    "CLAUDE.md.template"
    "AGENTS.md.template"
    "Plans.md.template"
    "rules/workflow.md.template"
    "rules/coding-standards.md.template"
    "rules/testing.md.template"
    "rules/plans-management.md.template"
    "rules/ui-debugging-agent-browser.md.template"
    "memory/decisions.md.template"
    "memory/patterns.md.template"
  )

  for template in "${templates[@]}"; do
    local file="$TEMPLATES_DIR/$template"
    if [ ! -f "$file" ]; then
      log_fail "$template: file does not exist"
      continue
    fi

    # Check frontmatter presence (starts with ---)
    if head -1 "$file" | grep -q "^---$"; then
      # Check _harness_template field
      if grep -q "_harness_template:" "$file"; then
        # Check _harness_version field
        if grep -q "_harness_version:" "$file"; then
          log_pass "$template: frontmatter complete"
        else
          log_fail "$template: _harness_version not found"
        fi
      else
        log_fail "$template: _harness_template not found"
      fi
    else
      log_fail "$template: YAML frontmatter not found"
    fi
  done
}

# ================================
# Test 2: JSON template metadata verification
# ================================
test_json_template_metadata() {
  echo ""
  echo "=== Test 2: JSON template metadata verification ==="

  local json_templates=(
    "claude/settings.local.json.template"
    "claude/settings.security.json.template"
  )

  for template in "${json_templates[@]}"; do
    local file="$TEMPLATES_DIR/$template"
    if [ ! -f "$file" ]; then
      log_skip "$template: file does not exist"
      continue
    fi

    if command -v jq >/dev/null 2>&1; then
      local harness_template harness_version
      harness_template=$(jq -r '._harness_template // empty' "$file" 2>/dev/null)
      harness_version=$(jq -r '._harness_version // empty' "$file" 2>/dev/null)

      if [ -n "$harness_template" ] && [ -n "$harness_version" ]; then
        log_pass "$template: metadata complete"
      else
        log_fail "$template: metadata incomplete (template: $harness_template, version: $harness_version)"
      fi
    else
      log_skip "$template: jq not available, skipping verification"
    fi
  done
}

# ================================
# Test 3: Version consistency verification
# ================================
test_version_consistency() {
  echo ""
  echo "=== Test 3: Version consistency verification ==="

  local plugin_version
  plugin_version=$(cat "$VERSION_FILE" | tr -d '\n')
  log_info "Plugin version: $plugin_version"

  # templateVersion is the "update version of the template itself", so it does not
  # need to always match the overall plugin VERSION.
  # Here we verify the registry format and consistency with representative template files.
  if command -v jq >/dev/null 2>&1; then
    local invalid_versions=0
    while IFS= read -r entry; do
      local key="${entry%%$'\t'*}"
      local ver="${entry#*$'\t'}"

      if ! echo "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_fail "template-registry.json: templateVersion format invalid for $key ($ver)"
        invalid_versions=1
      fi
    done < <(jq -r '.templates | to_entries[] | [.key, .value.templateVersion] | @tsv' "$REGISTRY_FILE")

    if [ $invalid_versions -eq 0 ]; then
      log_pass "template-registry.json: all templateVersions are SemVer format"
    fi
  else
    log_skip "template-registry.json: jq not available, skipping verification"
  fi

  # Major templates: _harness_version in the actual file must match templateVersion in registry.
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

      local registry_version=""
      if command -v jq >/dev/null 2>&1; then
        registry_version=$(jq -r --arg template "$template" '.templates[$template].templateVersion // empty' "$REGISTRY_FILE" 2>/dev/null)
      fi

      if [ -n "$registry_version" ] && [ "$file_version" = "$registry_version" ]; then
        log_pass "$template: version matches registry ($file_version)"
      else
        log_fail "$template: version mismatch with registry ($file_version != $registry_version)"
      fi
    fi
  done
}

# ================================
# Test 4: Frontmatter parsing test
# ================================
test_frontmatter_parsing() {
  echo ""
  echo "=== Test 4: Frontmatter parsing test ==="

  # Create temporary test file
  local test_file="/tmp/test_frontmatter_$$.md"

  cat > "$test_file" << 'MDEOF'
---
_harness_template: "test.md.template"
_harness_version: "2.5.27"
description: test
paths: "**/*.ts"
---

# Test Content

This is test content.
MDEOF

  # Frontmatter extraction test
  local extracted_version
  extracted_version=$(sed -n '/^---$/,/^---$/p' "$test_file" | grep "_harness_version:" | sed 's/.*: *"//' | sed 's/".*//')

  if [ "$extracted_version" = "2.5.27" ]; then
    log_pass "Frontmatter parsing: version extraction succeeded"
  else
    log_fail "Frontmatter parsing: version extraction failed (got: $extracted_version)"
  fi

  local extracted_template
  extracted_template=$(sed -n '/^---$/,/^---$/p' "$test_file" | grep "_harness_template:" | sed 's/.*: *"//' | sed 's/".*//')

  if [ "$extracted_template" = "test.md.template" ]; then
    log_pass "Frontmatter parsing: template name extraction succeeded"
  else
    log_fail "Frontmatter parsing: template name extraction failed (got: $extracted_template)"
  fi

  rm -f "$test_file"
}

# ================================
# Test 5: Backward compatibility test
# ================================
test_backward_compatibility() {
  echo ""
  echo "=== Test 5: Backward compatibility test ==="

  # Simulate an old file without frontmatter
  local old_file="/tmp/test_old_file_$$.md"

  cat > "$old_file" << 'MDEOF'
# Old Style CLAUDE.md

This file has no frontmatter.
MDEOF

  # Detect files without frontmatter
  if ! head -1 "$old_file" | grep -q "^---$"; then
    log_pass "Backward compatibility: correctly detected file without frontmatter"
  else
    log_fail "Backward compatibility: false positive (detected frontmatter where none exists)"
  fi

  rm -f "$old_file"

  # Check if template-tracker.sh exists and is executable
  local tracker_script="$PLUGIN_ROOT/scripts/template-tracker.sh"
  if [ -f "$tracker_script" ] && [ -x "$tracker_script" ]; then
    log_pass "Backward compatibility: template-tracker.sh exists and is executable"
  else
    log_skip "Backward compatibility: template-tracker.sh not found (fallback utility)"
  fi
}

# ================================
# Test 6: Practical scenario test
# ================================
test_practical_scenarios() {
  echo ""
  echo "=== Test 6: Practical scenario test ==="

  # Scenario 6.1: Copy to new project simulation
  local test_project_dir="/tmp/test_project_$$"
  mkdir -p "$test_project_dir"

  # Copy template
  cp "$TEMPLATES_DIR/CLAUDE.md.template" "$test_project_dir/CLAUDE.md"

  # Check that frontmatter is preserved after copy
  if grep -q "_harness_template:" "$test_project_dir/CLAUDE.md" && \
     grep -q "_harness_version:" "$test_project_dir/CLAUDE.md"; then
    log_pass "Scenario 6.1: frontmatter preserved after template copy"
  else
    log_fail "Scenario 6.1: frontmatter lost after template copy"
  fi

  # Scenario 6.2: Placeholder substitution simulation
  sed -i.bak 's/{{PROJECT_NAME}}/test-project/g' "$test_project_dir/CLAUDE.md"
  sed -i.bak 's/{{DATE}}/2025-12-23/g' "$test_project_dir/CLAUDE.md"
  sed -i.bak 's/{{LANGUAGE}}/Japanese/g' "$test_project_dir/CLAUDE.md"

  # Check that frontmatter is preserved after substitution
  if grep -q "_harness_template:" "$test_project_dir/CLAUDE.md" && \
     grep -q "_harness_version:" "$test_project_dir/CLAUDE.md"; then
    log_pass "Scenario 6.2: frontmatter preserved after placeholder substitution"
  else
    log_fail "Scenario 6.2: frontmatter lost after placeholder substitution"
  fi

  # Scenario 6.3: User content addition simulation
  echo "" >> "$test_project_dir/CLAUDE.md"
  echo "## Custom Section" >> "$test_project_dir/CLAUDE.md"
  echo "User-added content" >> "$test_project_dir/CLAUDE.md"

  # Check that frontmatter is preserved after addition
  if grep -q "_harness_template:" "$test_project_dir/CLAUDE.md" && \
     grep -q "_harness_version:" "$test_project_dir/CLAUDE.md"; then
    log_pass "Scenario 6.3: frontmatter preserved after user content addition"
  else
    log_fail "Scenario 6.3: frontmatter lost after user content addition"
  fi

  # Cleanup
  rm -rf "$test_project_dir"
}

# ================================
# Test 7: Registry integrity test
# ================================
test_registry_integrity() {
  echo ""
  echo "=== Test 7: template-registry.json integrity test ==="

  if ! command -v jq >/dev/null 2>&1; then
    log_skip "jq not available, skipping verification"
    return
  fi

  # JSON syntax check
  if jq empty "$REGISTRY_FILE" 2>/dev/null; then
    log_pass "registry: JSON syntax valid"
  else
    log_fail "registry: JSON syntax error"
    return
  fi

  # Check that all registered templates actually exist
  local missing_templates=0
  while IFS= read -r template_key; do
    local template_file="$TEMPLATES_DIR/$template_key"
    if [ ! -f "$template_file" ]; then
      log_fail "registry: $template_key does not exist"
      missing_templates=1
    fi
  done < <(jq -r '.templates | keys[]' "$REGISTRY_FILE")

  if [ $missing_templates -eq 0 ]; then
    log_pass "registry: all registered templates exist"
  fi

  # Check that tracked: true templates have frontmatter
  local tracked_without_frontmatter=0
  while IFS= read -r template_key; do
    local template_file="$TEMPLATES_DIR/$template_key"
    if [ -f "$template_file" ]; then
      # Check only .md templates
      if [[ "$template_key" == *.md.template ]]; then
        if ! grep -q "_harness_template:" "$template_file"; then
          log_fail "registry: $template_key (tracked=true) has no frontmatter"
          tracked_without_frontmatter=1
        fi
      fi
    fi
  done < <(jq -r '.templates | to_entries | map(select(.value.tracked == true)) | .[].key' "$REGISTRY_FILE")

  if [ $tracked_without_frontmatter -eq 0 ]; then
    log_pass "registry: all tracked templates have complete frontmatter"
  fi
}

# ================================
# Test 8: Edge case test
# ================================
test_edge_cases() {
  echo ""
  echo "=== Test 8: Edge case test ==="

  # Edge case 8.1: Empty frontmatter
  local edge1="/tmp/edge_empty_frontmatter_$$.md"
  cat > "$edge1" << 'MDEOF'
---
---

# Content
MDEOF

  if ! grep -q "_harness_version:" "$edge1"; then
    log_pass "Edge 8.1: empty frontmatter detected successfully"
  else
    log_fail "Edge 8.1: empty frontmatter detection failed"
  fi
  rm -f "$edge1"

  # Edge case 8.2: Frontmatter-like but not YAML
  local edge2="/tmp/edge_fake_frontmatter_$$.md"
  cat > "$edge2" << 'MDEOF'
---
This is not YAML, just dashes
---

# Content
MDEOF

  if ! grep -q "_harness_version:" "$edge2"; then
    log_pass "Edge 8.2: fake frontmatter detected successfully"
  else
    log_fail "Edge 8.2: fake frontmatter detection failed"
  fi
  rm -f "$edge2"

  # Edge case 8.3: Version format validation
  local valid_version_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'
  local plugin_version
  plugin_version=$(cat "$VERSION_FILE" | tr -d '\n')

  if [[ "$plugin_version" =~ $valid_version_pattern ]]; then
    log_pass "Edge 8.3: version format valid ($plugin_version)"
  else
    log_fail "Edge 8.3: version format invalid ($plugin_version)"
  fi
}

# ================================
# Main execution
# ================================
main() {
  echo "========================================"
  echo "Frontmatter Integration Test Suite"
  echo "========================================"
  echo "Plugin Root: $PLUGIN_ROOT"
  echo "Templates Dir: $TEMPLATES_DIR"
  echo ""

  # Precondition checks
  if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "Error: templates directory not found: $TEMPLATES_DIR"
    exit 1
  fi

  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "Error: registry file not found: $REGISTRY_FILE"
    exit 1
  fi

  # Run tests
  test_template_frontmatter_exists
  test_json_template_metadata
  test_version_consistency
  test_frontmatter_parsing
  test_backward_compatibility
  test_practical_scenarios
  test_registry_integrity
  test_edge_cases

  # Result summary
  echo ""
  echo "========================================"
  echo "Test Result Summary"
  echo "========================================"
  echo -e "${GREEN}Passed${NC}: $TESTS_PASSED"
  echo -e "${RED}Failed${NC}: $TESTS_FAILED"
  echo -e "${YELLOW}Skipped${NC}: $TESTS_SKIPPED"
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
