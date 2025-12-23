#!/bin/bash
# test-quality-guardrails.sh
# テスト改ざん防止機能（3層防御戦略）の検証テスト
#
# テスト対象:
# - 第1層: Rules テンプレートの存在と構造
# - 第2層: Skills の品質ガードレール統合
# - harness-init での展開設定

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# カウンター
PASSED=0
FAILED=0
TOTAL=0

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# テスト関数
assert_file_exists() {
  local file="$1"
  local description="$2"
  TOTAL=$((TOTAL + 1))

  if [ -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected file: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  TOTAL=$((TOTAL + 1))

  if [ ! -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if grep -q "$pattern" "$PLUGIN_ROOT/$file"; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected pattern: $pattern"
    echo "  File: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

assert_json_key_exists() {
  local file="$1"
  local key="$2"
  local description="$3"
  TOTAL=$((TOTAL + 1))

  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} $description (jq not available, skipped)"
    return 0
  fi

  if [ ! -f "$PLUGIN_ROOT/$file" ]; then
    echo -e "${RED}✗${NC} $description (file not found)"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if jq -e "$key" "$PLUGIN_ROOT/$file" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $description"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected key: $key"
    echo "  File: $file"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

echo "=================================================="
echo "テスト改ざん防止機能（3層防御戦略）検証"
echo "=================================================="
echo ""

# ============================================
# 第1層: Rules テンプレートの検証
# ============================================
echo "## 第1層: Rules テンプレート"
echo ""

# テスト品質ルールテンプレートの存在
assert_file_exists \
  "templates/rules/test-quality.md.template" \
  "test-quality.md.template が存在する"

# 実装品質ルールテンプレートの存在
assert_file_exists \
  "templates/rules/implementation-quality.md.template" \
  "implementation-quality.md.template が存在する"

# test-quality.md の必須コンテンツ
assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "it.skip\|test.skip" \
  "test-quality.md に skip 禁止パターンが含まれる"

assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "eslint\|lint\|disable" \
  "test-quality.md に lint 設定改ざん禁止が含まれる"

assert_file_contains \
  "templates/rules/test-quality.md.template" \
  "_harness_template" \
  "test-quality.md にフロントマターメタデータが含まれる"

# implementation-quality.md の必須コンテンツ
assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "ハードコード\|hardcode" \
  "implementation-quality.md にハードコード禁止が含まれる"

assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "スタブ\|stub" \
  "implementation-quality.md にスタブ禁止が含まれる"

assert_file_contains \
  "templates/rules/implementation-quality.md.template" \
  "_harness_template" \
  "implementation-quality.md にフロントマターメタデータが含まれる"

# template-registry.json への登録
assert_json_key_exists \
  "templates/template-registry.json" \
  '.templates["rules/test-quality.md.template"]' \
  "template-registry.json に test-quality.md が登録されている"

assert_json_key_exists \
  "templates/template-registry.json" \
  '.templates["rules/implementation-quality.md.template"]' \
  "template-registry.json に implementation-quality.md が登録されている"

echo ""

# ============================================
# 第2層: Skills の品質ガードレール検証
# ============================================
echo "## 第2層: Skills 品質ガードレール"
echo ""

# impl スキルの品質ガードレール
assert_file_contains \
  "skills/impl/SKILL.md" \
  "品質ガードレール\|Quality Guardrails" \
  "impl/SKILL.md に品質ガードレールセクションがある"

assert_file_contains \
  "skills/impl/SKILL.md" \
  "禁止パターン\|Prohibited\|禁止" \
  "impl/SKILL.md に禁止パターンが定義されている"

assert_file_contains \
  "skills/impl/SKILL.md" \
  "purpose-driven\|Purpose-Driven\|目的駆動" \
  "impl/SKILL.md に Purpose-Driven Implementation 原則がある"

# verify スキルの品質ガードレール
assert_file_contains \
  "skills/verify/SKILL.md" \
  "品質ガードレール\|Quality Guardrails" \
  "verify/SKILL.md に品質ガードレールセクションがある"

assert_file_contains \
  "skills/verify/SKILL.md" \
  "改ざん禁止\|Tampering Prohibited\|禁止" \
  "verify/SKILL.md に改ざん禁止パターンが定義されている"

assert_file_contains \
  "skills/verify/SKILL.md" \
  "承認リクエスト\|Approval Request" \
  "verify/SKILL.md に承認リクエスト形式がある"

echo ""

# ============================================
# harness-init 統合検証
# ============================================
echo "## harness-init 統合"
echo ""

# harness-init での品質ルール展開設定
assert_file_contains \
  "commands/core/harness-init.md" \
  "test-quality.md" \
  "harness-init に test-quality.md 展開が含まれる"

assert_file_contains \
  "commands/core/harness-init.md" \
  "implementation-quality.md" \
  "harness-init に implementation-quality.md 展開が含まれる"

assert_file_contains \
  "commands/core/harness-init.md" \
  "品質保護ルール\|Quality Protection" \
  "harness-init に品質保護ルールセクションがある"

echo ""

# ============================================
# ドキュメント検証
# ============================================
echo "## ドキュメント"
echo ""

# CLAUDE.md のテスト改ざん防止セクション
assert_file_contains \
  "CLAUDE.md" \
  "テスト改ざん防止\|Test Tampering Prevention" \
  "CLAUDE.md にテスト改ざん防止セクションがある"

assert_file_contains \
  "CLAUDE.md" \
  "3層防御\|3-layer\|第1層\|第2層\|第3層" \
  "CLAUDE.md に3層防御戦略の説明がある"

# README.md の品質保証セクション
assert_file_contains \
  "README.md" \
  "テスト改ざん防止\|品質保証\|Quality Assurance" \
  "README.md に品質保証セクションがある"

# 設計ドキュメント
assert_file_exists \
  "docs/QUALITY_GUARD_DESIGN.md" \
  "第3層 Hooks 設計ドキュメントが存在する"

echo ""

# ============================================
# 結果サマリー
# ============================================
echo "=================================================="
echo "テスト結果"
echo "=================================================="
echo ""
echo "合計: $TOTAL"
echo -e "成功: ${GREEN}$PASSED${NC}"
echo -e "失敗: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ すべてのテストが成功しました${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILED 件のテストが失敗しました${NC}"
  exit 1
fi
