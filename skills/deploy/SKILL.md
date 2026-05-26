---
name: deploy
description: "Deploy to Vercel/Netlify. One-way ticket to production arranged. Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Monitor"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[vercel|netlify|health]"
context: fork
---

# Deploy Skills

Skills for deployment and monitoring configuration.

## Feature Details

| Feature | Details |
|---------|---------|
| **Deployment setup** | See [references/deployment-setup.md](${CLAUDE_SKILL_DIR}/references/deployment-setup.md) |
| **Analytics** | See [references/analytics.md](${CLAUDE_SKILL_DIR}/references/analytics.md) |
| **Health checking** | See [references/health-checking.md](${CLAUDE_SKILL_DIR}/references/health-checking.md) |

## Execution Steps

1. Classify the user's request
2. Read the appropriate reference file from "Feature Details" above
3. Configure according to its contents
