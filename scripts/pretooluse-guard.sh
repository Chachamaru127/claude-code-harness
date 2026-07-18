#!/bin/bash
# pretooluse-guard.sh
# Claude Code Hooks: PreToolUse guardrail for dangerous operations.
# - Deny writes/edits to protected paths (e.g., .git/, .env, keys)
# - Ask for confirmation for writes outside the project directory
# - Deny sudo, ask for confirmation for rm -rf / git push
#
# Input: stdin JSON from Claude Code hooks
# Output: JSON to control PreToolUse permission decisions
#
# Cross-platform: Supports Windows (Git Bash/MSYS2/Cygwin/WSL), macOS, Linux

set +e

# Load cross-platform path utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/path-utils.sh" ]; then
  # shellcheck source=./path-utils.sh
  source "$SCRIPT_DIR/path-utils.sh"
else
  # Fallback: define minimal path utilities if path-utils.sh not found
  is_absolute_path() {
    local p="$1"
    [[ "$p" == /* ]] && return 0
    [[ "$p" =~ ^[A-Za-z]:[\\/] ]] && return 0
    return 1
  }
  normalize_path() {
    local p="$1"
    p="${p//\\//}"
    echo "$p"
  }
  # Note: This expects already-normalized paths from caller for performance
  is_path_under() {
    local child="$1"
    local parent="$2"
    [[ "$parent" != */ ]] && parent="${parent}/"
    [[ "${child}/" == "${parent}"* ]] || [ "$child" = "${parent%/}" ]
  }
fi

if [ -f "$SCRIPT_DIR/config-utils.sh" ]; then
  # shellcheck source=./config-utils.sh
  source "$SCRIPT_DIR/config-utils.sh"
fi

detect_lang() {
  local cwd_path="${1:-}"

  if declare -F get_harness_locale >/dev/null 2>&1; then
    if [ -n "$cwd_path" ] && [ -f "$cwd_path/.claude-code-harness.config.yaml" ]; then
      CONFIG_FILE="$cwd_path/.claude-code-harness.config.yaml" get_harness_locale
    else
      get_harness_locale
    fi
    return 0
  fi

  if [ -n "${CLAUDE_CODE_HARNESS_LANG:-}" ]; then
    case "$(printf '%s' "${CLAUDE_CODE_HARNESS_LANG}" | tr '[:upper:]' '[:lower:]')" in
      en|ja) printf '%s\n' "$(printf '%s' "${CLAUDE_CODE_HARNESS_LANG}" | tr '[:upper:]' '[:lower:]')" ;;
      *) echo "en" ;;
    esac
    return 0
  fi
  echo "en"
}

LANG_CODE="en"

# ===== Work Mode Detection =====
# /work (auto-iteration) 実行中は特定の確認プロンプトをスキップ
# セキュリティ: 有効期限（24時間）でバイパスを制限
# Note: CWD は後で JSON から取得されるため、ここでは初期化のみ
# 後方互換: ultrawork-active.json も work-active.json として検出

WORK_MODE="false"
WORK_BYPASS_RM_RF="false"
WORK_BYPASS_GIT_PUSH="false"
WORK_MAX_AGE_HOURS=24

# ===== Codex Mode Detection =====
# --codex モード時は Claude は PM 役であり、Edit/Write は禁止
# （実装は Codex Worker に委譲）
# work-active.json の codex_mode: true で検出
CODEX_MODE="false"

# ===== Breezing Role Guard =====
# Agent Teams Teammate のロールベースアクセス制御
# session_id / agent_id でセッションを識別し、ロールに応じて Write/Edit を制限
BREEZING_ROLE=""
BREEZING_OWNS=""
SESSION_ID=""
AGENT_ID=""
AGENT_TYPE=""
BREEZING_ROLE_KEY=""

# ===== Breezing-Codex Mode Detection =====
# breezing-codex モード (impl_mode: "codex") 時は直接の Write/Edit をブロック
# （実装は codex exec (CLI) 経由で Codex Implementer に委譲）
BREEZING_CODEX_MODE="false"

