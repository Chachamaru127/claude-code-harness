#!/usr/bin/env bash
#
# Verify the Japanese UX surfaces survive the English-default migration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for Japanese UX regression tests" >&2
  exit 1
fi

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -qF "$needle" "$file"; then
    echo "$file missing expected text: $needle" >&2
    exit 1
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

copy_dir() {
  local source="$1"
  if [ -d "$source" ]; then
    mkdir -p "$tmpdir/repo/$(dirname "$source")"
    cp -R "$source" "$tmpdir/repo/$source"
  fi
}

mkdir -p "$tmpdir/repo/scripts/i18n"
cp scripts/i18n/set-locale.sh "$tmpdir/repo/scripts/i18n/set-locale.sh"
copy_dir skills
copy_dir .agents/skills

# `.agents/skills/` is a local-only mirror (gitignored). On CI / fresh
# checkouts it does not exist on the host, so derive it inside the temp dir
# from skills/ before locale processing. This keeps the test self-contained
# without changing the project's "local-only mirror" intent.
if [ ! -d "$tmpdir/repo/.agents/skills" ]; then
  mkdir -p "$tmpdir/repo/.agents/skills"
  for s in harness-work harness-review harness-plan; do
    if [ -d "$tmpdir/repo/skills/$s" ]; then
      cp -R "$tmpdir/repo/skills/$s" "$tmpdir/repo/.agents/skills/$s"
    fi
  done
fi

locale_log="$tmpdir/i18n-japanese-ux-locale.log"
if ! (
  cd "$tmpdir/repo"
  bash scripts/i18n/set-locale.sh ja
) >"$locale_log" 2>&1; then
  echo "set-locale.sh ja failed:" >&2
  cat "$locale_log" >&2
  exit 1
fi

python3 - "$tmpdir/repo" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])


def frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise AssertionError(f"{path}: missing frontmatter")
    data: dict[str, str] = {}
    for line in lines[1:]:
        if line == "---":
            return data
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key] = value.strip()
    raise AssertionError(f"{path}: unterminated frontmatter")


key_skills = [
    ("skills/harness-work/SKILL.md", "実装して"),
    ("skills/harness-review/SKILL.md", "レビューして"),
    ("skills/harness-plan/SKILL.md", "計画作って"),
    (".agents/skills/harness-work/SKILL.md", "実装して"),
    (".agents/skills/harness-review/SKILL.md", "レビューして"),
    (".agents/skills/harness-plan/SKILL.md", "計画作って"),
]

checked = 0
for relative, phrase in key_skills:
    path = root / relative
    if not path.exists():
        continue
    checked += 1
    meta = frontmatter(path)
    text = path.read_text(encoding="utf-8")
    assert meta.get("description") == meta.get("description-ja"), (
        f"{relative}: description must become description-ja after set-locale ja"
    )
    assert meta.get("description-en"), f"{relative}: description-en was lost"
    assert phrase in meta.get("description", "") or phrase in text, (
        f"{relative}: Japanese trigger phrase disappeared: {phrase}"
    )
    assert "## Quick Reference" in text, f"{relative}: Quick Reference disappeared"

assert checked >= 6, f"expected to check major skill surfaces, checked {checked}"
print(f"checked {checked} Japanese skill descriptions")
PY

# README_ja.md is upstream-specific; only validate if present in this fork
if [ -f "README_ja.md" ]; then
  assert_contains README_ja.md "配布時の既定言語は English"
  assert_contains README_ja.md "CLAUDE_CODE_HARNESS_LANG=ja claude"
  assert_contains README_ja.md "/harness-work all"
  assert_contains README_ja.md "5動詞ワークフロー"
fi

for template in \
  templates/locales/ja/AGENTS.md.template \
  templates/locales/ja/CLAUDE.md.template \
  templates/locales/ja/Plans.md.template \
  templates/locales/ja/.claude-code-harness.config.yaml.template; do
  test -f "$template"
done
assert_contains templates/locales/ja/AGENTS.md.template "# AGENTS.md - 開発フロー概要"
assert_contains templates/locales/ja/CLAUDE.md.template "# CLAUDE.md - Claude Code 実行指示書"
assert_contains templates/locales/ja/Plans.md.template "# Plans.md - タスク管理"
assert_contains templates/locales/ja/.claude-code-harness.config.yaml.template "language: ja"

