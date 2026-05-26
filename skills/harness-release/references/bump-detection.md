# Bump Level Detection

Logic for estimating the bump level (patch/minor/major) from the contents of the `[Unreleased]` section.

## Detection Rules

Scan all `### <category>` headings directly under `[Unreleased]` and determine the level by the following priority:

```
1. "### Breaking Changes" is present                    → major
2. "### Removed" is present                             → major
3. "### Added" is present (none of the above)           → minor
4. "### Deprecated" is present (none of the above)      → minor
5. Only "### Fixed" / "### Changed" / "### Security"    → patch
6. No subsections at all (empty)                        → error
```

## Implementation

```python
import re

def detect_bump(changelog_text: str) -> str:
    """Return 'major' | 'minor' | 'patch'. Raises on empty [Unreleased]."""
    # Extract the [Unreleased] section
    m = re.search(
        r"## \[Unreleased\]\s*\n(.*?)(?=\n## \[|\Z)",
        changelog_text,
        re.S,
    )
    if not m:
        raise RuntimeError("[Unreleased] section not found")
    body = m.group(1).strip()
    if not body:
        raise RuntimeError("[Unreleased] is empty. Nothing to release")

    # Collect headings
    headings = set(re.findall(r"^### (.+?)\s*$", body, re.M))

    if "Breaking Changes" in headings or "Removed" in headings:
        return "major"
    if "Added" in headings or "Deprecated" in headings:
        return "minor"
    if headings & {"Fixed", "Changed", "Security"}:
        return "patch"
    raise RuntimeError(f"No recognized subsections found in [Unreleased]: {headings}")
```

## Why is Deprecated a minor bump?

Per the Keep a Changelog spec, Deprecated is "a notice that something will be Removed in the future".
It has the same user impact as a new feature or change, so it is treated as minor.
When the actual Removed happens, it escalates to major.

## User Override

If `/release patch|minor|major` is explicitly specified, skip this automatic detection and use the given value.
However, if the **bump target section is empty**, abort even with an override (there is nothing to release).

## Unrecognized Spelling Variations

The following are not recognized:

| Commonly written | Correct heading |
|------------------|-----------------|
| `### Features` | `### Added` |
| `### Bug Fixes` / `### Fix` | `### Fixed` |
| `### BREAKING CHANGE` / `### Breaking` | `### Breaking Changes` |
| `### Enhancements` | `### Changed` or `### Added` |

Align to KaCL standard headings before calling `/release`.
If unrecognized headings are detected before the gate, emit a warning and prompt the user to fix them.

## Handling pre-release / build metadata

If the current version has a pre-release suffix such as `1.0.0-alpha.1`, this skill:

1. Ignores the suffix for bump calculation (`1.0.0-alpha.1` → patch → `1.0.1`)
2. Discards the suffix (does not produce `1.0.1-alpha.1`)

Specifying an override bump does not change this behavior.
Projects that intentionally want to stay on a pre-release are not supported by this skill.

## Handling an empty [Unreleased]

If `/release` is called with an empty `[Unreleased]`, suggest the following:

- "Nothing to release. Add `### Fixed` or similar to `[Unreleased]`, or if you want a maintenance release with only a marker, consider the `--empty` flag."

`--empty` flag is not supported by this skill (empty releases are not created by default).