# Work モード検出関数（CWD 取得後に呼び出す）
# work-active.json を優先、後方互換で ultrawork-active.json もフォールバック
check_work_mode() {
  local cwd_path="$1"
  local active_file="${cwd_path}/.claude/state/work-active.json"

  # 後方互換: work-active.json がなければ ultrawork-active.json を試行
  if [ ! -f "$active_file" ]; then
    active_file="${cwd_path}/.claude/state/ultrawork-active.json"
  fi

  [ ! -f "$active_file" ] && return

  if ! command -v jq >/dev/null 2>&1; then
    echo "[work] Warning: jq not installed, guard bypass disabled" >&2
    return
  fi

  local is_active
  is_active=$(jq -r '.active // false' "$active_file" 2>/dev/null || echo "false")
  [ "$is_active" != "true" ] && return

  # 有効期限チェック（started_at から 24 時間以内か）
  local started_at
  started_at=$(jq -r '.started_at // empty' "$active_file" 2>/dev/null)
  [ -z "$started_at" ] && return

  # ISO8601 パース（macOS/Linux 両対応）
  # Z suffix を除去してパース
  local started_clean="${started_at%%Z*}"
  started_clean="${started_clean%%+*}"  # タイムゾーンオフセットも除去
  started_clean="${started_clean%%.*}"  # ミリ秒も除去

  local started_epoch=0
  local current_epoch
  current_epoch=$(date +%s)

  # macOS: date -j -f, Linux: date -d
  if [[ "$OSTYPE" == "darwin"* ]]; then
    started_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$started_clean" +%s 2>/dev/null || echo 0)
  else
    started_epoch=$(date -d "${started_at}" +%s 2>/dev/null || echo 0)
  fi

  if [ "$started_epoch" -eq 0 ]; then
    echo "[work] Warning: failed to parse started_at, guard bypass disabled" >&2
    return
  fi

  # 未来時刻チェック（改ざん防止）
  if [ "$started_epoch" -gt "$current_epoch" ]; then
    echo "[work] Warning: started_at is in the future, guard bypass disabled" >&2
    return
  fi

  local age_hours=$(( (current_epoch - started_epoch) / 3600 ))
  if [ "$age_hours" -ge "$WORK_MAX_AGE_HOURS" ]; then
    rm -f "$active_file" 2>/dev/null || true
    echo "[work] Warning: work-active.json expired (${age_hours}h >= ${WORK_MAX_AGE_HOURS}h), removed" >&2
    return
  fi

  WORK_MODE="true"
  # Performance: extract bypass_guards and codex_mode in one jq call to avoid re-reading
  local _work_extras
  _work_extras=$(jq -r '[
    (if .bypass_guards | type == "array" then (.bypass_guards | contains(["rm_rf"])) else false end),
    (if .bypass_guards | type == "array" then (.bypass_guards | contains(["git_push"])) else false end),
    (.codex_mode // false)
  ] | @tsv' "$active_file" 2>/dev/null)
  if [ -n "$_work_extras" ]; then
    IFS=$'\t' read -r WORK_BYPASS_RM_RF WORK_BYPASS_GIT_PUSH _work_codex_mode <<< "$_work_extras"
    # Cache codex_mode for check_codex_mode to avoid re-parsing
    WORK_CACHED_CODEX_MODE="${_work_codex_mode}"
  else
    WORK_BYPASS_RM_RF="false"
    WORK_BYPASS_GIT_PUSH="false"
  fi
}

# Codex モード検出関数（CWD 取得後に呼び出す）
# work-active.json に codex_mode: true がある場合、Claude の Edit/Write をブロック
# 前提: WORK_MODE が true かつ TTL が有効な場合のみ CODEX_MODE を設定
# Performance: check_work_mode でキャッシュ済みの値を優先使用
check_codex_mode() {
  # Work モードが有効でない場合はスキップ（TTL 切れ等を考慮）
  [ "$WORK_MODE" != "true" ] && return

  # Use cached value from check_work_mode if available (avoids re-reading file)
  if [ -n "${WORK_CACHED_CODEX_MODE:-}" ]; then
    [ "$WORK_CACHED_CODEX_MODE" = "true" ] && CODEX_MODE="true"
    return
  fi

  # Fallback: read file directly (for python3-only environments where jq cache wasn't set)
  local cwd_path="$1"
  local active_file="${cwd_path}/.claude/state/work-active.json"

  # 後方互換: work-active.json がなければ ultrawork-active.json を試行
  if [ ! -f "$active_file" ]; then
    active_file="${cwd_path}/.claude/state/ultrawork-active.json"
  fi

  [ ! -f "$active_file" ] && return

  local is_codex="false"

  if command -v python3 >/dev/null 2>&1; then
    is_codex=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    val = data.get("codex_mode", False)
    print("true" if val is True else "false")
except:
    print("false")
' "$active_file" 2>/dev/null || echo "false")
  fi

  [ "$is_codex" = "true" ] && CODEX_MODE="true"
}

# Breezing ロール検出関数（CWD + SESSION_ID/AGENT_ID 取得後に呼び出す）
# .claude/state/breezing-session-roles.json から role を検索
check_breezing_role() {
  local cwd_path="$1"
  local roles_file="${cwd_path}/.claude/state/breezing-session-roles.json"

  [ -z "$SESSION_ID" ] && [ -z "$AGENT_ID" ] && return
  [ ! -f "$roles_file" ] && return

  if ! command -v jq >/dev/null 2>&1; then
    return
  fi

  local lookup_key=""
  local role=""
  local owns=""

  for lookup_key in "$AGENT_ID" "$SESSION_ID"; do
    [ -z "$lookup_key" ] && continue
    role="$(jq -r --arg sid "$lookup_key" '.[$sid].role // empty' "$roles_file" 2>/dev/null)"
    [ -z "$role" ] && continue
    owns="$(jq -r --arg sid "$lookup_key" '.[$sid].owns // empty' "$roles_file" 2>/dev/null)"
    BREEZING_ROLE="$role"
    BREEZING_OWNS="$owns"
    BREEZING_ROLE_KEY="$lookup_key"
    return
  done
}

# Breezing-Codex モード検出関数（CWD 取得後に呼び出す）
# breezing-active.json に impl_mode: "codex" がある場合、直接の Write/Edit をブロック
check_breezing_codex_mode() {
  local cwd_path="$1"
  local active_file="${cwd_path}/.claude/state/breezing-active.json"

  [ ! -f "$active_file" ] && return

  local is_codex="false"

  if command -v jq >/dev/null 2>&1; then
    local impl_mode
    impl_mode=$(jq -r '.impl_mode // empty' "$active_file" 2>/dev/null)
    [ "$impl_mode" = "codex" ] && is_codex="true"
  elif command -v python3 >/dev/null 2>&1; then
    is_codex=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    val = data.get("impl_mode", "")
    print("true" if val == "codex" else "false")
except:
    print("false")
' "$active_file" 2>/dev/null || echo "false")
  else
    echo "[Breezing-Codex] Warning: jq/python3 not found, breezing-codex mode detection disabled" >&2
    return
  fi

  [ "$is_codex" = "true" ] && BREEZING_CODEX_MODE="true"
}

# Breezing ロール登録 Write の検出と処理
# Teammate の最初の Write (breezing-role-*.json) で session_id / agent_id → role を登録
try_register_breezing_role() {
  local file_path="$1"
  local cwd_path="$2"
  local roles_file="${cwd_path}/.claude/state/breezing-session-roles.json"

  # breezing-role-*.json への Write のみ対象
  BASENAME_ROLE="${file_path##*/}"
  case "$BASENAME_ROLE" in
    breezing-role-*.json) ;;
    *) return 1 ;;
  esac

  # パスが .claude/state/ 配下であることを確認
  case "$file_path" in
    .claude/state/breezing-role-*.json|*/.claude/state/breezing-role-*.json) ;;
    *) return 1 ;;
  esac

  [ -z "$SESSION_ID" ] && [ -z "$AGENT_ID" ] && return 1

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  # tool_input.content からロール情報を抽出
  local content role owns
  content=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
  [ -z "$content" ] && return 1

  role=$(echo "$content" | jq -r '.role // empty' 2>/dev/null)
  [ -z "$role" ] && return 1

  # セキュリティ: role は既知の値のみ許可
  case "$role" in
    reviewer|implementer|lead) ;;
    *) return 1 ;;
  esac

  owns=$(echo "$content" | jq -c '.owns // []' 2>/dev/null || echo '[]')

  # session_id → role マッピングを登録
  mkdir -p "${cwd_path}/.claude/state" 2>/dev/null || true

  if [ ! -f "$roles_file" ]; then
    echo '{}' > "$roles_file"
  fi

  jq \
    --arg sid "$SESSION_ID" \
    --arg aid "$AGENT_ID" \
    --arg atype "$AGENT_TYPE" \
    --arg role "$role" \
    --argjson owns "$owns" \
    '
      (if $sid != "" then .[$sid] = {"role": $role, "owns": $owns, "agent_type": $atype} else . end)
      | (if $aid != "" then .[$aid] = {"role": $role, "owns": $owns, "agent_type": $atype} else . end)
    ' \
    "$roles_file" > "${roles_file}.tmp" && mv "${roles_file}.tmp" "$roles_file"

  return 0
}

msg() {
  # msg <key> [arg]
  local key="$1"
  local arg="${2:-}"
  local arg2="${3:-}"
  local arg3="${4:-}"

  if [ "$LANG_CODE" = "en" ]; then
    case "$key" in
      deny_path_traversal) echo "Blocked: path traversal in file_path ($arg)" ;;
      ask_write_outside_project) echo "Confirm: writing outside project directory ($arg)" ;;
      deny_protected_path) echo "Blocked: protected path ($arg)" ;;
      deny_sudo) echo "Blocked: sudo is not allowed via Claude Code hooks" ;;
      ask_git_push) echo "Confirm: git push requested ($arg)" ;;
      ask_rm_rf) echo "Confirm: rm -rf requested ($arg)" ;;
      deny_git_commit_no_review) echo "Blocked: Run /harness-review before committing. After review approval, run git commit again." ;;
      deny_codex_mode) echo "[Codex Mode] Claude is the PM. Direct Edit/Write is prohibited. Delegate implementation to Codex Worker via codex exec (CLI)." ;;
      deny_breezing_codex_mode) echo "[Breezing-Codex] Direct Edit/Write is prohibited in codex impl mode. Implementation must go through codex exec (CLI)." ;;
      deny_codex_mcp) echo "Blocked: Codex MCP is deprecated. Use 'codex exec' (Bash) instead. See .claude/rules/codex-cli-only.md" ;;
      codex_plans_symlink) echo "[Codex Mode] Symbolic links are not allowed for Plans.md" ;;
      breezing_codex_symlink) echo "[Breezing-Codex] Symbolic links are not allowed" ;;
      breezing_reviewer_readonly) echo "[Breezing] Reviewer is read-only. Code changes are the Implementer's responsibility." ;;
      breezing_owns_outside) echo "[Breezing] This file is outside the owns scope: $arg" ;;
      breezing_reviewer_bash_write) echo "[Breezing] Reviewer cannot run write-like Bash commands." ;;
      breezing_reviewer_file_ops) echo "[Breezing] Reviewer cannot run file operation commands." ;;
      breezing_reviewer_git_mutation) echo "[Breezing] Reviewer cannot run git mutation commands." ;;
      breezing_implementer_git_commit) echo "[Breezing] Implementer cannot run git commit. Lead commits changes during the completion stage." ;;
      breezing_implementer_git_push) echo "[Breezing] Implementer cannot run git push." ;;
      breezing_codex_file_ops) echo "[Breezing-Codex] File operation commands are prohibited in codex impl mode." ;;
      breezing_codex_git_mutation) echo "[Breezing-Codex] Git mutation commands are prohibited in codex impl mode." ;;
      codex_ask_file_ops) echo "[Codex Mode] Run file operations (mv/cp) in PM mode? Delegating implementation to Codex Worker is recommended." ;;
      codex_ask_rm_rf) echo "[Codex Mode] Run rm -rf in PM mode? Delegating implementation to Codex Worker is recommended. ($arg)" ;;
      codex_ask_rm) echo "[Codex Mode] Run rm in PM mode? Delegating implementation to Codex Worker is recommended." ;;
      cost_limit_total) echo "[Cost Control] Session tool-call limit reached ($arg). Start a new session." ;;
      cost_limit_edit) echo "[Cost Control] Edit/Write call limit reached ($arg)." ;;
      cost_limit_bash) echo "[Cost Control] Bash call limit reached ($arg)." ;;
      cost_warning_total) echo "[Cost Warning] Total tool calls: ${arg}/${arg2} (over ${arg3}%)" ;;
      cost_warning_edit) echo "[Cost Warning] Edit/Write: ${arg}/${arg2}" ;;
      cost_warning_bash) echo "[Cost Warning] Bash: ${arg}/${arg2}" ;;
      test_quality_guideline) cat <<'EOF'
