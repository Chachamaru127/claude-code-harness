# Codex Mode Toggle

> **Status: Experimental**
>
> Codex モードは実験段階の機能です。本番環境での使用前にテストを推奨します。

Toggle Codex mode (parallel delegation to GPT experts) during reviews.

## Usage

```bash
/codex-mode           # Show current state
/codex-mode on        # Enable Codex mode
/codex-mode off       # Disable Codex mode
/codex-mode status    # Show detailed settings
```

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

## Toggle Operations

### Show State (`/codex-mode`)

```markdown
## Codex Mode Settings

Current: **OFF** (default mode)

Reviewer: Claude alone
Codex MCP: Configured

Toggle: `/codex-mode on` to enable
```

### Enable (`/codex-mode on`)

```markdown
## Codex Mode: ON

Codex mode enabled

Active experts:
- Security
- Accessibility
- Performance
- Quality
- SEO
- Architect
- Plan Reviewer
- Scope Analyst

Next `/harness-review` will delegate to Codex in parallel.
```

### Disable (`/codex-mode off`)

```markdown
## Codex Mode: OFF

Returned to default mode

Next `/harness-review` will run with Claude alone.
```

## Config File Update

This updates `.claude-code-harness.config.yaml`:

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

Enable/disable specific experts:

```bash
# Disable Security only (keep others)
/codex-mode experts security off

# Enable only Architect and Plan Reviewer
/codex-mode experts architect on
/codex-mode experts plan_reviewer on
```
