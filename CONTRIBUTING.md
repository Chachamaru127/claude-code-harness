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
├── commands/            # Slash commands
├── agents/              # Subagents
├── skills/              # Agent skills
├── hooks/               # Lifecycle hooks
├── templates/           # Template files
├── README.md
├── LICENSE
└── CONTRIBUTING.md
```

### Adding a New Command

1. Create `commands/your-command.md`
2. Follow the existing command structure
3. Update README.md with the new command

### Adding a New Agent

1. Create `agents/your-agent.md`
2. Define the agent with YAML frontmatter
3. Update README.md (recommended)

> Note: agents/ are auto-discovered by Claude Code. You typically do not need to manually enumerate them in `plugin.json`.

### Adding a New Skill

1. Create `skills/your-skill/SKILL.md`
2. Define trigger phrases
3. Update README.md

## Version Management

Version is defined in two places that must stay in sync:
- `VERSION` - Source of truth
- `.claude-plugin/plugin.json` - Used by plugin system

### Version Scripts

```bash
# Check if versions are in sync
./scripts/sync-version.sh check

# Sync plugin.json to VERSION
./scripts/sync-version.sh sync

# Bump patch version (e.g., 2.0.0 → 2.0.1)
./scripts/sync-version.sh bump
```

### Version Consistency Checks

- **Local (recommended)**: run `./scripts/sync-version.sh check` before committing
- **CI (recommended)**: run `./tests/validate-plugin.sh` and `./scripts/ci/check-consistency.sh` on PRs

## CHANGELOG 記載ルール（必須）

**[Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) フォーマットに準拠**

各バージョンエントリには以下のセクションを使用:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- 新機能について

### Changed
- 既存機能の変更について

### Deprecated
- 間もなく削除される機能について

### Removed
- 削除された機能について

### Fixed
- バグ修正について

### Security
- 脆弱性に関する場合

#### Before/After（大きな変更時のみ）

| Before | After |
|--------|-------|
| 変更前の状態 | 変更後の状態 |
```

**セクション使い分け**:

| セクション | 使うとき |
|------------|----------|
| Added | 完全に新しい機能を追加したとき |
| Changed | 既存機能の動作や体験を変更したとき |
| Deprecated | 将来削除予定の機能を告知するとき |
| Removed | 機能やコマンドを削除したとき |
| Fixed | バグや不具合を修正したとき |
| Security | セキュリティ関連の修正をしたとき |

**Before/After テーブル**: 大きな体験変化（コマンド廃止・統合、ワークフロー変更、破壊的変更）があるときのみ追加。軽微な修正では省略可。

**バージョン比較リンク**: CHANGELOG.md 末尾に `[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` 形式で追加

---

## Testing

Before submitting:

1. Validate plugin structure and consistency:

   ```bash
   ./tests/validate-plugin.sh
   ./scripts/ci/check-consistency.sh
   ```

2. (Recommended) Enable pre-commit hooks (auto bump patch version when code changes):

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