[Test Quality Guideline]
- Do not change tests to it.skip() / test.skip()
- Do not remove or weaken assertions
- Do not add eslint-disable comments
EOF
        ;;
      impl_quality_guideline) cat <<'EOF'
[Implementation Quality Guideline]
- Do not hard-code test expectations
- Do not add stubs, mocks, or empty implementations as the final fix
- Implement meaningful logic
EOF
        ;;
      skills_gate) cat <<EOF
[Skills Gate] Use a skill before editing code.

Skills Gate is enabled for this project.
Before changing code, call an appropriate skill with the Skill tool.

Available skills: ${arg}

Example: call 'impl' or 'harness-review' with the Skill tool.

After using a skill, run Write/Edit again.
EOF
        ;;
      lsp_gate) cat <<'EOF'
[LSP Policy] Analyze the impact with LSP tools before changing code.

Recommended LSP tools:
- Go-to-definition to inspect symbol definitions
- Find-references to inspect usage sites
- Diagnostics to detect type errors

After checking the impact with LSP tools, run Write/Edit again.
EOF
        ;;
      *) echo "$key $arg" ;;
    esac
    return 0
  fi

  # ja
  case "$key" in
    deny_path_traversal) echo "ブロック: パストラバーサルの疑い（file_path: $arg）" ;;
    ask_write_outside_project) echo "確認: プロジェクト外への書き込み（file_path: $arg）" ;;
    deny_protected_path) echo "ブロック: 保護対象パスへの操作（path: $arg）" ;;
    deny_sudo) echo "ブロック: sudo はフック経由では許可していません" ;;
    ask_git_push) echo "確認: git push を実行しようとしています（command: $arg）" ;;
    ask_rm_rf) echo "確認: rm -rf を実行しようとしています（command: $arg）" ;;
    deny_git_commit_no_review) echo "ブロック: コミット前に /harness-review を実行してください。レビュー後、再度 git commit を実行できます。" ;;
    deny_codex_mode) echo "[Codex Mode] --codex モードでは Claude は PM 役です。直接の Edit/Write は禁止されています。実装は codex exec (CLI) 経由で Codex Worker に委譲してください。" ;;
    deny_breezing_codex_mode) echo "[Breezing-Codex] codex 実装モードでは直接の Edit/Write は禁止されています。実装は codex exec (CLI) 経由で行ってください。" ;;
    deny_codex_mcp) echo "ブロック: Codex MCP は廃止されました。代わりに 'codex exec' (Bash) を使用してください。詳細: .claude/rules/codex-cli-only.md" ;;
    codex_plans_symlink) echo "[Codex Mode] Plans.md にシンボリックリンクは使用できません。" ;;
    breezing_codex_symlink) echo "[Breezing-Codex] シンボリックリンクは使用できません。" ;;
    breezing_reviewer_readonly) echo "[Breezing] Reviewer は Read-only です。コードの修正は Implementer の責務です。" ;;
    breezing_owns_outside) echo "[Breezing] このファイルは owns 範囲外です: $arg" ;;
    breezing_reviewer_bash_write) echo "[Breezing] Reviewer は書き込み系 Bash コマンドを実行できません。" ;;
    breezing_reviewer_file_ops) echo "[Breezing] Reviewer はファイル操作コマンドを実行できません。" ;;
    breezing_reviewer_git_mutation) echo "[Breezing] Reviewer は git 変更コマンドを実行できません。" ;;
    breezing_implementer_git_commit) echo "[Breezing] Implementer は git commit を実行できません。コミットは Lead が完了ステージで一括実行します。" ;;
    breezing_implementer_git_push) echo "[Breezing] Implementer は git push を実行できません。" ;;
    breezing_codex_file_ops) echo "[Breezing-Codex] codex 実装モードではファイル操作コマンドは禁止されています。" ;;
    breezing_codex_git_mutation) echo "[Breezing-Codex] codex 実装モードでは git 変更コマンドは禁止されています。" ;;
    codex_ask_file_ops) echo "[Codex Mode] PM モードでファイル操作（mv/cp）を実行しますか？実装は Codex Worker に委譲を推奨します。" ;;
    codex_ask_rm_rf) echo "[Codex Mode] PM モードで rm -rf を実行しますか？実装は Codex Worker に委譲を推奨します。($arg)" ;;
    codex_ask_rm) echo "[Codex Mode] PM モードで rm を実行しますか？実装は Codex Worker に委譲を推奨します。" ;;
    cost_limit_total) echo "[Cost Control] セッションのツール呼び出し上限 ($arg) に達しました。新しいセッションを開始してください。" ;;
    cost_limit_edit) echo "[Cost Control] Edit/Write 呼び出し上限 ($arg) に達しました。" ;;
    cost_limit_bash) echo "[Cost Control] Bash 呼び出し上限 ($arg) に達しました。" ;;
    cost_warning_total) echo "[Cost Warning] 総ツール呼び出し: ${arg}/${arg2} (${arg3}%超過)" ;;
    cost_warning_edit) echo "[Cost Warning] Edit/Write: ${arg}/${arg2}" ;;
    cost_warning_bash) echo "[Cost Warning] Bash: ${arg}/${arg2}" ;;
    test_quality_guideline) cat <<'EOF'
【テスト品質ガイドライン】
- it.skip() / test.skip() への変更禁止
- アサーションの削除・緩和禁止
- eslint-disable コメントの追加禁止
EOF
      ;;
    impl_quality_guideline) cat <<'EOF'
【実装品質ガイドライン】
- テスト期待値のハードコード禁止
- スタブ・モック・空実装禁止
- 意味のあるロジックを実装すること
EOF
      ;;
    skills_gate) cat <<EOF
[Skills Gate] コード編集前にスキルを使用してください。

このプロジェクトでは Skills Gate が有効です。
コード変更前に Skill ツールで適切なスキルを呼び出してください。

利用可能なスキル: ${arg}

例: Skill ツールで 'impl' や 'harness-review' を呼び出す

スキルを使用後、再度 Write/Edit を実行してください。
EOF
      ;;
    lsp_gate) cat <<'EOF'
[LSP Policy] コード変更前にLSPツールを使って影響範囲を分析してください。

推奨LSPツール:
- Go-to-definition でシンボルの定義を確認
- Find-references で使用箇所を確認
- Diagnostics で型エラーを検出

