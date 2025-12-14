#!/bin/bash
# session-summary.sh
# セッション終了時にサマリーを生成
#
# Usage: Stop hook から自動実行

set +e

STATE_FILE=".claude/state/session.json"
MEMORY_DIR=".claude/memory"
SESSION_LOG_FILE="${MEMORY_DIR}/session-log.md"
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 状態ファイルがなければスキップ
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# jq がなければスキップ
if ! command -v jq &> /dev/null; then
  exit 0
fi

# 既にメモリへ記録済みならスキップ（Stop hook の二重実行対策）
ALREADY_LOGGED=$(jq -r '.memory_logged // false' "$STATE_FILE" 2>/dev/null)
if [ "$ALREADY_LOGGED" = "true" ]; then
  exit 0
fi

# セッション情報を取得
SESSION_ID=$(jq -r '.session_id // "unknown"' "$STATE_FILE")
SESSION_START=$(jq -r '.started_at' "$STATE_FILE")
PROJECT_NAME=$(jq -r '.project_name // empty' "$STATE_FILE")
GIT_BRANCH=$(jq -r '.git.branch // empty' "$STATE_FILE")
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

# ================================
# `.claude/memory/session-log.md` へ自動追記（あれば作成）
# ================================

# 変更がなくても「開始した」という記録が欲しいケースがあるため、
# セッション開始が取れていればログを書いて良い（空セッションも可）
if [ -n "$SESSION_START" ] && [ "$SESSION_START" != "null" ]; then
  mkdir -p "$MEMORY_DIR" 2>/dev/null || true

  if [ ! -f "$SESSION_LOG_FILE" ]; then
    cat > "$SESSION_LOG_FILE" << 'EOF'
# Session Log

セッション単位の作業ログ（基本はローカル運用向け）。
重要な意思決定は `.claude/memory/decisions.md`、再利用できる解法は `.claude/memory/patterns.md` に昇格してください。

## Index

- （必要に応じて追記）

---
EOF
  fi

  # 変更ファイル一覧（重複排除）
  CHANGED_FILES=$(jq -r '.changes_this_session[]?.file' "$STATE_FILE" 2>/dev/null | awk 'NF' | awk '!seen[$0]++')
  IMPORTANT_FILES=$(jq -r '.changes_this_session[]? | select(.important == true) | .file' "$STATE_FILE" 2>/dev/null | awk 'NF' | awk '!seen[$0]++')

  # WIP タスク（存在すれば軽く抽出）
  WIP_TASKS=""
  if [ -f "Plans.md" ]; then
    WIP_TASKS=$(grep -n "cc:WIP\|pm:依頼中\|cursor:依頼中" Plans.md 2>/dev/null | head -20 || true)
  fi

  {
    echo ""
    echo "## セッション: ${CURRENT_TIME}"
    echo ""
    echo "- session_id: \`${SESSION_ID}\`"
    [ -n "$PROJECT_NAME" ] && echo "- project: \`${PROJECT_NAME}\`"
    [ -n "$GIT_BRANCH" ] && echo "- branch: \`${GIT_BRANCH}\`"
    echo "- started_at: \`${SESSION_START}\`"
    echo "- ended_at: \`${CURRENT_TIME}\`"
    [ "$DURATION_MINUTES" -gt 0 ] && echo "- duration_minutes: ${DURATION_MINUTES}"
    echo "- changes: ${CHANGES_COUNT}"
    [ "$IMPORTANT_CHANGES" -gt 0 ] && echo "- important_changes: ${IMPORTANT_CHANGES}"
    [ "$GIT_COMMITS" -gt 0 ] && echo "- commits: ${GIT_COMMITS}"
    echo ""
    echo "### 変更ファイル"
    if [ -n "$CHANGED_FILES" ]; then
      echo "$CHANGED_FILES" | while read -r f; do
        [ -n "$f" ] && echo "- \`$f\`"
      done
    else
      echo "- （なし）"
    fi
    echo ""
    echo "### 重要な変更（important=true）"
    if [ -n "$IMPORTANT_FILES" ]; then
      echo "$IMPORTANT_FILES" | while read -r f; do
        [ -n "$f" ] && echo "- \`$f\`"
      done
    else
      echo "- （なし）"
    fi
    echo ""
    echo "### 次回への引き継ぎ（任意）"
    if [ -n "$WIP_TASKS" ]; then
      echo ""
      echo "**Plans.md のWIP/依頼中（抜粋）**:"
      echo ""
      echo '```'
      echo "$WIP_TASKS"
      echo '```'
    else
      echo "- （必要に応じて追記）"
    fi
    echo ""
    echo "---"
  } >> "$SESSION_LOG_FILE" 2>/dev/null || true
fi

# 状態ファイルにセッション終了時刻・記録済みフラグを記録
jq --arg ended_at "$CURRENT_TIME" \
   --arg duration "$DURATION_MINUTES" \
   '. + {ended_at: $ended_at, duration_minutes: ($duration | tonumber), memory_logged: true}' \
   "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

exit 0
