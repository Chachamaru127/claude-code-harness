#!/usr/bin/env python3
import re
import sys
from urllib.parse import urlparse, parse_qs

ID_RE = re.compile(r"^[a-zA-Z0-9_-]{10,}$")

PATTERNS = [
    ("sheet", re.compile(r"docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_-]+)")),
    ("doc", re.compile(r"docs\.google\.com/document/d/([a-zA-Z0-9_-]+)")),
    ("slide", re.compile(r"docs\.google\.com/presentation/d/([a-zA-Z0-9_-]+)")),
    ("file", re.compile(r"drive\.google\.com/file/d/([a-zA-Z0-9_-]+)")),
    ("folder", re.compile(r"drive\.google\.com/.*/folders/([a-zA-Z0-9_-]+)")),
]


def extract_id(value: str):
    value = value.strip()
    if not value:
        return None

    for kind, pattern in PATTERNS:
        m = pattern.search(value)
        if m:
            return kind, m.group(1)

    # Try query params (e.g., drive.google.com/open?id=...)
    try:
        parsed = urlparse(value)
        query = parse_qs(parsed.query)
        if "id" in query and query["id"]:
            return "id", query["id"][0]
    except Exception:
        pass

    if ID_RE.match(value):
        return "id", value

    return "unknown", value


def main():
    args = sys.argv[1:]
    if not args:
        args = [line.strip() for line in sys.stdin if line.strip()]

    for item in args:
        kind, file_id = extract_id(item)
        print(f"{kind}\t{file_id}")


if __name__ == "__main__":
    main()
