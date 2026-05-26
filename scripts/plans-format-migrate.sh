#!/bin/bash
# plans-format-migrate.sh
# Migrates Plans.md from legacy format to the new format

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"
DRY_RUN="${2:-false}"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Plans.md Format Migration${NC}"
echo "=========================================="
echo ""

# Plans.md does not exist
if [ ! -f "$PLANS_FILE" ]; then
  echo -e "${RED}Error: $PLANS_FILE not found${NC}"
  exit 1
fi

# Create backup
BACKUP_DIR=".claude-code-harness/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$PLANS_FILE" "$BACKUP_DIR/Plans.md.backup"
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_DIR/Plans.md.backup"

# Change count
CHANGES=0

# 1. cursor:WIP → pm:依頼中 (interpreted as pending PM review)
# Note: cursor:WIP typically means "PM(Cursor) is reviewing"
# In the new format this corresponds to pm:依頼中 (implementation done, pending PM review)
if grep -qE 'cursor:WIP' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} cursor:WIP detected"
  if [ "$DRY_RUN" = "false" ]; then
    sed -i '' 's/cursor:WIP/pm:依頼中/g' "$PLANS_FILE" 2>/dev/null || \
    sed -i 's/cursor:WIP/pm:依頼中/g' "$PLANS_FILE"
    echo -e "  ${GREEN}✓${NC} cursor:WIP → pm:依頼中 converted"
  else
    echo -e "  [DRY RUN] cursor:WIP → pm:依頼中 will be converted"
  fi
  ((CHANGES++))
fi

# 2. cursor:完了 → pm:確認済
if grep -qE 'cursor:完了' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} cursor:完了 detected"
  if [ "$DRY_RUN" = "false" ]; then
    sed -i '' 's/cursor:完了/pm:確認済/g' "$PLANS_FILE" 2>/dev/null || \
    sed -i 's/cursor:完了/pm:確認済/g' "$PLANS_FILE"
    echo -e "  ${GREEN}✓${NC} cursor:完了 → pm:確認済 converted"
  else
    echo -e "  [DRY RUN] cursor:完了 → pm:確認済 will be converted"
  fi
  ((CHANGES++))
fi

# 3. Check for marker legend section
if ! grep -qE '## マーカー凡例|## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} Marker legend section is missing"
  echo -e "  ${YELLOW}!${NC} It is recommended to add it manually"
fi

# Show results
echo ""
echo "=========================================="
if [ $CHANGES -gt 0 ]; then
  if [ "$DRY_RUN" = "false" ]; then
    echo -e "${GREEN}✓ Migration complete: $CHANGES change(s)${NC}"
    echo ""
    echo "Please review the changes:"
    echo "  git diff $PLANS_FILE"
  else
    echo -e "${YELLOW}DRY RUN: $CHANGES change(s) pending${NC}"
    echo ""
    echo "To apply the conversion:"
    echo "  ./scripts/plans-format-migrate.sh $PLANS_FILE false"
  fi
else
  echo -e "${GREEN}✓ No changes needed. Format is already up to date.${NC}"
fi
