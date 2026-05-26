#!/bin/bash
# Verify that usage tracking hooks do not emit record-usage noise to stdout

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USERPROMPT_TRACK_SCRIPT="${ROOT_DIR}/scripts/userprompt-track-command.sh"
USAGE_TRACKER_SCRIPT="${ROOT_DIR}/scripts/usage-tracker.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state"

userprompt_output="$(cd "${TMP_DIR}" && printf '%s' '{"prompt":"/work 27.1.3"}' | bash "${USERPROMPT_TRACK_SCRIPT}")"
if echo "${userprompt_output}" | grep -q '\[record-usage\]'; then
  echo "userprompt-track-command stdout should not include record-usage noise"
  exit 1
fi
echo "${userprompt_output}" | grep -q '{"continue":true}' || {
  echo "userprompt-track-command should return continue JSON"
  exit 1
}

usage_output="$(cd "${TMP_DIR}" && printf '%s' '{"tool_name":"Skill","tool_input":{"skill":"company-ai-harness:memory"}}' | bash "${USAGE_TRACKER_SCRIPT}")"
if echo "${usage_output}" | grep -q '\[record-usage\]'; then
  echo "usage-tracker stdout should not include record-usage noise"
  exit 1
fi
echo "${usage_output}" | grep -q '{"continue":true}' || {
  echo "usage-tracker should return continue JSON"
  exit 1
}

echo "OK"
