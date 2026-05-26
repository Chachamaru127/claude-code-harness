#!/bin/bash
# Minimal regression tests for review-ai-residuals.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/scripts/review-ai-residuals.sh"
FIXTURE_DIR="${ROOT_DIR}/tests/fixtures/review-ai-residuals"

command -v jq >/dev/null 2>&1 || {
  echo "jq is required for tests/test-review-ai-residuals.sh"
  exit 1
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}/src"
cp "${FIXTURE_DIR}/clean.ts" "${TMP_DIR}/src/clean.ts"
cp "${FIXTURE_DIR}/major.ts" "${TMP_DIR}/src/major.ts"
cp "${FIXTURE_DIR}/minor.ts" "${TMP_DIR}/src/minor.ts"
cp "${FIXTURE_DIR}/recommendation.ts" "${TMP_DIR}/src/recommendation.ts"
cp "${FIXTURE_DIR}/README.md" "${TMP_DIR}/README.md"

file_output="$(
  cd "${TMP_DIR}" && \
  bash "${SCRIPT_PATH}" src/clean.ts src/major.ts src/minor.ts src/recommendation.ts README.md
)"

echo "${file_output}" | jq -e '
  .summary.verdict == "REQUEST_CHANGES" and
  .summary.major >= 4 and
  .summary.minor >= 4 and
  .summary.recommendation >= 1 and
  .summary.total == (.observations | length) and
  (.files_scanned | length) == 4 and
  ([.observations[].rule] | index("hardcoded-secret")) != null and
  ([.observations[].rule] | index("localhost-reference")) != null and
  ([.observations[].rule] | index("test-skip")) != null and
  ([.observations[].rule] | index("hardcoded-test-pass")) != null and
  ([.observations[].rule] | index("dummy-value")) != null and
  ([.observations[].rule] | index("todo-fixme")) != null and
  (([.observations[].match] | join(" ")) | contains("localhost:3000")) and
  (([.observations[].match] | join(" ")) | contains("<redacted>"))
' >/dev/null || {
  echo "explicit file scan did not return the expected JSON summary"
  exit 1
}

cd "${TMP_DIR}"
git init -q
git config user.name "Harness Test"
git config user.email "harness-test@example.com"
cp "${FIXTURE_DIR}/clean.ts" "${TMP_DIR}/src/major.ts"
cp "${FIXTURE_DIR}/clean.ts" "${TMP_DIR}/src/minor.ts"
git add src/clean.ts src/major.ts src/minor.ts
git commit -qm "chore: baseline"

cp "${FIXTURE_DIR}/major.ts" "${TMP_DIR}/src/major.ts"
cp "${FIXTURE_DIR}/minor.ts" "${TMP_DIR}/src/minor.ts"

diff_output="$(bash "${SCRIPT_PATH}" --base-ref HEAD)"

echo "${diff_output}" | jq -e '
  .scan_mode == "diff" and
  .base_ref == "HEAD" and
  .include_untracked == false and
  (.untracked_files_scanned | length) == 0 and
  .summary.verdict == "REQUEST_CHANGES" and
  .summary.major >= 4 and
  .summary.minor >= 1 and
  (.files_scanned | sort) == ["src/major.ts", "src/minor.ts"]
' >/dev/null || {
  echo "diff scan did not return the expected files or severities"
  exit 1
}

cat > "${TMP_DIR}/src/untracked.ts" <<'EOF'
export const localOnlyUrl = "http://localhost:3000";
export const token = "sk-live-untracked-secret";

test.skip("untracked smoke", () => {
  expect(true).toBe(true);
});
EOF
cat > "${TMP_DIR}/notes.md" <<'EOF'
TODO: docs are ignored by residual scan.
localhost:3000
EOF
cat > "${TMP_DIR}/binary.bin" <<'EOF'
TODO: unsupported extension is ignored.
EOF

untracked_output="$(bash "${SCRIPT_PATH}" --base-ref HEAD --include-untracked)"

echo "${untracked_output}" | jq -e '
  .scan_mode == "diff" and
  .base_ref == "HEAD" and
  .include_untracked == true and
  .summary.verdict == "REQUEST_CHANGES" and
  (.files_scanned | sort) == ["src/major.ts", "src/minor.ts", "src/recommendation.ts", "src/untracked.ts"] and
  (.untracked_files_scanned | sort) == ["src/recommendation.ts", "src/untracked.ts"] and
  ([.observations[] | select(.location | startswith("src/untracked.ts:")) | .rule] | index("test-skip")) != null and
  ([.observations[] | select(.location | startswith("src/untracked.ts:")) | .rule] | index("localhost-reference")) != null and
  ([.observations[] | select(.location | startswith("src/untracked.ts:")) | .rule] | index("hardcoded-secret")) != null and
  ((.files_scanned | index("notes.md")) == null) and
  ((.files_scanned | index("binary.bin")) == null)
' >/dev/null || {
  echo "--include-untracked scan did not return the expected files or JSON metadata"
  exit 1
}

if rg -n "grep -nE 'TODO\\|FIXME\\|XXX" \
  "${ROOT_DIR}/skills/harness-review/SKILL.md" \
  "${ROOT_DIR}/codex/.codex/skills/harness-review/SKILL.md" \
  "${ROOT_DIR}/opencode/skills/harness-review/SKILL.md" >/tmp/review-ai-residuals-docs.$$ 2>/dev/null; then
  cat /tmp/review-ai-residuals-docs.$$
  rm -f /tmp/review-ai-residuals-docs.$$ || true
  echo "harness-review docs still contain the manual untracked grep scanner"
  exit 1
fi
rm -f /tmp/review-ai-residuals-docs.$$ || true

if ! rg -q --fixed-strings -- "--include-untracked" \
  "${ROOT_DIR}/skills/harness-review/SKILL.md" \
  "${ROOT_DIR}/codex/.codex/skills/harness-review/SKILL.md"; then
  echo "harness-review docs do not point to --include-untracked"
  exit 1
fi

echo "OK"
