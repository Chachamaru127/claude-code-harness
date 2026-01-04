#!/bin/bash
# plans-format-check.sh
# Plans.md のフォーマットをチェックし、旧フォーマットがあれば警告・マイグレーション提案

set -uo pipefail

PLANS_FILE="${1:-Plans.md}"

# JSON出力用関数
output_json() {
  local status="$1"
  local message="$2"
  local migration_needed="${3:-false}"
  local issues="${4:-[]}"

  cat <<EOF
{
  "status": "$status",
  "message": "$message",
  "migration_needed": $migration_needed,
  "issues": $issues,
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$message"
  }
}
EOF
}

# Plans.md が存在しない場合
if [ ! -f "$PLANS_FILE" ]; then
  output_json "skip" "Plans.md が見つかりません" "false"
  exit 0
fi

# フォーマットチェック
ISSUES=()
MIGRATION_NEEDED=false

# 1. 廃止されたマーカーのチェック（cursor:WIP, cursor:完了）
if grep -qE 'cursor:(WIP|完了)' "$PLANS_FILE" 2>/dev/null; then
  MIGRATION_NEEDED=true
  ISSUES+=("\"cursor:WIP と cursor:完了 は廃止されました。pm:依頼中 / pm:確認済 に移行してください。\"")
fi

# 2. マーカー凡例セクションのチェック
if ! grep -qE '## マーカー凡例|## Marker Legend' "$PLANS_FILE" 2>/dev/null; then
  ISSUES+=("\"マーカー凡例セクションがありません。テンプレートから追加を推奨します。\"")
fi

# 3. 有効なハーネスマーカーの存在チェック
# 新フォーマット: cc:TODO, cc:WIP, cc:WORK, cc:DONE, cc:完了, cc:blocked, pm:依頼中, pm:確認済, cursor:依頼中, cursor:確認済
if ! grep -qE 'cc:(TODO|WIP|WORK|DONE|完了|blocked)|pm:(依頼中|確認済)|cursor:(依頼中|確認済)' "$PLANS_FILE" 2>/dev/null; then
  # 旧フォーマット（cursor:WIP/完了）もチェック
  if ! grep -qE 'cursor:(WIP|完了)' "$PLANS_FILE" 2>/dev/null; then
    ISSUES+=("\"ハーネスマーカー（cc:TODO, cc:WIP 等）が見つかりません。\"")
  fi
fi

# 結果出力
if [ ${#ISSUES[@]} -eq 0 ]; then
  output_json "ok" "Plans.md フォーマットは最新です" "false"
else
  ISSUES_JSON=$(printf '%s,' "${ISSUES[@]}" | sed 's/,$//')
  if [ "$MIGRATION_NEEDED" = true ]; then
    output_json "migration_required" "Plans.md に旧フォーマットが検出されました。/harness-update でマイグレーション可能です。" "true" "[$ISSUES_JSON]"
  else
    output_json "warning" "Plans.md に改善点があります" "false" "[$ISSUES_JSON]"
  fi
fi
