# Test Suite

This directory contains tests that ensure the quality of the claude-code-harness plugin.

## Tests for VibeCoder

These are simple tests designed for a **VibeCoder working alone on client projects** to quickly verify that the plugin is working correctly — no enterprise-level complexity required.

## How to Run Tests

### Plugin Structure Validation

Validates that the plugin's basic structure is correct:

```bash
./tests/validate-plugin.sh
./tests/validate-plugin-v3.sh
./scripts/ci/check-consistency.sh
```

### Unified Memory Validation

Validates the basic operation of the shared memory daemon:

```bash
./tests/test-memory-daemon.sh
```

Runs a loop to check that no zombie processes remain:

```bash
./tests/test-memory-daemon-zombie.sh 100
```

Validates search quality (hybrid ranking / privacy filter / API routes):

```bash
./tests/test-memory-search-quality.sh
```

These checks verify the following:

1. **Plugin structure**: Existence and validity of plugin.json
2. **Commands**: Existence of registered command files
3. **Skills**: Existence and basic quality of skill definitions
4. **Agents**: Existence of agent definitions
5. **Hooks**: Validity of hooks.json
6. **Scripts**: Existence and execute permissions of automation scripts
7. **Documentation**: Required documentation such as README

### Expected Output

```
==========================================
Claude harness - Plugin Validation Test
==========================================

1. Plugin structure validation
----------------------------------------
✓ plugin.json exists
✓ plugin.json is valid JSON
✓ plugin.json has a name field
✓ plugin.json has a version field
...

==========================================
Test Result Summary
==========================================
Passed: 25
Warnings: 1
Failed: 0

✓ All tests passed!
```

## Adding Tests

When adding new commands or skills, run these tests to verify the structure is correct.

## Use in CI/CD

GitHub Actions runs `.github/workflows/validate-plugin.yml` which executes:

- `./tests/validate-plugin.sh`
- `./scripts/ci/check-consistency.sh`
- `./tests/test-codex-package.sh`
- `cd core && npm test`

The `/harness-work all` success / failure fixtures for smoke / full are managed separately. See [docs/evidence/work-all.md](../docs/evidence/work-all.md) for details.

## Troubleshooting

### jq command not found

Test scripts use the `jq` command. If it is not installed:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (WSL)
sudo apt-get install jq
```

### When tests fail

1. Check the error message
2. Verify that the relevant file exists
3. Check for syntax errors in JSON files

## Key Points for VibeCoder

- **Simple**: No complex test framework needed
- **Practical**: Detects structural errors that actually cause problems
- **Fast**: Completes in a few seconds
- **Clear**: Results are immediately understandable

These tests are meant to quickly verify that nothing is broken after changing the plugin.
