#!/bin/bash
# setup-existing-project.sh
# Setup script for applying claude-code-harness to an existing project
#
# Usage: ./scripts/setup-existing-project.sh [--locale en|ja] [project_path]
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"

# Load cross-platform path utilities
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
fi

usage() {
    cat <<EOF
Usage: $0 [--locale en|ja] [project_path]

Options:
  --locale en|ja   Render setup templates in English (default) or Japanese.
  -h, --help       Show this help.
EOF
}

PROJECT_PATH="."
REQUESTED_LOCALE="${CLAUDE_CODE_HARNESS_LANG:-en}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --locale)
            if [[ $# -lt 2 ]]; then
                echo "Error: --locale requires en or ja" >&2
                exit 1
            fi
            REQUESTED_LOCALE="$2"
            shift 2
            ;;
        --locale=*)
            REQUESTED_LOCALE="${1#--locale=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            PROJECT_PATH="$1"
            shift
            ;;
    esac
done

normalize_setup_locale() {
    local value="${1:-en}"
    if [ -f "$SCRIPT_DIR/config-utils.sh" ]; then
        # shellcheck source=./config-utils.sh
        source "$SCRIPT_DIR/config-utils.sh"
        normalize_harness_locale "$value"
        return 0
    fi

    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
    case "$value" in
        en|ja) printf '%s\n' "$value" ;;
        *) printf '%s\n' "en" ;;
    esac
}

HARNESS_LOCALE="$(normalize_setup_locale "$REQUESTED_LOCALE")"

# Normalize project path for cross-platform compatibility
if type normalize_path &>/dev/null; then
  PROJECT_PATH="$(normalize_path "$PROJECT_PATH")"
fi

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Claude harness - Apply to existing project${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ================================
# Step 1: Prerequisites check
# ================================

echo -e "${BLUE}[1/6] Prerequisites check${NC}"
echo "----------------------------------------"

# Confirm project directory exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}✗ Project directory not found: $PROJECT_PATH${NC}"
    exit 1
fi

cd "$PROJECT_PATH" || {
    echo -e "${RED}✗ Cannot enter directory: $PROJECT_PATH${NC}"
    exit 1
}
PROJECT_PATH=$(pwd)
echo -e "${GREEN}✓${NC} Project directory: $PROJECT_PATH"

# Setup metadata
PROJECT_NAME="$(basename "$PROJECT_PATH")"
SETUP_DATE_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SETUP_DATE_SHORT="$(date +"%Y-%m-%d")"
HARNESS_VERSION="unknown"
if [ -f "$HARNESS_ROOT/VERSION" ]; then
    HARNESS_VERSION="$(cat "$HARNESS_ROOT/VERSION" | tr -d ' \n\r')"
fi

# Used for template substitution. Language represents the natural-language locale.
LANGUAGE="$HARNESS_LOCALE"
PRIMARY_TECHNOLOGY="unknown"

# Check if this is a Git repository
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠${NC}  Not a Git repository"
    read -p "Initialize a Git repository? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        echo -e "${GREEN}✓${NC} Git repository initialized"
    fi
else
    echo -e "${GREEN}✓${NC} Git repository confirmed"
fi

# Check for uncommitted changes
if [ -d ".git" ]; then
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC}  Uncommitted changes exist"
        echo ""
        echo -e "${YELLOW}Recommendation: commit before running setup${NC}"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup aborted"
            exit 0
        fi
    else
        echo -e "${GREEN}✓${NC} Working tree is clean"
    fi
fi

echo ""

# ================================
# Step 2: Discover existing specs and documents
# ================================

echo -e "${BLUE}[2/6] Discovering existing documents${NC}"
echo "----------------------------------------"

FOUND_DOCS=()
DOC_PATTERNS=(
    "README.md"
    "SPEC.md"
    "SPECIFICATION.md"
    "specification.md"
    "requirements.md"
    "docs/spec.md"
    "docs/specification.md"
    "docs/requirements.md"
    "docs/proposal.md"
    "docs/proposal-ja.md"
    "Plans.md"
    "PLAN.md"
    "plan-ja.md"
)

