#!/bin/bash
# session-monitor.sh
# セッション開始時にプロジェクト状態を収集・表示
#
# Usage: SessionStart hook から自動実行
# Output: プロジェクト状態サマリー + 状態ファイル生成

# エラーで停止しない（Git エラー等を許容）
set +e

# ================================
# 設定
# ================================
STATE_DIR=".claude/state"
STATE_FILE="$STATE_DIR/session.json"
PLANS_FILE="Plans.md"

# ================================
# ヘルパー関数
# ================================

# 相対時間を計算（秒数から「X分前」「X時間前」等）
relative_time() {
  local seconds=$1
  if [ "$seconds" -lt 60 ]; then
    echo "${seconds}秒前"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds / 60))分前"
  elif [ "$seconds" -lt 86400 ]; then
    echo "$((seconds / 3600))時間前"
  else
    echo "$((seconds / 86400))日前"
  fi
}

# Plans.md からタスク数をカウント
count_tasks() {
  local marker=$1
  local count=0
  if [ -f "$PLANS_FILE" ]; then
    count=$(grep -c "$marker" "$PLANS_FILE" 2>/dev/null || true)
    [ -z "$count" ] && count=0
  fi
  echo "$count"
}

# ================================
# 状態収集
# ================================

# プロジェクト情報
PROJECT_NAME=$(basename "$(pwd)")
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Git 情報
if [ -d ".git" ]; then
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -z "$GIT_BRANCH" ] && GIT_BRANCH="unknown"
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$GIT_UNCOMMITTED" ] && GIT_UNCOMMITTED="0"
  GIT_LAST_COMMIT=$(git log -1 --format="%h" 2>/dev/null || echo "none")
  GIT_LAST_COMMIT_TIME=$(git log -1 --format="%ct" 2>/dev/null || echo "0")
else
  GIT_BRANCH="(no git)"
  GIT_UNCOMMITTED="0"
  GIT_LAST_COMMIT="none"
  GIT_LAST_COMMIT_TIME="0"
fi

# Plans.md 情報
if [ -f "$PLANS_FILE" ]; then
  PLANS_EXISTS="true"
  PLANS_MODIFIED=$(stat -f "%m" "$PLANS_FILE" 2>/dev/null || stat -c "%Y" "$PLANS_FILE" 2>/dev/null || echo "0")
  WIP_COUNT=$(count_tasks "cc:WIP")
  TODO_COUNT=$(count_tasks "cc:TODO")
  PENDING_COUNT=$(count_tasks "cursor:依頼中")
  COMPLETED_COUNT=$(count_tasks "cc:完了")
else
  PLANS_EXISTS="false"
  PLANS_MODIFIED="0"
  WIP_COUNT="0"
  TODO_COUNT="0"
  PENDING_COUNT="0"
  COMPLETED_COUNT="0"
fi

# 前回セッション情報
LAST_SESSION_TIME="0"
if [ -f "$STATE_FILE" ]; then
  LAST_SESSION_TIME=$(cat "$STATE_FILE" | grep -o '"started_at":"[^"]*"' | cut -d'"' -f4 | xargs -I{} date -j -f "%Y-%m-%dT%H:%M:%SZ" "{}" "+%s" 2>/dev/null || echo "0")
fi

# ================================
# 状態ファイル生成
# ================================
mkdir -p "$STATE_DIR"

cat > "$STATE_FILE" << EOF
{
  "session_id": "$(uuidgen 2>/dev/null || echo "session-$(date +%s)")",
  "started_at": "$CURRENT_TIME",
  "cwd": "$(pwd)",
  "project_name": "$PROJECT_NAME",
  "git": {
    "branch": "$GIT_BRANCH",
    "uncommitted_changes": $GIT_UNCOMMITTED,
    "last_commit": "$GIT_LAST_COMMIT"
  },
  "plans": {
    "exists": $PLANS_EXISTS,
    "last_modified": $PLANS_MODIFIED,
    "wip_tasks": $WIP_COUNT,
    "todo_tasks": $TODO_COUNT,
    "pending_tasks": $PENDING_COUNT,
    "completed_tasks": $COMPLETED_COUNT
  },
  "changes_this_session": []
}
EOF

# ================================
# サマリー出力
# ================================
echo ""
echo "📊 セッション開始 - プロジェクト状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📂 プロジェクト: $PROJECT_NAME"
echo "🔀 ブランチ: $GIT_BRANCH"

if [ "$GIT_UNCOMMITTED" -gt 0 ]; then
  echo "📝 未コミット: ${GIT_UNCOMMITTED}ファイル"
fi

if [ "$PLANS_EXISTS" = "true" ]; then
  TOTAL_ACTIVE=$((WIP_COUNT + TODO_COUNT + PENDING_COUNT))
  if [ "$TOTAL_ACTIVE" -gt 0 ]; then
    echo "📋 Plans.md: WIP ${WIP_COUNT}件 / TODO $((TODO_COUNT + PENDING_COUNT))件"
  fi
fi

if [ -n "$LAST_SESSION_TIME" ] && [ "$LAST_SESSION_TIME" != "0" ] && [ "$LAST_SESSION_TIME" -gt 0 ] 2>/dev/null; then
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_SESSION_TIME))
  echo "⏰ 前回セッション: $(relative_time $DIFF)"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