LSPツールを使って変更の影響範囲を把握してから、再度 Write/Edit を実行してください。
EOF
      ;;
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
  # Performance: extract all fields in one jq call instead of 5 separate invocations
  _jq_parsed="$(echo "$INPUT" | jq -r '[
    (.tool_name // ""),
    (.tool_input.file_path // ""),
    (.tool_input.command // ""),
    (.cwd // ""),
    (.session_id // ""),
    (.agent_id // ""),
    (.agent_type // "")
  ] | map(tostring | gsub("\u001f"; "")) | join("\u001f")' 2>/dev/null)"
  if [ -n "$_jq_parsed" ]; then
    IFS=$'\037' read -r TOOL_NAME FILE_PATH COMMAND CWD SESSION_ID AGENT_ID AGENT_TYPE <<< "$_jq_parsed"
  fi
  unset _jq_parsed
elif command -v python3 >/dev/null 2>&1; then
  # Performance+Security: extract all fields in one python3 call (no eval)
  _py_parsed="$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
def get_nested(d, path):
    for k in path.split('.'):
        if isinstance(d, dict):
            d = d.get(k) or ''
        else:
            return ''
    return d if isinstance(d, str) else ''
fields = ['tool_name', 'tool_input.file_path', 'tool_input.command', 'cwd', 'session_id', 'agent_id', 'agent_type']
print('\x1f'.join(get_nested(data, f).replace('\x1f', '') for f in fields))
" 2>/dev/null)"
  if [ -n "$_py_parsed" ]; then
    IFS=$'\037' read -r TOOL_NAME FILE_PATH COMMAND CWD SESSION_ID AGENT_ID AGENT_TYPE <<< "$_py_parsed"
  fi
  unset _py_parsed
fi

LANG_CODE="$(detect_lang "$CWD")"

[ -z "$TOOL_NAME" ] && exit 0

# ===== Work モード検出実行（CWD 取得後） =====
if [ -n "$CWD" ]; then
  check_work_mode "$CWD"
  check_codex_mode "$CWD"
  check_breezing_role "$CWD"
  check_breezing_codex_mode "$CWD"
fi

# ===== Cost Control: セッション単位でツール呼び出し数を追跡 =====
CONFIG_FILE=".claude-code-harness.config.yaml"
STATE_DIR=".claude/state"
COST_STATE_FILE="$STATE_DIR/cost-state.json"

check_cost_control() {
  local tool="$1"

  # cost_control.enabled チェック
  if [ ! -f "$CONFIG_FILE" ]; then
    return 0
  fi

  local cost_enabled
  cost_enabled=$(grep -E "^  enabled:" "$CONFIG_FILE" 2>/dev/null | head -n 1 | awk '{print $2}' || echo "false")
  if [ "$cost_enabled" != "true" ]; then
    return 0
  fi

  # cost-state.json がなければ初期化
  # Security: refuse if state dir or file is a symlink (prevents symlink-based overwrites)
  if [ -L "$STATE_DIR" ] || [ -L "$COST_STATE_FILE" ]; then
    return 0
  fi
  if [ ! -f "$COST_STATE_FILE" ]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    echo '{"total_tool_calls":0,"edit_calls":0,"bash_calls":0}' > "$COST_STATE_FILE"
  fi

  if command -v jq >/dev/null 2>&1; then
    # 現在のカウントを取得
    local total_calls edit_calls bash_calls
    total_calls=$(jq -r '.total_tool_calls // 0' "$COST_STATE_FILE" 2>/dev/null || echo 0)
    edit_calls=$(jq -r '.edit_calls // 0' "$COST_STATE_FILE" 2>/dev/null || echo 0)
    bash_calls=$(jq -r '.bash_calls // 0' "$COST_STATE_FILE" 2>/dev/null || echo 0)

    # 設定から上限を取得
    local total_limit edit_limit bash_limit warn_percent
    total_limit=$(grep -A5 "session_limits:" "$CONFIG_FILE" 2>/dev/null | grep "total_tool_calls:" | awk '{print $2}' || echo 500)
    edit_limit=$(grep -A5 "session_limits:" "$CONFIG_FILE" 2>/dev/null | grep "edit_calls:" | awk '{print $2}' || echo 100)
    bash_limit=$(grep -A5 "session_limits:" "$CONFIG_FILE" 2>/dev/null | grep "bash_calls:" | awk '{print $2}' || echo 200)
    warn_percent=$(grep "warn_threshold_percent:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo 80)

    # カウントをインクリメント
    total_calls=$((total_calls + 1))
    case "$tool" in
      Write|Edit) edit_calls=$((edit_calls + 1)) ;;
      Bash) bash_calls=$((bash_calls + 1)) ;;
    esac

    # cost-state.json を更新
    jq --argjson t "$total_calls" --argjson e "$edit_calls" --argjson b "$bash_calls" \
      '.total_tool_calls = $t | .edit_calls = $e | .bash_calls = $b' \
      "$COST_STATE_FILE" > "${COST_STATE_FILE}.tmp" && mv "${COST_STATE_FILE}.tmp" "$COST_STATE_FILE"

    # 上限チェック
    if [ "$total_calls" -ge "$total_limit" ]; then
      msg cost_limit_total "$total_limit"
      return 1
    fi

    case "$tool" in
      Write|Edit)
        if [ "$edit_calls" -ge "$edit_limit" ]; then
          msg cost_limit_edit "$edit_limit"
          return 1
        fi
        ;;
      Bash)
        if [ "$bash_calls" -ge "$bash_limit" ]; then
          msg cost_limit_bash "$bash_limit"
          return 1
        fi
        ;;
    esac

    # 警告閾値チェック（additionalContext で警告）
    local warn_total=$((total_limit * warn_percent / 100))
    local warn_edit=$((edit_limit * warn_percent / 100))
    local warn_bash=$((bash_limit * warn_percent / 100))

    local warnings=""
    if [ "$total_calls" -ge "$warn_total" ] && [ "$total_calls" -lt "$total_limit" ]; then
      warnings="${warnings}$(msg cost_warning_total "$total_calls" "$total_limit" "$warn_percent")\n"
    fi
    case "$tool" in
      Write|Edit)
        if [ "$edit_calls" -ge "$warn_edit" ] && [ "$edit_calls" -lt "$edit_limit" ]; then
          warnings="${warnings}$(msg cost_warning_edit "$edit_calls" "$edit_limit")\n"
        fi
        ;;
      Bash)
        if [ "$bash_calls" -ge "$warn_bash" ] && [ "$bash_calls" -lt "$bash_limit" ]; then
          warnings="${warnings}$(msg cost_warning_bash "$bash_calls" "$bash_limit")\n"
        fi
        ;;
    esac

    if [ -n "$warnings" ]; then
      echo -e "$warnings"
      return 2  # 警告あり（ブロックではない）
    fi
  fi

  return 0
}

# コスト制御チェックは emit_deny 定義後に実行（後方で実行）

emit_decision() {
  local decision="$1"
  local reason="$2"
  local additional_context="${3:-}"

  if command -v jq >/dev/null 2>&1; then
    if [ -n "$additional_context" ]; then
      jq -nc --arg decision "$decision" --arg reason "$reason" --arg ctx "$additional_context" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$decision, permissionDecisionReason:$reason, additionalContext:$ctx}}'
    else
      jq -nc --arg decision "$decision" --arg reason "$reason" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$decision, permissionDecisionReason:$reason}}'
    fi
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    DECISION="$decision" REASON="$reason" ADDITIONAL_CONTEXT="$additional_context" python3 - <<'PY'
import json, os
output = {
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": os.environ.get("DECISION", ""),
    "permissionDecisionReason": os.environ.get("REASON", ""),
  }
}
ctx = os.environ.get("ADDITIONAL_CONTEXT", "")
if ctx:
    output["hookSpecificOutput"]["additionalContext"] = ctx
print(json.dumps(output))
PY
    return 0
  fi

  # Fallback: omit reason and additionalContext to avoid JSON escaping issues.
  printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"${decision}\"}}"
}

emit_deny() {
  # Record hook blocking event (non-blocking, fire-and-forget)
  local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -x "$SCRIPT_DIR/record-usage.js" ] && command -v node >/dev/null 2>&1; then
    node "$SCRIPT_DIR/record-usage.js" hook pretooluse-guard --blocked >/dev/null 2>&1 &
  fi
  emit_decision "deny" "$1"
}
emit_ask() { emit_decision "ask" "$1"; }

# ===== Codex MCP ブロック（廃止済み） =====
# MCP サーバーは削除済み。テキスト修正をすり抜けた場合のフェイルセーフ。
if [[ "$TOOL_NAME" == mcp__codex__* ]]; then
  emit_deny "$(msg deny_codex_mcp)"
  exit 0
fi

# ===== コスト制御チェック実行 =====
COST_CHECK_MSG=""
COST_CHECK_MSG=$(check_cost_control "$TOOL_NAME")
COST_CHECK_RESULT=$?

