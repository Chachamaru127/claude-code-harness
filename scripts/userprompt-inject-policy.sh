#!/bin/bash
# userprompt-inject-policy.sh
# UserPromptSubmit時にポリシーコンテキストを注入
#
# Usage: UserPromptSubmit hook から自動実行
# Input: stdin JSON (Claude Code hooks)
# Output: JSON (hookSpecificOutput.additionalContext)

set +e

# ===== 定数 =====
STATE_DIR=".claude/state"
SESSION_FILE="${STATE_DIR}/session.json"
TOOLING_POLICY_FILE="${STATE_DIR}/tooling-policy.json"

# ===== ユーティリティ =====

# JSONから値を抽出（jq優先、なければpython3）
json_get() {
  local json="$1"
  local key="$2"
  local default="${3:-}"

  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r "$key // \"$default\"" 2>/dev/null || echo "$default"
  elif command -v python3 >/dev/null 2>&1; then
    echo "$json" | python3 -c "import json,sys; data=json.load(sys.stdin); keys='$key'.strip('.').split('.'); val=data;
for k in keys: val=val.get(k) if isinstance(val,dict) else None
print(val if val is not None else '$default')" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# JSONファイルから値を抽出
json_file_get() {
  local file="$1"
  local key="$2"
  local default="${3:-0}"

  if [ ! -f "$file" ]; then
    echo "$default"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r "$key // $default" "$file" 2>/dev/null || echo "$default"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import json
with open('$file', 'r') as f:
    data = json.load(f)
keys = '$key'.strip('.').split('.')
val = data
for k in keys:
    val = val.get(k) if isinstance(val, dict) else None
    if val is None:
        break
print(val if val is not None else '$default')" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# JSONファイルを更新（原子的）
json_file_update() {
  local file="$1"
  local updates="$2"  # jq update式（例: ".prompt_seq = 1 | .intent = \"semantic\""）

  [ ! -f "$file" ] && return 1

  local temp_file
  temp_file=$(mktemp)

  if command -v jq >/dev/null 2>&1; then
    jq "$updates" "$file" > "$temp_file" && mv "$temp_file" "$file"
  elif command -v python3 >/dev/null 2>&1; then
    # Python fallback（簡易版）
    python3 -c "
import json
with open('$file', 'r') as f:
    data = json.load(f)
# 簡易的な更新（prompt_seqのインクリメントのみ対応）
data['prompt_seq'] = data.get('prompt_seq', 0) + 1
with open('$temp_file', 'w') as f:
    json.dump(data, f)
" && mv "$temp_file" "$file"
  fi
}

# ===== メイン処理 =====

# stateディレクトリ確認
[ ! -d "$STATE_DIR" ] && exit 0

# stdin から JSON 入力を読み取る
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

[ -z "$INPUT" ] && exit 0

# prompt を抽出（必要に応じて）
PROMPT=$(json_get "$INPUT" ".prompt" "")

# prompt_seq をインクリメント
CURRENT_PROMPT_SEQ=$(json_file_get "$SESSION_FILE" ".prompt_seq" "0")
NEW_PROMPT_SEQ=$((CURRENT_PROMPT_SEQ + 1))

# semantic/literal判定（キーワードベース）
INTENT="literal"
SEMANTIC_KEYWORDS="定義|参照|rename|診断|リファクタ|変更|修正|実装|追加|削除|移動|シンボル|関数|クラス|メソッド|変数"
if echo "$PROMPT" | grep -qiE "$SEMANTIC_KEYWORDS"; then
  INTENT="semantic"
fi

# LSP可用性の確認
LSP_AVAILABLE=$(json_file_get "$TOOLING_POLICY_FILE" ".lsp.available" "false")

# session.json を更新（prompt_seq、intent）
if command -v jq >/dev/null 2>&1; then
  json_file_update "$SESSION_FILE" ".prompt_seq = $NEW_PROMPT_SEQ | .intent = \"$INTENT\""
else
  # jqがない場合はpython fallbackで最小限の更新
  if command -v python3 >/dev/null 2>&1; then
    temp_file=$(mktemp)
    python3 <<PY > "$temp_file"
import json
with open("$SESSION_FILE", "r") as f:
    data = json.load(f)
data["prompt_seq"] = $NEW_PROMPT_SEQ
data["intent"] = "$INTENT"
print(json.dumps(data, indent=2))
PY
    mv "$temp_file" "$SESSION_FILE"
  fi
fi

# tooling-policy.json の LSP使用フラグをリセット（新しいプロンプトなので）
if [ -f "$TOOLING_POLICY_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    temp_file=$(mktemp)
    if [ "$INTENT" = "semantic" ]; then
      # semantic時: LSPフラグリセット + Skills decision required = true
      jq '.lsp.used_since_last_prompt = false | .skills.decision_required = true' "$TOOLING_POLICY_FILE" > "$temp_file" && mv "$temp_file" "$TOOLING_POLICY_FILE"
    else
      # literal時: LSPフラグのみリセット、Skills decision = false
      jq '.lsp.used_since_last_prompt = false | .skills.decision_required = false' "$TOOLING_POLICY_FILE" > "$temp_file" && mv "$temp_file" "$TOOLING_POLICY_FILE"
    fi
  fi
fi

# 注入コンテキストの生成
INJECTION=""

if [ "$INTENT" = "semantic" ]; then
  if [ "$LSP_AVAILABLE" = "true" ]; then
    # LSP導入済み：LSPツール使用を推奨
    INJECTION="
## LSP/Skills Policy (Enforced)

**Intent**: semantic (definition/reference/rename/diagnostics required)
**LSP Status**: Available (official LSP plugin installed)

Before modifying code (Write/Edit), you MUST:
1. Use LSP tools (definition, references, rename, diagnostics) to understand code structure
2. Evaluate available Skills and update \`.claude/state/skills-decision.json\` with your decision
3. Analyze impact of changes before editing

If you attempt Write/Edit without using LSP first, your request will be denied with guidance on which LSP tool to use next.
If you attempt to use a Skill without updating skills-decision.json, your request will be denied.

**This is enforced by PreToolUse hooks**. Do not skip LSP analysis or Skills evaluation.
"
  else
    # LSP未導入：推奨のみ（deny しない）
    INJECTION="
## LSP/Skills Policy (Recommendation)

**Intent**: semantic (code analysis recommended)
**LSP Status**: Not available (no official LSP plugin detected)

Recommendation:
- For better code understanding, consider installing official LSP plugin via \`/lsp-setup\`
- Evaluate available Skills and update \`.claude/state/skills-decision.json\` if applicable
- You can proceed without LSP, but accuracy may be lower

To install LSP: run \`/lsp-setup\` command
"
  fi
fi

# JSON出力（Claude Code UserPromptSubmit hook形式）
# hookEventName は hookSpecificOutput の中に配置
if [ -n "$INJECTION" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg ctx "$INJECTION" \
      '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$ctx}}'
  else
    # jq無しの場合は最小限の出力
    echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}'
  fi
else
  # 注入不要な場合
  echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit"}}'
fi

exit 0
