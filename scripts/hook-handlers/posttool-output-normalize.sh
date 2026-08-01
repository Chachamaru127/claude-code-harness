#!/bin/bash
# posttool-output-normalize.sh
# Phase 62.2.1: PostToolUse.updatedToolOutput governance handler (opt-in)
#
# Claude Code 2.1.121 で PostToolUse hook が hookSpecificOutput.updatedToolOutput
# を返せるようになった。この handler は **opt-in** で動作し、許可された 3 用途
# (redaction / compaction / machine-readable normalization) のみに使う。
# 元 output と更新後 output は append-only で audit ledger に記録する。
#
# **opt-in 方法**: .claude-plugin/hooks.json または .claude/settings.local.json で
#   "PostToolUse" matcher にこのスクリプトを追加する。デフォルトでは無効。
#
# **禁止用途** (Phase 58.2.2 governance):
#   - レビュー / テスト出力の改ざん
#   - JSON 契約 tool の output に人間向け説明を mix する
#   - エラー証拠の隠蔽
#
# Input:  stdin JSON ({ tool_name, tool_input, tool_response, ... })
# Output: stdout JSON ({ hookSpecificOutput: { updatedToolOutput: "..." } })
#         または空 (= no-op)
# Audit:  .claude/state/output-audit.jsonl に before/after を append-only 記録

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_DIR="${PROJECT_ROOT}/.claude/state"
AUDIT_LOG="${STATE_DIR}/output-audit.jsonl"

mkdir -p "${STATE_DIR}"

INPUT="$(cat)"

if [ -z "${INPUT}" ]; then
  exit 0
fi

# Allowlist of normalization rules (opt-in matchers).
# Each rule: { matcher: tool_name regex, action: redact|compact|normalize }
TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
TOOL_OUTPUT="$(printf '%s' "${INPUT}" | jq -r '.tool_response.output // .tool_response.stdout // ""' 2>/dev/null || echo "")"

# Default policy: no-op (silent passthrough). The handler only acts when explicitly
# enabled via env HARNESS_OUTPUT_GOVERNANCE_ENABLE=1 AND the matcher fires.
if [ "${HARNESS_OUTPUT_GOVERNANCE_ENABLE:-0}" != "1" ]; then
  exit 0
fi

# Example normalization: redact obvious secrets from output.
# Only operates on tool_response.output; never modifies tool_response.stderr or
# JSON-contract tool outputs (those tools list themselves in JSON_CONTRACT_TOOLS).
JSON_CONTRACT_TOOLS_REGEX='^(Read|Grep|Glob|TodoWrite|Bash)$'
if grep -Eq "${JSON_CONTRACT_TOOLS_REGEX}" <<<"${TOOL_NAME}"; then
  # Skip JSON-contract tools to avoid mixing human-readable text into structured output.
  exit 0
fi

NORMALIZED_OUTPUT="${TOOL_OUTPUT}"
APPLIED_RULE=""

# Rule 1: redact OpenAI / Anthropic API key patterns (defense-in-depth).
if grep -Eq 'sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}' <<<"${TOOL_OUTPUT}"; then
  NORMALIZED_OUTPUT="$(printf '%s' "${TOOL_OUTPUT}" | sed -E 's/sk-[A-Za-z0-9]{20,}/sk-REDACTED/g; s/sk-ant-[A-Za-z0-9-]{20,}/sk-ant-REDACTED/g')"
  APPLIED_RULE="redact-api-key"
fi

# If no rule applied, exit silently.
if [ -z "${APPLIED_RULE}" ]; then
  exit 0
fi

# Append audit record (before / after / rule / timestamp).
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
AUDIT_RECORD="$(jq -nc \
  --arg timestamp "${TIMESTAMP}" \
  --arg tool "${TOOL_NAME}" \
  --arg rule "${APPLIED_RULE}" \
  --arg before "${TOOL_OUTPUT}" \
  --arg after "${NORMALIZED_OUTPUT}" \
  '{timestamp:$timestamp, tool:$tool, rule:$rule, before:$before, after:$after}')"

printf '%s\n' "${AUDIT_RECORD}" >> "${AUDIT_LOG}"

# Emit hookSpecificOutput.
jq -nc \
  --arg output "${NORMALIZED_OUTPUT}" \
  '{hookSpecificOutput: {updatedToolOutput: $output}}'
