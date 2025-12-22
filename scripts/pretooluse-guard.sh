#!/bin/bash
# pretooluse-guard.sh
# Claude Code Hooks: PreToolUse guardrail for dangerous operations.
# - Deny writes/edits to protected paths (e.g., .git/, .env, keys)
# - Ask for confirmation for writes outside the project directory
# - Deny sudo, ask for confirmation for rm -rf / git push
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to control PreToolUse permission decisions

set +e

detect_lang() {
  # Default to Japanese for this harness (can be overridden).
  # - CLAUDE_CODE_HARNESS_LANG=en で英語
  # - CLAUDE_CODE_HARNESS_LANG=ja で日本語
  if [ -n "${CLAUDE_CODE_HARNESS_LANG:-}" ]; then
    echo "${CLAUDE_CODE_HARNESS_LANG}"
    return 0
  fi
  echo "ja"
}

LANG_CODE="$(detect_lang)"

msg() {
  # msg <key> [arg]
  local key="$1"
  local arg="${2:-}"

  if [ "$LANG_CODE" = "en" ]; then
    case "$key" in
      deny_path_traversal) echo "Blocked: path traversal in file_path ($arg)" ;;
      ask_write_outside_project) echo "Confirm: writing outside project directory ($arg)" ;;
      deny_protected_path) echo "Blocked: protected path ($arg)" ;;
      deny_sudo) echo "Blocked: sudo is not allowed via Claude Code hooks" ;;
      ask_git_push) echo "Confirm: git push requested ($arg)" ;;
      ask_rm_rf) echo "Confirm: rm -rf requested ($arg)" ;;
      *) echo "$key $arg" ;;
    esac
    return 0
  fi

  # ja (default)
  case "$key" in
    deny_path_traversal) echo "ブロック: パストラバーサルの疑い（file_path: $arg）" ;;
    ask_write_outside_project) echo "確認: プロジェクト外への書き込み（file_path: $arg）" ;;
    deny_protected_path) echo "ブロック: 保護対象パスへの操作（path: $arg）" ;;
    deny_sudo) echo "ブロック: sudo はフック経由では許可していません" ;;
    ask_git_push) echo "確認: git push を実行しようとしています（command: $arg）" ;;
    ask_rm_rf) echo "確認: rm -rf を実行しようとしています（command: $arg）" ;;
    *) echo "$key $arg" ;;
  esac
}

INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

TOOL_NAME=""
FILE_PATH=""
COMMAND=""
CWD=""

if command -v jq >/dev/null 2>&1; then
  TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  CWD="$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
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
file_path = tool_input.get("file_path") or ""
command = tool_input.get("command") or ""
print(f"TOOL_NAME={shlex.quote(tool_name)}")
print(f"CWD={shlex.quote(cwd)}")
print(f"FILE_PATH={shlex.quote(file_path)}")
print(f"COMMAND={shlex.quote(command)}")
PY
)"
fi

[ -z "$TOOL_NAME" ] && exit 0

emit_decision() {
  local decision="$1"
  local reason="$2"

  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg decision "$decision" --arg reason "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$decision, permissionDecisionReason:$reason}}'
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    DECISION="$decision" REASON="$reason" python3 - <<'PY'
import json, os
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": os.environ.get("DECISION", ""),
    "permissionDecisionReason": os.environ.get("REASON", ""),
  }
}))
PY
    return 0
  fi

  # Fallback: omit reason to avoid JSON escaping issues.
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"${decision}\"}}"
}

emit_deny() { emit_decision "deny" "$1"; }
emit_ask() { emit_decision "ask" "$1"; }

is_path_traversal() {
  local p="$1"
  [[ "$p" == ".." ]] && return 0
  [[ "$p" == "../"* ]] && return 0
  [[ "$p" == *"/../"* ]] && return 0
  [[ "$p" == *"/.." ]] && return 0
  return 1
}

