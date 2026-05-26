#!/bin/bash
# Verify harness-release treats bare invocation as reviewed work commit + release,
# and asks before releasing unreviewed work.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

skill_files=(
  "$ROOT_DIR/skills/harness-release/SKILL.md"
)

required_terms=(
  "AskUserQuestion"
  "I want to commit my current work and release it"
  "Bare invocation contract"
  "Review Gate"
  "Work Commit Gate"
  "Start with review"
  "harness-review"
  "APPROVE"
  "REQUEST_CHANGES"
  "harness-work"
  "fix-then-re-review loop"
  "\`REQUEST_CHANGES\` alone must not be used as a final stopping reason"
  "release dry-run"
  "working tree clean check"
  "RELEASE_AUTOSTART:"
  'if $ARGUMENTS == ""'
  "task is unclear"
  "↑ Claude will summarize these results"
)

failures=0

for file in "${skill_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "missing release skill file: ${file#$ROOT_DIR/}" >&2
    failures=$((failures + 1))
    continue
  fi

  for term in "${required_terms[@]}"; do
    if ! grep -Fq "$term" "$file"; then
      echo "missing required term in ${file#$ROOT_DIR/}: $term" >&2
      failures=$((failures + 1))
    fi
  done

  if [[ "$file" != */opencode/skills/* ]]; then
    if ! grep -Eq '^allowed-tools: .*AskUserQuestion' "$file"; then
      echo "AskUserQuestion is not exposed in allowed-tools: ${file#$ROOT_DIR/}" >&2
      failures=$((failures + 1))
    fi

    if ! grep -Eq '^allowed-tools: .*Skill' "$file"; then
      echo "Skill tool is not exposed for harness-review handoff: ${file#$ROOT_DIR/}" >&2
      failures=$((failures + 1))
    fi
  fi
done


if [ "$failures" -gt 0 ]; then
  exit 1
fi

echo "test-harness-release-governance: ok"
