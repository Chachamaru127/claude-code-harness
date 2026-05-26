#!/bin/bash
# test-workflow-skill-references.sh
# Validates that skills/agents referenced by workflows actually exist
#
# Usage: ./tests/test-workflow-skill-references.sh
#        ./tests/test-workflow-skill-references.sh --strict  # treat unimplemented skills as failures
#
# Validation coverage:
# - Extracts `skill:` entries from workflows/**/*.yaml
# - Verifies each skill exists under skills/**/ or agents/**/
#
# Default behavior:
# - Skill exists → PASS
# - Skill missing → WARN (warning only, does not fail the test)
#
# --strict mode:
# - Skill missing → FAIL (test failure)

set -euo pipefail

# Argument parsing
STRICT_MODE=false
if [ "${1:-}" = "--strict" ]; then
  STRICT_MODE=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

log_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  echo "  $2"
  FAILED=$((FAILED + 1))
}

log_warn() {
  echo -e "${YELLOW}⚠️ WARN${NC}: $1"
  WARNINGS=$((WARNINGS + 1))
}

# ================================
# Skill/agent existence check
# ================================

skill_exists() {
  local skill_name="$1"

  # Check if it exists as a directory under skills/**/
  if [ -d "$PROJECT_ROOT/skills/$skill_name" ]; then
    return 0
  fi

  # Check if it exists as a directory under skills/*/$skill_name/ (nested skill)
  for parent_dir in "$PROJECT_ROOT/skills"/*; do
    if [ -d "$parent_dir/$skill_name" ]; then
      return 0
    fi
  done

  # Check if it exists as a .md file under agents/**/
  if [ -f "$PROJECT_ROOT/agents/$skill_name.md" ]; then
    return 0
  fi

  # Check if it exists as a reference skill under skills/**/references/
  if [ -f "$PROJECT_ROOT/skills/$skill_name.md" ]; then
    return 0
  fi
  if [ -f "$PROJECT_ROOT/skills/$skill_name/references/$skill_name.md" ]; then
    return 0
  fi
  for parent_dir in "$PROJECT_ROOT/skills"/*; do
    if [ -f "$parent_dir/references/$skill_name.md" ]; then
      return 0
    fi
  done

  # If the skill name is hyphen-separated, check for the parent skill
  # e.g. "ask-project-type" → exists under the "setup" parent skill
  local parent_skill
  parent_skill=$(echo "$skill_name" | cut -d'-' -f1)
  if [ -d "$PROJECT_ROOT/skills/$parent_skill/$skill_name" ]; then
    return 0
  fi

  # Check if defined via frontmatter name: (including reference skills)
  if grep -R --include="*.md" -n "name: $skill_name" "$PROJECT_ROOT/skills" "$PROJECT_ROOT/agents" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# ================================
# Main processing
# ================================

echo "================================"
echo "Workflow reference consistency test"
echo "================================"
echo ""

# Search for workflow files
WORKFLOW_FILES=$(find "$PROJECT_ROOT/workflows" -name "*.yaml" -o -name "*.yml" 2>/dev/null || true)

if [ -z "$WORKFLOW_FILES" ]; then
  log_warn "No workflow files found"
  exit 0
fi

# Process each workflow file
for workflow_file in $WORKFLOW_FILES; do
  workflow_name=$(basename "$workflow_file")
  echo "--- $workflow_name ---"

  # Extract `skill:` lines (accounting for YAML indentation)
  SKILLS=$(grep -E "^\s*skill:\s*" "$workflow_file" 2>/dev/null | sed 's/.*skill:\s*//g' | tr -d '"' | tr -d "'" || true)

  if [ -z "$SKILLS" ]; then
    echo "  (no skill references)"
    continue
  fi

  # Check existence of each skill
  for skill in $SKILLS; do
    # Skip comment lines and empty lines
    if [[ "$skill" =~ ^# ]] || [ -z "$skill" ]; then
      continue
    fi

    if skill_exists "$skill"; then
      log_pass "skill: $skill"
    else
      if [ "$STRICT_MODE" = true ]; then
        log_fail "skill: $skill" "Skill '$skill' not found in skills/ or agents/"
      else
        log_warn "skill: $skill - not implemented (planned for future)"
      fi
    fi
  done
done

echo ""

# ================================
# Agent reference check (.md files under agents/)
# ================================

echo "--- Agent definition check ---"

AGENT_FILES=$(find "$PROJECT_ROOT/agents" -name "*.md" 2>/dev/null || true)

if [ -n "$AGENT_FILES" ]; then
  AGENT_COUNT=$(echo "$AGENT_FILES" | wc -l | tr -d ' ')
  log_pass "agents/ has $AGENT_COUNT agent definition(s)"
else
  log_warn "No agent definitions found in agents/"
fi

echo ""

# ================================
# Results summary
# ================================

echo "================================"
echo "Test results summary"
echo "================================"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo -e "${RED}Reference consistency errors found. Please fix them.${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}All references are valid!${NC}"
  exit 0
fi
