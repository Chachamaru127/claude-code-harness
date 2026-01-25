---
description: Toggle Codex mode on/off for reviews
---

# /codex-mode - Toggle Codex Mode

Toggles Codex mode (parallel delegation to GPT experts) during reviews.

## Usage

```bash
/codex-mode           # Show current state
/codex-mode on        # Enable Codex mode
/codex-mode off       # Disable Codex mode
/codex-mode status    # Show detailed settings
```

## Prerequisites

- Codex MCP server is configured
- Setup completed with `/codex-review` or `/harness-review`

## What is Codex Mode

| Mode | Reviewer | Characteristics |
|------|----------|-----------------|
| **Default** | Claude alone | Fast, no Codex required |
| **Codex mode** | Codex (GPT) | Parallel delegation to 9 experts |

### Codex Mode's 9 Experts

| Expert | Role | Perspective |
|--------|------|-------------|
| Security | Security analysis | OWASP Top 10, authentication/authorization |
| Accessibility | a11y check | WCAG 2.1 AA compliance |
| Performance | Performance analysis | Rendering, DB queries |
| Quality | Code quality | Readability, maintainability |
| SEO | SEO/OGP check | Meta tags, structured data |
| Architect | Design review | Architectural decisions |
| Plan Reviewer | Plan verification | Completeness, risk analysis |
| Scope Analyst | Requirements analysis | Ambiguity, gap detection |

## Execution Flow

### 1. Show State (`/codex-mode`)

```markdown
## Codex Mode Settings

Current: **OFF** (default mode)

Reviewer: Claude alone
Codex MCP: ✅ Configured

Toggle: `/codex-mode on` to enable
```

### 2. Enable (`/codex-mode on`)

```markdown
## Codex Mode: ON

✅ Codex mode enabled

Active experts:
- ✅ Security
- ✅ Accessibility
- ✅ Performance
- ✅ Quality
- ✅ SEO
- ✅ Architect
- ✅ Plan Reviewer
- ✅ Scope Analyst

Next `/harness-review` will delegate to Codex in parallel.
```

### 3. Disable (`/codex-mode off`)

```markdown
## Codex Mode: OFF

✅ Returned to default mode

Next `/harness-review` will run with Claude alone.
```

### 4. Show Details (`/codex-mode status`)

```markdown
## Codex Mode Detailed Settings

| Setting | Current Value |
|---------|---------------|
| Mode | codex |
| Judgment output | enabled |
| Auto-fix | enabled |
| Max retries | 3 |

### Expert Settings

| Expert | State |
|--------|-------|
| security | ✅ ON |
| accessibility | ✅ ON |
| performance | ✅ ON |
| quality | ✅ ON |
| seo | ✅ ON |
| architect | ✅ ON |
| plan_reviewer | ✅ ON |
| scope_analyst | ✅ ON |

### Individual Toggle

```bash
/codex-mode experts security off   # Disable Security only
/codex-mode experts architect on   # Enable Architect only
```
```

## Config File Update

This command updates `.claude-code-harness.config.yaml`.

```yaml
review:
  mode: codex  # default | codex
  judgment:
    enabled: true
    auto_fix: true
    max_retries: 3
  codex:
    enabled: true
    auto: true
    experts:
      security: true
      accessibility: true
      performance: true
      quality: true
      seo: true
      architect: true
      plan_reviewer: true
      scope_analyst: true
```

## Individual Expert Settings

You can enable/disable specific experts only.

```bash
# Disable Security only (keep others)
/codex-mode experts security off

# Enable only Architect and Plan Reviewer
/codex-mode experts architect on
/codex-mode experts plan_reviewer on
```

## VibeCoder Phrases

| What You Want | How to Say |
|---------------|------------|
| Want to use Codex | "Switch to Codex mode" |
| Return to normal | "Return to default" |
| Check settings | "Show Codex settings" |
| Disable security only | "I don't need the security check" |

## Related Commands

- `/harness-review` - Run review (Codex mode supported)
- `/codex-review` - Codex MCP setup
