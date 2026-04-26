#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/.claude/state"
cp "${ROOT_DIR}/scripts/statusline-harness.sh" "${TMP_DIR}/statusline-harness.sh"

rich_input='{"model":{"display_name":"Claude"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":1.25,"total_duration_ms":9000},"output_style":{"name":"default"},"agent":{"name":"worker"},"worktree":{"name":"worker-wt"},"effort":{"level":"high"},"thinking":{"enabled":true}}'
sparse_input='{"model":{"display_name":"Claude"},"context_window":{"used_percentage":18},"cost":{"total_cost_usd":0.4,"total_duration_ms":3000},"output_style":{"name":"default"}}'

rich_output="$(
  cd "${TMP_DIR}" &&
  printf '%s' "${rich_input}" | bash "${TMP_DIR}/statusline-harness.sh"
)"

printf '%s' "${rich_output}" | grep -q 'effort:high' || {
  echo "statusline output must show effort:high when effort.level is present"
  exit 1
}

printf '%s' "${rich_output}" | grep -q 'think:on' || {
  echo "statusline output must show think:on when thinking.enabled is true"
  exit 1
}

sparse_output="$(
  cd "${TMP_DIR}" &&
  printf '%s' "${sparse_input}" | bash "${TMP_DIR}/statusline-harness.sh"
)"

if printf '%s' "${sparse_output}" | grep -q 'effort:'; then
  echo "statusline output must stay quiet when effort.level is absent"
  exit 1
fi

if printf '%s' "${sparse_output}" | grep -q 'think:'; then
  echo "statusline output must stay quiet when thinking.enabled is absent"
  exit 1
fi

telemetry_file="${TMP_DIR}/.claude/state/statusline-telemetry.jsonl"
[ -f "${telemetry_file}" ] || {
  echo "statusline telemetry file was not written"
  exit 1
}

jq -s '
  .[0].effort_level == "high" and
  .[0].thinking_enabled == true and
  .[1].thinking_enabled == null
' "${telemetry_file}" >/dev/null || {
  echo "statusline telemetry must capture effort/thinking fields with null-safe fallback"
  exit 1
}

mkdir -p "${TMP_DIR}/bin"
cat > "${TMP_DIR}/bin/stat" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-f" ] && [ "${2:-}" = "%m" ]; then
  printf '/mock-mount\n'
  exit 0
fi
exec /usr/bin/stat "$@"
EOF
chmod +x "${TMP_DIR}/bin/stat"
touch "${TMP_DIR}/cache-file"

linux_like_output="$(
  cd "${TMP_DIR}" &&
  PATH="${TMP_DIR}/bin:${PATH}" \
  HARNESS_STATUSLINE_GIT_CACHE="${TMP_DIR}/cache-file" \
  printf '%s' "${rich_input}" | bash "${TMP_DIR}/statusline-harness.sh"
)"

printf '%s' "${linux_like_output}" | grep -q 'effort:high' || {
  echo "statusline output must keep working when GNU stat returns a non-numeric -f %m value"
  exit 1
}

echo "OK"