for pattern in "${DOC_PATTERNS[@]}"; do
    if [ -f "$pattern" ]; then
        FOUND_DOCS+=("$pattern")
        echo -e "${GREEN}✓${NC} Found: $pattern"
    fi
done

if [ ${#FOUND_DOCS[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC}  No existing specification documents found"
else
    echo ""
    echo -e "${GREEN}Found ${#FOUND_DOCS[@]} document(s)${NC}"
fi

echo ""

# ================================
# Step 3: Project analysis
# ================================

echo -e "${BLUE}[3/6] Project analysis${NC}"
echo "----------------------------------------"

# Run analyze-project.sh
if [ -f "$HARNESS_ROOT/scripts/analyze-project.sh" ]; then
    ANALYSIS_RESULT=$("$HARNESS_ROOT/scripts/analyze-project.sh" "$PROJECT_PATH" 2>/dev/null || echo "{}")
    
    # Display tech stack (analyze-project.sh output: technologies/frameworks/testing)
    if command -v jq &> /dev/null; then
        TECHNOLOGIES=$(echo "$ANALYSIS_RESULT" | jq -r '.technologies[]?' 2>/dev/null || true)
        FRAMEWORKS=$(echo "$ANALYSIS_RESULT" | jq -r '.frameworks[]?' 2>/dev/null || true)
        TESTING=$(echo "$ANALYSIS_RESULT" | jq -r '.testing[]?' 2>/dev/null || true)

        PRIMARY_TECHNOLOGY=$(echo "$ANALYSIS_RESULT" | jq -r '.technologies[0] // "unknown"' 2>/dev/null || echo "unknown")

        if [ -n "${TECHNOLOGIES}${FRAMEWORKS}${TESTING}" ]; then
            echo "Detected:"
            if [ -n "$TECHNOLOGIES" ]; then
                echo "  technologies:"
                echo "$TECHNOLOGIES" | while read -r tech; do
                    [ -n "$tech" ] && echo -e "    ${GREEN}•${NC} $tech"
                done
            fi
            if [ -n "$FRAMEWORKS" ]; then
                echo "  frameworks:"
                echo "$FRAMEWORKS" | while read -r fw; do
                    [ -n "$fw" ] && echo -e "    ${GREEN}•${NC} $fw"
                done
            fi
            if [ -n "$TESTING" ]; then
                echo "  testing:"
                echo "$TESTING" | while read -r t; do
                    [ -n "$t" ] && echo -e "    ${GREEN}•${NC} $t"
                done
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC}  Project analysis script not found"
fi

echo ""

# ================================
# Step 4: Create harness configuration file
# ================================

echo -e "${BLUE}[4/6] Creating harness configuration file${NC}"
echo "----------------------------------------"

# Create .claude-code-harness directory
mkdir -p .claude-code-harness

# Create config file with references to existing documents (do not overwrite if already exists)
CONFIG_PATH=".claude-code-harness/config.json"
if [ -f "$CONFIG_PATH" ]; then
    echo -e "${YELLOW}⚠${NC}  Config file already exists (skipping): $CONFIG_PATH"
else
    existing_docs_json=""
    if [ ${#FOUND_DOCS[@]} -gt 0 ]; then
        existing_docs_json=$(
            for doc in "${FOUND_DOCS[@]}"; do
                echo "    \"$doc\","
            done | sed '$ s/,$//'
        )
    fi
    cat > "$CONFIG_PATH" << EOF
{
  "version": "$HARNESS_VERSION",
  "setup_date": "$SETUP_DATE_ISO",
  "project_type": "existing",
  "existing_documents": [
$existing_docs_json
  ],
  "harness_path": "$HARNESS_ROOT"
}
EOF

    echo -e "${GREEN}✓${NC} Config file created: $CONFIG_PATH"
fi

# Create existing documents summary (do not overwrite if already exists)
if [ ${#FOUND_DOCS[@]} -gt 0 ]; then
    SUMMARY_PATH=".claude-code-harness/existing-docs-summary.md"
    if [ -f "$SUMMARY_PATH" ]; then
        echo -e "${YELLOW}⚠${NC}  Existing documents summary already exists (skipping): $SUMMARY_PATH"
    else
        if [ "$HARNESS_LOCALE" = "ja" ]; then
        cat > "$SUMMARY_PATH" << EOF
# Existing Documents

This project already contains the following documents:

EOF
        else
        cat > "$SUMMARY_PATH" << EOF
# Existing Documents

This project already contains the following documents:

EOF
        fi

        for doc in "${FOUND_DOCS[@]}"; do
            echo "## $doc" >> "$SUMMARY_PATH"
            echo "" >> "$SUMMARY_PATH"
            echo '```' >> "$SUMMARY_PATH"
            head -20 "$doc" >> "$SUMMARY_PATH"
            echo '```' >> "$SUMMARY_PATH"
            echo "" >> "$SUMMARY_PATH"
        done

        echo -e "${GREEN}✓${NC} Existing documents summary created: $SUMMARY_PATH"
    fi
fi

echo ""

# ================================
# Step 5: Create Project Rules
# ================================

echo -e "${BLUE}[5/6] Creating Project Rules / workflow files${NC}"
echo "----------------------------------------"

# Create .claude/rules directory
mkdir -p .claude/rules

# Simple template rendering ({{PROJECT_NAME}}/{{DATE}}/{{LANGUAGE}})
escape_sed_repl() {
    # Make safe as a sed replacement string (escape \ / & |)
    # Escape backslash first, then escape the other characters
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/[\/&|]/\\&/g'
}

render_template_if_missing() {
    local template_path="$1"
    local dest_path="$2"
    local label="$3"

    if [ -f "$dest_path" ]; then
        echo -e "${GREEN}✓${NC} ${label}: already exists (skipping)"
        return 0
    fi
    if [ ! -f "$template_path" ]; then
        echo -e "${YELLOW}⚠${NC} ${label}: template not found: $template_path"
        return 0
    fi
    # Also handle nested paths
    mkdir -p "$(dirname "$dest_path")" 2>/dev/null || true

    local project_esc date_esc lang_esc
    project_esc=$(escape_sed_repl "$PROJECT_NAME")
    date_esc=$(escape_sed_repl "$SETUP_DATE_SHORT")
    lang_esc=$(escape_sed_repl "$LANGUAGE")

    sed \
        -e "s|{{PROJECT_NAME}}|$project_esc|g" \
        -e "s|{{DATE}}|$date_esc|g" \
        -e "s|{{LANGUAGE}}|$lang_esc|g" \
        "$template_path" > "$dest_path"

    echo -e "${GREEN}✓${NC} ${label} created: $dest_path"
}

template_for_locale() {
    local relative_path="$1"
    local localized_path="$TEMPLATE_DIR/locales/$HARNESS_LOCALE/$relative_path"

    if [ "$HARNESS_LOCALE" = "ja" ] && [ -f "$localized_path" ]; then
        printf '%s\n' "$localized_path"
        return 0
    fi

    printf '%s\n' "$TEMPLATE_DIR/$relative_path"
}

# Create Project Rules for existing project (do not overwrite if already exists)
RULES_PATH=".claude/rules/harness.md"
if [ -f "$RULES_PATH" ]; then
    echo -e "${YELLOW}⚠${NC}  Project Rules already exist (skipping): $RULES_PATH"
else
    if [ "$HARNESS_LOCALE" = "ja" ]; then
    cat > "$RULES_PATH" << EOF
# Claude Harness - Project Rules

This project uses **claude-code-harness**.

## Applying Harness To An Existing Project

This project already had code and documents before Harness was installed.

### Respect Existing Assets

1. **Prefer existing documents**
   - Read existing specifications, README files, and plans first.
   - .claude-code-harness/existing-docs-summary.md lists discovered documents.

2. **Keep the existing code style**
   - Follow the project's current formatting and conventions.
   - New code should look like it belongs in this repository.

3. **Improve gradually**
   - Do not rewrite everything at once.
   - Check behavior frequently so existing workflows keep working.

## Available Commands

### Core Loop (Plan -> Work -> Review)
- /plan-with-agent - Create or update the project plan with existing docs in mind.
- /work - Implement tasks while preserving existing code behavior.
- /harness-review - Review code quality and risk.

### Quality / Operations
- /validate - Run delivery validation.
- /cleanup - Organize Plans.md and related files.
- /sync-status - Check progress and suggest next actions.
- /refactor - Run safe refactoring.

### Implementation Support
- /crud - Generate CRUD features.
- /ci-setup - Configure CI/CD.

### Conversation-Triggered Skills
- component - "Build a hero section" -> UI component implementation.
- auth - "Add login" -> authentication implementation.
- payments - "Add Stripe payments" -> payment integration.
- deploy-setup - "Deploy to Vercel" -> deployment setup.
- analytics - "Add analytics" -> analytics integration.
- auto-fix - "Fix the review comments" -> automatic fix workflow.

## Notes For Existing Projects

1. **Read existing specs first**
   - Check project documents before running implementation commands.
   - Ask for clarification when documents conflict.

2. **Apply changes gradually**
   - Start with small features.
   - Verify behavior often.

3. **Use version control carefully**
   - Commit frequently.
   - Create a branch before large changes.

## Setup Information

- Setup date: $SETUP_DATE_SHORT
- Harness version: $HARNESS_VERSION
- Config file: .claude-code-harness/config.json
EOF
    else
    cat > "$RULES_PATH" << EOF
# Claude Harness - Project Rules

This project uses **claude-code-harness**.

## Applying Harness To An Existing Project

This project already had code and documents before Harness was installed.

### Respect Existing Assets

1. **Prefer existing documents**
   - Read existing specifications, README files, and plans first.
   - .claude-code-harness/existing-docs-summary.md lists discovered documents.

2. **Keep the existing code style**
   - Follow the project's current formatting and conventions.
   - New code should look like it belongs in this repository.

3. **Improve gradually**
   - Do not rewrite everything at once.
   - Check behavior frequently so existing workflows keep working.

## Available Commands

### Core Loop (Plan -> Work -> Review)
- /plan-with-agent - Create or update the project plan with existing docs in mind.
- /work - Implement tasks while preserving existing code behavior.
- /harness-review - Review code quality and risk.

### Quality / Operations
- /validate - Run delivery validation.
- /cleanup - Organize Plans.md and related files.
- /sync-status - Check progress and suggest next actions.
- /refactor - Run safe refactoring.

### Implementation Support
- /crud - Generate CRUD features.
- /ci-setup - Configure CI/CD.

### Conversation-Triggered Skills
- component - "Build a hero section" -> UI component implementation.
- auth - "Add login" -> authentication implementation.
- payments - "Add Stripe payments" -> payment integration.
- deploy-setup - "Deploy to Vercel" -> deployment setup.
- analytics - "Add analytics" -> analytics integration.
- auto-fix - "Fix the review comments" -> automatic fix workflow.

## Notes For Existing Projects

1. **Read existing specs first**
   - Check project documents before running implementation commands.
   - Ask for clarification when documents conflict.

2. **Apply changes gradually**
   - Start with small features.
   - Verify behavior often.

3. **Use version control carefully**
   - Commit frequently.
   - Create a branch before large changes.

## Setup Information

- Setup date: $SETUP_DATE_SHORT
- Harness version: $HARNESS_VERSION
- Config file: .claude-code-harness/config.json
EOF
    fi

    echo -e "${GREEN}✓${NC} Project Rules created: $RULES_PATH"
fi

echo ""

# Create workflow files (AGENTS/CLAUDE/Plans) as needed (do not overwrite if already exist)
TEMPLATE_DIR="$HARNESS_ROOT/templates"
render_template_if_missing "$(template_for_locale ".claude-code-harness.config.yaml.template")" ".claude-code-harness.config.yaml" ".claude-code-harness.config.yaml"
render_template_if_missing "$(template_for_locale "AGENTS.md.template")" "AGENTS.md" "AGENTS.md"
render_template_if_missing "$(template_for_locale "CLAUDE.md.template")" "CLAUDE.md" "CLAUDE.md"
render_template_if_missing "$(template_for_locale "Plans.md.template")" "Plans.md" "Plans.md"

echo ""

# ================================
# Step 5.5: Initialize project memory (SSOT)
# ================================
echo -e "${BLUE}[5.5/6] Initializing project memory (SSOT)${NC}"
echo "----------------------------------------"

# decisions/patterns are recommended to share as SSOT. session-log is for local use.
mkdir -p .claude/memory
render_template_if_missing "$TEMPLATE_DIR/memory/decisions.md.template" ".claude/memory/decisions.md" "decisions.md (SSOT)"
render_template_if_missing "$TEMPLATE_DIR/memory/patterns.md.template" ".claude/memory/patterns.md" "patterns.md (SSOT)"
render_template_if_missing "$TEMPLATE_DIR/memory/session-log.md.template" ".claude/memory/session-log.md" "session-log.md"

echo ""

# ================================
# Step 6: Setup complete
# ================================

echo -e "${BLUE}[6/6] Setup complete${NC}"
echo "----------------------------------------"

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Review existing documents:"
echo -e "   ${BLUE}cat .claude-code-harness/existing-docs-summary.md${NC}"
echo ""
echo "2. Open the project in Claude Code:"
echo -e "   ${BLUE}cd $PROJECT_PATH${NC}"
echo -e "   ${BLUE}claude${NC}"
echo -e "   ${YELLOW}(If the plugin is not installed, load this harness directly from local)${NC}"
echo -e "   ${BLUE}claude --plugin-dir \"$HARNESS_ROOT\"${NC}"
echo ""
echo "3. Review existing specs then update the plan:"
echo -e "   ${BLUE}/plan${NC}"
echo ""
echo "4. Start implementing with a small feature:"
echo -e "   ${BLUE}/work${NC}"
echo ""
echo "5. Review frequently:"
echo -e "   ${BLUE}/harness-review${NC}"
echo ""
echo "6. (Optional) Enable Cursor integration:"
echo -e "   ${BLUE}/setup-cursor${NC}"
echo ""

# Add to .gitignore
if [ -f ".gitignore" ]; then
    if ! grep -q ".claude-code-harness" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude harness" >> .gitignore
        echo ".claude-code-harness/" >> .gitignore
        echo -e "${GREEN}✓${NC} Added to .gitignore"
    fi

    # Memory policy recommendation (avoid duplicate entries)
    if ! grep -q "Claude Memory Policy" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude Memory Policy (recommended)" >> .gitignore
        echo "# - Keep (shared SSOT): .claude/memory/decisions.md, .claude/memory/patterns.md" >> .gitignore
        echo "# - Ignore (local): .claude/state/, session-log.md, context.json, archives" >> .gitignore
        echo ".claude/state/" >> .gitignore
        echo ".claude/memory/session-log.md" >> .gitignore
        echo ".claude/memory/context.json" >> .gitignore
        echo ".claude/memory/archive/" >> .gitignore
        echo -e "${GREEN}✓${NC} Added memory policy recommendation to .gitignore (adjust as needed)"
    fi
fi

echo ""
echo -e "${YELLOW}⚠${NC}  Important: committing the changes is recommended"
echo ""
