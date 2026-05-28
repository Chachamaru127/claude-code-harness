#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="${ROOT_DIR}/scripts/model-routing.sh"
COMPANION="${ROOT_DIR}/scripts/codex-companion.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

[ -x "${ROUTER}" ] || {
  echo "model-routing.sh must be executable"
  exit 1
}

codex_lite_model="$(bash "${ROUTER}" --host codex --role explorer --field model)"
[ "${codex_lite_model}" = "gpt-5.4-mini" ] || {
  echo "codex explorer must route to gpt-5.4-mini"
  exit 1
}

claude_advisor_effort="$(bash "${ROUTER}" --host claude --role advisor --field effort)"
[ "${claude_advisor_effort}" = "xhigh" ] || {
  echo "claude advisor must route to xhigh"
  exit 1
}

claude_advisor_model="$(bash "${ROUTER}" --host claude --role advisor --field model)"
[ "${claude_advisor_model}" = "claude-opus-4-7" ] || {
  echo "claude advisor must route to claude-opus-4-7"
  exit 1
}

cursor_worker_model="$(bash "${ROUTER}" --host cursor --role worker --field model)"
[ "${cursor_worker_model}" = "composer-2.5-fast" ] || {
  echo "cursor worker must route to composer-2.5-fast"
  exit 1
}

cursor_advisor_model="$(bash "${ROUTER}" --host cursor --role advisor --field model)"
[ "${cursor_advisor_model}" = "claude-opus-4-7-thinking-xhigh" ] || {
  echo "cursor advisor must route to claude-opus-4-7-thinking-xhigh"
  exit 1
}

cursor_args="$(bash "${ROUTER}" --host cursor --tier review --format args | tr '\n' ' ')"
printf '%s' "${cursor_args}" | grep -q -- '--model composer-2.5-fast' || {
  echo "cursor args must include review model"
  exit 1
}

cursor_env="$(bash "${ROUTER}" --host cursor --tier standard --format env)"
printf '%s' "${cursor_env}" | grep -q '^CURSOR_MODEL=composer-2.5-fast$' || {
  echo "cursor env must export CURSOR_MODEL"
  exit 1
}

codex_args="$(bash "${ROUTER}" --host codex --tier review --format args | tr '\n' ' ')"
printf '%s' "${codex_args}" | grep -q -- '--model gpt-5.5' || {
  echo "codex args must include review model"
  exit 1
}
printf '%s' "${codex_args}" | grep -q -- 'model_reasoning_effort="xhigh"' || {
  echo "codex args must include xhigh reasoning config"
  exit 1
}

if bash "${ROUTER}" --host codex --tier unknown >/tmp/model-routing-unknown.out 2>/tmp/model-routing-unknown.err; then
  echo "unknown tier should fail"
  exit 1
fi

mkdir -p "${TMP_DIR}/home/.codex/plugins/openai-codex/1.0.0" "${TMP_DIR}/bin"
touch "${TMP_DIR}/home/.codex/plugins/openai-codex/1.0.0/codex-companion.mjs"

cat > "${TMP_DIR}/bin/codex" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "${CODEX_STUB_ARGS_FILE}"
EOF
chmod +x "${TMP_DIR}/bin/codex"

SCHEMA_FILE="${TMP_DIR}/schema.json"
printf '{"type":"object"}\n' > "${SCHEMA_FILE}"

CODEX_STUB_ARGS_FILE="${TMP_DIR}/args-lite.txt" \
HOME="${TMP_DIR}/home" \
PATH="${TMP_DIR}/bin:${PATH}" \
HARNESS_MODEL_TIER="lite" \
  bash "${COMPANION}" task --output-schema "${SCHEMA_FILE}" "simple docs cleanup"

grep -qx -- '--model' "${TMP_DIR}/args-lite.txt" || {
  echo "structured codex path must include --model"
  exit 1
}
grep -qx -- 'gpt-5.4-mini' "${TMP_DIR}/args-lite.txt" || {
  echo "structured codex path must use routed lite model"
  exit 1
}
grep -qx -- '-c' "${TMP_DIR}/args-lite.txt" || {
  echo "structured codex path must include config override"
  exit 1
}
grep -qx -- 'model_reasoning_effort="low"' "${TMP_DIR}/args-lite.txt" || {
  echo "structured codex path must translate computed effort to config"
  exit 1
}

CODEX_STUB_ARGS_FILE="${TMP_DIR}/args-explicit.txt" \
HOME="${TMP_DIR}/home" \
PATH="${TMP_DIR}/bin:${PATH}" \
HARNESS_MODEL_TIER="lite" \
  bash "${COMPANION}" task --output-schema "${SCHEMA_FILE}" --model custom-model --effort xhigh "hard review"

grep -qx -- 'custom-model' "${TMP_DIR}/args-explicit.txt" || {
  echo "explicit model must be preserved"
  exit 1
}
if grep -qx -- 'gpt-5.4-mini' "${TMP_DIR}/args-explicit.txt"; then
  echo "routed model must not override explicit model"
  exit 1
fi
grep -qx -- 'model_reasoning_effort="xhigh"' "${TMP_DIR}/args-explicit.txt" || {
  echo "explicit effort must translate to config"
  exit 1
}

echo "OK"
