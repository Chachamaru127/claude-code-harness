#!/bin/bash
# validate-skills.sh
# スキルの整合性・ガバナンス検証テスト
#
# Usage: ./tests/validate-skills.sh [--verbose]
#
# 検証項目:
#   1. SKILL.md の frontmatter 必須フィールド (description, allowed-tools)
#   2. references/ ディレクトリ内の *.md ファイル存在
#   3. allowed-tools が有効な Claude Code ツール名か
#   4. dependencies が存在するスキルを参照しているか

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PLUGIN_ROOT/skills"

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

# カラー出力
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

# 有効な Claude Code ツール名リスト
VALID_TOOLS=(
  "Read" "Write" "Edit" "Glob" "Grep" "Bash"
  "Task" "WebFetch" "WebSearch" "TodoWrite"
  "AskUserQuestion" "Skill" "EnterPlanMode" "ExitPlanMode"
  "NotebookEdit" "LSP" "MCPSearch" "Append"
)

is_valid_tool() {
  local tool="$1"
  for valid in "${VALID_TOOLS[@]}"; do
    if [[ "$valid" == "$tool" ]]; then
      return 0
    fi
  done
  return 1
}

# frontmatter からフィールド値を抽出
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
echo "Claude harness - スキル検証テスト"
echo "=========================================="
echo ""

if [ ! -d "$SKILLS_DIR" ]; then
  fail_test "skills ディレクトリが見つかりません: $SKILLS_DIR"
  exit 1
fi

# スキルディレクトリを収集
SKILL_DIRS=()
while IFS= read -r skill_md; do
  SKILL_DIRS+=("$(dirname "$skill_md")")
done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null | sort)

if [ ${#SKILL_DIRS[@]} -eq 0 ]; then
  warn_test "SKILL.md が見つかりません"
  exit 0
fi

echo "1. SKILL.md frontmatter 検証"
echo "----------------------------------------"

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  debug_log "Checking: $skill_name"

  # description 必須
  description=$(extract_frontmatter_field "$skill_file" "description")
  if [ -n "$description" ]; then
    pass_test "[$skill_name] description: ${description:0:50}..."
  else
    fail_test "[$skill_name] description が見つかりません"
  fi

  # allowed-tools 必須
  allowed_tools=$(extract_frontmatter_field "$skill_file" "allowed-tools")
  if [ -n "$allowed_tools" ]; then
    pass_test "[$skill_name] allowed-tools: $allowed_tools"
  else
    fail_test "[$skill_name] allowed-tools が見つかりません"
  fi
done

echo ""
echo "2. allowed-tools 有効性検証"
echo "----------------------------------------"

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  allowed_tools=$(extract_frontmatter_field "$skill_file" "allowed-tools")
  if [ -z "$allowed_tools" ]; then
    continue
  fi

  # [Tool1, Tool2] または ["Tool1", "Tool2"] 形式をパース
  # クォート、ブラケット、スペースを除去
  tools_str=$(echo "$allowed_tools" | sed 's/^\[//' | sed 's/\]$//' | tr ',' '\n' | sed 's/^[ "]*//;s/[ "]*$//')

  invalid_found=0
  while IFS= read -r tool; do
    # 余分な空白とクォートを除去
    tool=$(echo "$tool" | tr -d ' "'\''')
    if [ -z "$tool" ]; then
      continue
    fi

    # ワイルドカードパターン (mcp__*) はスキップ
    if [[ "$tool" == *"*"* ]]; then
      debug_log "[$skill_name] Wildcard pattern skipped: $tool"
      continue
    fi

    if is_valid_tool "$tool"; then
      debug_log "[$skill_name] Valid tool: $tool"
    else
      fail_test "[$skill_name] 無効なツール名: $tool"
      invalid_found=1
    fi
  done <<< "$tools_str"

  if [ "$invalid_found" -eq 0 ]; then
    pass_test "[$skill_name] 全ツール名が有効"
  fi
done

echo ""
echo "3. references/ ディレクトリ検証"
echo "----------------------------------------"

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  ref_dir="$skill_dir/references"

  if [ -d "$ref_dir" ]; then
    ref_count=$(find "$ref_dir" -name "*.md" -type f | wc -l | tr -d ' ')
    if [ "$ref_count" -gt 0 ]; then
      pass_test "[$skill_name] references/: $ref_count 個のドキュメント"
    else
      warn_test "[$skill_name] references/ が空です"
    fi
  else
    debug_log "[$skill_name] references/ なし（オプション）"
  fi
done

echo ""
echo "4. dependencies 検証"
echo "----------------------------------------"

# 全スキル名を収集
ALL_SKILL_NAMES=()
for skill_dir in "${SKILL_DIRS[@]}"; do
  ALL_SKILL_NAMES+=("$(basename "$skill_dir")")
done

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  dependencies=$(extract_frontmatter_field "$skill_file" "dependencies")
  if [ -z "$dependencies" ] || [ "$dependencies" == "[]" ]; then
    debug_log "[$skill_name] 依存なし"
    continue
  fi

  # [dep1, dep2] 形式をパース
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
      pass_test "[$skill_name] 依存 '$dep' は存在します"
    else
      fail_test "[$skill_name] 依存 '$dep' が見つかりません"
      invalid_dep=1
    fi
  done <<< "$deps_str"
done

echo ""
echo "=========================================="
echo "スキル検証結果サマリー"
echo "=========================================="
echo -e "${GREEN}合格:${NC} $PASS_COUNT"
echo -e "${YELLOW}警告:${NC} $WARN_COUNT"
echo -e "${RED}失敗:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ 全てのスキル検証に合格しました！${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAIL_COUNT 件の検証が失敗しました${NC}"
  exit 1
fi
