#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for hooks in "$ROOT/hooks/hooks.json" "$ROOT/.claude-plugin/hooks.json"; do
  [ -f "$hooks" ] || { echo "missing $hooks" >&2; exit 1; }
  command_count=0
  while IFS= read -r command; do
    command_count=$((command_count + 1))
    case "$command" in
      *'${CLAUDE_PLUGIN_ROOT}/bin/harness'*)
        echo "$hooks must not bypass valid_root for CLAUDE_PLUGIN_ROOT" >&2
        exit 1
        ;;
    esac
    for required in \
      'valid_root(){' \
      '[ -x "$r/bin/harness" ]' \
      '[ -f "$r/.claude-plugin/plugin.json" ]' \
      'claude-code-harness' \
      'root="${CLAUDE_PLUGIN_ROOT:-}"; if ! valid_root "$root"'
    do
      case "$command" in
        *"$required"*) ;;
        *)
          echo "$hooks command is missing trusted-root guard: $required" >&2
          exit 1
          ;;
      esac
    done
  done < <(jq -r '.. | objects | .command? // empty | select(contains("bin/harness"))' "$hooks")

  if [ "$command_count" -eq 0 ]; then
    echo "$hooks has no harness hook commands to validate" >&2
    exit 1
  fi
done

cmp -s "$ROOT/hooks/hooks.json" "$ROOT/.claude-plugin/hooks.json" || {
  echo "dual hooks.json files differ" >&2
  exit 1
}

echo "test-hooks-trusted-root: ok"
