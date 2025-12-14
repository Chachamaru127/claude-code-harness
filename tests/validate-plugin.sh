#!/bin/bash
# VibeCoder向けプラグイン検証テスト
# このスクリプトは、claude-code-harnessが正しく構成されているかを検証します

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Claude Code Harness - プラグイン検証テスト"
echo "=========================================="
echo ""

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# テスト結果を記録
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

json_is_valid() {
    local file="$1"
    python3 - <<'PY' "$file" >/dev/null 2>&1
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    json.load(f)
PY
}

json_has_key() {
    local file="$1"
    local key="$2"
    python3 - <<'PY' "$file" "$key" >/dev/null 2>&1
import json, sys
path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
if key not in data:
    raise SystemExit(1)
PY
}

has_frontmatter_description() {
    local file="$1"
    # frontmatter があり、その中に description: があるか
    awk '
      NR==1 { if ($0 != "---") exit 1 }
      NR>1 && $0=="---" { exit 2 }  # end of frontmatter without description
      NR>1 && $0 ~ /^description:/ { exit 0 }
      NR>50 { exit 1 }              # safety
    ' "$file"
}

echo "1. プラグイン構造の検証"
echo "----------------------------------------"

# plugin.jsonの存在確認
if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    pass_test "plugin.json が存在します"
else
    fail_test "plugin.json が見つかりません"
    exit 1
fi

# plugin.jsonの妥当性チェック
if json_is_valid "$PLUGIN_ROOT/.claude-plugin/plugin.json"; then
    pass_test "plugin.json は有効なJSONです"
else
    fail_test "plugin.json が不正なJSONです"
    exit 1
fi

# 必須フィールドの確認
REQUIRED_FIELDS=("name" "version" "description" "author")
for field in "${REQUIRED_FIELDS[@]}"; do
    if json_has_key "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$field"; then
        pass_test "plugin.json に $field フィールドがあります"
    else
        fail_test "plugin.json に $field フィールドがありません"
    fi
done

echo ""
echo "2. コマンドの検証"
echo "----------------------------------------"

