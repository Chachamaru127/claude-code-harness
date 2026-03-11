#!/bin/bash
# Harness Status Line — Claude Code /statusline 用スクリプト
# コンテキスト使用率・コスト・git ブランチ・Harness バージョンを常時表示
#
# 設定方法:
#   /statusline (プロンプトで "use scripts/statusline-harness.sh" と指示)
#   または settings.json に手動追加:
#   { "statusLine": { "type": "command", "command": "path/to/statusline-harness.sh" } }

set -euo pipefail

input=$(cat)

# Extract fields with jq (// 0 for null safety)
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
STYLE=$(echo "$input" | jq -r '.output_style.name // ""')
AGENT_NAME=$(echo "$input" | jq -r '.agent.name // ""')
WT_NAME=$(echo "$input" | jq -r '.worktree.name // ""')

# Colors
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Context bar with threshold colors
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '█')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

# Duration formatting
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# Git info (cached for 5 seconds)
CACHE_FILE="/tmp/harness-statusline-git-cache"
CACHE_MAX_AGE=5
cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}
if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null || echo "")
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH|$STAGED|$MODIFIED" > "$CACHE_FILE"
    else
        echo "||" > "$CACHE_FILE"
    fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED < "$CACHE_FILE"

# Line 1: Model + Git + Agent/Worktree context
LINE1="${CYAN}[$MODEL]${RESET}"
if [ -n "$BRANCH" ]; then
    GIT_STATUS=""
    [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
    LINE1="${LINE1} 🌿 ${BRANCH} ${GIT_STATUS}"
fi
if [ -n "$AGENT_NAME" ]; then
    LINE1="${LINE1} ${DIM}agent:${AGENT_NAME}${RESET}"
fi
if [ -n "$WT_NAME" ]; then
    LINE1="${LINE1} ${DIM}wt:${WT_NAME}${RESET}"
fi

# Line 2: Context bar + Cost + Duration + Style
COST_FMT=$(printf '$%.2f' "$COST")
LINE2="${BAR_COLOR}${BAR}${RESET} ${PCT}%"
LINE2="${LINE2} | ${YELLOW}${COST_FMT}${RESET}"
LINE2="${LINE2} | ⏱️ ${MINS}m${SECS}s"
if [ -n "$STYLE" ] && [ "$STYLE" != "default" ]; then
    LINE2="${LINE2} ${DIM}[${STYLE}]${RESET}"
fi

echo -e "$LINE1"
echo -e "$LINE2"
