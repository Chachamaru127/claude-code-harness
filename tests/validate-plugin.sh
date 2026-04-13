#!/bin/bash
# VibeCoder向けプラグイン検証テスト
# このスクリプトは、claude-code-harnessが正しく構成されているかを検証します

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Claude harness - プラグイン検証テスト"
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
echo "2. コマンドの検証（レガシー）"
echo "----------------------------------------"

# v2.17.0 以降: コマンドは Skills に移行済み
# commands/ ディレクトリが存在する場合のみ検証（後方互換性）
if [ -d "$PLUGIN_ROOT/commands" ]; then
    CMD_COUNT=$(find "$PLUGIN_ROOT/commands" -name "*.md" -type f | wc -l | tr -d ' ')
    pass_test "commands/ に ${CMD_COUNT} 個のコマンドファイルがあります（レガシー）"

    # サブディレクトリ構造を表示
    for subdir in "$PLUGIN_ROOT/commands"/*/; do
        if [ -d "$subdir" ]; then
            subdir_name=$(basename "$subdir")
            subdir_count=$(find "$subdir" -name "*.md" -type f | wc -l | tr -d ' ')
            if [ "$subdir_count" -gt 0 ]; then
                pass_test "  └─ ${subdir_name}/ に ${subdir_count} 個のコマンド"
            else
                warn_test "  └─ ${subdir_name}/ は空です（コマンドファイルがありません）"
            fi
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
    # v2.17.0+: Skills に移行済みのため、commands/ は不要
    pass_test "commands/ は Skills に移行済み（v2.17.0+）"
fi

echo ""
echo "3. スキルの検証"
echo "----------------------------------------"

# plugin.json の skills パス先に SKILL.md が実在するかチェック（v4.0.3 regression guard）
# skills: ["./"] のような誤設定で配布時に 0 件ロードされる事故を再発させないため、
# plugin.json の skills フィールドが指すディレクトリを実際に走査し、SKILL.md の存在を検証する。
skills_path_check_output=$(python3 - "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$PLUGIN_ROOT" <<'PY' 2>&1
import json
import os
import sys

manifest_path, plugin_root = sys.argv[1], sys.argv[2]
with open(manifest_path, "r", encoding="utf-8") as fh:
    manifest = json.load(fh)

skills_field = manifest.get("skills", "./skills/")
if isinstance(skills_field, str):
    paths = [skills_field]
elif isinstance(skills_field, list):
    paths = skills_field
else:
    print("skills field must be string or array of strings", file=sys.stderr)
    sys.exit(2)

errors = []
details = []
for entry in paths:
    resolved = os.path.normpath(os.path.join(plugin_root, entry))
    if not os.path.isdir(resolved):
        errors.append(f"path does not exist: {entry}")
        continue
    count = 0
    for dirpath, _dirnames, filenames in os.walk(resolved):
        if "SKILL.md" in filenames:
            count += 1
    if count == 0:
        errors.append(f"no SKILL.md found under: {entry}")
    else:
        details.append(f"{entry} -> {count} skills")

if errors:
    for err in errors:
        print(err, file=sys.stderr)
    sys.exit(1)

print(", ".join(details))
PY
)
skills_path_check_status=$?

if [ $skills_path_check_status -eq 0 ]; then
    pass_test "plugin.json の skills パス先に SKILL.md が実在します ($skills_path_check_output)"
else
    fail_test "plugin.json の skills パス先に SKILL.md が見つかりません: $skills_path_check_output"
fi

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

POST_TOOL_FAILURE="$PLUGIN_ROOT/scripts/hook-handlers/post-tool-failure.sh"
if [ -f "$POST_TOOL_FAILURE" ]; then
    tmp_dir="$(mktemp -d)"
    target_file="$tmp_dir/target.txt"
    mkdir -p "$tmp_dir/.claude/state"
    printf 'SAFE\n' > "$target_file"
    ln -s "$target_file" "$tmp_dir/.claude/state/tool-failure-counter.txt"

    hook_output="$(printf '{"tool_name":"Bash","error":"boom"}' | PROJECT_ROOT="$tmp_dir" bash "$POST_TOOL_FAILURE" 2>/dev/null || true)"
    target_after="$(cat "$target_file" 2>/dev/null || true)"

    if [ "$hook_output" = "{}" ] && [ "$target_after" = "SAFE" ]; then
        pass_test "post-tool-failure.sh は symlink state file を上書きしません"
    else
        fail_test "post-tool-failure.sh の symlink 防御が不足しています"
    fi

    rm -rf "$tmp_dir"
fi

MEMORY_WRAPPERS=(
    "$PLUGIN_ROOT/scripts/lib/harness-mem-bridge.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-bridge.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-session-start.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-user-prompt.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-post-tool-use.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-stop.sh"
    "$PLUGIN_ROOT/scripts/hook-handlers/memory-codex-notify.sh"
)
for wrapper in "${MEMORY_WRAPPERS[@]}"; do
    if [ -f "$wrapper" ]; then
        pass_test "memory wrapper が存在します: $(basename "$wrapper")"
    else
        fail_test "memory wrapper が見つかりません: $wrapper"
    fi
done

if bash "$PLUGIN_ROOT/tests/test-memory-hook-wiring.sh" >/dev/null 2>&1; then
    pass_test "memory hook wiring が有効です"
else
    fail_test "memory hook wiring の整合が崩れています"
fi

if bash "$PLUGIN_ROOT/tests/test-sync-plugin-cache.sh" >/dev/null 2>&1; then
    pass_test "sync-plugin-cache が memory wrapper を配布キャッシュへ同期できます"
else
    fail_test "sync-plugin-cache が memory wrapper を配布キャッシュへ同期できません"
fi

if bash "$PLUGIN_ROOT/tests/test-runtime-reactive-hooks.sh" >/dev/null 2>&1; then
    pass_test "reactive hook runtime (TaskCreated/FileChanged/CwdChanged) が動作します"
else
    fail_test "reactive hook runtime (TaskCreated/FileChanged/CwdChanged) に問題があります"
fi

if bash "$PLUGIN_ROOT/tests/test-claude-upstream-integration.sh" >/dev/null 2>&1; then
    pass_test "Claude Code 2.1.80-2.1.86 の統合ポイントが配線されています"
else
    fail_test "Claude Code 2.1.80-2.1.86 の統合ポイントに欠落があります"
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
echo "7. Claude Code プラグイン検証（v2.1.77+）"
echo "----------------------------------------"

# claude コマンドが利用可能な場合のみ実行
if command -v claude > /dev/null 2>&1; then
    # サブコマンドの存在を確認（v2.1.77 未満では plugin validate が無い）
    if claude plugin validate --help > /dev/null 2>&1; then
        if claude plugin validate "$PLUGIN_ROOT/.claude-plugin/plugin.json" > /dev/null 2>&1; then
            pass_test "claude plugin validate に合格"
        else
            fail_test "claude plugin validate でエラー検出（CC v2.1.77+ 必須）"
        fi
    else
        warn_test "claude plugin validate が未サポート（CC v2.1.77+ にアップデート推奨）"
    fi
else
    warn_test "claude コマンドが未インストール（claude plugin validate をスキップ）"
fi

echo ""
echo "8. Hardening parity の検証"
echo "----------------------------------------"

HARDENING_DOC="$PLUGIN_ROOT/docs/hardening-parity.md"
HARDENING_CONTRACT="$PLUGIN_ROOT/scripts/lib/codex-hardening-contract.txt"
if [ -f "$HARDENING_DOC" ]; then
    pass_test "hardening parity 文書が存在します"
else
    fail_test "docs/hardening-parity.md が見つかりません"
fi

if [ -f "$HARDENING_CONTRACT" ] && grep -q "HARNESS_HARDENING_CONTRACT_V1" "$HARDENING_CONTRACT"; then
    pass_test "Codex hardening contract テンプレートが存在します"
else
    fail_test "scripts/lib/codex-hardening-contract.txt が見つかりません"
fi

if grep -q "docs/hardening-parity.md" "$PLUGIN_ROOT/README.md"; then
    pass_test "README.md から hardening parity 文書へリンクされています"
else
    fail_test "README.md に hardening parity 文書へのリンクがありません"
fi

RULES_FILE="$PLUGIN_ROOT/go/internal/guardrail/rules.go"
RULE_IDS=(
    "R10:no-git-bypass-flags"
    "R11:no-reset-hard-protected-branch"
    "R12:deny-direct-push-protected-branch"
    "R13:warn-protected-review-paths"
)
for rule_id in "${RULE_IDS[@]}"; do
    if grep -q "$rule_id" "$RULES_FILE"; then
        pass_test "guardrail rule: $rule_id"
    else
        fail_test "guardrail rule が見つかりません: $rule_id"
    fi
done

CODEX_WRAPPER="$PLUGIN_ROOT/scripts/codex/codex-exec-wrapper.sh"
if grep -q "codex-hardening-contract.txt" "$CODEX_WRAPPER"; then
    pass_test "Codex wrapper が hardening contract テンプレートを参照しています"
else
    fail_test "Codex wrapper が hardening contract テンプレートを参照していません"
fi

CODEX_ENGINE="$PLUGIN_ROOT/scripts/codex-worker-engine.sh"
if grep -q "codex-hardening-contract.txt" "$CODEX_ENGINE"; then
    pass_test "Codex worker engine が hardening contract テンプレートを参照しています"
else
    fail_test "Codex worker engine が hardening contract テンプレートを参照していません"
fi

CODEX_GATE="$PLUGIN_ROOT/scripts/codex-worker-quality-gate.sh"
if grep -q "gate_hardening()" "$CODEX_GATE" && grep -q '"hardening"' "$CODEX_GATE"; then
    pass_test "Codex quality gate に hardening parity チェックがあります"
else
    fail_test "Codex quality gate に hardening parity チェックがありません"
fi

echo ""
echo "9. Migration residue check"
echo "----------------------------------------"

if bash "$PLUGIN_ROOT/scripts/check-residue.sh" > /dev/null 2>&1; then
    pass_test "No migration residue detected (scripts/check-residue.sh clean)"
else
    fail_test "Migration residue found — run 'bash scripts/check-residue.sh' to see details"
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
