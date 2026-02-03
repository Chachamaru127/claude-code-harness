---
name: harness-mem
description: "Claude-mem integration setup for cross-session memory and learning. Use when user mentions '/harness-mem', claude-mem integration, cross-session memory, or memory setup. Do NOT load for: app memory/storage features, casual 'remember this' requests."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[setup|status]"
---

# Harness-Mem Skill

Customize Claude-mem for harness specifications to enhance cross-session quality and context maintenance.

## Quick Reference

- "**Integrate with Claude-mem**" → this skill
- "**Enable cross-session memory**" → this skill
- "**Set up harness-mem**" → this skill

## Deliverables

- **Harness-specific mode settings for Claude-mem**: Auto-record guardrail activations, Plans.md updates, and SSOT changes
- **Cross-session learning**: Utilize past mistakes and solutions in future sessions
- **Japanese localization option**: Record observations and summaries in Japanese

## Prerequisites

Claude-mem plugin must be installed. If not installed, this skill will support the installation.

---

## Execution Flow

### Step 0: OS Detection

```bash
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
  OS_TYPE="windows"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="mac"
else
  OS_TYPE="linux"
fi
```

### Step 1: Bun Installation Check

Claude-mem v7.3.7+ uses Bun-based workers.

```bash
if command -v bun &> /dev/null; then
  echo "Bun is installed: $(bun --version)"
else
  echo "Bun is not installed"
fi
```

**If Bun not installed, offer installation:**

**macOS / Linux / WSL**:
```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
bun --version
```

**Windows (PowerShell)**:
```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
# Or: npm install -g bun
bun --version
```

### Step 2: Claude-mem Installation Check

```bash
if [ -d "$HOME/.claude/plugins/claude-mem" ]; then
  echo "Claude-mem is installed"
else
  echo "Claude-mem not found"
fi
```

**If not installed:**

> Claude-mem is not installed.
>
> Install now?
> 1. Yes - Install from npm
> 2. Manual - Show installation instructions

### Step 3: Configure Harness Mode

Create/update `.claude-mem.config.yaml`:

```yaml
# Harness-specific Claude-mem configuration
mode: harness

# Auto-recording settings
auto_record:
  guardrail_activations: true
  plans_updates: true
  ssot_changes: true
  review_results: true

# Learning settings
learning:
  enabled: true
  store_failures: true
  store_solutions: true

# Localization
locale: ja  # or 'en'

# Memory paths
paths:
  observations: .claude/memory/observations.md
  summaries: .claude/memory/summaries.md
  decisions: .claude/memory/decisions.md
```

### Step 4: Verify Integration

```bash
# Check Claude-mem is running
claude-mem status

# Verify harness mode
grep "mode: harness" .claude-mem.config.yaml
```

## Features

### Auto-Recording

| Event | Recorded Data |
|-------|---------------|
| Guardrail activation | Rule violated, context, resolution |
| Plans.md update | Task changes, status transitions |
| SSOT change | Decision records, pattern additions |
| Review result | Issues found, fixes applied |

### Cross-Session Learning

```
Session N: Error "User type not found"
  → Recorded: "Check User type definition before implementation"

Session N+1: Similar task detected
  → Retrieved: Past error and solution
  → Applied: Pre-check User type definition
  → Result: Success without error
```

### Japanese Localization

When `locale: ja`:
- Observations recorded in Japanese
- Summaries generated in Japanese
- Maintains consistency with Japanese SSOT files

## Troubleshooting

### Claude-mem not recording

**Cause**: Harness mode not configured

**Solution**:
```bash
# Verify config
cat .claude-mem.config.yaml | grep mode

# Should show: mode: harness
```

### Memory not persisting

**Cause**: Paths not configured

**Solution**: Ensure paths are set in config and directories exist:
```bash
mkdir -p .claude/memory
```

## Related Skills

- `memory` - SSOT and Plans.md management
- `session` - Session management
