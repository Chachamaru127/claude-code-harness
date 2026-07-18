#!/usr/bin/env bash
# Self-test for tests/test-support-claim-wording.sh.
#
# Locks the checker against the allowlist-evasion class found in PR #239
# review: a positive support claim ("Hermes Agent is supported, but runtime
# floor parity is not proven") must FAIL even when the same line contains a
# denial-looking token (not proven / blocked / support wording / 未主張).
# Legitimate denial wording (blocked-wording tables, "not a public
# `supported` claim") must stay green.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT_DIR}/tests/test-support-claim-wording.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "test-support-claim-wording-selftest: FAIL: $1" >&2
  exit 1
}

expect_fail() {
  local name="$1"
  local file="$2"
  if bash "$CHECKER" "$file" >/dev/null 2>&1; then
    fail "overclaim fixture was accepted: ${name}"
  fi
}

expect_pass() {
  local name="$1"
  local file="$2"
  bash "$CHECKER" "$file" >/dev/null 2>&1 \
    || fail "legitimate denial fixture was rejected: ${name}"
}

[ -f "$CHECKER" ] || fail "missing ${CHECKER}"

# --- Overclaim fixtures: every one of these must make the checker exit 1. ---
# Each line pairs a positive support claim with a token that the pre-fix
# allowlist treated as a whole-line excuse.

cat > "${TMP_DIR}/overclaim-not-proven.md" <<'EOF'
Hermes Agent is supported, but runtime floor parity is not proven.
EOF
expect_fail "supported + not proven" "${TMP_DIR}/overclaim-not-proven.md"

cat > "${TMP_DIR}/overclaim-blocked-token.md" <<'EOF'
Cursor is supported; workflow smoke is blocked.
EOF
expect_fail "supported + blocked token" "${TMP_DIR}/overclaim-blocked-token.md"

cat > "${TMP_DIR}/overclaim-support-wording-token.md" <<'EOF'
Hermes Agent is supported until the next support wording review.
EOF
expect_fail "supported + support wording token" "${TMP_DIR}/overclaim-support-wording-token.md"

cat > "${TMP_DIR}/overclaim-not-claimed-token.md" <<'EOF'
supported Hermes adapter ships today; parity is not claimed.
EOF
expect_fail "supported adapter + not claimed token" "${TMP_DIR}/overclaim-not-claimed-token.md"

cat > "${TMP_DIR}/overclaim-ja.md" <<'EOF'
Hermes Agent は対応済み。runtime parity は未主張。
EOF
expect_fail "JP 対応済み + 未主張 token" "${TMP_DIR}/overclaim-ja.md"

# A negator phrase must not swallow an unrelated later claim (the denial
# phrase itself must contain the support word it excuses, nothing more).

cat > "${TMP_DIR}/overclaim-negator-preamble.md" <<'EOF'
We must not let anyone believe otherwise: Hermes Agent is supported.
EOF
expect_fail "must-not preamble + positive claim" "${TMP_DIR}/overclaim-negator-preamble.md"

cat > "${TMP_DIR}/overclaim-never-preamble.md" <<'EOF'
Never mind the caveats: Grok is fully supported in production today.
EOF
expect_fail "never preamble + positive claim" "${TMP_DIR}/overclaim-never-preamble.md"

# "blocked:" only neutralizes a blocked-wording table cell (closed by "|");
# outside a table it must not consume the rest of the line.

cat > "${TMP_DIR}/overclaim-blocked-no-table.md" <<'EOF'
blocked: for the record, Hermes Agent is supported starting today.
EOF
expect_fail "blocked: prose (no table cell)" "${TMP_DIR}/overclaim-blocked-no-table.md"

# --- Legitimate denial fixtures: every one of these must stay green. ---

cat > "${TMP_DIR}/denial-public-claim.md" <<'EOF'
This is not a public `supported` claim. Harness has not added a Hermes setup
script, host-specific distribution package, or CI-gated workflow smoke.
EOF
expect_pass "not a public supported claim" "${TMP_DIR}/denial-public-claim.md"

cat > "${TMP_DIR}/denial-blocked-table.md" <<'EOF'
| Allowed | Blocked |
|---|---|
| candidate Hermes Agent path | blocked: supported Hermes adapter |
| manual symlink research route | blocked: Hermes 正式対応 |
EOF
expect_pass "blocked-wording table" "${TMP_DIR}/denial-blocked-table.md"

cat > "${TMP_DIR}/denial-plain.md" <<'EOF'
Hermes Agent is not supported.
EOF
expect_pass "plain negation" "${TMP_DIR}/denial-plain.md"

cat > "${TMP_DIR}/denial-ja.md" <<'EOF'
Hermes Agent は正式対応ではない。
EOF
expect_pass "JP 正式対応ではない" "${TMP_DIR}/denial-ja.md"

cat > "${TMP_DIR}/clean-candidate.md" <<'EOF'
Hermes Agent is a candidate Harness host path.
EOF
expect_pass "clean candidate wording" "${TMP_DIR}/clean-candidate.md"

cat > "${TMP_DIR}/denial-promote-idiom.md" <<'EOF'
Do not promote Grok to public `supported` until live H4 evidence exists.
EOF
expect_pass "do-not-promote idiom" "${TMP_DIR}/denial-promote-idiom.md"

# The promote idiom must not hide a separate positive claim after it.
cat > "${TMP_DIR}/overclaim-after-promote-idiom.md" <<'EOF'
Do not promote Grok to public `supported` yet; Hermes Agent is supported now.
EOF
expect_fail "promote idiom + trailing claim" "${TMP_DIR}/overclaim-after-promote-idiom.md"

# --- Real public surfaces must stay green with the default file list. ---
bash "$CHECKER" >/dev/null 2>&1 \
  || fail "default public surface scan is red"

echo "test-support-claim-wording-selftest: ok"
