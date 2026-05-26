#!/bin/bash
# validate-skills.sh
# Skill consistency and governance validation test
#
# Usage: ./tests/validate-skills.sh [--verbose]
#
# Validation items:
#   1. SKILL.md frontmatter required fields (description, allowed-tools)
#   2. Existence of *.md files in references/ directory
#   3. Whether allowed-tools contains valid Claude Code tool names
#   4. Whether dependencies reference skills that exist

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PLUGIN_ROOT/skills"

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass_test() {
  echo -e "${GREEN}✓${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
  echo -e "${RED}✗${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn_test() {
  echo -e "${YELLOW}⚠${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

debug_log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "  [DEBUG] $1"
  fi
}

# Valid Claude Code tool name list
VALID_TOOLS=(
  "Read" "Write" "Edit" "Glob" "Grep" "Bash"
  "Task" "WebFetch" "WebSearch" "TodoWrite"
  "AskUserQuestion" "Skill" "EnterPlanMode" "ExitPlanMode"
  "NotebookEdit" "LSP" "MCPSearch" "Append"
  "Monitor" "ScheduleWakeup" "Agent"
)

is_valid_tool() {
  local tool="$1"

  # MCP tools are exposed as concrete names such as mcp__harness__...
  # and should be accepted without enumerating every connector method.
  if [[ "$tool" == mcp__* ]]; then
    return 0
  fi

  for valid in "${VALID_TOOLS[@]}"; do
    if [[ "$valid" == "$tool" ]]; then
      return 0
    fi
  done
  return 1
}

# Extract field value from frontmatter
extract_frontmatter_field() {
  local file="$1"
  local field="$2"

  awk -v field="$field" '
    NR==1 && $0!="---" { exit 1 }
    NR>1 && $0=="---" { exit 0 }
    $0 ~ "^"field":" {
      sub("^"field": *", "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit 0
    }
  ' "$file"
}

echo "=========================================="
echo "Claude harness - Skill validation test"
echo "=========================================="
echo ""

if [ ! -d "$SKILLS_DIR" ]; then
  fail_test "skills directory not found: $SKILLS_DIR"
  exit 1
fi

# Collect skill directories
SKILL_DIRS=()
while IFS= read -r skill_md; do
  if git -C "$PLUGIN_ROOT" check-ignore -q "${skill_md#$PLUGIN_ROOT/}" 2>/dev/null; then
    debug_log "Skipping ignored skill: $skill_md"
    continue
  fi
  SKILL_DIRS+=("$(dirname "$skill_md")")
done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null | sort)

