#!/bin/bash
# stop-plans-reminder.sh
# Stop Hook 用: Plans.md マーカー更新のリマインダー
#
# Claude Code 2.1.1 互換: prompt タイプの代わりに command タイプで実装
# 出力: JSON 形式 {"decision": "approve", "reason": "...", "systemMessage": "..."}

set -euo pipefail

# 判定用変数
NEED_REMINDER="false"
REASON=""
MESSAGE=""

# 変更があるかチェック
HAS_CHANGES="false"

# Git 未コミット変更
if [ -d ".git" ]; then
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
  if [ "$GIT_UNCOMMITTED" -gt 0 ]; then
    HAS_CHANGES="true"
  fi
fi

# セッション中の変更
if [ -f ".claude/state/session.json" ] && command -v jq >/dev/null 2>&1; then
  SESSION_CHANGES=$(jq '.changes_this_session // 0' .claude/state/session.json 2>/dev/null || echo "0")
  if [ "$SESSION_CHANGES" != "0" ] && [ "$SESSION_CHANGES" != "null" ]; then
    HAS_CHANGES="true"
  fi
fi

# 変更がある場合のみ Plans.md をチェック
if [ "$HAS_CHANGES" = "true" ] && [ -f "Plans.md" ]; then
  PM_PENDING=$(( $(grep -c "pm:依頼中" Plans.md 2>/dev/null || echo "0") + $(grep -c "cursor:依頼中" Plans.md 2>/dev/null || echo "0") ))
  CC_WIP=$(grep -c "cc:WIP" Plans.md 2>/dev/null || echo "0")
  CC_DONE=$(grep -c "cc:完了" Plans.md 2>/dev/null || echo "0")

  # PM からの依頼がある場合
  if [ "$PM_PENDING" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="pm_pending_tasks > 0"
    MESSAGE="Plans.md: pm:依頼中 が${PM_PENDING}件あります。作業開始時は cc:WIP に、完了時は cc:完了 に更新してください"
  fi

  # WIP タスクがある場合
  if [ "$CC_WIP" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="cc_wip_tasks > 0"
    MESSAGE="Plans.md: cc:WIP が${CC_WIP}件あります。完了した場合は cc:完了 に更新してください"
  fi

  # 完了タスクがある場合（PM確認待ち）
  if [ "$CC_DONE" -gt 0 ]; then
    NEED_REMINDER="true"
    REASON="cc_done_tasks > 0"
    MESSAGE="Plans.md: cc:完了 が${CC_DONE}件あります。PMが確認後 pm:確認済 に更新してください"
  fi
fi

# JSON 出力
if [ "$NEED_REMINDER" = "true" ]; then
  cat << EOF
{"decision": "approve", "reason": "$REASON", "systemMessage": "$MESSAGE"}
EOF
else
  cat << EOF
{"decision": "approve", "reason": "No reminder needed", "systemMessage": ""}
EOF
fi
