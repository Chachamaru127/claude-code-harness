#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT_DIR" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path

root = Path(sys.argv[1])
files = [root / "README.md", root / "README_ja.md"]
blocked = {
    "docs/images/hokage/hokage-hero.jpg",
    "assets/readme-visuals-ja/safety-shield.svg",
}

class ImageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            self.images.append(dict(attrs))

errors = []
for file in files:
    parser = ImageParser()
    parser.feed(file.read_text())
    for image in parser.images:
        src = image.get("src", "")
        if not src or src.startswith("http://") or src.startswith("https://"):
            continue
        if src in blocked:
            errors.append(f"{file.name}: blocked image still referenced: {src}")
        if not (root / src).exists():
            errors.append(f"{file.name}: missing local image: {src}")

text = "\n".join(file.read_text() for file in files)
required = {
    "README.md": "docs/images/readme/loop-en.svg",
    "README_ja.md": "docs/images/readme/loop-ja.svg",
}
for file in files:
    expected = required[file.name]
    if expected not in file.read_text():
        errors.append(f"{file.name}: missing approved operating-loop hero image: {expected}")

if "docs/images/hokage/hokage-hero.jpg" in text:
    errors.append("obsolete hero path still present")
if "Hokage" in text:
    errors.append("internal code-name still present in README surface")

if errors:
    for error in errors:
        print(f"test-readme-image-assets: FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("test-readme-image-assets: ok")
PY