if [ ${#SKILL_DIRS[@]} -eq 0 ]; then
  warn_test "No SKILL.md found"
  exit 0
fi

echo "1. SKILL.md frontmatter validation"
echo "----------------------------------------"

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  debug_log "Checking: $skill_name"

  # description is required
  description=$(extract_frontmatter_field "$skill_file" "description")
  if [ -n "$description" ]; then
    pass_test "[$skill_name] description: ${description:0:50}..."
  else
    fail_test "[$skill_name] description not found"
  fi

  # allowed-tools is required
  allowed_tools=$(extract_frontmatter_field "$skill_file" "allowed-tools")
  if [ -n "$allowed_tools" ]; then
    pass_test "[$skill_name] allowed-tools: $allowed_tools"
  else
    fail_test "[$skill_name] allowed-tools not found"
  fi
done

echo ""
echo "2. allowed-tools validity validation"
echo "----------------------------------------"

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  allowed_tools=$(extract_frontmatter_field "$skill_file" "allowed-tools")
  if [ -z "$allowed_tools" ]; then
    continue
  fi

  # Parse [Tool1, Tool2] or ["Tool1", "Tool2"] format
  # Remove quotes, brackets, and spaces
  tools_str=$(echo "$allowed_tools" | sed 's/^\[//' | sed 's/\]$//' | tr ',' '\n' | sed 's/^[ "]*//;s/[ "]*$//')

  invalid_found=0
  while IFS= read -r tool; do
    # Remove extra spaces and quotes
    tool=$(echo "$tool" | tr -d ' "'\''')
    if [ -z "$tool" ]; then
      continue
    fi

    # Skip wildcard patterns (mcp__*)
    if [[ "$tool" == *"*"* ]]; then
      debug_log "[$skill_name] Wildcard pattern skipped: $tool"
      continue
    fi

    if is_valid_tool "$tool"; then
      debug_log "[$skill_name] Valid tool: $tool"
    else
      fail_test "[$skill_name] Invalid tool name: $tool"
      invalid_found=1
    fi
  done <<< "$tools_str"

  if [ "$invalid_found" -eq 0 ]; then
    pass_test "[$skill_name] All tool names are valid"
  fi
done

echo ""
echo "3. references/ directory validation"
echo "----------------------------------------"

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  ref_dir="$skill_dir/references"

  if [ -d "$ref_dir" ]; then
    ref_count=$(find "$ref_dir" -name "*.md" -type f | wc -l | tr -d ' ')
    if [ "$ref_count" -gt 0 ]; then
      pass_test "[$skill_name] references/: $ref_count document(s)"
    else
      warn_test "[$skill_name] references/ is empty"
    fi
  else
    debug_log "[$skill_name] references/ not present (optional)"
  fi
done

echo ""
echo "4. dependencies validation"
echo "----------------------------------------"

# Collect all skill names
ALL_SKILL_NAMES=()
for skill_dir in "${SKILL_DIRS[@]}"; do
  ALL_SKILL_NAMES+=("$(basename "$skill_dir")")
done

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  dependencies=$(extract_frontmatter_field "$skill_file" "dependencies")
  if [ -z "$dependencies" ] || [ "$dependencies" == "[]" ]; then
    debug_log "[$skill_name] no dependencies"
    continue
  fi

  # Parse [dep1, dep2] format
  deps_str=$(echo "$dependencies" | sed 's/^\[//' | sed 's/\]$//' | tr ',' '\n')

  invalid_dep=0
  while IFS= read -r dep; do
    dep=$(echo "$dep" | tr -d ' ')
    if [ -z "$dep" ]; then
      continue
    fi

    found=0
    for existing in "${ALL_SKILL_NAMES[@]}"; do
      if [ "$existing" == "$dep" ]; then
        found=1
        break
      fi
    done

    if [ "$found" -eq 1 ]; then
      pass_test "[$skill_name] dependency '$dep' exists"
    else
      fail_test "[$skill_name] dependency '$dep' not found"
      invalid_dep=1
    fi
  done <<< "$deps_str"
done

echo ""
echo "5. local-only .agents mirror validation"
echo "----------------------------------------"

AGENTS_SKILLS_DIR="$PLUGIN_ROOT/.agents/skills"

if [ ! -d "$AGENTS_SKILLS_DIR" ]; then
  pass_test ".agents/skills does not exist (normal on a fresh checkout)"
else
  agents_mirror_checked=0

  while IFS= read -r agent_skill_file; do
    agent_skill_dir="$(dirname "$agent_skill_file")"
    skill_name="$(basename "$agent_skill_dir")"
    source_skill_dir="$SKILLS_DIR/$skill_name"

    if [ ! -d "$source_skill_dir" ]; then
      debug_log "[$skill_name] .agents local-only entry has no skills/ source; skipped"
      continue
    fi

    agents_mirror_checked=$((agents_mirror_checked + 1))
    if diff -qr --exclude='.DS_Store' --exclude='.claude' "$source_skill_dir" "$agent_skill_dir" >/dev/null 2>&1; then
      pass_test "[.agents/$skill_name] mirror is in sync"
    else
      fail_test "[.agents/$skill_name] mirror is out of sync with skills/$skill_name (run bash scripts/sync-skill-mirrors.sh)"
      if [ "$VERBOSE" -eq 1 ]; then
        diff -qr --exclude='.DS_Store' --exclude='.claude' "$source_skill_dir" "$agent_skill_dir" | sed 's/^/  [DIFF] /' || true
      fi
    fi
  done < <(find "$AGENTS_SKILLS_DIR" -mindepth 2 -maxdepth 2 -name "SKILL.md" -type f 2>/dev/null | sort)

  if [ "$agents_mirror_checked" -eq 0 ]; then
    warn_test "No mirror targets found in .agents/skills"
  fi
fi

echo ""
echo "=========================================="
echo "Skill validation results summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
echo -e "${RED}Failed:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ All skill validations passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAIL_COUNT validation(s) failed${NC}"
  exit 1
fi
