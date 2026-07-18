#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/scripts/pretooluse-guard.sh"
TMP_DIR="$(mktemp -d)"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "test-env-template-guardrail: FAIL: $1" >&2
  exit 1
}

guard_decision() {
  local file_path="$1"
  local tool_name="${2:-Write}"
  local payload output
  payload="$(jq -nc --arg cwd "$TMP_DIR" --arg path "$file_path" \
    --arg tool "$tool_name" \
    '{tool_name:$tool,tool_input:{file_path:$path,content:"KEY=value"},cwd:$cwd}')"
  output="$(cd "$TMP_DIR" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$GUARD" <<<"$payload")"
  if [ -z "$output" ]; then
    printf 'allow\n'
    return
  fi
  printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
}

for template in .env.example .env.template .env.sample .env.dist config/.env.example config/.env.template config/.env.sample config/.env.dist; do
  for tool_name in Write Edit; do
    decision="$(guard_decision "$template" "$tool_name")"
    [ "$decision" = "allow" ] || fail "$tool_name $template must be allowed, got $decision"
  done
done

for secret_path in .env .env.local .env.production '.env.*' .env.example.local .env.template.bak secret/.env.example secrets/.env.example .git/.env.example; do
  for tool_name in Write Edit; do
    decision="$(guard_decision "$secret_path" "$tool_name")"
    [ "$decision" = "deny" ] || fail "$tool_name $secret_path must remain denied, got $decision"
  done
done

mkdir -p "$TMP_DIR/secrets"
printf 'SECRET=value\n' > "$TMP_DIR/.env"
ln -s "$TMP_DIR/.env" "$TMP_DIR/.env.example"
ln -s "$TMP_DIR/secrets" "$TMP_DIR/config-link"

for symlink_path in .env.example config-link/.env.example; do
  for tool_name in Write Edit; do
    decision="$(guard_decision "$symlink_path" "$tool_name")"
    [ "$decision" = "deny" ] || fail "$tool_name $symlink_path symlink boundary must remain denied, got $decision"
  done
done

echo "test-env-template-guardrail: ok"
