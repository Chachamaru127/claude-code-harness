#!/usr/bin/env bash
#
# Verify Phase 55.1.2 locale resolution for shell hooks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_UTILS="$PROJECT_ROOT/scripts/config-utils.sh"
PRETOOLUSE_GUARD="$PROJECT_ROOT/scripts/pretooluse-guard.sh"
USERPROMPT_INJECT_POLICY="$PROJECT_ROOT/scripts/userprompt-inject-policy.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for i18n locale resolver tests" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_locale() {
  local config_file="$1"
  local env_locale="${2:-__unset__}"

  if [ "$env_locale" = "__unset__" ]; then
    env -u CLAUDE_CODE_HARNESS_LANG CONFIG_FILE="$config_file" bash -c \
      'source "$1"; get_harness_locale' _ "$CONFIG_UTILS"
  else
    CONFIG_FILE="$config_file" CLAUDE_CODE_HARNESS_LANG="$env_locale" bash -c \
      'source "$1"; get_harness_locale' _ "$CONFIG_UTILS"
  fi
}

guard_decision() {
  local cwd="$1"
  local env_locale="${2:-__unset__}"
  local payload="$3"

  if [ "$env_locale" = "__unset__" ]; then
    (cd "$cwd" && env -u CLAUDE_CODE_HARNESS_LANG bash "$PRETOOLUSE_GUARD" <<< "$payload")
  else
    (cd "$cwd" && CLAUDE_CODE_HARNESS_LANG="$env_locale" bash "$PRETOOLUSE_GUARD" <<< "$payload")
  fi
}

userprompt_policy() {
  local cwd="$1"
  local env_locale="${2:-__unset__}"
  local payload="$3"

  if [ "$env_locale" = "__unset__" ]; then
    (cd "$cwd" && env -u CLAUDE_CODE_HARNESS_LANG bash "$USERPROMPT_INJECT_POLICY" <<< "$payload")
  else
    (cd "$cwd" && CLAUDE_CODE_HARNESS_LANG="$env_locale" bash "$USERPROMPT_INJECT_POLICY" <<< "$payload")
  fi
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $label: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

missing_config="$tmpdir/missing.yaml"
assert_eq "en" "$(run_locale "$missing_config")" "missing config defaults to en"
assert_eq "ja" "$(run_locale "$missing_config" "ja")" "env ja is accepted"
assert_eq "en" "$(run_locale "$missing_config" "fr")" "invalid env locale normalizes to en"

config_ja="$tmpdir/config-ja.yaml"
cat > "$config_ja" <<'YAML'
i18n:
  language: ja
YAML
assert_eq "ja" "$(run_locale "$config_ja" "en")" "config ja has priority over env en"

config_invalid="$tmpdir/config-invalid.yaml"
cat > "$config_invalid" <<'YAML'
i18n:
  language: fr
YAML
assert_eq "en" "$(run_locale "$config_invalid")" "invalid config locale normalizes to en"

hook_project="$tmpdir/hook-project"
mkdir -p "$hook_project"

sudo_payload="$(jq -nc --arg cwd "$hook_project" '{tool_name:"Bash", tool_input:{command:"sudo whoami"}, cwd:$cwd}')"
default_sudo="$(guard_decision "$hook_project" "__unset__" "$sudo_payload")"
assert_eq "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$default_sudo")" "sudo is still denied by default"
if ! jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$default_sudo" | grep -q '^Blocked:'; then
  echo "FAIL: default pretooluse message must be English" >&2
  echo "$default_sudo" >&2
  exit 1
fi

ja_sudo="$(guard_decision "$hook_project" "ja" "$sudo_payload")"
assert_eq "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$ja_sudo")" "sudo is denied with ja env"
if ! jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$ja_sudo" | grep -q '^ブロック:'; then
  echo "FAIL: CLAUDE_CODE_HARNESS_LANG=ja must preserve Japanese message" >&2
  echo "$ja_sudo" >&2
  exit 1
fi

cat > "$hook_project/.claude-code-harness.config.yaml" <<'YAML'
i18n:
  language: ja
YAML
config_sudo="$(guard_decision "$hook_project" "en" "$sudo_payload")"
if ! jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$config_sudo" | grep -q '^ブロック:'; then
  echo "FAIL: config ja must have priority over env en in pretooluse guard" >&2
  echo "$config_sudo" >&2
  exit 1
fi

rm_payload="$(jq -nc --arg cwd "$hook_project" '{tool_name:"Bash", tool_input:{command:"rm -rf build"}, cwd:$cwd}')"
rm_en="$(guard_decision "$hook_project" "en" "$rm_payload")"
rm_ja="$(guard_decision "$hook_project" "ja" "$rm_payload")"
assert_eq "ask" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$rm_en")" "rm -rf asks in en"
assert_eq "ask" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$rm_ja")" "rm -rf asks in ja"

write_payload="$(jq -nc --arg cwd "$hook_project" '{tool_name:"Write", tool_input:{file_path:".env"}, cwd:$cwd}')"
write_en="$(guard_decision "$hook_project" "en" "$write_payload")"
write_ja="$(guard_decision "$hook_project" "ja" "$write_payload")"
assert_eq "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$write_en")" ".env write denied in en"
assert_eq "deny" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$write_ja")" ".env write denied in ja"

