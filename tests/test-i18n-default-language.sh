#!/usr/bin/env bash
#
# Verify the Phase 55 language contract defaults new distribution surfaces to
# English while keeping Japanese as an explicit opt-in.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

python3 - <<'PY'
import json
import subprocess
from pathlib import Path

root = Path(".")

schema = json.loads(Path("claude-code-harness.config.schema.json").read_text(encoding="utf-8"))
language = schema["properties"]["i18n"]["properties"]["language"]
enum = set(language.get("enum", []))
assert language.get("default") == "en", "schema i18n.language default must be en"
assert enum == {"en", "ja"}, f"schema i18n.language enum must keep en and ja, got {sorted(enum)!r}"

example = json.loads(Path("claude-code-harness.config.example.json").read_text(encoding="utf-8"))
assert example["i18n"]["language"] == "en", "example config must default to en"
assert "ja" in json.dumps(example["i18n"], ensure_ascii=False), "example config must still document ja opt-in"

contract = Path("docs/i18n-language-contract.md").read_text(encoding="utf-8")
assert "User-facing default locale is `en`." in contract
assert "Japanese remains supported" in contract
assert "`description-en` and `description-ja`" in contract
assert "Default | `en`" in contract

claude_md = Path("CLAUDE.md").read_text(encoding="utf-8")
assert "All responses must be in **Japanese**" not in claude_md, "root CLAUDE.md must not force Japanese for distributed users"
assert "If no\nlanguage is configured, use English" in claude_md, "root CLAUDE.md must preserve English default"
assert "user asks in\nJapanese" not in claude_md, "Japanese input alone must not override the English default"

opencode_agents = Path("opencode/AGENTS.md").read_text(encoding="utf-8")
assert "All responses must be in **Japanese**" not in opencode_agents, "opencode AGENTS.md must not force Japanese for distributed users"
assert "If no\nlanguage is configured, use English" in opencode_agents, "opencode AGENTS.md must preserve English default"
assert "user asks in\nJapanese" not in opencode_agents, "Japanese input alone must not override the English default"

codex_agents = Path("codex/AGENTS.md").read_text(encoding="utf-8")
assert "All responses must be in **Japanese**" not in codex_agents, "codex AGENTS.md must not force Japanese for distributed users"
assert "If no\nlanguage is configured, use English" in codex_agents, "codex AGENTS.md must preserve English default"
assert "user asks in\nJapanese" not in codex_agents, "Japanese input alone must not override the English default"

tracked_files = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
for file_name in tracked_files:
    path = Path(file_name)
    parts = path.parts
    if path.name != "SKILL.md":
        continue
    is_shipped_skill = (
        parts[:1] == ("skills",)
        or parts[:1] == ("skills-codex",)
        or parts[:3] == ("codex", ".codex", "skills")
        or parts[:2] == ("opencode", "skills")
    )
    if not is_shipped_skill:
        continue
    text = path.read_text(encoding="utf-8")
    assert "出力は日本語" not in text, f"{path} must not force Japanese output"

template = Path("templates/.claude-code-harness.config.yaml.template").read_text(encoding="utf-8")
assert "i18n:" in template, "setup config template must include i18n"
assert "language: en" in template, "setup config template must render English default"
assert "language: ja" in template or "`ja`" in template or "Japanese" in template, "setup config template must mention Japanese opt-in"

print("i18n default language contract ok")
PY

echo "✓ i18n default language surfaces are English by default and keep Japanese opt-in"
