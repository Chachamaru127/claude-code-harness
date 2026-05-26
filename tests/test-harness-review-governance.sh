#!/bin/bash
# Verify harness-review keeps the TeamAgent debate and acceptance-gate contract
# in both the shared skill and shipped mirrors.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

skill_files=(
  "$ROOT_DIR/skills/harness-review/SKILL.md"
)

reference_names=(
  "governance.md"
  "code-review.md"
  "codex-closeout.md"
  "team-debate.md"
  "plan-review.md"
  "scope-review.md"
  "dual-review.md"
)

required_skill_terms=(
  "AskUserQuestion"
  "review of previous work"
  "REVIEW_TARGET_ASK"
  "REVIEW_TARGET_AMBIGUOUS"
  "REVIEW_TARGET_CONFIRMED"
  "uncommitted changes only"
  "most recent 1 commit"
  "TeamAgent Debate"
  "Clear passing threshold"
  "authoritative spec"
  "Plans.md"
  "regression"
  "post-fix re-review"
  "team_agent_mode"
  "decision_needed"
  "Spec Agent"
  "Plans Agent"
  "Regression Agent"
  "Skeptic Agent"
  "--quick"
  "--codex-closeout"
  "review default read-only boundary"
  "Do not push just to review"
  "accepted findings"
  "rejected findings"
  "stop-on-clean"
  "↑ Claude will summarize these results"
)

required_reference_terms=(
  "TeamAgent Debate"
  "passing threshold"
  "authoritative spec"
  "Plans.md"
  "regression"
  "acceptance_bar"
  "team_debate"
  "manual-pass"
  "review default read-only boundary"
  "Do not push just to review"
  "accepted findings"
  "rejected findings"
  "target selection"
  "stop-on-clean"
)

required_helper_terms=(
  "--dry-run"
  "--parallel-tests"
  "--base"
  "--commit"
  "--uncommitted"
  "harness-review-closeout.v1"
)

failures=0

check_file_contains() {
  local file="$1"
  local term="$2"

  if ! grep -Fq -- "$term" "$file"; then
    echo "missing required term in ${file#$ROOT_DIR/}: $term" >&2
    failures=$((failures + 1))
  fi
}

for file in "${skill_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "missing skill file: ${file#$ROOT_DIR/}" >&2
    failures=$((failures + 1))
    continue
  fi

  for term in "${required_skill_terms[@]}"; do
    check_file_contains "$file" "$term"
  done

  if [[ "$file" != */opencode/skills/* ]]; then
    if ! grep -Eq '^allowed-tools: .*AskUserQuestion' "$file"; then
      echo "AskUserQuestion is not exposed in allowed-tools: ${file#$ROOT_DIR/}" >&2
      failures=$((failures + 1))
    fi
  fi

  line_count="$(wc -l < "$file" | tr -d ' ')"
  if [ "$line_count" -gt 350 ]; then
    echo "dispatcher too large in ${file#$ROOT_DIR/}: ${line_count} lines" >&2
    failures=$((failures + 1))
  fi
done

for reference_name in "${reference_names[@]}"; do
  file="$ROOT_DIR/skills/harness-review/references/$reference_name"
  if [ ! -f "$file" ]; then
    echo "missing reference file: ${file#$ROOT_DIR/}" >&2
    failures=$((failures + 1))
  fi
done

for term in "${required_reference_terms[@]}"; do
  found=0
  for reference_name in "${reference_names[@]}"; do
    if grep -Fq -- "$term" "$ROOT_DIR/skills/harness-review/references/$reference_name"; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "missing required reference term across source references: $term" >&2
    failures=$((failures + 1))
  fi
done

helper_file="$ROOT_DIR/scripts/harness-review-closeout.sh"
if [ ! -x "$helper_file" ]; then
  echo "missing executable helper: ${helper_file#$ROOT_DIR/}" >&2
  failures=$((failures + 1))
else
  if ! bash -n "$helper_file"; then
    echo "helper has shell syntax errors: ${helper_file#$ROOT_DIR/}" >&2
    failures=$((failures + 1))
  fi

  for term in "${required_helper_terms[@]}"; do
    check_file_contains "$helper_file" "$term"
  done
fi


if [ "$failures" -gt 0 ]; then
  exit 1
fi

echo "test-harness-review-governance: ok"