hook_project="$tmpdir/hook-project"
mkdir -p "$hook_project/.claude/state"
sudo_payload="$(jq -nc --arg cwd "$hook_project" '{tool_name:"Bash", tool_input:{command:"sudo whoami"}, cwd:$cwd}')"
sudo_ja="$(cd "$hook_project" && CLAUDE_CODE_HARNESS_LANG=ja bash "$PROJECT_ROOT/scripts/pretooluse-guard.sh" <<< "$sudo_payload")"
if ! jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "$sudo_ja" | grep -q '^ブロック:'; then
  echo "Japanese pretooluse guard message disappeared" >&2
  echo "$sudo_ja" >&2
  exit 1
fi

printf '{"prompt_seq":0,"intent":"literal"}\n' > "$hook_project/.claude/state/session.json"
printf '{"lsp":{"available":false},"skills":{}}\n' > "$hook_project/.claude/state/tooling-policy.json"
printf '{"review_status":"pending"}\n' > "$hook_project/.claude/state/work-active.json"
prompt_payload="$(jq -nc '{prompt:"hello"}')"
prompt_ja="$(cd "$hook_project" && CLAUDE_CODE_HARNESS_LANG=ja bash "$PROJECT_ROOT/scripts/userprompt-inject-policy.sh" <<< "$prompt_payload")"
if ! jq -r '.hookSpecificOutput.additionalContext' <<< "$prompt_ja" | grep -q 'work モード継続中'; then
  echo "Japanese user prompt hook message disappeared" >&2
  echo "$prompt_ja" >&2
  exit 1
fi

python3 - <<'PY'
import json
from pathlib import Path

ja_mode = json.loads(Path("templates/modes/harness--ja.json").read_text(encoding="utf-8"))
en_mode = json.loads(Path("templates/modes/harness.json").read_text(encoding="utf-8"))
assert ja_mode["name"].endswith("(Japanese)"), "Japanese mode name should remain explicit"
assert en_mode["name"] != ja_mode["name"], "English and Japanese modes should stay distinct"
mode_text = json.dumps(ja_mode, ensure_ascii=False)
assert "LANGUAGE REQUIREMENTS" in mode_text, "Japanese mode language requirements disappeared"
assert "日本語" in mode_text, "Japanese mode must continue requesting Japanese output"
PY

assert_contains docs/i18n-language-contract.md "## Japanese UX Regression Boundary"
assert_contains docs/i18n-language-contract.md 'Creative skills such as `x-announce` and `x-article`'
assert_contains docs/i18n-language-contract.md "Japanese article / post structure"
assert_contains docs/i18n-language-contract.md "Do not remove Japanese defaults"

for optional_source in \
  skills/x-article/SKILL.md \
  skills/x-announce/SKILL.md \
  codex/.codex/skills/x-article/SKILL.md \
  codex/.codex/skills/x-announce/SKILL.md \
  .agents/skills/x-article/SKILL.md \
  .agents/skills/x-announce/SKILL.md; do
  if [ -f "$optional_source" ]; then
    case "$optional_source" in
      *x-article*) assert_contains "$optional_source" "画像内テキストは日本語を基本にする" ;;
      *x-announce*) assert_contains "$optional_source" "投稿テキスト5本" ;;
    esac
  fi
done

python3 - <<'PY'
from pathlib import Path


def frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    data: dict[str, str] = {}
    for line in lines[1:]:
        if line == "---":
            return data
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key] = value.strip()
    raise AssertionError(f"{path}: unterminated frontmatter")


for path in (
    Path("codex/.codex/skills/x-article/SKILL.md"),
    Path("codex/.codex/skills/x-announce/SKILL.md"),
):
    if not path.exists():
        continue
    meta = frontmatter(path)
    assert meta["description"] == meta["description-en"], f"{path}: English discovery default drifted"
    assert meta["description-ja"], f"{path}: Japanese creative metadata disappeared"
PY

echo "✓ Japanese UX regression surfaces remain available under explicit ja opt-in"
