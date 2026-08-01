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

set -euo pipefail

# スクリプトディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/plans-marker-count.sh" ]; then
  # shellcheck source=./plans-marker-count.sh
  source "${SCRIPT_DIR}/plans-marker-count.sh"
else
  count_status_cells() {
    local marker=$1
    local file=${2:-Plans.md}
    local count
    if [ ! -f "$file" ]; then
      echo 0
      return 0
    fi
    count=$(grep -c "$marker" "$file" 2>/dev/null || true)
    echo "${count:-0}"
  }
fi
PROGRESS_SNAPSHOT_LIB="${SCRIPT_DIR}/lib/progress-snapshot.sh"
if [ -f "${PROGRESS_SNAPSHOT_LIB}" ]; then
  # shellcheck source=/dev/null
  source "${PROGRESS_SNAPSHOT_LIB}"
fi

# ===== バナー表示（stderr でターミナルに表示） =====
VERSION=$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")
echo -e "\033[0;36m[claude-code-harness v${VERSION}]\033[0m Session initialized" >&2

# ===== SIMPLE モード検出 =====
SIMPLE_MODE="false"
if [ -f "$SCRIPT_DIR/check-simple-mode.sh" ]; then
  # shellcheck source=./check-simple-mode.sh
  source "$SCRIPT_DIR/check-simple-mode.sh"
  if is_simple_mode; then
    SIMPLE_MODE="true"
    echo -e "\033[1;33m[WARNING]\033[0m CLAUDE_CODE_SIMPLE mode detected — skills/agents/memory disabled" >&2
  fi
fi

# ===== stdin から JSON 入力を読み取り =====
INPUT=""
if [ -t 0 ]; then
  : # stdin が TTY の場合は入力なし
else
  INPUT=$(cat 2>/dev/null || true)
fi

# ===== agent_type / session_id 判定（Claude Code v2.1.2+） =====
AGENT_TYPE=""
CC_SESSION_ID=""
if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    AGENT_TYPE="$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)"
    CC_SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
  fi
fi

# サブエージェント時は軽量初期化（早期 return）
# - プラグインキャッシュ同期をスキップ
# - Skills Gate 初期化をスキップ
# - Plans.md チェックをスキップ
# - テンプレート更新チェックをスキップ
# - 新規ルールファイルチェックをスキップ
# - 古いフック設定検出をスキップ
if [ "$AGENT_TYPE" = "subagent" ]; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[subagent] 軽量初期化完了"}}
EOF
  exit 0
fi

# ===== Hook 使用状況記録 =====
if [ -x "$SCRIPT_DIR/record-usage.js" ] && command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/record-usage.js" hook session-init >/dev/null 2>&1 &
fi

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

# ===== Step 1.5: Symlink 健全性チェック（Windows 互換） =====
# Windows の git clone で symlink が壊れる問題を自動修復
SYMLINK_INFO=""
if [ -f "$SCRIPT_DIR/fix-symlinks.sh" ]; then
  FIX_RESULT=$(bash "$SCRIPT_DIR/fix-symlinks.sh" 2>/dev/null || echo '{"fixed":0}')
  if command -v jq >/dev/null 2>&1; then
    SYMLINK_FIXED=$(echo "$FIX_RESULT" | jq -r '.fixed // 0' 2>/dev/null)
    if [ "$SYMLINK_FIXED" -gt 0 ] 2>/dev/null; then
      SYMLINK_DETAILS=$(echo "$FIX_RESULT" | jq -r '.details | join(", ")' 2>/dev/null)
      SYMLINK_INFO="🔧 Symlink 自動修復: ${SYMLINK_FIXED} 件修復 (${SYMLINK_DETAILS})"
      echo -e "\033[1;33m[FIX]\033[0m Broken symlinks repaired: ${SYMLINK_FIXED} skills" >&2
    fi
  fi
fi

# ===== Step 2: Skills Gate 初期化 =====
# Resolve to git repository root for consistency with other hooks
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="$(pwd)"
STATE_DIR="${REPO_ROOT}/.claude/state"
SKILLS_CONFIG_FILE="${STATE_DIR}/skills-config.json"
SESSION_SKILLS_USED_FILE="${STATE_DIR}/session-skills-used.json"

mkdir -p "$STATE_DIR"

