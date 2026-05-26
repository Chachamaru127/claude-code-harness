#!/usr/bin/env bash
#
# Verify every shipped skill surface uses English-only metadata.
# The project is now English-only: description-ja fields must NOT exist.
# Phase 1.5: restricted to active skills/ surface only (codex/opencode archived).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

bash scripts/i18n/check-translations.sh

python3 - <<'PY'
import subprocess
from pathlib import Path

SURFACES = [
    Path("skills"),
]


def is_git_ignored(path: Path) -> bool:
    result = subprocess.run(
        ["git", "check-ignore", "-q", "--", str(path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


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


skill_count = 0
for surface in SURFACES:
    files = [path for path in sorted(surface.glob("*/SKILL.md")) if not is_git_ignored(path)]
    assert files, f"{surface}: no SKILL.md files found"
    for path in files:
        skill_count += 1
        meta = frontmatter(path)
        # English-only: description and description-en must exist and be equal
        for key in ("description", "description-en"):
            assert meta.get(key), f"{path}: missing or empty {key}"
        assert meta["description"] == meta["description-en"], (
            f"{path}: description must equal description-en (English-only)"
        )
        # English-only: description-ja must NOT be present
        assert "description-ja" not in meta, (
            f"{path}: description-ja must not exist in English-only mode"
        )

print(f"validated {skill_count} shipped skill files (English-only)")
PY

echo "✓ shipped skill frontmatter is English-only (no description-ja)"
