#!/bin/bash
# session-summary.sh
# セッション終了時にサマリーを生成
#
# Usage: Stop hook から自動実行

set +e

STATE_FILE=".claude/state/session.json"
MEMORY_DIR=".claude/memory"
SESSION_LOG_FILE="${MEMORY_DIR}/session-log.md"
EVENT_LOG_FILE=".claude/state/session.events.jsonl"
ARCHIVE_DIR=".claude/state/sessions"
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
WIP_TASK_TITLE=""
if [ -f "Plans.md" ]; then
  COMPLETED_TASKS=$(grep -c "cc:完了" Plans.md 2>/dev/null || echo "0")
  # 現在のWIPタスクタイトルを取得（最初の1件）
  WIP_TASK_TITLE=$(grep -E "^\s*-\s*\[.\]\s*\*\*.*\`cc:WIP\`" Plans.md 2>/dev/null | head -1 | sed 's/.*\*\*\(.*\)\*\*.*/\1/' || true)
fi

# Agent Trace から直近の編集ファイル情報を取得
AGENT_TRACE_FILE=".claude/state/agent-trace.jsonl"
RECENT_EDITS=""
RECENT_PROJECT=""
if [ -f "$AGENT_TRACE_FILE" ]; then
  # 直近10件のトレースから編集ファイルを抽出
  RECENT_EDITS=$(tail -10 "$AGENT_TRACE_FILE" 2>/dev/null | jq -r '.files[].path' 2>/dev/null | sort -u | head -5 || true)
  # 最新のプロジェクト情報を取得
  RECENT_PROJECT=$(tail -1 "$AGENT_TRACE_FILE" 2>/dev/null | jq -r '.metadata.project // empty' 2>/dev/null || true)
fi

# セッション時間計算
START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$SESSION_START" "+%s" 2>/dev/null || date -d "$SESSION_START" "+%s" 2>/dev/null || echo "0")
NOW_EPOCH=$(date +%s)
DURATION_MINUTES=$(( (NOW_EPOCH - START_EPOCH) / 60 ))

# サマリー出力（変更がある場合のみ）
if [ "$CHANGES_COUNT" -gt 0 ] || [ "$GIT_COMMITS" -gt 0 ] || [ -n "$RECENT_EDITS" ]; then
  echo ""
  echo "📊 セッションサマリー"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # プロジェクト名（Agent Trace から）
  if [ -n "$RECENT_PROJECT" ]; then
    echo "📁 プロジェクト: ${RECENT_PROJECT}"
  fi

  # 現在のタスク（WIP）
  if [ -n "$WIP_TASK_TITLE" ]; then
    echo "🎯 現在のタスク: ${WIP_TASK_TITLE}"
  fi

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

  # 直近の編集ファイル（Agent Trace から）
  if [ -n "$RECENT_EDITS" ]; then
    echo ""
    echo "📄 直近の編集:"
    echo "$RECENT_EDITS" | while read -r f; do
      [ -n "$f" ] && echo "   - $f"
    done
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
append_event() {
  local event_type="$1"
  local event_state="$2"
  local event_time="$3"

  # イベントログ初期化
  mkdir -p ".claude/state" 2>/dev/null || true
  touch "$EVENT_LOG_FILE" 2>/dev/null || true

  if command -v jq >/dev/null 2>&1; then
    local seq
    local event_id
    seq=$(jq -r '.event_seq // 0' "$STATE_FILE" 2>/dev/null)
    seq=$((seq + 1))
    event_id=$(printf "event-%06d" "$seq")

    jq --arg state "$event_state" \
       --arg updated_at "$event_time" \
       --arg event_id "$event_id" \
       --argjson event_seq "$seq" \
       '.state = $state | .updated_at = $updated_at | .last_event_id = $event_id | .event_seq = $event_seq' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo "{\"id\":\"$event_id\",\"type\":\"$event_type\",\"ts\":\"$event_time\",\"state\":\"$event_state\"}" >> "$EVENT_LOG_FILE"
  fi
}

append_event "session.stop" "stopped" "$CURRENT_TIME"

if command -v jq >/dev/null 2>&1; then
  jq --arg ended_at "$CURRENT_TIME" \
     --arg duration "$DURATION_MINUTES" \
     '. + {ended_at: $ended_at, duration_minutes: ($duration | tonumber), memory_logged: true}' \
     "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# アーカイブ保存（resume/fork 用）
if [ -f "$STATE_FILE" ]; then
  mkdir -p "$ARCHIVE_DIR" 2>/dev/null || true
  if command -v jq >/dev/null 2>&1; then
    ARCHIVE_ID=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
    if [ -n "$ARCHIVE_ID" ]; then
      cp "$STATE_FILE" "$ARCHIVE_DIR/${ARCHIVE_ID}.json" 2>/dev/null || true
      if [ -f "$EVENT_LOG_FILE" ]; then
        cp "$EVENT_LOG_FILE" "$ARCHIVE_DIR/${ARCHIVE_ID}.events.jsonl" 2>/dev/null || true
      fi
    fi
  fi
fi

exit 0