if [ "$COST_CHECK_RESULT" -eq 1 ]; then
  # 上限到達 → deny
  emit_deny "$COST_CHECK_MSG"
  exit 0
fi
# 警告 (result=2) の場合は後続処理で additionalContext に含める

# ===== additionalContext ガイドライン生成 (Claude Code v2.1.9+) =====
# Write/Edit 操作時にファイルパスに応じたガイドラインを返す

TEST_QUALITY_GUIDELINE="$(msg test_quality_guideline)"

IMPL_QUALITY_GUIDELINE="$(msg impl_quality_guideline)"

# ファイルパスに応じたガイドラインを返す
# 引数: $1 = ファイルパス（相対または絶対）
# 戻り値: ガイドライン文字列（該当なしの場合は空）
get_guideline_for_path() {
  local path="$1"

  # テストファイルパターン
  case "$path" in
    tests/*|test/*|__tests__/*|*.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx|*.test.ts|*.test.tsx|*.test.js|*.test.jsx)
      echo "$TEST_QUALITY_GUIDELINE"
      return 0
      ;;
  esac

  # 実装ファイルパターン
  case "$path" in
    src/*.ts|src/*.tsx|src/*.js|src/*.jsx|lib/*.ts|lib/*.tsx|lib/*.js|lib/*.jsx)
      echo "$IMPL_QUALITY_GUIDELINE"
      return 0
      ;;
  esac

  # 該当なし
  echo ""
}

# additionalContext 付きで明示的に "allow" を返す
# permissionDecision を省略すると曖昧な動作になり bypass mode でもプロンプトが出る
# permissionDecision: "allow" で明示的に許可することでプロンプトを回避
emit_approve_with_context() {
  local context="$1"
  if [ -n "$context" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -nc --arg ctx "$context" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", additionalContext:$ctx}}'
    elif command -v python3 >/dev/null 2>&1; then
      ADDITIONAL_CONTEXT="$context" python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":os.environ["ADDITIONAL_CONTEXT"]}}))
'
    fi
  fi
  # 空の context の場合は何も出力しない（デフォルト動作）
}

is_path_traversal() {
  local p="$1"
  [[ "$p" == ".." ]] && return 0
  [[ "$p" == "../"* ]] && return 0
  [[ "$p" == *"/../"* ]] && return 0
  [[ "$p" == *"/.." ]] && return 0
  return 1
}

# Resolve symlinks and return the canonical (real) path.
# Falls back to the input path if realpath is unavailable or the path doesn't exist yet.
resolve_real_path() {
  local p="$1"
  local base_dir="${2:-}"

  # If relative path and base_dir given, prepend it
  if [ -n "$base_dir" ] && ! is_absolute_path "$p"; then
    p="${base_dir}/${p}"
  fi

  # Try realpath (GNU/macOS) first, then readlink -f (Linux), then Python fallback
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null && return 0
  fi
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$p" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$p" 2>/dev/null && return 0
  fi

  # Fallback: return normalized input
  echo "$p"
}

is_protected_path() {
  local p="$1"
  case "$p" in
    .git/*|*/.git/*) return 0 ;;
    secret/*|*/secret/*|secrets/*|*/secrets/*) return 0 ;;
    *.pem|*.key|*id_rsa*|*id_ed25519*|*/.ssh/*) return 0 ;;
  esac
  case "$p" in
    .env.example|.env.template|.env.sample|.env.dist|*/.env.example|*/.env.template|*/.env.sample|*/.env.dist) return 1 ;;
    .env|.env.*|*/.env|*/.env.*) return 0 ;;
  esac
  return 1
}


