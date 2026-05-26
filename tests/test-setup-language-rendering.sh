#!/usr/bin/env bash
#
# Verify setup-facing templates render English by default and preserve the
# Japanese opt-in path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

render_template() {
  local template="$1"
  local rendered="$2"
  local locale="$3"

  sed \
    -e "s|{{PROJECT_NAME}}|sample-project|g" \
    -e "s|{{DATE}}|2026-04-24|g" \
    -e "s|{{LANGUAGE}}|$locale|g" \
    "$template" > "$rendered"
}

assert_no_placeholders() {
  local file="$1"
  if grep -q '{{[A-Z_]*}}' "$file"; then
    echo "$file rendered with unresolved placeholders" >&2
    exit 1
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -qF "$needle" "$file"; then
    echo "$file missing expected text: $needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -qF "$needle" "$file"; then
    echo "$file contains unexpected text: $needle" >&2
    exit 1
  fi
}

rendered_config="$tmpdir/.claude-code-harness.config.yaml"
cp templates/.claude-code-harness.config.yaml.template "$rendered_config"
assert_no_placeholders "$rendered_config"

python3 - "$rendered_config" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
assert re.search(r"(?m)^i18n:\s*$", text), "rendered config must include i18n section"
assert re.search(r"(?m)^\s+language:\s+en\s*$", text), "rendered config must default i18n.language to en"
assert "ja" in text and "Japanese" in text, "rendered config must keep Japanese opt-in guidance"
PY

for template in templates/AGENTS.md.template templates/CLAUDE.md.template templates/Plans.md.template; do
  rendered="$tmpdir/en-$(basename "$template" .template)"
  render_template "$template" "$rendered" "en"
  assert_no_placeholders "$rendered"
done

assert_contains "$tmpdir/en-AGENTS.md" "# AGENTS.md - Development Flow Overview"
assert_contains "$tmpdir/en-CLAUDE.md" "# CLAUDE.md - Claude Code Instructions"
assert_contains "$tmpdir/en-Plans.md" "# Plans.md - Task Tracking"
assert_not_contains "$tmpdir/en-AGENTS.md" "開発フロー概要"
assert_not_contains "$tmpdir/en-CLAUDE.md" "実行指示書"
assert_not_contains "$tmpdir/en-Plans.md" "タスク管理"

for template in \
  templates/locales/ja/AGENTS.md.template \
  templates/locales/ja/CLAUDE.md.template \
  templates/locales/ja/Plans.md.template \
  templates/locales/ja/.claude-code-harness.config.yaml.template; do
  test -f "$template"
done

for template in templates/locales/ja/AGENTS.md.template templates/locales/ja/CLAUDE.md.template templates/locales/ja/Plans.md.template; do
  rendered="$tmpdir/ja-$(basename "$template" .template)"
  render_template "$template" "$rendered" "ja"
  assert_no_placeholders "$rendered"
done

assert_contains "$tmpdir/ja-AGENTS.md" "# AGENTS.md - 開発フロー概要"
assert_contains "$tmpdir/ja-CLAUDE.md" "# CLAUDE.md - Claude Code 実行指示書"
assert_contains "$tmpdir/ja-Plans.md" "# Plans.md - タスク管理"
assert_contains "templates/locales/ja/.claude-code-harness.config.yaml.template" "language: ja"

default_project="$tmpdir/default-project"
ja_project="$tmpdir/ja-project"
hook_default_project="$tmpdir/hook-default"
hook_ja_project="$tmpdir/hook-ja"
mkdir -p "$default_project" "$ja_project" "$hook_default_project" "$hook_ja_project"

printf 'n\n' | bash scripts/setup-existing-project.sh "$default_project" >/dev/null
assert_contains "$default_project/AGENTS.md" "# AGENTS.md - Development Flow Overview"
assert_contains "$default_project/CLAUDE.md" "# CLAUDE.md - Claude Code Instructions"
assert_contains "$default_project/Plans.md" "# Plans.md - Task Tracking"
assert_contains "$default_project/.claude-code-harness.config.yaml" "language: en"
assert_contains "$default_project/.claude/rules/harness.md" "# Claude Harness - Project Rules"
assert_no_placeholders "$default_project/AGENTS.md"
assert_no_placeholders "$default_project/CLAUDE.md"
assert_no_placeholders "$default_project/Plans.md"

printf 'n\n' | bash scripts/setup-existing-project.sh --locale ja "$ja_project" >/dev/null
assert_contains "$ja_project/AGENTS.md" "# AGENTS.md - 開発フロー概要"
assert_contains "$ja_project/CLAUDE.md" "# CLAUDE.md - Claude Code 実行指示書"
assert_contains "$ja_project/Plans.md" "# Plans.md - タスク管理"
assert_contains "$ja_project/.claude-code-harness.config.yaml" "language: ja"
assert_contains "$ja_project/.claude/rules/harness.md" "# Claude harness - Project Rules"
assert_no_placeholders "$ja_project/AGENTS.md"
assert_no_placeholders "$ja_project/CLAUDE.md"
assert_no_placeholders "$ja_project/Plans.md"

(
  cd "$hook_default_project"
  bash "$PROJECT_ROOT/scripts/setup-hook.sh" init >/dev/null
)
assert_contains "$hook_default_project/AGENTS.md" "# AGENTS.md - Development Flow Overview"
assert_contains "$hook_default_project/CLAUDE.md" "# CLAUDE.md - Claude Code Instructions"
assert_contains "$hook_default_project/Plans.md" "# Plans.md - Task Tracking"
assert_contains "$hook_default_project/.claude-code-harness.config.yaml" "language: en"
assert_no_placeholders "$hook_default_project/AGENTS.md"
assert_no_placeholders "$hook_default_project/CLAUDE.md"
assert_no_placeholders "$hook_default_project/Plans.md"

(
  cd "$hook_ja_project"
  CLAUDE_CODE_HARNESS_LANG=ja bash "$PROJECT_ROOT/scripts/setup-hook.sh" init >/dev/null
)
assert_contains "$hook_ja_project/AGENTS.md" "# AGENTS.md - 開発フロー概要"
assert_contains "$hook_ja_project/CLAUDE.md" "# CLAUDE.md - Claude Code 実行指示書"
assert_contains "$hook_ja_project/Plans.md" "# Plans.md - タスク管理"
assert_contains "$hook_ja_project/.claude-code-harness.config.yaml" "language: ja"
assert_no_placeholders "$hook_ja_project/AGENTS.md"
assert_no_placeholders "$hook_ja_project/CLAUDE.md"
assert_no_placeholders "$hook_ja_project/Plans.md"

test -f templates/modes/harness--ja.json

python3 - <<'PY'
import json
from pathlib import Path

marketplace = json.loads(Path(".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
hooks = json.loads(Path(".claude-plugin/hooks.json").read_text(encoding="utf-8"))
hooks_mirror = json.loads(Path("hooks/hooks.json").read_text(encoding="utf-8"))

assert marketplace["metadata"]["description"].startswith("Marketplace entry"), "marketplace metadata must be English default"
assert hooks["description"] == "company-ai-harness: automation hooks", "plugin hooks description must be English default"
assert hooks_mirror["description"] == hooks["description"], "hooks mirror description must stay synchronized"
PY

echo "✓ setup language rendering keeps English default and Japanese opt-in templates"
