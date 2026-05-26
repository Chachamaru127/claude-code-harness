#!/bin/bash
# localize-rules.sh
# Localizes rules to match the project structure
#
# Usage: ./scripts/localize-rules.sh [--dry-run]
#
# Features:
# - Adjusts paths: based on project analysis results
# - Adds language-specific rules
# - Preserves existing customizations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PLUGIN_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_PATH:-$DEFAULT_PLUGIN_PATH}}"
DRY_RUN=false

# Argument parsing
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# ================================
# Project analysis
# ================================
echo "🔍 Analyzing project structure..."

# analyze-project.sh を実行
ANALYSIS=$("$PLUGIN_PATH/scripts/analyze-project.sh" 2>/dev/null || echo '{"languages":["unknown"],"source_dirs":["."],"test_info":[],"extensions":[]}')

# JSON から値を抽出
LANGUAGES=$(echo "$ANALYSIS" | jq -r '.languages[]' 2>/dev/null | tr '\n' ' ')
SOURCE_DIRS=$(echo "$ANALYSIS" | jq -r '.source_dirs[]' 2>/dev/null | tr '\n' ' ')
TEST_DIRS=$(echo "$ANALYSIS" | jq -r '.test_info.dirs[]' 2>/dev/null | tr '\n' ' ')
HAS_COLOCATED_TESTS=$(echo "$ANALYSIS" | jq -r '.test_info.has_colocated_tests // false' 2>/dev/null)

echo "  Languages: $LANGUAGES"
echo "  Source directories: $SOURCE_DIRS"

# ================================
# paths pattern generation
# ================================
generate_code_paths() {
  local -a paths=()
  local src_dirs=($SOURCE_DIRS)

  # Extensions based on language
  local extensions=""
  if [[ "$LANGUAGES" == *"typescript"* ]] || [[ "$LANGUAGES" == *"react"* ]]; then
    extensions="ts,tsx,js,jsx"
  elif [[ "$LANGUAGES" == *"javascript"* ]]; then
    extensions="js,jsx"
  elif [[ "$LANGUAGES" == *"python"* ]]; then
    extensions="py"
  elif [[ "$LANGUAGES" == *"go"* ]]; then
    extensions="go"
  elif [[ "$LANGUAGES" == *"rust"* ]]; then
    extensions="rs"
  elif [[ "$LANGUAGES" == *"ruby"* ]]; then
    extensions="rb"
  elif [[ "$LANGUAGES" == *"java"* ]] || [[ "$LANGUAGES" == *"kotlin"* ]]; then
    extensions="java,kt"
  else
    extensions="ts,tsx,js,jsx,py,rb,go,rs,java,kt"
  fi

  # Generate patterns per source directory
  for dir in "${src_dirs[@]}"; do
    if [ "$dir" = "." ]; then
      paths+=("**/*.{$extensions}")
    else
      paths+=("$dir/**/*.{$extensions}")
    fi
  done

  printf '%s\n' "${paths[@]}"
}

