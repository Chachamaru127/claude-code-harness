#!/usr/bin/env bash
#
# Verify that harness-work completion reports follow the shared locale
# resolver and keep the Claude, Codex, and OpenCode surfaces synchronized.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

python3 - "$PROJECT_ROOT" <<'PY'
from __future__ import annotations

from collections import Counter
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


root = Path(sys.argv[1])
skill_surfaces = [
    root / "skills/harness-work/SKILL.md",
    root / "skills-codex/harness-work/SKILL.md",
    root / "codex/.codex/skills/harness-work/SKILL.md",
    root / "opencode/skills/harness-work/SKILL.md",
]
reference_surfaces = [
    root / "skills/harness-work/references/completion-report.md",
    root / "skills-codex/harness-work/references/completion-report.md",
    root / "codex/.codex/skills/harness-work/references/completion-report.md",
    root / "opencode/skills/harness-work/references/completion-report.md",
]
pointer_surfaces = skill_surfaces + [
    root / "skills/breezing/SKILL.md",
    root / "skills-codex/breezing/SKILL.md",
    root / "codex/.codex/skills/breezing/SKILL.md",
    root / "opencode/skills/breezing/SKILL.md",
]


def marked_block(text: str, marker: str, *, source: Path) -> str:
    start = f"<!-- {marker}:start -->"
    end = f"<!-- {marker}:end -->"
    assert text.count(start) == 1, f"{source}: expected exactly one {start}"
    assert text.count(end) == 1, f"{source}: expected exactly one {end}"
    return text.split(start, 1)[1].split(end, 1)[0].strip()


contracts: list[str] = []
for path in skill_surfaces:
    assert path.is_file(), f"missing harness-work surface: {path}"
    text = path.read_text(encoding="utf-8")
    contract = marked_block(
        text,
        "harness-work-completion-output-contract",
        source=path,
    )
    assert "get_harness_locale" in contract, f"{path}: shared locale resolver is not required"
    assert "Unset, invalid, and resolved `en` render the English template." in contract
    assert "Only resolved `ja` renders the Japanese template." in contract
    assert "Japanese input alone does not select the Japanese template." in contract
    assert "references/completion-report.md" in contract
    contracts.append(contract)

assert len(set(contracts)) == 1, "Claude/Codex/OpenCode completion output contracts drifted"

for path in pointer_surfaces:
    text = path.read_text(encoding="utf-8")
    assert "完了報告フォーマット" not in text, (
        f"{path}: stale pointer to removed completion-report heading"
    )

reference_texts = [path.read_text(encoding="utf-8") for path in reference_surfaces]
assert len(set(reference_texts)) == 1, "Claude/Codex/OpenCode completion template references drifted"
reference = reference_texts[0]

templates: dict[tuple[str, str], str] = {}
for mode in ("solo", "breezing"):
    for locale in ("en", "ja"):
        templates[(mode, locale)] = marked_block(
            reference,
            f"completion-report-template:{mode}:{locale}",
            source=reference_surfaces[0],
        )

placeholder_pattern = re.compile(r"\{[A-Za-z][A-Za-z0-9_]*\}")
for mode in ("solo", "breezing"):
    en_placeholders = Counter(placeholder_pattern.findall(templates[(mode, "en")]))
    ja_placeholders = Counter(placeholder_pattern.findall(templates[(mode, "ja")]))
    assert en_placeholders == ja_placeholders, (
        f"{mode} EN/JA templates do not carry the same semantic fields: "
        f"en={en_placeholders}, ja={ja_placeholders}"
    )
    assert en_placeholders, f"{mode} templates must expose report fields"

assert "What changed" in templates[("solo", "en")]
assert "User impact" in templates[("solo", "en")]
assert "Validation" in templates[("solo", "en")]
assert "Remaining work" in templates[("solo", "en")]
assert "何をしたか" in templates[("solo", "ja")]
assert "何が変わるか" in templates[("solo", "ja")]
assert "検証" in templates[("solo", "ja")]
assert "残りの課題" in templates[("solo", "ja")]
assert "Breezing complete" in templates[("breezing", "en")]
assert "Breezing 完了" in templates[("breezing", "ja")]

japanese_script = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
for mode in ("solo", "breezing"):
    assert not japanese_script.search(templates[(mode, "en")]), (
        f"{mode} English template contains Japanese labels"
    )

assert "タスク {task_id} 完了" in templates[("solo", "ja")]
assert "変更前: {before}" in templates[("solo", "ja")]
assert "変更後: {after}" in templates[("solo", "ja")]
assert "変更ファイル（{file_count}件）" in templates[("solo", "ja")]
assert "コミット: {commit_hash}" in templates[("solo", "ja")]
assert "レビュー: {review_verdict}" in templates[("solo", "ja")]
assert "{completed_count}/{total_count}タスク" in templates[("breezing", "ja")]
assert "{file_count}ファイル変更" in templates[("breezing", "ja")]
assert "{insertions}行追加" in templates[("breezing", "ja")]
assert "{deletions}行削除" in templates[("breezing", "ja")]
assert "タスク {remaining_task_id}" in templates[("breezing", "ja")]

forbidden_ja_labels = {
    "Task": re.compile(r"\bTask\b"),
    "Before": re.compile(r"\bBefore:"),
    "After": re.compile(r"\bAfter:"),
    "files": re.compile(r"\bfiles?\b", re.IGNORECASE),
    "tasks": re.compile(r"\btasks?\b", re.IGNORECASE),
    "files changed": re.compile(r"\bfiles changed\b", re.IGNORECASE),
    "insertions": re.compile(r"\binsertions?\b", re.IGNORECASE),
    "deletions": re.compile(r"\bdeletions?\b", re.IGNORECASE),
    "commit": re.compile(r"\bcommit\b", re.IGNORECASE),
    "review": re.compile(r"\breview\b", re.IGNORECASE),
}
for mode in ("solo", "breezing"):
    human_text = placeholder_pattern.sub("", templates[(mode, "ja")])
    for label, pattern in forbidden_ja_labels.items():
        assert not pattern.search(human_text), (
            f"{mode} Japanese template retains English human-facing label: {label}"
        )


def resolve_locale(explicit: str) -> str:
    with tempfile.TemporaryDirectory() as tmpdir:
        missing_config = Path(tmpdir) / "missing.yaml"
        env = os.environ.copy()
        env.pop("CLAUDE_CODE_HARNESS_LANG", None)
        env["CONFIG_FILE"] = str(missing_config)
        return subprocess.check_output(
            [
                "bash",
                "-c",
                'source "$1"; get_harness_locale "$2"',
                "_",
                str(root / "scripts/config-utils.sh"),
                explicit,
            ],
            env=env,
            text=True,
        ).strip()


resolved = {
    "unset": resolve_locale(""),
    "en": resolve_locale("en"),
    "ja": resolve_locale("ja"),
}
assert resolved == {"unset": "en", "en": "en", "ja": "ja"}, resolved

for case, locale in resolved.items():
    chosen = templates[("breezing", locale)]
    if case in {"unset", "en"}:
        assert "Breezing complete" in chosen, f"{case} did not select English"
        assert not japanese_script.search(chosen), f"{case} selected Japanese labels"
    else:
        assert "Breezing 完了" in chosen, "explicit ja did not select Japanese"

contract_doc = (root / "docs/i18n-language-contract.md").read_text(encoding="utf-8")
assert "## Skill Body And Completion Report Contract" in contract_doc
assert "Japanese input alone does not select a Japanese completion template." in contract_doc

print("harness-work completion report locale contract ok")
PY

echo "✓ harness-work completion reports default to English and preserve explicit Japanese"
