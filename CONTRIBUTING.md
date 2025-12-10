# Contributing to cursor-cc-plugins

Thank you for your interest in contributing to cursor-cc-plugins! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in [GitHub Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
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
cursor-cc-plugins/
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
3. Add to `plugin.json` agents array
4. Update README.md

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

# Bump patch version (0.3.1 → 0.3.2)
./scripts/sync-version.sh bump
```

### Pre-commit Hook

A pre-commit hook automatically checks version consistency. If `VERSION` or `plugin.json` is modified and they don't match, the commit will fail.

To fix: `./scripts/sync-version.sh sync`

---

## Testing

Before submitting:

1. Install the plugin locally:
   ```bash
   /plugin marketplace add ./path/to/cursor-cc-plugins
   /plugin install cursor-cc-plugins
   ```

2. Test commands work as expected
3. Verify no errors in plugin loading

## Questions?

- Open an issue for questions
- Check existing documentation

Thank you for contributing!
