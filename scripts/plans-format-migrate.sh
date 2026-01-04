#!/bin/bash
# plans-format-migrate.sh
# Plans.md の旧フォーマットを新フォーマットに移行

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"
DRY_RUN="${2:-false}"

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Plans.md フォーマットマイグレーション${NC}"
echo "=========================================="
echo ""

# Plans.md が存在しない場合
if [ ! -f "$PLANS_FILE" ]; then
  echo -e "${RED}エラー: $PLANS_FILE が見つかりません${NC}"
  exit 1
fi

# バックアップ作成
BACKUP_DIR=".claude-code-harness/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$PLANS_FILE" "$BACKUP_DIR/Plans.md.backup"
echo -e "${GREEN}✓${NC} バックアップ作成: $BACKUP_DIR/Plans.md.backup"

# 変更カウント
CHANGES=0

# 1. cursor:WIP → pm:依頼中（PMレビュー待ち状態として解釈）
# Note: cursor:WIP は通常「PM(Cursor)がレビュー中」を意味する
# 新フォーマットでは pm:依頼中（実装完了→PMレビュー待ち）に相当
if grep -qE 'cursor:WIP' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} cursor:WIP を検出"
  if [ "$DRY_RUN" = "false" ]; then
    sed -i '' 's/cursor:WIP/pm:依頼中/g' "$PLANS_FILE" 2>/dev/null || \
    sed -i 's/cursor:WIP/pm:依頼中/g' "$PLANS_FILE"
    echo -e "  ${GREEN}✓${NC} cursor:WIP → pm:依頼中 に変換"
  else
    echo -e "  [DRY RUN] cursor:WIP → pm:依頼中 に変換予定"
  fi
  ((CHANGES++))
fi

# 2. cursor:完了 → pm:確認済
if grep -qE 'cursor:完了' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} cursor:完了 を検出"
  if [ "$DRY_RUN" = "false" ]; then
    sed -i '' 's/cursor:完了/pm:確認済/g' "$PLANS_FILE" 2>/dev/null || \
    sed -i 's/cursor:完了/pm:確認済/g' "$PLANS_FILE"
    echo -e "  ${GREEN}✓${NC} cursor:完了 → pm:確認済 に変換"
  else
    echo -e "  [DRY RUN] cursor:完了 → pm:確認済 に変換予定"
  fi
  ((CHANGES++))
fi

# 3. マーカー凡例セクションの更新チェック
if ! grep -qE '## マーカー凡例|## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}→${NC} マーカー凡例セクションがありません"
  echo -e "  ${YELLOW}!${NC} 手動で追加することを推奨します"
fi

# 結果表示
echo ""
echo "=========================================="
if [ $CHANGES -gt 0 ]; then
  if [ "$DRY_RUN" = "false" ]; then
    echo -e "${GREEN}✓ マイグレーション完了: $CHANGES 件の変更${NC}"
    echo ""
    echo "変更内容を確認してください:"
    echo "  git diff $PLANS_FILE"
  else
    echo -e "${YELLOW}DRY RUN: $CHANGES 件の変更が予定されています${NC}"
    echo ""
    echo "実際に変換するには:"
    echo "  ./scripts/plans-format-migrate.sh $PLANS_FILE false"
  fi
else
  echo -e "${GREEN}✓ 変更は不要です。フォーマットは最新です。${NC}"
fi
