#!/usr/bin/env python3
"""Count bare Japanese string literals in go/internal/hookhandler.

The awk-based counter matched em dashes and box-drawing characters under
mawk (the default awk on Debian/Ubuntu), so the gate failed on Instabox even
though those literals are not Japanese. This matcher uses explicit Unicode
ranges and the same localizer-span rules as before.
"""
import re
import sys
from pathlib import Path

JAPANESE = re.compile(r'"[^"\n]*[\u3041-\u309f\u30a0-\u30ff\u4e00-\u9fff][^"\n]*"')
LOCALIZER = re.compile(r"localizedHarnessMessage\s*\(")


def strip_line_comment(line: str) -> str:
    in_double = in_raw = escaped = False
    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_double:
            escaped = True
            continue
        if char == '"' and not in_raw:
            in_double = not in_double
            continue
        if char == "`" and not in_double:
            in_raw = not in_raw
            continue
        if char == "/" and not in_double and not in_raw and line[index + 1 : index + 2] == "/":
            return line[:index]
    return line


def count_bare(root: Path) -> int:
    handler = root / "go/internal/hookhandler"
    if not handler.is_dir():
        return 0
    count = 0
    for path in sorted(handler.glob("*.go")):
        if path.name.endswith("_test.go"):
            continue
        depth = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            code = strip_line_comment(line)
            in_call = depth > 0
            opens_call = bool(LOCALIZER.search(code))
            if not in_call and not opens_call and JAPANESE.search(code):
                count += 1
            if opens_call or in_call:
                depth += code.count("(") - code.count(")")
                if depth < 0:
                    depth = 0
    return count


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    print(count_bare(root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