runtime_project="$tmpdir/runtime-project"
mkdir -p "$runtime_project/src"
runtime_project="$(cd "$runtime_project" && pwd -P)"

guideline_payload="$(jq -nc --arg cwd "$runtime_project" '{tool_name:"Write", tool_input:{file_path:"src/main.ts"}, cwd:$cwd}')"
guideline_en="$(guard_decision "$runtime_project" "__unset__" "$guideline_payload")"
assert_eq "PreToolUse" "$(jq -r '.hookSpecificOutput.hookEventName' <<< "$guideline_en")" "pretooluse guideline hook event shape"
assert_eq "allow" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$guideline_en")" "pretooluse guideline keeps allow decision"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$guideline_en" | grep -q 'Implementation Quality Guideline'; then
  echo "FAIL: default implementation guideline must be English" >&2
  echo "$guideline_en" >&2
  exit 1
fi

guideline_ja="$(guard_decision "$runtime_project" "ja" "$guideline_payload")"
assert_eq "allow" "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$guideline_ja")" "pretooluse guideline keeps allow decision in ja"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$guideline_ja" | grep -q '実装品質ガイドライン'; then
  echo "FAIL: CLAUDE_CODE_HARNESS_LANG=ja must preserve Japanese implementation guideline" >&2
  echo "$guideline_ja" >&2
  exit 1
fi

make_userprompt_project() {
  local dir="$1"
  mkdir -p "$dir/.claude/state"
  printf '{"prompt_seq":0,"intent":"literal"}\n' > "$dir/.claude/state/session.json"
  printf '{"lsp":{"available":false},"skills":{}}\n' > "$dir/.claude/state/tooling-policy.json"
  printf '{"review_status":"pending"}\n' > "$dir/.claude/state/work-active.json"
}

make_userprompt_policy_only_project() {
  local dir="$1"
  mkdir -p "$dir/.claude/state"
  printf '{"prompt_seq":0,"intent":"literal"}\n' > "$dir/.claude/state/session.json"
  printf '{"lsp":{"available":false},"skills":{}}\n' > "$dir/.claude/state/tooling-policy.json"
}

userprompt_en_project="$tmpdir/userprompt-en"
make_userprompt_project "$userprompt_en_project"
prompt_payload="$(jq -nc '{prompt:"hello"}')"
userprompt_en="$(userprompt_policy "$userprompt_en_project" "__unset__" "$prompt_payload")"
assert_eq "UserPromptSubmit" "$(jq -r '.hookSpecificOutput.hookEventName' <<< "$userprompt_en")" "userprompt hook event shape"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_en" | grep -q 'Work Mode Still Active'; then
  echo "FAIL: default userprompt work warning must be English" >&2
  echo "$userprompt_en" >&2
  exit 1
fi
if jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_en" | grep -q 'work モード継続中'; then
  echo "FAIL: default userprompt work warning should not be Japanese" >&2
  echo "$userprompt_en" >&2
  exit 1
fi
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_en" | grep -q 'Response Language: English'; then
  echo "FAIL: default userprompt must inject the English response-language directive" >&2
  echo "$userprompt_en" >&2
  exit 1
fi

userprompt_ja_project="$tmpdir/userprompt-ja"
make_userprompt_project "$userprompt_ja_project"
userprompt_ja="$(userprompt_policy "$userprompt_ja_project" "ja" "$prompt_payload")"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_ja" | grep -q 'work モード継続中'; then
  echo "FAIL: CLAUDE_CODE_HARNESS_LANG=ja must preserve Japanese userprompt work warning" >&2
  echo "$userprompt_ja" >&2
  exit 1
fi
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_ja" | grep -q '応答言語: 日本語'; then
  echo "FAIL: CLAUDE_CODE_HARNESS_LANG=ja must inject the Japanese response-language directive" >&2
  echo "$userprompt_ja" >&2
  exit 1
fi

userprompt_config_project="$tmpdir/userprompt-config-ja"
make_userprompt_project "$userprompt_config_project"
cat > "$userprompt_config_project/.claude-code-harness.config.yaml" <<'YAML'
i18n:
  language: ja
YAML
userprompt_config="$(userprompt_policy "$userprompt_config_project" "en" "$prompt_payload")"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_config" | grep -q 'work モード継続中'; then
  echo "FAIL: config ja must have priority over env en in userprompt policy" >&2
  echo "$userprompt_config" >&2
  exit 1
fi

userprompt_semantic_ja_project="$tmpdir/userprompt-semantic-ja"
make_userprompt_policy_only_project "$userprompt_semantic_ja_project"
semantic_payload="$(jq -nc '{prompt:"実装して"}')"
userprompt_semantic_ja="$(userprompt_policy "$userprompt_semantic_ja_project" "ja" "$semantic_payload")"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_semantic_ja" | grep -q 'LSP/Skills Policy（推奨）'; then
  echo "FAIL: CLAUDE_CODE_HARNESS_LANG=ja must localize userprompt LSP recommendation" >&2
  echo "$userprompt_semantic_ja" >&2
  exit 1
fi
if jq -r '.hookSpecificOutput.additionalContext' <<< "$userprompt_semantic_ja" | grep -q 'LSP Status: Not available'; then
  echo "FAIL: ja userprompt LSP recommendation should not remain English" >&2
  echo "$userprompt_semantic_ja" >&2
  exit 1
fi

echo "✓ shell locale resolver and pretooluse guard locale behavior are coherent"