if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  [ -z "$FILE_PATH" ] && exit 0

  if is_path_traversal "$FILE_PATH"; then
    emit_deny "$(msg deny_path_traversal "$FILE_PATH")"
    exit 0
  fi

  # ===== Symlink bypass protection =====
  # Resolve the real path to prevent symlink-based bypasses of protected path checks.
  # Example: attacker creates symlink "safe.txt -> ../../.env" to bypass is_protected_path.
  RESOLVED_FILE_PATH="$(resolve_real_path "$FILE_PATH" "$CWD")"

  # If the resolved path differs from the original, re-check for path traversal
  if [ "$RESOLVED_FILE_PATH" != "$FILE_PATH" ]; then
    # Check if symlink target points to a protected path
    RESOLVED_REL_PATH="$RESOLVED_FILE_PATH"
    if [ -n "$CWD" ]; then
      RESOLVED_NORM_CWD="$(normalize_path "$CWD")"
      RESOLVED_CWD_SLASH="${RESOLVED_NORM_CWD%/}/"
      if [[ "$RESOLVED_FILE_PATH" == "$RESOLVED_CWD_SLASH"* ]]; then
        RESOLVED_REL_PATH="${RESOLVED_FILE_PATH#$RESOLVED_CWD_SLASH}"
      fi
    fi
    if is_protected_path "$RESOLVED_REL_PATH"; then
      emit_deny "$(msg deny_protected_path "$FILE_PATH -> $RESOLVED_REL_PATH")"
      exit 0
    fi
    # Check if symlink escapes project directory
    if [ -n "$CWD" ] && is_absolute_path "$RESOLVED_FILE_PATH"; then
      if ! is_path_under "$RESOLVED_FILE_PATH" "$CWD"; then
        emit_deny "$(msg deny_path_traversal "$FILE_PATH -> $RESOLVED_FILE_PATH")"
        exit 0
      fi
    fi
  fi

  # ===== Codex Mode: PM は Edit/Write 禁止（Plans.md は許可） =====
  if [ "$CODEX_MODE" = "true" ]; then
    # Plans.md の状態マーカー更新は許可（PM の正当な操作）
    # パターンを厳格化: 正確に "Plans.md" で終わる場合のみ許可
    # シンボリックリンクは拒否（セキュリティ対策）
    if [ -L "$FILE_PATH" ]; then
      emit_deny "$(msg codex_plans_symlink)"
      exit 0
    fi
    # 関数外なので local は使わない
    BASENAME_FILE="${FILE_PATH##*/}"
    if [ "$BASENAME_FILE" = "Plans.md" ]; then
      : # 許可（正確に Plans.md のみ）
    else
      emit_deny "$(msg deny_codex_mode)"
      exit 0
    fi
  fi

  # ===== Breezing-Codex Mode: 直接の Edit/Write をブロック =====
  if [ "$BREEZING_CODEX_MODE" = "true" ]; then
    if [ -L "$FILE_PATH" ]; then
      emit_deny "$(msg breezing_codex_symlink)"
      exit 0
    fi
    # 許可リスト: breezing 関連 state, review state, *.md (ドキュメント)
    # セキュリティ: ultrawork-active.json 等の制御ファイルは許可しない
    case "$FILE_PATH" in
      .claude/state/breezing*|*/.claude/state/breezing*) ;; # breezing state は許可
      .claude/state/review*|*/.claude/state/review*) ;; # review state は許可
      *.md) ;; # ドキュメントファイルは許可
      *)
        emit_deny "$(msg deny_breezing_codex_mode)"
        exit 0
        ;;
    esac
  fi

  # ===== Breezing Role Guard: Teammate のロールベースアクセス制御 =====
  if { [ -n "$SESSION_ID" ] || [ -n "$AGENT_ID" ]; } && [ -n "$CWD" ]; then
    # ロール登録 Write の検出（breezing-role-*.json への Write は登録処理）
    if try_register_breezing_role "$FILE_PATH" "$CWD" 2>/dev/null; then
      exit 0  # 登録 Write は許可
    fi

    # Reviewer: Write/Edit をブロック（.claude/state/ は許可）
    if [ "$BREEZING_ROLE" = "reviewer" ]; then
      case "$FILE_PATH" in
        .claude/state/*|*/.claude/state/*) ;; # state ファイルは許可
        *)
          emit_deny "$(msg breezing_reviewer_readonly)"
          exit 0
          ;;
      esac
    fi

    # Implementer: owns 外のファイルへの Write/Edit をブロック
    if [ "$BREEZING_ROLE" = "implementer" ] && [ -n "$BREEZING_OWNS" ] && [ "$BREEZING_OWNS" != "null" ]; then
      # .claude/state/ は常に許可
      case "$FILE_PATH" in
        .claude/state/*|*/.claude/state/*) ;; # state ファイルは許可
        *.md) ;; # ドキュメントファイルは許可
        *)
          # owns パスとのマッチング
          BREEZING_FILE_ALLOWED="false"

          # CWD からの相対パスを計算（REL_PATH はこの時点で未定義のため）
          BREEZING_REL_PATH="$FILE_PATH"
          if [ -n "$CWD" ]; then
            BREEZING_REL_PATH="${FILE_PATH#${CWD}/}"
          fi

          # jq で owns 配列を取得してマッチング
          if [ -f "${CWD}/.claude/state/breezing-session-roles.json" ]; then
            ROLE_KEY="${BREEZING_ROLE_KEY:-$SESSION_ID}"
            while IFS= read -r OWNED_PATTERN; do
              [ -z "$OWNED_PATTERN" ] && continue
              # 絶対パスでマッチング
              case "$FILE_PATH" in
                $OWNED_PATTERN*) BREEZING_FILE_ALLOWED="true"; break ;;
              esac
              # 相対パスでもマッチング
              case "$BREEZING_REL_PATH" in
                $OWNED_PATTERN*) BREEZING_FILE_ALLOWED="true"; break ;;
              esac
            done < <(jq -r --arg sid "$ROLE_KEY" '.[$sid].owns[]? // empty' \
              "${CWD}/.claude/state/breezing-session-roles.json" 2>/dev/null)
          fi

          if [ "$BREEZING_FILE_ALLOWED" = "false" ]; then
            emit_deny "$(msg breezing_owns_outside "$FILE_PATH")"
            exit 0
          fi
          ;;
      esac
    fi
  fi

  # Normalize paths for cross-platform comparison
  NORM_FILE_PATH="$(normalize_path "$FILE_PATH")"
  NORM_CWD="$(normalize_path "$CWD")"

  # If absolute and outside project cwd, ask for confirmation.
  # Supports both Unix (/path) and Windows (C:/path, C:\path) absolute paths
  if [ -n "$NORM_CWD" ] && is_absolute_path "$NORM_FILE_PATH"; then
    if ! is_path_under "$NORM_FILE_PATH" "$NORM_CWD"; then
      emit_ask "$(msg ask_write_outside_project "$FILE_PATH")"
      exit 0
    fi
  fi

  # Normalize to relative when possible for pattern matching.
  REL_PATH="$NORM_FILE_PATH"
  if [ -n "$NORM_CWD" ] && is_path_under "$NORM_FILE_PATH" "$NORM_CWD"; then
    # Remove the CWD prefix to get relative path
    # 関数外なので local は使わない
    CWD_WITH_SLASH="${NORM_CWD%/}/"
    if [[ "$NORM_FILE_PATH" == "$CWD_WITH_SLASH"* ]]; then
      REL_PATH="${NORM_FILE_PATH#$CWD_WITH_SLASH}"
    fi
  fi

  if is_protected_path "$REL_PATH"; then
    emit_deny "$(msg deny_protected_path "$REL_PATH")"
    exit 0
  fi

  # ===== LSP/Skills ゲート (Phase0+) =====
  STATE_DIR=".claude/state"
  SESSION_FILE="$STATE_DIR/session.json"
  TOOLING_POLICY_FILE="$STATE_DIR/tooling-policy.json"
  SKILLS_POLICY_FILE="$STATE_DIR/skills-policy.json"
  SKILLS_CONFIG_FILE="$STATE_DIR/skills-config.json"
  SESSION_SKILLS_USED_FILE="$STATE_DIR/session-skills-used.json"

  # デフォルト除外パターン（policy file がなくても適用）
  is_default_excluded() {
    local path="$1"
    # .md, .txt, .json ファイルは常に除外（ドキュメント・設定ファイル）
    case "$path" in
      *.md|*.txt|*.json) return 0 ;;
    esac
    # .claude/ 配下は常に除外
    case "$path" in
      .claude/*) return 0 ;;
    esac
    # docs/, templates/, benchmarks/ は常に除外
    case "$path" in
      docs/*|templates/*|benchmarks/*) return 0 ;;
    esac
    return 1
  }

  # 除外パスチェック関数
  is_excluded_path() {
    local path="$1"
    local policy_file="$2"

    # まずデフォルト除外をチェック
    is_default_excluded "$path" && return 0

    # policy file がなければデフォルトのみで判定終了
    [ ! -f "$policy_file" ] && return 1

    if command -v jq >/dev/null 2>&1; then
      # skills_gate.exclude_paths をチェック
      local exclude_paths
      exclude_paths=$(jq -r '.skills_gate.exclude_paths[]? // empty' "$policy_file" 2>/dev/null)

      while IFS= read -r pattern; do
        [ -z "$pattern" ] && continue
        case "$path" in
          $pattern*) return 0 ;;
        esac
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

  # ===== Skills Gate: セッション単位でスキル使用をチェック =====
  # skills-config.json が存在し、enabled=true の場合のみゲートを適用
  if [ -f "$SKILLS_CONFIG_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
      SKILLS_GATE_ACTIVE=$(jq -r '.enabled // false' "$SKILLS_CONFIG_FILE" 2>/dev/null || echo "false")
      
      if [ "$SKILLS_GATE_ACTIVE" = "true" ]; then
        # 除外パスチェック
        if is_excluded_path "$REL_PATH" "$SKILLS_POLICY_FILE"; then
          : # 除外パス → スキップ
        else
          # session-skills-used.json をチェック
          SKILL_USED_THIS_SESSION="false"
          if [ -f "$SESSION_SKILLS_USED_FILE" ]; then
            USED_COUNT=$(jq -r '.used | length' "$SESSION_SKILLS_USED_FILE" 2>/dev/null || echo "0")
            if [ "$USED_COUNT" -gt 0 ]; then
              SKILL_USED_THIS_SESSION="true"
            fi
          fi
          
          if [ "$SKILL_USED_THIS_SESSION" = "false" ]; then
            # スキル未使用 → ブロック
            AVAILABLE_SKILLS=$(jq -r '.skills // [] | join(", ")' "$SKILLS_CONFIG_FILE" 2>/dev/null || echo "impl, harness-review")
            DENY_MSG="$(msg skills_gate "$AVAILABLE_SKILLS")"
            emit_deny "$DENY_MSG"
            exit 0
          fi
        fi
      fi
    fi
  fi

  # ===== LSP Gate: セマンティック変更時にLSP使用を推奨 =====
  if [ -f "$SESSION_FILE" ] && [ -f "$TOOLING_POLICY_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
      CURRENT_PROMPT_SEQ=$(jq -r '.prompt_seq // 0' "$SESSION_FILE" 2>/dev/null || echo 0)
      INTENT=$(jq -r '.intent // "literal"' "$SESSION_FILE" 2>/dev/null || echo "literal")
      LSP_AVAILABLE=$(jq -r '.lsp.available // false' "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)
      LSP_LAST_USED_SEQ=$(jq -r '.lsp.last_used_prompt_seq // 0' "$TOOLING_POLICY_FILE" 2>/dev/null || echo 0)

      FILE_EXT="${FILE_PATH##*.}"
      LSP_AVAILABLE_FOR_EXT=$(jq -r ".lsp.available_by_ext[\"$FILE_EXT\"] // false" "$TOOLING_POLICY_FILE" 2>/dev/null || echo false)

      if [ "$INTENT" = "semantic" ] && [ "$LSP_AVAILABLE" = "true" ] && [ "$LSP_AVAILABLE_FOR_EXT" = "true" ]; then
        if [ "$LSP_LAST_USED_SEQ" != "$CURRENT_PROMPT_SEQ" ]; then
          DENY_MSG="$(msg lsp_gate)"
          emit_deny "$DENY_MSG"
          exit 0
        fi
      fi
    fi
  fi

  # ===== additionalContext 出力 (Claude Code v2.1.9+) =====
  # すべてのガードを通過した場合、ファイルパスに応じたガイドラインを返す
  GUIDELINE="$(get_guideline_for_path "$REL_PATH")"
  if [ -n "$GUIDELINE" ]; then
    emit_approve_with_context "$GUIDELINE"
  fi

  exit 0
fi


if [ "$TOOL_NAME" = "Bash" ]; then
  [ -z "$COMMAND" ] && exit 0

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])sudo([[:space:]]|$)'; then
    emit_deny "$(msg deny_sudo)"
    exit 0
  fi

  # ===== Breezing Role Guard: Bash コマンド制限 =====
  if [ -n "$BREEZING_ROLE" ]; then
    # Reviewer: 書き込み系 Bash コマンドをブロック
    if [ "$BREEZING_ROLE" = "reviewer" ]; then
      # 読み取り専用コマンド（cat, grep, ls, git status/diff/log, echo）は許可
      # 書き込み系（リダイレクト、sed -i、tee、mv、cp、rm、git commit/push）はブロック
      # 2>&1（stderr→stdout）は読み取り安全なので除外
      BREEZING_SANITIZED_CMD=$(echo "$COMMAND" | sed 's/2>&1//g; s/>&2//g')
      if echo "$BREEZING_SANITIZED_CMD" | grep -Eq '(>|>>|2>|&>|(^|[[:space:]])tee([[:space:]]|$)|sed[[:space:]]+-i)'; then
        emit_deny "$(msg breezing_reviewer_bash_write)"
        exit 0
      fi
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])(mv|cp|rm|mkdir|touch)[[:space:]]'; then
        emit_deny "$(msg breezing_reviewer_file_ops)"
        exit 0
      fi
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+(commit|push|add|checkout|reset|rebase|merge|cherry-pick)([[:space:]]|$)'; then
        emit_deny "$(msg breezing_reviewer_git_mutation)"
        exit 0
      fi
    fi

    # Implementer: git commit をブロック（コミットは Lead のみ）
    if [ "$BREEZING_ROLE" = "implementer" ]; then
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
        emit_deny "$(msg breezing_implementer_git_commit)"
        exit 0
      fi
      if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
        emit_deny "$(msg breezing_implementer_git_push)"
        exit 0
      fi
    fi
  fi

  # ===== Breezing-Codex Mode: Bash での書き込み系コマンドを制限 =====
  if [ "$BREEZING_CODEX_MODE" = "true" ]; then
    # リダイレクト・インプレース編集をブロック（2>&1 は読み取り安全なので除外）
    BREEZING_CODEX_SANITIZED_CMD=$(echo "$COMMAND" | sed 's/2>&1//g; s/>&2//g')
    if echo "$BREEZING_CODEX_SANITIZED_CMD" | grep -Eq '(>|>>|2>|&>|(^|[[:space:]])tee([[:space:]]|$)|sed[[:space:]]+-i|awk[[:space:]]+-i[[:space:]]+inplace)'; then
      emit_deny "$(msg deny_breezing_codex_mode)"
      exit 0
    fi
    # ファイル操作コマンドをブロック
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])(mv|cp|rm|mkdir|touch)[[:space:]]'; then
      emit_deny "$(msg breezing_codex_file_ops)"
      exit 0
    fi
    # git 変更コマンドをブロック
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+(commit|push|add|checkout|reset|rebase|merge|cherry-pick|apply|am|switch|restore|stash|pull|clean|rm|mv|submodule)([[:space:]]|$)'; then
      emit_deny "$(msg breezing_codex_git_mutation)"
      exit 0
    fi
  fi

  # ===== Codex Mode: PM は Bash での書き込み系コマンドも制限 =====
  if [ "$CODEX_MODE" = "true" ]; then
    # 書き込み系パターンを検出
    # - リダイレクト: >, >>, 2>, &>
    # - tee コマンド
    # - sed -i（in-place 編集）
    # - awk -i inplace
    # 注意: 読み取り専用コマンド（cat, grep, ls, git status 等）は許可
    # 注意: rm は後の rm -rf ホワイトリストで処理するためここでは除外
    # 2>&1（stderr→stdout）は読み取り安全なので除外
    CODEX_SANITIZED_CMD=$(echo "$COMMAND" | sed 's/2>&1//g; s/>&2//g')
    if echo "$CODEX_SANITIZED_CMD" | grep -Eq '(>|>>|2>|&>|(^|[[:space:]])tee([[:space:]]|$)|sed[[:space:]]+-i|awk[[:space:]]+-i[[:space:]]+inplace)'; then
      emit_deny "$(msg deny_codex_mode)"
      exit 0
    fi
    # mv, cp は確認を求める（ask）
    # rm は後の rm -rf ホワイトリストで処理（順序問題を回避）
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])(mv|cp)[[:space:]]'; then
      emit_ask "$(msg codex_ask_file_ops)"
      exit 0
    fi
  fi

  # ===== Commit Guard: レビュー完了前のコミットをブロック =====
  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    REVIEW_STATE_FILE=".claude/state/review-approved.json"
    REVIEW_RESULT_FILE=".claude/state/review-result.json"
    COMMIT_GUARD_ENABLED="true"

    # 設定ファイルで無効化されているかチェック
    CONFIG_FILE=".claude-code-harness.config.yaml"
    if [ -f "$CONFIG_FILE" ] && command -v grep >/dev/null 2>&1; then
      if grep -q "commit_guard:[[:space:]]*false" "$CONFIG_FILE" 2>/dev/null; then
        COMMIT_GUARD_ENABLED="false"
      fi
    fi

    if [ "$COMMIT_GUARD_ENABLED" = "true" ]; then
      # Bookkeeping-only commits (VERSION / .claude-plugin/plugin.json /
      # harness.toml / CHANGELOG.md) are release metadata, not reviewed work.
      # Exempt them only when the command is a pure git commit and the already
      # staged index contains only those files.
      BOOKKEEPING_ONLY="false"
      if echo "$COMMAND" | grep -Eq '(^|[[:space:]])git[[:space:]]+(add|restore|reset|rm)([[:space:]]|$)' \
         || echo "$COMMAND" | grep -Eq '(&&|\|\||\;|^\||[[:space:]]\|[[:space:]])'; then
        BOOKKEEPING_ONLY="false"
      elif echo "$COMMAND" | grep -Eq '(^|[[:space:]])git[[:space:]]+commit[[:space:]]+([^|&;]*[[:space:]])?(-[a-zA-Z]*a[a-zA-Z]*|--all|--include(=[^[:space:]]*)?|--only|--)([[:space:]]|$)' \
         || echo "$COMMAND" | grep -Eq '(^|[[:space:]])git[[:space:]]+commit[[:space:]]+[^-[:space:]]' \
         || echo "$COMMAND" | grep -Eq -e '-m[[:space:]]+"[^"]*"[[:space:]]+[^-[:space:]]' -e "-m[[:space:]]+'[^']*'[[:space:]]+[^-[:space:]]"; then
        BOOKKEEPING_ONLY="false"
      elif command -v git >/dev/null 2>&1; then
        PATHSPEC_SUSPECT="false"
        case "$COMMAND" in
          *$'\n'*|*'$('*) PATHSPEC_SUSPECT="true" ;;
          *)
            if TOKENS=$(printf '%s' "$COMMAND" | xargs -n1 printf '%s\n' 2>/dev/null); then
              SKIP_NEXT="false"; SEEN_COMMIT="false"
              while IFS= read -r t; do
                [ -z "$t" ] && continue
                if [ "$SKIP_NEXT" = "true" ]; then SKIP_NEXT="false"; continue; fi
                if [ "$SEEN_COMMIT" != "true" ]; then
                  [ "$t" = "commit" ] && SEEN_COMMIT="true"
                  continue
                fi
                case "$t" in
                  -m|--message|-F|--file|-c|-C|--reuse-message|--reedit-message|--author|--date|--cleanup|-t|--template|--trailer) SKIP_NEXT="true" ;;
                  --message=*|--file=*|--author=*|--date=*|--cleanup=*|--template=*|--trailer=*|--fixup=*|--squash=*|--gpg-sign=*) : ;;
                  --pathspec-from-file*|--|--patch|--interactive) PATHSPEC_SUSPECT="true"; break ;;
                  -*p*) PATHSPEC_SUSPECT="true"; break ;;
                  --*) : ;;
                  -*) : ;;
                  *) PATHSPEC_SUSPECT="true"; break ;;
                esac
              done <<< "$TOKENS"
            else
              PATHSPEC_SUSPECT="true"
            fi
            ;;
        esac
        if [ "$PATHSPEC_SUSPECT" = "false" ]; then
          STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
          if [ -n "$STAGED_FILES" ]; then
            BOOKKEEPING_ONLY="true"
            while IFS= read -r f; do
              [ -z "$f" ] && continue
              case "$f" in
                "VERSION"|".claude-plugin/plugin.json"|"harness.toml"|"CHANGELOG.md") ;;
                *) BOOKKEEPING_ONLY="false"; break ;;
              esac
            done <<< "$STAGED_FILES"
          fi
        fi
      fi

      if [ "$BOOKKEEPING_ONLY" = "true" ]; then
        mkdir -p .claude/state 2>/dev/null || true
        printf '{"ts":"%s","scope":"pretool-commit-guard","reason":"bookkeeping-only","approval_required":false}\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          >> ".claude/state/commit-cleanup-audit.jsonl" 2>/dev/null || true
      else
        # レビュー承認状態をチェック
        REVIEW_APPROVED="false"
        if command -v jq >/dev/null 2>&1; then
          if [ -f "$REVIEW_RESULT_FILE" ]; then
            RESULT_VERDICT=$(jq -r '.verdict // empty' "$REVIEW_RESULT_FILE" 2>/dev/null)
            if [ "$RESULT_VERDICT" = "APPROVE" ]; then
              REVIEW_APPROVED="true"
            fi
          fi

          if [ "$REVIEW_APPROVED" = "false" ] && [ -f "$REVIEW_STATE_FILE" ]; then
            APPROVED_AT=$(jq -r '.approved_at // empty' "$REVIEW_STATE_FILE" 2>/dev/null)
            JUDGMENT=$(jq -r '.judgment // empty' "$REVIEW_STATE_FILE" 2>/dev/null)
            if [ -n "$APPROVED_AT" ] && [ "$JUDGMENT" = "APPROVE" ]; then
              REVIEW_APPROVED="true"
            fi
          fi
        fi

        if [ "$REVIEW_APPROVED" = "false" ]; then
          emit_deny "$(msg deny_git_commit_no_review)"
          exit 0
        fi

        # コミット後に承認状態をクリア（次回コミット前に再レビューを要求）
        # Note: これは PostToolUse で行うべきだが、ここでは警告のみ
      fi
    fi
  fi

  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
    # Work モード中はバイパス可能
    if [ "$WORK_MODE" = "true" ] && [ "$WORK_BYPASS_GIT_PUSH" = "true" ]; then
      : # スキップ（自動承認）
    else
      emit_ask "$(msg ask_git_push "$COMMAND")"
      exit 0
    fi
  fi

  # rm の危険な再帰削除パターンを検出
  # 注意: rm -rf / rm -r -f のみバイパス対象。それ以外のフラグ組み合わせは確認を求める
  if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]+-[a-z]*r[a-z]*[[:space:]]' || \
     echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]+--recursive'; then

    # ===== Work ホワイトリスト方式（Codex 承認済み） =====
    # デフォルト: 確認を求める
    RM_AUTO_APPROVE="false"

    # Work モードが有効で rm_rf バイパスが許可されている場合のみチェック
    if [ "$WORK_MODE" = "true" ] && [ "$WORK_BYPASS_RM_RF" = "true" ]; then

      # 0. 許可されるフラグ形式のみ（rm -rf または rm -r -f）
      # rm -rfv, rm -fr, rm --recursive など他の形式は確認を求める
      if ! echo "$COMMAND" | grep -Eq '(^|[[:space:]])rm[[:space:]]+(-rf|-r[[:space:]]+-f)[[:space:]]+'; then
        : # 確認を求める（許可されないフラグ形式）
      # 1. 危険なシェル構文を含む場合は確認（* ? $ ( ) { } ; | & < > \ `）
      elif echo "$COMMAND" | grep -Eq '[\*\?\$\(\)\{\};|&<>\\`]'; then
        : # 確認を求める
      # 2. sudo/xargs/find を含む場合は確認
      elif echo "$COMMAND" | grep -Eiq '(sudo|xargs|find)[[:space:]]'; then
        : # 確認を求める
      else
        # rm ターゲットを抽出（フラグ部分を除去）
        RM_TARGET=$(echo "$COMMAND" | sed -E 's/^.*rm[[:space:]]+(-rf|-r[[:space:]]+-f)[[:space:]]+//' | sed 's/[[:space:]].*//')

        # 3. 単一ターゲットチェック（スペースで複数指定されていないか）
        RM_TARGET_COUNT=$(echo "$COMMAND" | sed -E 's/^.*rm[[:space:]]+(-rf|-fr|-r[[:space:]]+-f|-f[[:space:]]+-r)[[:space:]]+//' | wc -w | tr -d ' ')
        if [ "$RM_TARGET_COUNT" -eq 1 ]; then

          # 4. 相対パスのみ（/ や ~ で始まらない）
          # 5. 親参照なし（.. を含まない）
          # 6. 末尾スラッシュなし
          # 7. パス区切りなし（basename のみ許可）
          # 8. . や // を含まない
          case "$RM_TARGET" in
            /*|~*|*..*)
              : # 確認を求める
              ;;
            */)
              : # 確認を求める（末尾スラッシュ）
              ;;
            *//*|*/.*)
              : # 確認を求める（// や /. を含む）
              ;;
            */*)
              : # 確認を求める（パス区切りを含む）
              ;;
            .)
              : # 確認を求める（カレントディレクトリ）
              ;;
            *)
              # 9. 保護パスチェック
              case "$RM_TARGET" in
                .git*|.env*|*secrets*|*keys*|*.pem|*.key|*id_rsa*|*id_ed25519*|.ssh*|.npmrc*|.aws*|.gitmodules*)
                  : # 確認を求める（保護パス）
                  ;;
                *)
                  # 10. ホワイトリストチェック
                  if [ -n "$CWD" ]; then
                    WORK_FILE="$CWD/.claude/state/work-active.json"
                    # 後方互換: work-active.json がなければ ultrawork-active.json を試行
                    if [ ! -f "$WORK_FILE" ]; then
                      WORK_FILE="$CWD/.claude/state/ultrawork-active.json"
                    fi
                    if [ -f "$WORK_FILE" ] && command -v jq >/dev/null 2>&1; then
                      # allowed_rm_paths からホワイトリストを取得
                      ALLOWED_PATHS=$(jq -r '.allowed_rm_paths[]? // empty' "$WORK_FILE" 2>/dev/null)
                      if [ -n "$ALLOWED_PATHS" ]; then
                        while IFS= read -r ALLOWED; do
                          if [ "$RM_TARGET" = "$ALLOWED" ]; then
                            RM_AUTO_APPROVE="true"
                            break
                          fi
                        done <<< "$ALLOWED_PATHS"
                      fi
                    fi
                  fi
                  ;;
              esac
              ;;
          esac
        fi
      fi
    fi

    # 自動承認でない場合は確認を求める
    if [ "$RM_AUTO_APPROVE" != "true" ]; then
      # Codex モード時は PM 用のメッセージを追加
      if [ "$CODEX_MODE" = "true" ]; then
        emit_ask "$(msg codex_ask_rm_rf "$COMMAND")"
      else
        emit_ask "$(msg ask_rm_rf "$COMMAND")"
      fi
      exit 0
    fi
    # else: 自動承認（何も出力せずに通過）
  fi

  # ===== Codex Mode: 単純な rm（-r なし）も確認 =====
  if [ "$CODEX_MODE" = "true" ]; then
    if echo "$COMMAND" | grep -Eiq '(^|[[:space:]])rm[[:space:]]'; then
      emit_ask "$(msg codex_ask_rm)"
      exit 0
    fi
  fi

  exit 0
fi

exit 0
