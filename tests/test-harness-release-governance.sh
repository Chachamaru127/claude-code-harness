#!/bin/bash
# Verify harness-release treats bare invocation as reviewed work commit + release,
# and asks before releasing unreviewed work.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

skill_files=(
  "$ROOT_DIR/skills/harness-release/SKILL.md"
  "$ROOT_DIR/codex/.codex/skills/harness-release/SKILL.md"
  "$ROOT_DIR/opencode/skills/harness-release/SKILL.md"
)

required_terms=(
  "AskUserQuestion"
  "今までの作業をコミットしてリリースしたい"
  "Bare invocation contract"
  "Review Gate"
  "Work Commit Gate"
  "レビューから開始"
  "harness-review"
  "APPROVE"
  "REQUEST_CHANGES"
  "harness-work"
  "修正後再レビュー loop"
  "\`REQUEST_CHANGES\` 単体を最終停止理由にしてはいけない"
  "release dry-run"
  "working tree clean check"
  "RELEASE_AUTOSTART:"
  'if $ARGUMENTS == ""'
  "タスクが不明確"
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

if ! diff -qr --exclude='.DS_Store' "$ROOT_DIR/skills/harness-release" "$ROOT_DIR/codex/.codex/skills/harness-release" >/dev/null; then
  echo "codex harness-release mirror drifted from skills/ SSOT" >&2
  failures=$((failures + 1))
fi

if ! node "$ROOT_DIR/scripts/validate-opencode.js" >/dev/null; then
  echo "opencode skill frontmatter failed native validation" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  exit 1
fi

echo "test-harness-release-governance: ok"
