# Contributing to claude-code-harness

Thank you for your interest in contributing to **claude-code-harness**! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in [GitHub Issues](https://github.com/Chachamaru127/claude-code-harness/issues)
2. If not, create a new issue with:
   - Clear title describing the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Claude Code version and OS

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test your changes locally
5. Commit with clear messages: `git commit -m "feat: add new feature"`
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request

### Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

### Code Style

- Use clear, descriptive names
- Add comments for complex logic
- Keep commands/agents/skills focused on single responsibilities

## Plugin Structure

```
claude-code-harness/
├── .claude-plugin/
│   ├── plugin.json      # Plugin manifest
│   └── marketplace.json # Marketplace config
├── skills/              # Skills (primary - v2.17.0+)
├── agents/              # Subagents
├── hooks/               # Lifecycle hooks
├── templates/           # Template files
├── README.md
├── LICENSE
└── CONTRIBUTING.md
```

> **Note**: As of v2.17.0, commands have been migrated to skills. Skills are the recommended approach for new functionality.

### Adding a New Skill (Recommended)

1. Create `skills/your-skill/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: your-skill
   description: "Description with trigger phrases. Use when... Do NOT load for..."
   allowed-tools: ["Read", "Write", "Edit", "Bash"]
   ---
   ```
2. Add supporting files to `skills/your-skill/references/` if needed
3. Update README.md with the new skill

### Adding a New Agent

1. Create `agents/your-agent.md`
2. Define the agent with YAML frontmatter
3. Update README.md (recommended)

> Note: agents/ are auto-discovered by Claude Code. You typically do not need to manually enumerate them in `plugin.json`.

## Version Management

Version is defined in two places that must stay in sync:
- `VERSION` - Source of truth
- `.claude-plugin/plugin.json` - Used by plugin system

Normal feature/docs PRs should leave both files unchanged and record user-facing changes in `CHANGELOG.md` under `[Unreleased]`.
Use a version bump only when you are intentionally cutting a release.

### Version Scripts

```bash
# Check if versions are in sync
./scripts/sync-version.sh check

# Sync plugin.json to VERSION
./scripts/sync-version.sh sync

# Bump patch version for a release (e.g., 2.0.0 → 2.0.1)
./scripts/sync-version.sh bump
```

### Release-only Versioning Policy

- Normal PRs: do not edit `VERSION` or `.claude-plugin/plugin.json`; add notes under `[Unreleased]`
- Release work: run `./scripts/sync-version.sh bump`, add a versioned `CHANGELOG.md` entry, then create the tag / GitHub Release
- The repo pre-commit hook only syncs `plugin.json` to `VERSION` when you intentionally edit release metadata; it does not auto-bump patch versions

### Version Consistency Checks

- **Local (recommended)**: run `./scripts/sync-version.sh check` before committing
- **CI (recommended)**: run `./tests/validate-plugin.sh` and `./scripts/ci/check-consistency.sh` on PRs

## CHANGELOG Entry Rules (Required)

**Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format**

Each version entry uses these sections:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Features being removed soon

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Vulnerability-related fixes

#### Before/After (major changes only)

| Before | After |
|--------|-------|
| Previous state | New state |
```

**Section guide**:

| Section | Use when |
|------------|----------|
| Added | Added a completely new feature |
| Changed | Changed existing behavior or experience |
| Deprecated | Announcing a future removal |
| Removed | Removed a feature or command |
| Fixed | Fixed a bug or defect |
| Security | Security-related fix |

**Before/After table**: Add only for major UX changes (command removal/merge, workflow change, breaking change). Omit for minor fixes.

**Version comparison links**: Add `[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` at the end of CHANGELOG.md

---

## Testing

Before submitting:

1. Validate plugin structure and consistency:

   ```bash
   ./tests/validate-plugin.sh
   ./scripts/ci/check-consistency.sh
   ```

2. (Recommended) Enable pre-commit hooks (keep release metadata in sync without auto-bumping):

   ```bash
   ./scripts/install-git-hooks.sh
   ```

   **Windows users**: Git hooks require [Git for Windows](https://gitforwindows.org/) which includes Git Bash. The hooks run automatically via Git Bash regardless of your shell (PowerShell, CMD, etc.).

3. Test locally in a separate project using `--plugin-dir`:

   ```bash
   cd /path/to/your-project
   claude --plugin-dir /path/to/claude-code-harness
   ```

3. Verify commands work as expected (`/help`), and the core loop runs:

   - `/harness-init`
   - `/plan-with-agent`
   - `/work`
   - `/harness-review`

## Questions?

- Open an issue for questions
- Check existing documentation

Thank you for contributing!
