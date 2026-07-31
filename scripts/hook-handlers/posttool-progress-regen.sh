#!/bin/bash
# posttool-progress-regen.sh
# Phase 65.4.2 - PostToolUse hook で Progress Tracker HTML を自動再生成
#
# Trigger: Edit / Write / Bash の発火 (PostToolUse hook 経由)
# Rate limit: 60 秒以内の連続発火は skip
# Background: 再生成は background で実行 (hook 自体は即座に return、CC を blockしない)
#
# Input:  stdin (JSON: PostToolUse hook payload)
# Output: stdout (JSON: {"ok": true} or {"ok": true, "skipped": "rate-limit"})
#
# State file: .claude/state/progress-last-regen.txt
#   (epoch seconds of last successful regen)
#
# Side effect: out/progress-snapshot.html を再生成

set +e  # hook はエラーで CC を止めないこと

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PARENT_DIR}/.." && pwd)"

# project root 検出 (host project が CCH 自体ではない場合は host 側が target)
if declare -F detect_project_root > /dev/null 2>&1; then
  PROJECT_ROOT="${PROJECT_ROOT:-$(detect_project_root 2>/dev/null || pwd)}"
else
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

STATE_FILE="${PROJECT_ROOT}/.claude/state/progress-last-regen.txt"
PLANS_FILE="${PROJECT_ROOT}/Plans.md"
OUT_HTML="${PROJECT_ROOT}/out/progress-snapshot.html"
SNAPSHOT_SCRIPT="${REPO_ROOT}/scripts/progress-snapshot.sh"
RENDER_SCRIPT="${REPO_ROOT}/scripts/render-html.sh"

RATE_LIMIT_SEC=60

# Plans.md がなければ何もしない
if [[ ! -f "$PLANS_FILE" ]]; then
  echo '{"ok":true,"skipped":"no-plans-md"}'
  exit 0
fi

# stdin を読み捨てる (hook payload は使わない)
cat >/dev/null 2>&1

# rate limit check
NOW_EPOCH="$(date +%s)"
if [[ -f "$STATE_FILE" ]]; then
  LAST_EPOCH="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  if ! [[ "$LAST_EPOCH" =~ ^[0-9]+$ ]]; then
    LAST_EPOCH=0
  fi
  ELAPSED=$((NOW_EPOCH - LAST_EPOCH))
  if [[ $ELAPSED -lt $RATE_LIMIT_SEC ]]; then
    echo "{\"ok\":true,\"skipped\":\"rate-limit\",\"elapsed_sec\":${ELAPSED}}"
    exit 0
  fi
fi

# project name
PROJECT_NAME="$(basename "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")")"

# state ディレクトリ確保
mkdir -p "${PROJECT_ROOT}/.claude/state" "${PROJECT_ROOT}/out" 2>/dev/null

# background regen (hook は即座に return)
(
  # BSD (macOS) mktemp only substitutes X's at the END of the template, so a
  # suffixed form like progress-snap-XXXX.json yields that literal path — not a
  # unique one. Any leftover from an interrupted run then fails with EEXIST and
  # this regen stays silently broken. Keep the X's trailing.
  SNAP_TMP="$(mktemp "${TMPDIR:-/tmp}/progress-snap-XXXXXX" 2>/dev/null)"
  if bash "$SNAPSHOT_SCRIPT" --plans "$PLANS_FILE" --project "$PROJECT_NAME" > "$SNAP_TMP" 2>/dev/null; then
    if bash "$RENDER_SCRIPT" --template progress --data "$SNAP_TMP" --out "$OUT_HTML" >/dev/null 2>&1; then
      # 成功: state file 更新
      echo "$NOW_EPOCH" > "$STATE_FILE"
    fi
  fi
  rm -f "$SNAP_TMP"
) &

echo '{"ok":true,"regenerated":true}'
exit 0
