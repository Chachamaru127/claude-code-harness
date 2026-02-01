# Webhook Setup Reference

Setup GitHub Actions webhook triggers for automation, including PR auto-review.

## Quick Reference

- "**PR自動レビューしたい**" → Webhook setup
- "**CI でハーネス使いたい**" → Webhook triggers
- "**自動化したい**" → GitHub Actions integration

## Deliverables

- `.github/workflows/harness-review.yml` - PR auto-review workflow
- `.github/workflows/harness-plan-check.yml` - Plans.md consistency check (optional)

---

## Execution Flow

### Step 1: Feature Selection

> Which automation to setup?
> 1. PR auto-review (`/harness-review` on PR creation)
> 2. Plans.md consistency check (post task completion status on PR)
> 3. Both

**Wait for response**

### Step 2: Generate Workflow Files

#### PR Auto-Review (Option 1, 3)

`.github/workflows/harness-review.yml`:

```yaml
name: Harness Review

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    name: Auto Review
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code

      - name: Run Harness Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          CHANGED_FILES=$(git diff --name-only origin/${{ github.base_ref }}...HEAD)
          claude --non-interactive << 'EOF'
          /harness-review --ci --files "$CHANGED_FILES"
          EOF

      - name: Post Review Comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            let reviewBody = '## Harness Auto Review\n\n';
            if (fs.existsSync('.claude/state/last-review.md')) {
              reviewBody += fs.readFileSync('.claude/state/last-review.md', 'utf8');
            } else {
              reviewBody += 'Auto review complete. No critical issues detected.';
            }
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: reviewBody
            });
```

#### Plans.md Consistency Check (Option 2, 3)

`.github/workflows/harness-plan-check.yml`:

```yaml
name: Plans Check

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - 'Plans.md'
      - 'src/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  check:
    name: Plans Consistency
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check Plans.md
        id: plans
        run: |
          if [ ! -f Plans.md ]; then
            echo "plans_exists=false" >> $GITHUB_OUTPUT
            exit 0
          fi
          echo "plans_exists=true" >> $GITHUB_OUTPUT
          WIP=$(grep -c "cc:WIP" Plans.md 2>/dev/null || echo "0")
          TODO=$(grep -c "cc:TODO" Plans.md 2>/dev/null || echo "0")
          DONE=$(grep -c "cc:DONE" Plans.md 2>/dev/null || echo "0")
          echo "wip=$WIP" >> $GITHUB_OUTPUT
          echo "todo=$TODO" >> $GITHUB_OUTPUT
          echo "done=$DONE" >> $GITHUB_OUTPUT

      - name: Post Status Comment
        if: steps.plans.outputs.plans_exists == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const body = `## Plans.md Status
            | Status | Count |
            |--------|-------|
            | WIP | ${{ steps.plans.outputs.wip }} |
            | TODO | ${{ steps.plans.outputs.todo }} |
            | DONE | ${{ steps.plans.outputs.done }} |`;
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
```

### Step 3: Secret Setup Guide

> **ANTHROPIC_API_KEY setup required**
>
> 1. Settings → Secrets and variables → Actions
> 2. Click "New repository secret"
> 3. Name: `ANTHROPIC_API_KEY`
> 4. Value: Your Anthropic API key
>
> Get API key at https://console.anthropic.com

### Step 4: Completion Report

> Webhook trigger setup complete!
>
> **Generated files**:
> - `.github/workflows/harness-review.yml` - PR auto-review
> - `.github/workflows/harness-plan-check.yml` - Plans.md check
>
> **Next steps:**
> 1. Set `ANTHROPIC_API_KEY` secret
> 2. Commit & push changes
> 3. Create PR to verify

---

## Customization

### Filter Review Target Files

```yaml
on:
  pull_request:
    paths:
      - 'src/**'
      - '!src/**/*.test.ts'  # Exclude test files
```

### Customize Review Focus

```yaml
- name: Run Harness Review
  run: |
    claude --non-interactive << 'EOF'
    /harness-review --ci --focus security,performance
    EOF
```

### Run Only on Specific Branches

```yaml
on:
  pull_request:
    branches:
      - main
      - develop
```

---

## Troubleshooting

### Error: ANTHROPIC_API_KEY not set

**Cause**: Secret not configured

**Solution**: Set `ANTHROPIC_API_KEY` in repo Settings → Secrets

### Error: Permission denied

**Cause**: Insufficient workflow permissions

**Solution**: Check `permissions` section
```yaml
permissions:
  contents: read
  pull-requests: write
```
