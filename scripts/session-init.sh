#!/bin/bash
# session-init.sh
# SessionStart Hook: セッション開始時の初期化処理
#
# 機能:
# 1. プラグインキャッシュの整合性チェックと同期
# 2. Skills Gate の初期化
# 3. Plans.md の状態表示
#
# 出力: JSON形式で hookSpecificOutput.additionalContext に情報を出力
#       → Claude Code が system-reminder として表示

set -e

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== バナー表示（stderr でターミナルに表示） =====
VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
echo -e "\033[0;36m[claude-code-harness v${VERSION}]\033[0m Session initialized" >&2

# 出力メッセージを蓄積する変数
OUTPUT=""

add_line() {
  OUTPUT="${OUTPUT}$1\n"
}

# ===== Step 1: プラグインキャッシュ同期 =====
if [ -f "$SCRIPT_DIR/sync-plugin-cache.sh" ]; then
  # 同期処理は静かに実行
  bash "$SCRIPT_DIR/sync-plugin-cache.sh" >/dev/null 2>&1 || true
fi

# ===== Step 2: Skills Gate 初期化 =====
STATE_DIR=".claude/state"
SKILLS_CONFIG_FILE="${STATE_DIR}/skills-config.json"
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

mkdir -p "$STATE_DIR"

# session-skills-used.json をリセット（新セッション開始）
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

# skills-config.json の読み込みと表示
SKILLS_INFO=""
if [ -f "$SKILLS_CONFIG_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG_FILE" 2>/dev/null)
    SKILLS_LIST=$(jq -r '.skills // [] | join(", ")' "$SKILLS_CONFIG_FILE" 2>/dev/null)

    if [ "$SKILLS_ENABLED" = "true" ] && [ -n "$SKILLS_LIST" ]; then
      SKILLS_INFO="🎯 Skills Gate: 有効 (${SKILLS_LIST})"
    fi
  fi
fi

# ===== Step 3: Plans.md チェック =====
PLANS_INFO=""
if [ -f "Plans.md" ]; then
  wip_count=$(grep -c "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null || echo "0")
  todo_count=$(grep -c "cc:TODO" Plans.md 2>/dev/null || echo "0")

  PLANS_INFO="📄 Plans.md: 進行中 ${wip_count} / 未着手 ${todo_count}"
else
  PLANS_INFO="📄 Plans.md: 未検出"
fi

# ===== Step 4: テンプレート更新チェック =====
TEMPLATE_INFO=""
TEMPLATE_TRACKER="$SCRIPT_DIR/template-tracker.sh"

if [ -f "$TEMPLATE_TRACKER" ] && [ -f "$SCRIPT_DIR/../templates/template-registry.json" ]; then
  # generated-files.json がない場合は初期化
  if [ ! -f "${STATE_DIR}/generated-files.json" ]; then
    bash "$TEMPLATE_TRACKER" init >/dev/null 2>&1 || true
    TEMPLATE_INFO="📦 テンプレート追跡: 初期化完了"
  else
    # 更新チェック（JSON出力をパース）
    CHECK_RESULT=$(bash "$TEMPLATE_TRACKER" check 2>/dev/null || echo '{"needsCheck": false}')

    if command -v jq >/dev/null 2>&1; then
      NEEDS_CHECK=$(echo "$CHECK_RESULT" | jq -r '.needsCheck // false')
      UPDATES_COUNT=$(echo "$CHECK_RESULT" | jq -r '.updatesCount // 0')

      if [ "$NEEDS_CHECK" = "true" ] && [ "$UPDATES_COUNT" -gt 0 ]; then
        # 更新が必要なファイルの詳細を取得
        LOCALIZED_COUNT=$(echo "$CHECK_RESULT" | jq '[.updates[] | select(.localized == true)] | length')
        OVERWRITE_COUNT=$((UPDATES_COUNT - LOCALIZED_COUNT))

        TEMPLATE_INFO="⚠️ テンプレート更新: ${UPDATES_COUNT}件"
        if [ "$OVERWRITE_COUNT" -gt 0 ]; then
          TEMPLATE_INFO="${TEMPLATE_INFO} (上書き可: ${OVERWRITE_COUNT})"
        fi
        if [ "$LOCALIZED_COUNT" -gt 0 ]; then
          TEMPLATE_INFO="${TEMPLATE_INFO} (マージ要: ${LOCALIZED_COUNT})"
        fi
        TEMPLATE_INFO="${TEMPLATE_INFO} → \`/harness-update\` で確認"
      fi
    fi
  fi
fi

# ===== 出力メッセージの構築 =====
add_line "# [claude-code-harness] セッション初期化"
add_line ""
add_line "${PLANS_INFO}"

if [ -n "$SKILLS_INFO" ]; then
  add_line "${SKILLS_INFO}"
fi

if [ -n "$TEMPLATE_INFO" ]; then
  add_line "${TEMPLATE_INFO}"
fi

add_line ""
add_line "## マーカー凡例"
add_line "| マーカー | 状態 | 説明 |"
add_line "|---------|------|------|"
add_line "| \`cc:TODO\` | 未着手 | Impl（Claude Code）が実行予定 |"
add_line "| \`cc:WIP\` | 作業中 | Impl が実装中 |"
add_line "| \`cc:blocked\` | ブロック中 | 依存タスク待ち |"
add_line "| \`pm:依頼中\` | PM から依頼 | 2-Agent 運用時 |"
add_line ""
add_line "> **互換**: \`cursor:依頼中\` / \`cursor:確認済\` は \`pm:*\` と同義として扱います。"

# ===== JSON 出力 =====
# Claude Code の SessionStart hook は JSON 形式の hookSpecificOutput を受け付ける
# additionalContext の内容が system-reminder として表示される

# エスケープ処理（JSON用）
# 改行は \n、ダブルクォートは \"、バックスラッシュは \\
escape_json() {
  local str="$1"
  str="${str//\\/\\\\}"      # バックスラッシュ
  str="${str//\"/\\\"}"      # ダブルクォート
  str="${str//$'\n'/\\n}"    # 改行
  str="${str//$'\t'/\\t}"    # タブ
  echo "$str"
}

ESCAPED_OUTPUT=$(echo -e "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${ESCAPED_OUTPUT}"}}
EOF

exit 0