# コマンドは plugin.json で手動列挙せず、commands/ を自動検出する（Claude Code Plugins reference 準拠）
# サブディレクトリ内のコマンドも検出（core/, handoff/, optional/ 等）
if [ -d "$PLUGIN_ROOT/commands" ]; then
    CMD_COUNT=$(find "$PLUGIN_ROOT/commands" -name "*.md" -type f | wc -l | tr -d ' ')
    pass_test "commands/ に ${CMD_COUNT} 個のコマンドファイルがあります"

    # サブディレクトリ構造を表示
    for subdir in "$PLUGIN_ROOT/commands"/*/; do
        if [ -d "$subdir" ]; then
            subdir_name=$(basename "$subdir")
            subdir_count=$(find "$subdir" -name "*.md" -type f | wc -l | tr -d ' ')
            pass_test "  └─ ${subdir_name}/ に ${subdir_count} 個のコマンド"
        fi
    done

    # frontmatter description の存在確認（SlashCommand tool / /help の発見性向上）
    MISSING_DESC=0
    while IFS= read -r cmd_file; do
        if has_frontmatter_description "$cmd_file"; then
            pass_test "frontmatter description: $(basename "$cmd_file")"
        else
            warn_test "frontmatter description が見つかりません: $(basename "$cmd_file")"
            MISSING_DESC=$((MISSING_DESC + 1))
        fi
    done < <(find "$PLUGIN_ROOT/commands" -name "*.md" -type f | sort)
else
    fail_test "commands ディレクトリが見つかりません"
fi

echo ""
echo "3. スキルの検証"
echo "----------------------------------------"

# スキルディレクトリの存在
if [ -d "$PLUGIN_ROOT/skills" ]; then
    SKILL_COUNT=$(find "$PLUGIN_ROOT/skills" -name "SKILL.md" | wc -l)
    pass_test "$SKILL_COUNT 個のスキルが定義されています"
    
    # スキルのフロントマター確認（サンプル）
    SKILLS_WITH_DESCRIPTION=0
    SKILLS_WITH_ALLOWED_TOOLS=0
    
    find "$PLUGIN_ROOT/skills" -name "SKILL.md" | while read -r skill_file; do
        if grep -q "^description:" "$skill_file"; then
            ((SKILLS_WITH_DESCRIPTION++))
        fi
        if grep -q "^allowed-tools:" "$skill_file"; then
            ((SKILLS_WITH_ALLOWED_TOOLS++))
        fi
    done
    
    if [ $SKILL_COUNT -gt 0 ]; then
        pass_test "スキルファイルが適切に配置されています"
    fi
else
    warn_test "skills ディレクトリが見つかりません"
fi

echo ""
echo "4. エージェントの検証"
echo "----------------------------------------"

if [ -d "$PLUGIN_ROOT/agents" ]; then
    AGENT_COUNT=$(find "$PLUGIN_ROOT/agents" -name "*.md" | wc -l)
    if [ $AGENT_COUNT -gt 0 ]; then
        pass_test "$AGENT_COUNT 個のエージェントが定義されています"
    else
        warn_test "エージェントが定義されていません"
    fi
else
    warn_test "agents ディレクトリが見つかりません"
fi

echo ""
echo "5. フックの検証"
echo "----------------------------------------"

if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
    if json_is_valid "$PLUGIN_ROOT/hooks/hooks.json"; then
        pass_test "hooks.json は有効なJSONです"
        
        pass_test "hooks.json が読み込めます"
    else
        fail_test "hooks.json が不正なJSONです"
    fi
else
    warn_test "hooks.json が見つかりません"
fi

echo ""
echo "6. スクリプトの検証"
echo "----------------------------------------"

if [ -d "$PLUGIN_ROOT/scripts" ]; then
    SCRIPT_COUNT=$(find "$PLUGIN_ROOT/scripts" -name "*.sh" -type f | wc -l)
    if [ $SCRIPT_COUNT -gt 0 ]; then
        pass_test "$SCRIPT_COUNT 個のスクリプトが存在します"
        
        # 実行権限の確認（GNU/BSD 両対応: -perm -111 を使用）
        EXECUTABLE_COUNT=$(find "$PLUGIN_ROOT/scripts" -name "*.sh" -type f -perm -111 | wc -l | tr -d ' ')
        if [ $EXECUTABLE_COUNT -eq $SCRIPT_COUNT ]; then
            pass_test "全てのスクリプトに実行権限があります"
        else
            warn_test "一部のスクリプトに実行権限がありません ($EXECUTABLE_COUNT/$SCRIPT_COUNT)"
        fi
    else
        warn_test "スクリプトが見つかりません"
    fi
else
    warn_test "scripts ディレクトリが見つかりません"
fi

echo ""
echo "7. ドキュメントの検証"
echo "----------------------------------------"

if [ -f "$PLUGIN_ROOT/README.md" ]; then
    README_SIZE=$(wc -c < "$PLUGIN_ROOT/README.md")
    if [ $README_SIZE -gt 1000 ]; then
        pass_test "README.md が存在します (${README_SIZE} bytes)"
    else
        warn_test "README.md が簡潔すぎます (${README_SIZE} bytes)"
    fi
else
    fail_test "README.md が見つかりません"
fi

if [ -f "$PLUGIN_ROOT/IMPLEMENTATION_GUIDE.md" ]; then
    pass_test "IMPLEMENTATION_GUIDE.md が存在します"
else
    warn_test "IMPLEMENTATION_GUIDE.md が見つかりません（推奨）"
fi

echo ""
echo "=========================================="
echo "テスト結果サマリー"
echo "=========================================="
echo -e "${GREEN}合格:${NC} $PASS_COUNT"
echo -e "${YELLOW}警告:${NC} $WARN_COUNT"
echo -e "${RED}失敗:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ 全てのテストに合格しました！${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAIL_COUNT 件のテストが失敗しました${NC}"
    exit 1
fi
