#!/bin/bash
# usage tracking hooks が stdout に record-usage ノイズを出さないことを確認

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERPROMPT_TRACK_SCRIPT="${ROOT_DIR}/scripts/userprompt-track-command.sh"
USAGE_TRACKER_SCRIPT="${ROOT_DIR}/scripts/usage-tracker.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state"

userprompt_output="$(cd "${TMP_DIR}" && printf '%s' '{"prompt":"/work 27.1.3"}' | bash "${USERPROMPT_TRACK_SCRIPT}")"
if grep -q '\[record-usage\]' <<<"${userprompt_output}"; then
  echo "userprompt-track-command stdout should not include record-usage noise"
  exit 1
fi
grep -q '{"continue":true}' <<<"${userprompt_output}" || {
  echo "userprompt-track-command should return continue JSON"
  exit 1
}

usage_output="$(cd "${TMP_DIR}" && printf '%s' '{"tool_name":"Skill","tool_input":{"skill":"claude-code-harness:memory"}}' | bash "${USAGE_TRACKER_SCRIPT}")"
if grep -q '\[record-usage\]' <<<"${usage_output}"; then
  echo "usage-tracker stdout should not include record-usage noise"
  exit 1
fi
grep -q '{"continue":true}' <<<"${usage_output}" || {
  echo "usage-tracker should return continue JSON"
  exit 1
}

echo "OK"