generate_test_paths() {
  local -a paths=()
  local test_dirs_arr=($TEST_DIRS)

  # Detected test directories
  if [ ${#test_dirs_arr[@]} -gt 0 ]; then
    for dir in "${test_dirs_arr[@]}"; do
      paths+=("$dir/**/*.*")
    done
  else
    # Check default test directories
    for dir in tests test __tests__ spec e2e; do
      if [ -d "$dir" ]; then
        paths+=("$dir/**/*.*")
      fi
    done
  fi

  # colocated tests
  if [ "$HAS_COLOCATED_TESTS" = "true" ]; then
    paths+=("**/*.{test,spec}.{ts,tsx,js,jsx,py}")
  fi

  # Default
  if [ ${#paths[@]} -eq 0 ]; then
    paths=(
      "**/*.{test,spec}.*"
      "tests/**/*.*"
      "test/**/*.*"
    )
  fi

  printf '%s\n' "${paths[@]}"
}

render_paths_block() {
  local label="$1"
  shift

  printf '%s\n' "${label}"
  for path_pattern in "$@"; do
    printf '  - "%s"\n' "$path_pattern"
  done
}

# ================================
# ルールファイル生成
# ================================
CODE_PATHS=()
while IFS= read -r line; do
  [ -n "$line" ] && CODE_PATHS+=("$line")
done < <(generate_code_paths)

TEST_PATHS=()
while IFS= read -r line; do
  [ -n "$line" ] && TEST_PATHS+=("$line")
done < <(generate_test_paths)

CODE_PATHS_BLOCK="$(render_paths_block "paths:" "${CODE_PATHS[@]}")"
TEST_PATHS_BLOCK="$(render_paths_block "paths:" "${TEST_PATHS[@]}")"

echo ""
echo "📝 Generated paths:"
printf '  Code:\n%s\n' "$(printf '    - %s\n' "${CODE_PATHS[@]}")"
printf '  Test:\n%s\n' "$(printf '    - %s\n' "${TEST_PATHS[@]}")"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "🔍 [Dry Run] No actual changes will be made"
  exit 0
fi

# Ensure .claude/rules directory
mkdir -p .claude/rules

# ================================
# Localize coding-standards.md
# ================================
echo ""
echo "📁 Localizing rules..."

# Generate from template (confirm overwrite if file already exists)
CODING_STANDARDS=".claude/rules/coding-standards.md"

# Add language-specific sections
LANG_SPECIFIC=""
if [[ "$LANGUAGES" == *"typescript"* ]]; then
  LANG_SPECIFIC+="
## TypeScript specific

- \`any\` is forbidden (use \`unknown\`)
- Return types must be explicit
- Strict null checking must be enabled
"
fi

if [[ "$LANGUAGES" == *"python"* ]]; then
  LANG_SPECIFIC+="
## Python specific

- Follow PEP 8 style guide
- Use type hints
- docstrings must use Google style
"
fi

if [[ "$LANGUAGES" == *"react"* ]]; then
  LANG_SPECIFIC+="
## React specific

- Use function components
- Custom hooks must have a \`use\` prefix
- Prop types must be defined
"
fi

# Generate coding-standards.md
cat > "$CODING_STANDARDS" << EOF
---
description: Coding standards (applied only when editing code files)
${CODE_PATHS_BLOCK}
---

# Coding Standards

## Commit message conventions

| Prefix | Purpose | Example |
|--------|---------|---------|
| \`feat:\` | New feature | \`feat: add user authentication\` |
| \`fix:\` | Bug fix | \`fix: fix login error\` |
| \`docs:\` | Documentation | \`docs: update README\` |
| \`refactor:\` | Refactoring | \`refactor: reorganize auth logic\` |
| \`test:\` | Tests | \`test: add auth tests\` |
| \`chore:\` | Other | \`chore: update dependencies\` |

## Code style

- ✅ Follow the existing code style
- ✅ Only the minimal changes required
- ❌ "Improvements" to code you did not change
- ❌ Unrequested refactoring
- ❌ Excessive comment additions
$LANG_SPECIFIC
## Pull Request

- Title: concise description of the change (under 50 characters)
- Description: state "what" and "why"
- Always include how to test
EOF

echo "  ✅ $CODING_STANDARDS"

# ================================
# Localize testing.md
# ================================
TESTING_RULES=".claude/rules/testing.md"

cat > "$TESTING_RULES" << EOF
---
description: Rules when creating or editing test files
${TEST_PATHS_BLOCK}
---

# Testing Rules

## Testing principles

1. **Boundary testing**: Always test boundary values of inputs
2. **Happy path & error path**: Cover both cases
3. **Independence**: Each test must not depend on other tests
4. **Clear naming**: Test name must describe what is being tested

## Test naming convention

\`\`\`
describe('feature name', () => {
  it('should expected behavior when condition', () => {
    // ...
  });
});
\`\`\`

## Prohibited

- ❌ Tests that depend on internal implementation details
- ❌ Real connections to external services (use mocks)
- ❌ Shared state between tests
EOF

echo "  ✅ $TESTING_RULES"

# ================================
# Done
# ================================
echo ""
echo "✅ Rule localization complete"
echo ""
echo "📋 Generated rules:"
echo "  - .claude/rules/coding-standards.md (paths: YAML list)"
echo "  - .claude/rules/testing.md (paths: YAML list)"
