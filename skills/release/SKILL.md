---
name: release
description: "Automates release process: CHANGELOG update, version bump, and tag creation. Use when user mentions release, version bump, or tag creation. Do NOT load for: release planning discussions, version number mentions, 'ship it' casual talk."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[patch|minor|major]"
disable-model-invocation: true
---

# Release Skill

Automates the claude-code-harness release process.

## Quick Reference

- "**Release a new version**" → `/release`
- "**Bump patch version**" → `/release patch`
- "**Create a minor release**" → `/release minor`

---

## Execution Flow

### Step 1: Change Verification

Run in parallel:
1. `git status` - Check uncommitted changes
2. `git diff --stat` - List changed files
3. `git log --oneline -10` - Recent commit history

### Step 2: Version Determination

Check current version:
```bash
cat VERSION
```

Determine version based on changes ([Semantic Versioning](https://semver.org/)):
- **patch** (x.y.Z): Bug fixes, minor improvements
- **minor** (x.Y.0): New features (backward compatible)
- **major** (X.0.0): Breaking changes

Ask user: "What should the next version be? (e.g., 2.5.23)"

### Step 3: CHANGELOG Update (JP + EN)

**Follow [Keep a Changelog](https://keepachangelog.com/) format**

Update both `CHANGELOG_ja.md` (Japanese) and `CHANGELOG.md` (English).

Add new version entry after `## [Unreleased]`:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing features

### Fixed
- Bug fixes

### Deprecated
- Features to be removed

### Removed
- Removed features

### Security
- Security fixes
```

### Step 3.5: README Update Check

> Check if README needs update (JP/EN both)

### Step 4: Version File Update

```bash
echo "X.Y.Z" > VERSION
```

### Step 5: Commit and Tag

```bash
git add -A
git commit -m "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

### Step 6: Push

```bash
git push origin main
git push origin vX.Y.Z
```

### Step 7: GitHub Release (Optional)

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z - Title" \
  --notes "$(cat <<'EOF'
## 🎯 What's Changed for You
...
EOF
)"
```

---

## GitHub Release Format

Follow `.claude/rules/github-release.md`:

```markdown
## 🎯 What's Changed for You

**One-line value description**

### Before → After

| Before | After |
|--------|-------|
| Previous state | New state |

---

## Added / Changed / Fixed

- **Feature**: Description

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Related Skills

- `verify` - Pre-release verification
- `docs` - Documentation updates
