#!/usr/bin/env bash
# Phase 93.3.4 — Cursor advisory pre-review wiring contract tests
#
# Validates scripts/pre-review-cursor.sh without calling real cursor-agent.
# Uses a fake cursor-companion stub via HARNESS_PRE_REVIEW_CURSOR_COMPANION.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/scripts/pre-review-cursor.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1" >&2; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected '${expected}', got '${actual}')"
  fi
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected to contain '${needle}')"
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    fail "$label (must not contain '${needle}')"
  else
    pass "$label"
  fi
}

assert_not_matches() {
  local label="$1"
  local pattern="$2"
  local haystack="$3"
  if grep -qE -- "$pattern" <<<"$haystack"; then
    fail "$label (must not match /${pattern}/)"
  else
    pass "$label"
  fi
}

# ---- pre-flight ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "pre-flight: pre-review-cursor.sh missing or not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: pre-review-cursor.sh exists and is executable"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pre-review-cursor-test.XXXXXX")"
FAKE_COMPANION="${TMP_DIR}/fake-cursor-companion.sh"
ARGS_FILE="${TMP_DIR}/companion-args.txt"
OUTPUT_FILE="${TMP_DIR}/script-output.txt"
FAKE_MR="${TMP_DIR}/fake-model-routing.sh"

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

write_fake_companion() {
  local exit_code="$1"
  local stdout_body="${2:-}"
  local stdout_file="${TMP_DIR}/companion-stdout-${exit_code}.txt"
  printf '%s' "$stdout_body" > "${stdout_file}"
  cat >"${FAKE_COMPANION}" <<EOF
#!/usr/bin/env bash
ARGS_FILE="${ARGS_FILE}"
STDOUT_FILE="${stdout_file}"
for arg in "\$@"; do
  printf '%s\n' "\$arg"
done > "\${ARGS_FILE}"
if [ -s "\${STDOUT_FILE}" ]; then
  cat "\${STDOUT_FILE}"
fi
exit ${exit_code}
EOF
  chmod +x "${FAKE_COMPANION}"
}

write_fake_model_router() {
  cat >"${FAKE_MR}" <<'EOF'
#!/usr/bin/env bash
printf 'composer-2.5-fast\n'
EOF
  chmod +x "${FAKE_MR}"
}

run_pre_review() {
  local rc=0
  set +e
  HARNESS_PRE_REVIEW_CURSOR_COMPANION="${FAKE_COMPANION}" \
  HARNESS_PRE_REVIEW_MODEL_ROUTER="${FAKE_MR}" \
    bash "${SCRIPT}" "$@" >"${OUTPUT_FILE}" 2>&1
  rc=$?
  set -e
  printf '%s' "$rc"
}

write_fake_model_router
write_fake_companion 0 "Potential missing edge-case test for empty diff."

# Use an empty diff so companion args are not polluted by this test file's source.
EMPTY_BASE="HEAD"

# ---- (a) companion invoked without --write ----

rc="$(run_pre_review --base "${EMPTY_BASE}")"
assert_eq "(a) success path exits 0" "0" "$rc"
assert_contains "(a) invokes cursor-companion task subcommand" "task" "$(head -n 1 "${ARGS_FILE}")"
if head -n 20 "${ARGS_FILE}" | grep -qE '(^|[[:space:]])--write([[:space:]]|$)'; then
  fail "(a) must not pass --write to cursor-companion (args: $(head -n 5 "${ARGS_FILE}"))"
else
  pass "(a) cursor-companion called without --write"
fi
if head -n 20 "${ARGS_FILE}" | grep -qE '(^|[[:space:]])--workspace([[:space:]]|$)'; then
  fail "(a) must not pass --workspace to cursor-companion (args: $(head -n 5 "${ARGS_FILE}"))"
else
  pass "(a) cursor-companion called without --workspace"
fi

# ---- (b) no --resume flags (fresh session contract) ----

if head -n 20 "${ARGS_FILE}" | grep -qE '(^|[[:space:]])--resume([[:space:]|=]|$)'; then
  fail "(b) must not pass --resume to cursor-companion (args: $(head -n 5 "${ARGS_FILE}"))"
else
  pass "(b) cursor-companion called without --resume"
fi

# ---- (c) script output has no verdict tokens ----

OUT="$(cat "${OUTPUT_FILE}")"
assert_contains "(c) emits PRE_REVIEW_FINDINGS header" "PRE_REVIEW_FINDINGS:" "$OUT"
assert_not_matches "(c) output excludes APPROVE verdict token" '\bAPPROVE\b' "$OUT"
assert_not_matches "(c) output excludes REQUEST_CHANGES verdict token" 'REQUEST_CHANGES' "$OUT"

# ---- (d) fail-open when companion exits non-zero ----

write_fake_companion 1 ""
rc="$(run_pre_review --base "${EMPTY_BASE}")"
assert_eq "(d) companion failure exits 0 (fail-open)" "0" "$rc"
OUT="$(cat "${OUTPUT_FILE}")"
assert_contains "(d) companion failure emits PRE_REVIEW_SKIPPED" "PRE_REVIEW_SKIPPED:" "$OUT"

# ---- (e) SKILL grep regression guards ----

HR="${ROOT}/skills/harness-review/SKILL.md"
HW="${ROOT}/skills/harness-work/SKILL.md"
BZ="${ROOT}/skills/breezing/SKILL.md"

if grep -q -- '--pre-review cursor' "${HR}"; then
  pass "(e) harness-review documents --pre-review cursor"
else
  fail "(e) harness-review missing --pre-review cursor section"
fi

if grep -q 'fresh-context advisory pre-review' "${HW}"; then
  pass "(e) harness-work retains fresh-context advisory pre-review exception"
else
  fail "(e) harness-work missing fresh-context advisory pre-review Role scope text"
fi

if grep -q 'fresh-context advisory pre-review' "${BZ}"; then
  pass "(e) breezing retains fresh-context advisory pre-review exception"
else
  fail "(e) breezing missing fresh-context advisory pre-review Role scope text"
fi

# ---- summary ----

echo "PASS=$PASS FAIL=$FAIL" >&2
if [[ "$FAIL" -gt 0 ]]; then
  printf 'Failures:\n' >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    printf '  - %s\n' "$msg" >&2
  done
  exit 1
fi

echo "ok"