# session-skills-used.json をリセット（新セッション開始）
echo '{"used": [], "session_start": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$SESSION_SKILLS_USED_FILE"

RESUME_CONTEXT_FILE="${STATE_DIR}/memory-resume-context.md"
RESUME_PENDING_FLAG="${STATE_DIR}/.memory-resume-pending"
RESUME_PROCESSING_FLAG="${STATE_DIR}/.memory-resume-processing"
RESUME_MAX_BYTES="${HARNESS_MEM_RESUME_MAX_BYTES:-32768}"
HANDOFF_ARTIFACT_FILE="${STATE_DIR}/handoff-artifact.json"
LEGACY_PRECOMPACT_SNAPSHOT_FILE="${STATE_DIR}/precompact-snapshot.json"

case "$RESUME_MAX_BYTES" in
  ''|*[!0-9]*) RESUME_MAX_BYTES=32768 ;;
esac
if [ "$RESUME_MAX_BYTES" -gt 65536 ]; then
  RESUME_MAX_BYTES=65536
fi
if [ "$RESUME_MAX_BYTES" -lt 4096 ]; then
  RESUME_MAX_BYTES=4096
fi

consume_memory_resume_context() {
  local file="$1"
  local max_bytes="$2"
  local total=0
  local line=""
  local line_bytes=0
  local out=""

  if [ ! -f "$file" ]; then
    return 0
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line_bytes="$(printf '%s\n' "$line" | wc -c | tr -d '[:space:]')"
    case "$line_bytes" in
      ''|*[!0-9]*) line_bytes=0 ;;
    esac
    if [ $((total + line_bytes)) -gt "$max_bytes" ]; then
      break
    fi
    out="${out}${line}
"
    total=$((total + line_bytes))
  done < "$file"

  rm -f "$RESUME_PENDING_FLAG" "$RESUME_PROCESSING_FLAG" "$RESUME_CONTEXT_FILE" 2>/dev/null || true
  printf '%s' "$out"
}

get_handoff_artifact_path() {
  if [ -f "$HANDOFF_ARTIFACT_FILE" ]; then
    printf '%s' "$HANDOFF_ARTIFACT_FILE"
    return 0
  fi

  if [ -f "$LEGACY_PRECOMPACT_SNAPSHOT_FILE" ]; then
    printf '%s' "$LEGACY_PRECOMPACT_SNAPSHOT_FILE"
    return 0
  fi

  return 0
}