is_protected_path() {
  local p="$1"
  case "$p" in
    .git/*|*/.git/*) return 0 ;;
    .env|.env.*|*/.env|*/.env.*) return 0 ;;
    secrets/*|*/secrets/*) return 0 ;;
    *.pem|*.key|*id_rsa*|*id_ed25519*|*/.ssh/*) return 0 ;;
  esac
  return 1
}

if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  [ -z "$FILE_PATH" ] && exit 0

  if is_path_traversal "$FILE_PATH"; then
    emit_deny "$(msg deny_path_traversal "$FILE_PATH")"
    exit 0
  fi

  # If absolute and outside project cwd, ask for confirmation.
  if [ -n "$CWD" ] && [[ "$FILE_PATH" == /* ]] && [[ "$FILE_PATH" != "$CWD/"* ]]; then
    emit_ask "$(msg ask_write_outside_project "$FILE_PATH")"
    exit 0
  fi

  # Normalize to relative when possible for pattern matching.
  REL_PATH="$FILE_PATH"
  if [ -n "$CWD" ] && [[ "$FILE_PATH" == "$CWD/"* ]]; then
    REL_PATH="${FILE_PATH#$CWD/}"
  fi

  if is_protected_path "$REL_PATH"; then
    emit_deny "$(msg deny_protected_path "$REL_PATH")"
    exit 0
  fi

  # ===== LSP/Skills ゲート (Phase0+) =====

  STATE_DIR=".claude/state"
  SESSION_FILE="$STATE_DIR/session.json"
  TOOLING_POLICY_FILE="$STATE_DIR/tooling-policy.json"
  SKILLS_DECISION_FILE="$STATE_DIR/skills-decision.json"
  SKILLS_POLICY_FILE="$STATE_DIR/skills-policy.json"

  # 除外パスチェック関数
  is_excluded_path() {
    local path="$1"
    local policy_file="$2"

    [ ! -f "$policy_file" ] && return 1

    if command -v jq >/dev/null 2>&1; then
      # skills_gate.exclude_paths をチェック
      local exclude_paths
      exclude_paths=$(jq -r '.skills_gate.exclude_paths[]? // empty' "$policy_file" 2>/dev/null)

      while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        # パターンマッチ（前方一致 or ワイルドカード）
        case "$path" in
          $pattern*) return 0 ;;
        esac
        # *.md のようなパターン
        case "$pattern" in
          \*.*)
            local ext="${pattern#\*}"
            [[ "$path" == *"$ext" ]] && return 0
            ;;
        esac
      done <<< "$exclude_paths"

      # exclude_extensions をチェック
      local exclude_exts
      exclude_exts=$(jq -r '.skills_gate.exclude_extensions[]? // empty' "$policy_file" 2>/dev/null)
      local file_ext=".${path##*.}"

      while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        [ "$file_ext" = "$ext" ] && return 0
      done <<< "$exclude_exts"
    fi

    return 1
  }

  # stateファイルが存在する場合のみゲートを適用
  if [ -f "$SESSION_FILE" ] && [ -f "$TOOLING_POLICY_FILE" ]; then
    # JSONから値を抽出（jq優先）
    if command -v jq >/dev/null 2>&1; then
      CURRENT_PROMPT_SEQ=$(jq -r '.prompt_seq // 0' "$SESSION_FILE" 2>/dev/null || echo 0)
      INTENT=$(jq -r '.intent // "literal"' "$SESSION_FILE" 2>/dev/null || echo "literal")
      LSP_AVAILABLE=$(jq -r '.lsp.available // false' "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)
      LSP_LAST_USED_SEQ=$(jq -r '.lsp.last_used_prompt_seq // 0' "$TOOLING_POLICY_FILE" 2>/dev/null || echo 0)

      # ファイル拡張子を取得
      FILE_EXT="${FILE_PATH##*.}"
      LSP_AVAILABLE_FOR_EXT=$(jq -r ".lsp.available_by_ext[\"$FILE_EXT\"] // false" "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)

      # Skills decision required チェック
      SKILLS_DECISION_REQUIRED=$(jq -r '.skills.decision_required // false' "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)
      SKILLS_DECISION_SEQ=0
      if [ -f "$SKILLS_DECISION_FILE" ]; then
        SKILLS_DECISION_SEQ=$(jq -r '.prompt_seq // 0' "$SKILLS_DECISION_FILE" 2>/dev/null || echo 0)
      fi

      # LSPゲート: semantic かつ LSP利用可能 かつ LSP未実行
      if [ "$INTENT" = "semantic" ] && [ "$LSP_AVAILABLE" = "true" ] && [ "$LSP_AVAILABLE_FOR_EXT" = "true" ]; then
        if [ "$LSP_LAST_USED_SEQ" != "$CURRENT_PROMPT_SEQ" ]; then
          # LSP未実行のまま Write/Edit に入ろうとしている → deny
          DENY_MSG="[LSP Policy] コード変更前にLSPツールを使って影響範囲を分析してください。

推奨LSPツール（tool_name確定後に更新）:
- LSP tool: definition, references, rename, diagnostics のいずれか
- 例: Go-to-definition でシンボルの定義を確認
- 例: Find-references で使用箇所を確認
- 例: Diagnostics で型エラーを検出

LSPツールを使って変更の影響範囲を把握してから、再度 Write/Edit を実行してください。

注: Phase0ログで実際の tool_name を確認し、このメッセージを更新することを推奨します。"
          emit_deny "$DENY_MSG"
          exit 0
        fi
      elif [ "$INTENT" = "semantic" ] && [ "$LSP_AVAILABLE" = "false" ]; then
        # LSP未導入だが semantic → 推奨メッセージのみ（allow）
        # ここではdenyしないが、UserPromptSubmitで既に推奨メッセージを出しているので、追加アクションは不要
        : # no-op
      fi

      # Skillsゲート: skills-decision.json が必要なのに更新されていない
      # ただし以下は常に許可（詰ませない）:
      # - skills-decision.json 自体
      # - skills-policy.json で除外されたパス
      if [ "$SKILLS_DECISION_REQUIRED" = "true" ] && [[ "$REL_PATH" != *"skills-decision.json"* ]]; then
        # 除外パスチェック
        if is_excluded_path "$REL_PATH" "$SKILLS_POLICY_FILE"; then
          : # 除外パス → スキップ
        elif [ "$SKILLS_DECISION_SEQ" != "$CURRENT_PROMPT_SEQ" ]; then
          DENY_MSG="[Skills Policy] Skillsの宣言が必要です。

先に \`.claude/state/skills-decision.json\` を更新してから、再度 Write/Edit を実行してください。

例:
{
  \"prompt_seq\": $CURRENT_PROMPT_SEQ,
  \"selected\": [\"skill_name_1\", \"skill_name_2\"],
  \"mode\": \"declared\"
}"
          emit_deny "$DENY_MSG"
          exit 0
        fi
      fi
    fi
  fi

  exit 0
fi

if [ "$TOOL_NAME" = "Bash" ]; then
  [ -z "$COMMAND" ] && exit 0

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])sudo([[:space:]]|$)'; then
    emit_deny "$(msg deny_sudo)"
    exit 0
  fi

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
    emit_ask "$(msg ask_git_push "$COMMAND")"
    exit 0
  fi

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]+-rf([[:space:]]|$)'; then
    emit_ask "$(msg ask_rm_rf "$COMMAND")"
    exit 0
  fi

  exit 0
fi

exit 0


