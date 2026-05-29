#!/bin/bash
#
# Claude Harness Quick Install Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/quick-install.sh | bash
#
# Or with dev tools:
#   curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/quick-install.sh | bash -s -- --with-dev-tools
#
# Japanese setup templates:
#   curl -fsSL https://raw.githubusercontent.com/Chachamaru127/claude-code-harness/main/scripts/quick-install.sh | bash -s -- --locale ja
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
WITH_DEV_TOOLS=false
LOCALE="en"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --with-dev-tools)
      WITH_DEV_TOOLS=true
      shift
      ;;
    --locale)
      if [ $# -lt 2 ]; then
        LOCALE="en"
        shift
      else
        LOCALE="$2"
        shift 2
      fi
      ;;
    --locale=*)
      LOCALE="${1#--locale=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

case "$LOCALE" in
  ja|en) ;;
  *) LOCALE="en" ;;
esac

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Claude Harness - Quick Install${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check if claude is installed
if ! command -v claude &> /dev/null; then
  echo -e "${RED}Error: Claude Code CLI not found.${NC}"
  echo
  echo "Install Claude Code first:"
  echo "  npm install -g @anthropic-ai/claude-code"
  echo
  exit 1
fi

echo -e "${GREEN}✓${NC} Claude Code found"

# Check Claude Code version
CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
echo -e "  Version: ${CLAUDE_VERSION}"
echo

# Install plugin
echo -e "${YELLOW}Installing Claude Harness plugin...${NC}"
echo

# Add to marketplace
echo "  Adding from marketplace..."
claude /plugin marketplace add Chachamaru127/claude-code-harness 2>/dev/null || true

# Install
echo "  Installing plugin..."
claude /plugin install claude-code-harness@claude-code-harness-marketplace 2>/dev/null || {
  echo -e "${YELLOW}Note: Plugin may already be installed or requires manual installation.${NC}"
}

echo
echo -e "${GREEN}✓${NC} Plugin installation complete"
echo

# Install dev tools if requested
if [ "$WITH_DEV_TOOLS" = true ]; then
  echo -e "${YELLOW}Installing development tools...${NC}"
  echo

  # AST-Grep
  if ! command -v sg &> /dev/null; then
    echo "  AST-Grep not found."
    if command -v brew &> /dev/null; then
      echo "  Installing AST-Grep with Homebrew..."
      brew install ast-grep 2>/dev/null || echo "  Please install ast-grep manually: https://ast-grep.github.io/guide/quick-start.html"
    else
      echo "  Please install ast-grep manually: https://ast-grep.github.io/guide/quick-start.html"
    fi
  else
    echo -e "  ${GREEN}✓${NC} AST-Grep already installed"
  fi

  # TypeScript Language Server (if package.json exists)
  if [ -f "package.json" ]; then
    if ! command -v typescript-language-server &> /dev/null; then
      echo "  TypeScript Language Server not found."
      echo "  Please install it with your project's versioned package-manager workflow."
    else
      echo -e "  ${GREEN}✓${NC} TypeScript Language Server already installed"
    fi
  fi

  echo
  echo -e "${GREEN}✓${NC} Development tools installation complete"
  echo
fi

# Next steps
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "Next steps:"
echo
echo "  1. Start Claude Code in your project:"
echo "     ${YELLOW}cd /path/to/your-project && claude${NC}"
echo
echo "  2. Initialize Harness:"
if [ "$LOCALE" = "ja" ]; then
  echo "     ${YELLOW}CLAUDE_CODE_HARNESS_LANG=ja claude${NC}"
  echo "     ${YELLOW}/harness-setup${NC}"
else
  echo "     ${YELLOW}/harness-setup${NC}"
fi
echo
echo "  3. Create your first plan:"
echo "     ${YELLOW}/plan-with-agent${NC}"
echo
echo "  Language: English is the default. For Japanese, set"
echo "  ${YELLOW}i18n.language: ja${NC} in .claude-code-harness.config.yaml"
echo "  or start Claude with ${YELLOW}CLAUDE_CODE_HARNESS_LANG=ja${NC}."
echo
echo "  Note: Default security permissions (deny/ask rules) are applied"
echo "  automatically via plugin settings. No manual configuration needed."
echo

if [ "$WITH_DEV_TOOLS" = false ]; then
  echo "Optional: Install dev tools for advanced code intelligence:"
  echo "     ${YELLOW}/dev-tools-setup${NC}"
  echo
fi

echo "Documentation: https://github.com/Chachamaru127/claude-code-harness"
echo
