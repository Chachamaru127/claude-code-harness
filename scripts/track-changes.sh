#!/bin/bash
# track-changes.sh
# ファイル変更を追跡し、状態ファイルを更新
#
# Usage: PostToolUse hook から自動実行
# Input: stdin JSON (Claude Code hooks) / 互換: $1=tool_name, $2=file_path
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set +e

# Load cross-platform path utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
else
  # Fallback: minimal normalize_path and is_path_under
  normalize_path() {
    local p="$1"
    p="${p//\\//}"
    echo "$p"
  }
  is_path_under() {
    local child="$1"
    local parent="$2"
    child="$(normalize_path "$child")"
    parent="$(normalize_path "$parent")"
    [[ "$parent" != */ ]] && parent="${parent}/"
    [[ "${child}/" == "${parent}"* ]] || [ "$child" = "${parent%/}" ]
  }
fi

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

TOOL_NAME="${1:-}"
FILE_PATH="${2:-}"
CWD=""

if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TOOL_NAME_FROM_STDIN="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH_FROM_STDIN="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD_FROM_STDIN="$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(echo "$INPUT" | python3 - <<'PY' 2>/dev/null
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME_FROM_STDIN={shlex.quote(tool_name)}")
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
PY
)"
  fi

  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  [ -z "$FILE_PATH" ] && FILE_PATH="${FILE_PATH_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

TOOL_NAME="${TOOL_NAME:-unknown}"

# 可能ならプロジェクト相対パスへ正規化（クロスプラットフォーム対応）
if [ -n "$CWD" ] && [ -n "$FILE_PATH" ]; then
  NORM_FILE_PATH="$(normalize_path "$FILE_PATH")"
  NORM_CWD="$(normalize_path "$CWD")"

  if is_path_under "$NORM_FILE_PATH" "$NORM_CWD"; then
    # Remove the CWD prefix to get relative path
    cwd_with_slash="${NORM_CWD%/}/"
    if [[ "$NORM_FILE_PATH" == "$cwd_with_slash"* ]]; then
      FILE_PATH="${NORM_FILE_PATH#$cwd_with_slash}"
    fi
  fi
fi
STATE_FILE=".claude/state/session.json"
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 状態ファイルがなければスキップ
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# ファイルパスがなければスキップ
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 重要なファイルの変更を検出
IMPORTANT_FILES="Plans.md CLAUDE.md AGENTS.md"
IS_IMPORTANT="false"

for important in $IMPORTANT_FILES; do
  if [[ "$FILE_PATH" == *"$important"* ]]; then
    IS_IMPORTANT="true"
    break
  fi
done

# テストファイルの検出
if [[ "$FILE_PATH" == *".test."* ]] || [[ "$FILE_PATH" == *".spec."* ]] || [[ "$FILE_PATH" == *"__tests__"* ]]; then
  IS_IMPORTANT="true"
fi

# 変更を記録（jq があれば使用、なければスキップ）
if command -v jq &> /dev/null; then
  # 新しい変更エントリを追加
  TEMP_FILE=$(mktemp 2>/dev/null) || {
    # mktemp 失敗時は静かにスキップ（PostToolUse hookなので中断しない）
    exit 0
  }
  # クリーンアップを保証
  trap 'rm -f "$TEMP_FILE"' EXIT

  if jq --arg file "$FILE_PATH" \
        --arg action "$TOOL_NAME" \
        --arg timestamp "$CURRENT_TIME" \
        --arg important "$IS_IMPORTANT" \
        '.changes_this_session += [{
          "file": $file,
          "action": $action,
          "timestamp": $timestamp,
          "important": ($important == "true")
        }]' "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$STATE_FILE" 2>/dev/null || true
  fi
fi

# 重要なファイルの変更時は通知
if [ "$IS_IMPORTANT" = "true" ]; then
  case "$FILE_PATH" in
    *Plans.md*)
      echo "📋 Plans.md が更新されました"
      ;;
    *CLAUDE.md*)
      echo "📝 CLAUDE.md が更新されました"
      ;;
    *AGENTS.md*)
      echo "📝 AGENTS.md が更新されました"
      ;;
    *.test.*|*.spec.*|*__tests__*)
      echo "🧪 テストファイルが更新されました: $(basename "$FILE_PATH")"
      ;;
  esac
fi

exit 0