render_handoff_context() {
  local artifact_path="$1"
  if [ -z "$artifact_path" ] || [ ! -f "$artifact_path" ]; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$artifact_path" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text(encoding='utf-8'))
except Exception:
    sys.exit(0)

def normalize_text(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return " ".join(value.split())
    if isinstance(value, dict):
        for key in ("summary", "task", "title", "detail", "message", "reason", "status"):
            candidate = value.get(key)
            if isinstance(candidate, str) and candidate.strip():
                return " ".join(candidate.split())
        return ""
    if isinstance(value, list):
        parts = []
        for item in value:
            text = normalize_text(item)
            if text:
                parts.append(text)
            if len(parts) >= 3:
                break
        return "; ".join(parts)
    return str(value)

def format_list(items, limit=4):
    parts = []
    for item in items or []:
        text = normalize_text(item)
        if text:
            parts.append(text)
        if len(parts) >= limit:
            break
    return "; ".join(parts)

previous = data.get("previous_state") or {}
next_action = data.get("next_action") or {}
open_risks = data.get("open_risks") or []
failed_checks = data.get("failed_checks") or []
decision_log = data.get("decision_log") or []
context_reset = data.get("context_reset") or {}
continuity = data.get("continuity") or {}
wip_tasks = data.get("wipTasks") or []
recent_edits = data.get("recentEdits") or []

lines = ["## Structured Handoff"]

previous_summary = normalize_text(previous.get("summary"))
if previous_summary:
    lines.append(f"- Previous state: {previous_summary}")

session_state = previous.get("session_state") or {}
if isinstance(session_state, dict):
    session_bits = []
    for key in ("state", "review_status", "active_skill", "resumed_at"):
        candidate = session_state.get(key)
        if isinstance(candidate, str) and candidate.strip():
            session_bits.append(f"{key}={candidate.strip()}")
    if session_bits:
        lines.append(f"- Session state: {', '.join(session_bits)}")

plan_counts = previous.get("plan_counts") or {}
if isinstance(plan_counts, dict):
    count_bits = []
    for key in ("total", "wip", "blocked", "recent_edits"):
        candidate = plan_counts.get(key)
        if isinstance(candidate, (int, float)) and int(candidate) > 0:
            count_bits.append(f"{key}={int(candidate)}")
    if count_bits:
        lines.append(f"- Plan counts: {', '.join(count_bits)}")

next_bits = []
next_summary = normalize_text(next_action.get("summary"))
if next_summary:
    next_bits.append(next_summary)
task_id = normalize_text(next_action.get("taskId"))
task = normalize_text(next_action.get("task"))
if task_id or task:
    next_bits.append(" ".join(part for part in [task_id, task] if part).strip())
depends = normalize_text(next_action.get("depends"))
dod = normalize_text(next_action.get("dod"))
if depends:
    next_bits.append(f"depends={depends}")
if dod:
    next_bits.append(f"DoD={dod}")
if next_bits:
    lines.append(f"- Next action: {' | '.join(next_bits)}")

if open_risks:
    lines.append(f"- Open risks: {format_list(open_risks)}")
if failed_checks:
    lines.append(f"- Failed checks: {format_list(failed_checks)}")
if decision_log:
    lines.append(f"- Decision log: {format_list(decision_log, 2)}")
context_reset_summary = normalize_text(context_reset.get("summary"))
if context_reset_summary:
    lines.append(f"- Context reset: {context_reset_summary}")
continuity_summary = normalize_text(continuity.get("summary"))
if continuity_summary:
    lines.append(f"- Continuity: {continuity_summary}")
if wip_tasks:
    lines.append(f"- WIP tasks: {format_list(wip_tasks, 5)}")
if recent_edits:
    lines.append(f"- Recent edits: {format_list(recent_edits, 5)}")

print("\n".join(lines))
PY
    return 0
  fi

  return 0
}

sync_handoff_session_metadata() {
  local artifact_path="$1"
  local session_file="$2"
  [ -n "$artifact_path" ] || return 0
  [ -f "$artifact_path" ] || return 0
  [ -n "$session_file" ] || return 0
  [ -f "$session_file" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local context_reset_summary
  local context_reset_recommended
  local continuity_summary
  local continuity_effort
  local continuity_plugin_first
  local continuity_resume_aware
  local tmp_file

  context_reset_summary="$(jq -r '.context_reset.summary // empty' "$artifact_path" 2>/dev/null || true)"
  context_reset_recommended="$(jq -r '.context_reset.recommended // false' "$artifact_path" 2>/dev/null || echo false)"
  continuity_summary="$(jq -r '.continuity.summary // empty' "$artifact_path" 2>/dev/null || true)"
  continuity_effort="$(jq -r '.continuity.effort_hint // empty' "$artifact_path" 2>/dev/null || true)"
  continuity_plugin_first="$(jq -r '.continuity.plugin_first_workflow // false' "$artifact_path" 2>/dev/null || echo false)"
  continuity_resume_aware="$(jq -r '.continuity.resume_aware_effort_continuity // false' "$artifact_path" 2>/dev/null || echo false)"

  tmp_file="$(mktemp)"
  jq \
    --arg artifact_path "$artifact_path" \
    --arg context_reset_summary "$context_reset_summary" \
    --arg continuity_summary "$continuity_summary" \
    --arg continuity_effort "$continuity_effort" \
    --argjson context_reset_recommended "$context_reset_recommended" \
    --argjson continuity_plugin_first "$continuity_plugin_first" \
    --argjson continuity_resume_aware "$continuity_resume_aware" \
    '
    .harness = (.harness // {}) |
    .harness.last_handoff_artifact = $artifact_path |
    .harness.context_reset = {
      summary: $context_reset_summary,
      recommended: $context_reset_recommended
    } |
    .harness.continuity = {
      summary: $continuity_summary,
      effort_hint: $continuity_effort,
      plugin_first_workflow: $continuity_plugin_first,
      resume_aware_effort_continuity: $continuity_resume_aware
    }
    ' "$session_file" > "$tmp_file" && mv "$tmp_file" "$session_file"
}

# SSOT 同期フラグをクリア（新セッション開始時）
# このフラグは /sync-ssot-from-memory 実行時に作成され、
# Plans.md クリーンアップ前の SSOT 同期確認に使用される
rm -f "${STATE_DIR}/.ssot-synced-this-session" 2>/dev/null || true

# work 警告フラグをクリア（新セッション開始時）
# このフラグは userprompt-inject-policy.sh で一度だけ警告するために使用される
# 後方互換: 両方のフラグ名をクリア
rm -f "${STATE_DIR}/.work-review-warned" 2>/dev/null || true
rm -f "${STATE_DIR}/.ultrawork-review-warned" 2>/dev/null || true

# ===== Step 2.5: Harness セッション初期化 & CC session_id マッピング =====
SESSION_FILE="${STATE_DIR}/session.json"
SESSION_MAP_FILE="${STATE_DIR}/session-map.json"
ARCHIVE_DIR="${STATE_DIR}/sessions"
mkdir -p "$ARCHIVE_DIR"

# 新規セッション用の Harness session_id を生成
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HARNESS_SESSION_ID="session-$(date +%s)"

# session.json を初期化（存在しない場合、または stopped 状態の場合）
INIT_NEW_SESSION="false"
if [ ! -f "$SESSION_FILE" ]; then
  INIT_NEW_SESSION="true"
elif command -v jq >/dev/null 2>&1; then
  CURRENT_STATE="$(jq -r '.state // "idle"' "$SESSION_FILE" 2>/dev/null)"
  if [ "$CURRENT_STATE" = "stopped" ] || [ "$CURRENT_STATE" = "completed" ] || [ "$CURRENT_STATE" = "failed" ]; then
    INIT_NEW_SESSION="true"
  fi
fi

if [ "$INIT_NEW_SESSION" = "true" ]; then
  cat > "$SESSION_FILE" <<SESSEOF
{
  "session_id": "$HARNESS_SESSION_ID",
  "parent_session_id": null,
  "state": "initialized",
  "started_at": "$NOW",
  "updated_at": "$NOW",
  "event_seq": 0,
  "last_event_id": ""
}
SESSEOF

  # イベントログを初期化
  echo "{\"type\":\"session.start\",\"ts\":\"$NOW\",\"state\":\"initialized\",\"data\":{\"cc_session_id\":\"$CC_SESSION_ID\"}}" > "${STATE_DIR}/session.events.jsonl"
else
  # 既存セッションの session_id を取得
  if command -v jq >/dev/null 2>&1; then
    HARNESS_SESSION_ID="$(jq -r '.session_id // empty' "$SESSION_FILE" 2>/dev/null)"
  fi
fi

# CC session_id と Harness session_id のマッピングを保存
if [ -n "$CC_SESSION_ID" ] && [ -n "$HARNESS_SESSION_ID" ]; then
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$SESSION_MAP_FILE" ]; then
      tmp_file=$(mktemp)
      jq --arg cc_id "$CC_SESSION_ID" --arg harness_id "$HARNESS_SESSION_ID" \
         '.[$cc_id] = $harness_id' "$SESSION_MAP_FILE" > "$tmp_file" && mv "$tmp_file" "$SESSION_MAP_FILE"
    else
      echo "{\"$CC_SESSION_ID\":\"$HARNESS_SESSION_ID\"}" > "$SESSION_MAP_FILE"
    fi
  fi
fi

# ===== Step 2.6: セッション間通信用の登録 =====
# active.json に自分を登録（他セッションから認識可能にする）
if [ -f "$SCRIPT_DIR/session-register.sh" ]; then
  bash "$SCRIPT_DIR/session-register.sh" "$HARNESS_SESSION_ID" 2>/dev/null || true
fi

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
# plansDirectory 設定を考慮
PLANS_PATH="Plans.md"
if [ -f "${SCRIPT_DIR}/config-utils.sh" ]; then
  source "${SCRIPT_DIR}/config-utils.sh"
  PLANS_PATH=$(get_plans_file_path)
fi

PLANS_INFO=""
if [ -f "$PLANS_PATH" ]; then
  wip_count=$(( \
    $(count_status_cells "cc:wip" "$PLANS_PATH") + \
    $(count_status_cells "cc:WIP" "$PLANS_PATH") + \
    $(count_status_cells "pm:requested" "$PLANS_PATH") + \
    $(count_status_cells "pm:依頼中" "$PLANS_PATH") + \
    $(count_status_cells "cursor:依頼中" "$PLANS_PATH") \
  ))
  todo_count=$(( \
    $(count_status_cells "cc:todo" "$PLANS_PATH") + \
    $(count_status_cells "cc:TODO" "$PLANS_PATH") \
  ))

  PLANS_INFO="📄 Plans.md: 進行中 ${wip_count} / 未着手 ${todo_count}"
else
  PLANS_INFO="📄 Plans.md: 未検出"
fi

SNAPSHOT_INFO=""
if declare -F progress_snapshot_summary >/dev/null 2>&1; then
  SNAPSHOT_INFO="$(progress_snapshot_summary "${STATE_DIR}" 2>/dev/null || true)"
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
      INSTALLS_COUNT=$(echo "$CHECK_RESULT" | jq -r '.installsCount // 0')

      if [ "$NEEDS_CHECK" = "true" ]; then
        parts=()

        # 更新が必要なファイル
        if [ "$UPDATES_COUNT" -gt 0 ]; then
          LOCALIZED_COUNT=$(echo "$CHECK_RESULT" | jq '[.updates[] | select(.localized == true)] | length')
          OVERWRITE_COUNT=$((UPDATES_COUNT - LOCALIZED_COUNT))

          if [ "$OVERWRITE_COUNT" -gt 0 ]; then
            parts+=("更新可: ${OVERWRITE_COUNT}")
          fi
          if [ "$LOCALIZED_COUNT" -gt 0 ]; then
            parts+=("マージ要: ${LOCALIZED_COUNT}")
          fi
        fi

        # 新規インストールが必要なファイル
        if [ "$INSTALLS_COUNT" -gt 0 ]; then
          parts+=("新規追加: ${INSTALLS_COUNT}")
        fi

        if [ ${#parts[@]} -gt 0 ]; then
          TEMPLATE_INFO="⚠️ テンプレート更新: $(IFS=', '; echo "${parts[*]}") → \`/harness-update\` で確認"
        fi
      fi
    fi
  fi
fi

# ===== Step 5: 新規追加ルールファイルのチェック =====
# 品質保護ルール（v2.5.30+）が未導入の場合に通知
MISSING_RULES_INFO=""
RULES_DIR=".claude/rules"
QUALITY_RULES=("test-quality.md" "implementation-quality.md")
MISSING_RULES=()

if [ -d "$RULES_DIR" ]; then
  for rule in "${QUALITY_RULES[@]}"; do
    if [ ! -f "$RULES_DIR/$rule" ]; then
      MISSING_RULES+=("$rule")
    fi
  done

  if [ ${#MISSING_RULES[@]} -gt 0 ]; then
    MISSING_RULES_INFO="⚠️ 品質保護ルール未導入: ${MISSING_RULES[*]} → \`/harness-update\` で追加可能"
  fi
elif [ -f ".claude-code-harness-version" ]; then
  # ハーネス導入済みだが rules ディレクトリがない場合
  MISSING_RULES_INFO="⚠️ 品質保護ルール未導入 → \`/harness-update\` で追加可能"
fi

# ===== Step 6: 古いフック設定の検出 =====
# コマンドパスに "claude-code-harness" を含むフックのみ検出（ユーザー独自フックは除外）
OLD_HOOKS_INFO=""
SETTINGS_FILE=".claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    # プラグインが使用しているイベントタイプ
    PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
    OLD_HARNESS_EVENTS=()

    for event in "${PLUGIN_EVENTS[@]}"; do
      # イベントが存在し、かつコマンドに "claude-code-harness" が含まれる場合のみ
      if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
        COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
        if grep -q "claude-code-harness" <<<"$COMMANDS"; then
          OLD_HARNESS_EVENTS+=("$event")
        fi
      fi
    done

    if [ ${#OLD_HARNESS_EVENTS[@]} -gt 0 ]; then
      OLD_HOOKS_INFO="⚠️ 古いハーネスフック設定を検出: ${OLD_HARNESS_EVENTS[*]} → \`/harness-update\` で削除を推奨"
    fi
  fi
fi

# ===== 出力メッセージの構築 =====
add_line "# [claude-code-harness] セッション初期化"
add_line ""

# SIMPLE モード警告（additionalContext にも出力 — check-simple-mode.sh の警告文を再利用）
if [ "$SIMPLE_MODE" = "true" ]; then
  add_line "⚠️ **CLAUDE_CODE_SIMPLE モード検出** (CC v2.1.50+)"
  while IFS= read -r warning_line; do
    add_line "$warning_line"
  done <<< "$(simple_mode_warning ja)"
  add_line ""
fi

MEMORY_CONTEXT=""
if [ -f "$RESUME_PENDING_FLAG" ] || [ -f "$RESUME_CONTEXT_FILE" ]; then
  MEMORY_CONTEXT="$(consume_memory_resume_context "$RESUME_CONTEXT_FILE" "$RESUME_MAX_BYTES")"
fi

if [ -n "$MEMORY_CONTEXT" ]; then
  OUTPUT="${OUTPUT}${MEMORY_CONTEXT}"
  case "$MEMORY_CONTEXT" in
    *$'\n') ;;
    *) OUTPUT="${OUTPUT}\n" ;;
  esac
  add_line ""
fi

HANDOFF_CONTEXT=""
HANDOFF_ARTIFACT_PATH="$(get_handoff_artifact_path)"
if [ -n "$HANDOFF_ARTIFACT_PATH" ]; then
  # stale handoff を拒否: 24時間以上前の artifact は無視
  HANDOFF_AGE_LIMIT=86400
  if [ -f "$HANDOFF_ARTIFACT_PATH" ]; then
    HANDOFF_MTIME="$(stat -f %m "$HANDOFF_ARTIFACT_PATH" 2>/dev/null || stat -c %Y "$HANDOFF_ARTIFACT_PATH" 2>/dev/null || echo 0)"
    NOW="$(date +%s)"
    HANDOFF_AGE=$(( NOW - HANDOFF_MTIME ))
    if [ "$HANDOFF_AGE" -lt "$HANDOFF_AGE_LIMIT" ]; then
      HANDOFF_CONTEXT="$(render_handoff_context "$HANDOFF_ARTIFACT_PATH")"
    fi
  fi
fi

if [ -n "$HANDOFF_CONTEXT" ]; then
  OUTPUT="${OUTPUT}${HANDOFF_CONTEXT}"
  case "$HANDOFF_CONTEXT" in
    *$'\n') ;;
    *) OUTPUT="${OUTPUT}\n" ;;
  esac
  add_line ""
fi

sync_handoff_session_metadata "$HANDOFF_ARTIFACT_PATH" "$SESSION_FILE"

add_line "${PLANS_INFO}"

if [ -n "${SNAPSHOT_INFO}" ]; then
  add_line "${SNAPSHOT_INFO}"
fi

if [ -n "$SKILLS_INFO" ]; then
  add_line "${SKILLS_INFO}"
fi

if [ -n "$TEMPLATE_INFO" ]; then
  add_line "${TEMPLATE_INFO}"
fi

if [ -n "$MISSING_RULES_INFO" ]; then
  add_line "${MISSING_RULES_INFO}"
fi

if [ -n "$OLD_HOOKS_INFO" ]; then
  add_line "${OLD_HOOKS_INFO}"
fi

if [ -n "$SYMLINK_INFO" ]; then
  add_line "${SYMLINK_INFO}"
fi

add_line ""
add_line "## マーカー凡例"
add_line "| マーカー | 状態 | 説明 |"
add_line "|---------|------|------|"
add_line "| \`cc:todo\` | 未着手 | Impl（Claude Code）が実行予定 |"
add_line "| \`cc:wip\` | 作業中 | Impl が実装中 |"
add_line "| \`cc:done\` | 完了 | Impl が作業完了、確認待ち |"
add_line "| \`cc:blocked\` | ブロック中 | 依存タスク待ち |"
add_line "| \`pm:requested\` | PM から依頼 | 2-Agent 運用時 |"
add_line "| \`pm:approved\` | PM 確認済み | 2-Agent 運用時 |"
add_line ""
add_line "> **互換**: \`cc:TODO\` / \`cc:WIP\` / \`cc:完了\` / \`pm:依頼中\` / \`pm:確認済\` / \`cursor:*\` は読み取り可能です。"

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
