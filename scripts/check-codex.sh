#!/bin/bash
# check-codex.sh - Codex availability check (for once hook)
# Runs once on first /harness-review invocation
#
# Usage: ./scripts/check-codex.sh

set -euo pipefail

# Path to the project configuration file
CONFIG_FILE=".claude-code-harness.config.yaml"

# Check if codex.enabled is already configured
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "codex:" "$CONFIG_FILE" 2>/dev/null; then
        # Already configured, nothing to do
        exit 0
    fi
fi

# Check if Codex CLI is installed
if ! command -v codex &> /dev/null; then
    # Codex not present, nothing to do
    exit 0
fi

# Get Codex version
CODEX_VERSION=$(codex --version 2>/dev/null | head -1 || echo "unknown")

# Get the latest version from npm (unknown if network is unavailable)
LATEST_VERSION=$(npm show @openai/codex version 2>/dev/null || echo "unknown")

# Version comparison function
version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Notify user that Codex was found
cat << EOF

🤖 Codex detected

**Installed version**: ${CODEX_VERSION}
**Latest version**: ${LATEST_VERSION}
EOF

# Warn if version is outdated
if [[ "$LATEST_VERSION" != "unknown" && "$CODEX_VERSION" != "unknown" ]]; then
    # Extract numeric version from version string
    CURRENT_NUM=$(echo "$CODEX_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
    LATEST_NUM=$(echo "$LATEST_VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")

    if version_lt "$CURRENT_NUM" "$LATEST_NUM"; then
        cat << EOF

⚠️ **Codex CLI is outdated**

To update:
\`\`\`bash
codex update
\`\`\`

Only fall back to a package manager (e.g. \`npm update -g @openai/codex\`)
if your installation is too old to support \`codex update\`.

EOF
    fi
fi

# Check for timeout / gtimeout (macOS compatibility)
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

if [[ -z "$TIMEOUT_CMD" ]]; then
    cat << 'EOF'

⚠️ **timeout command not found**

Codex CLI parallel review uses the `timeout` command for timeout control.
macOS does not include it by default; install it with:

```bash
brew install coreutils
```

This provides `gtimeout`, which Harness detects automatically.
Codex still works without it, but timeout control will be disabled.

EOF
else
    echo ""
    echo "**Timeout command**: \`${TIMEOUT_CMD}\` ✅"
fi

cat << 'EOF'

To enable second-opinion review:

```yaml
# .claude-code-harness.config.yaml
review:
  codex:
    enabled: true
    # model is usually omitted, letting Codex CLI default metadata decide
    # specify only when a fixed model is required for validation or org allowlist
```

Or run `/codex-review` to trigger a Codex review individually

Details: skills/codex-review/SKILL.md

EOF

exit 0
