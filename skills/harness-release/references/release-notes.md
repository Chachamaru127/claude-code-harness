# Release Notes Format

Rules for converting a CHANGELOG `## [X.Y.Z]` section into GitHub Release notes.

## Language

- **GitHub Release notes: English** (standard for public repositories)
- **CHANGELOG.md: Japanese** (when the project's primary language is Japanese)

If CHANGELOG is written in Japanese, an English translation is required when creating the GitHub Release.
The skill calls Claude to generate a draft and has the user review it at the Confirmation Gate.

## Required Elements

```markdown
## What's Changed

**<1-line value summary>**

### Before / After

| Before | After |
|--------|-------|
| <previous UX> | <new UX> |

---

### Added
- <item>

### Changed
- <item>

### Fixed
- <item>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## How to Generate Each Element

### "What's Changed" Summary

Extract from the `### Theme` line in the CHANGELOG `[X.Y.Z]` section.
If absent, summarize in one sentence from the first item in Added/Changed/Fixed.

### Before / After Table

Extract from the "Before / After" descriptions in the CHANGELOG.
If absent, infer from:
- Fixed items → `<bug description>` vs `Fixed`
- Added items → `<feature> was not available` vs `Now available`
- Changed items → `<old behavior>` vs `<new behavior>`

### Added / Changed / Fixed

Translate and copy the relevant CHANGELOG sections directly.

### Footer

Fixed: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## GitHub Release Creation Command

```bash
gh release create "v$NEW_VERSION" \
  --title "v$NEW_VERSION - <1-line summary>" \
  --notes "$(cat <<'EOF'
<release notes body>
EOF
)"
```

## Draft Review

At the Confirmation Gate, show the following:

```
GitHub Release Preview:
━━━━━━━━━━━━━━━━━━━━━━
Title: v4.0.4 - Fix CI validation gap
Body (first 20 lines):

  ## What's Changed

  **Fixed a gap in validate-plugin.sh ...**
  ...

(Full body: 45 lines)
━━━━━━━━━━━━━━━━━━━━━━
```

If the user instructs "revise: ...", regenerate.

## Validation

Before `gh release create`, check that the Release Notes satisfy:

1. `## What's Changed` section exists
2. A **bold summary** line exists
3. A `### Before / After` table exists
4. Footer `Generated with [Claude Code]` exists

If any check fails, return to the gate and prompt for fixes.

## Consolidating Multiple Changes

When the CHANGELOG `[X.Y.Z]` has two or more features:

- Title: Use the most important one as representative (or "Multiple fixes and improvements")
- Body: Split each feature into `### N. <feature name>` sections with English translation

Releasing multiple versions on the same day is not recommended (see versioning.md). Batch releases into one.
