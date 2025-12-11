#!/bin/bash
# session-summary.sh
# セッション終了時にサマリーを生成
#
# Usage: Stop hook から自動実行

set +e

STATE_FILE=".claude/state/session.json"
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 状態ファイルがなければスキップ
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# jq がなければスキップ
if ! command -v jq &> /dev/null; then
  exit 0
fi

# セッション情報を取得
SESSION_START=$(jq -r '.started_at' "$STATE_FILE")
CHANGES_COUNT=$(jq '.changes_this_session | length' "$STATE_FILE")
IMPORTANT_CHANGES=$(jq '[.changes_this_session[] | select(.important == true)] | length' "$STATE_FILE")

# Git 情報
GIT_COMMITS=0
if [ -d ".git" ]; then
  # セッション開始後のコミット数（概算）
  GIT_COMMITS=$(git log --oneline --since="$SESSION_START" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
fi

# Plans.md のタスク状況
COMPLETED_TASKS=0
if [ -f "Plans.md" ]; then
  COMPLETED_TASKS=$(grep -c "cc:完了" Plans.md 2>/dev/null || echo "0")
fi

# セッション時間計算
START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$SESSION_START" "+%s" 2>/dev/null || date -d "$SESSION_START" "+%s" 2>/dev/null || echo "0")
NOW_EPOCH=$(date +%s)
DURATION_MINUTES=$(( (NOW_EPOCH - START_EPOCH) / 60 ))

# サマリー出力（変更がある場合のみ）
if [ "$CHANGES_COUNT" -gt 0 ] || [ "$GIT_COMMITS" -gt 0 ]; then
  echo ""
  echo "📊 セッションサマリー"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$COMPLETED_TASKS" -gt 0 ]; then
    echo "✅ 完了タスク: ${COMPLETED_TASKS}件"
  fi

  echo "📝 変更ファイル: ${CHANGES_COUNT}件"

  if [ "$IMPORTANT_CHANGES" -gt 0 ]; then
    echo "⚠️ 重要な変更: ${IMPORTANT_CHANGES}件"
  fi

  if [ "$GIT_COMMITS" -gt 0 ]; then
    echo "💾 コミット: ${GIT_COMMITS}件"
  fi

  if [ "$DURATION_MINUTES" -gt 0 ]; then
    echo "⏱️ セッション時間: ${DURATION_MINUTES}分"
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# 状態ファイルにセッション終了時刻を記録
jq --arg ended_at "$CURRENT_TIME" \
   --arg duration "$DURATION_MINUTES" \
   '. + {ended_at: $ended_at, duration_minutes: ($duration | tonumber)}' \
   "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

exit 0
