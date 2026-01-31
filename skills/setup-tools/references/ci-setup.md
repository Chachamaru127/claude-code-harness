# CI/CD Setup Reference

Automatically builds a CI/CD pipeline using GitHub Actions.

## Quick Reference

- "**Add CI**" → this setup
- "**Make tests run on PR**" → Sets up checks on PR/Push
- "**Don't know what to run**" → Analyzes project and suggests lint/typecheck/test/build

## Deliverables

- Add `.github/workflows/*` to auto-run lint/typecheck/test/build
- Provides failure cause analysis and fix suggestions (safety first)

**Features**:
- Lint (ESLint, Prettier)
- Type Check (TypeScript)
- Unit Test (Jest, Vitest)
- E2E Test (Playwright)
- Build Check

---

## Execution Flow

### Step 1: Confirm Project Type

> Tell us your project type:
> 1. Next.js (App Router)
> 2. Next.js (Pages Router)
> 3. React (Vite)
> 4. Other

**Wait for response**

### Step 2: Confirm Test Framework

> Tell us your test framework:
> 1. Jest
> 2. Vitest
> 3. Both
> 4. None

**Wait for response**

### Step 3: Confirm E2E Testing

> Run E2E tests?
> 1. Yes (Playwright)
> 2. No

**Wait for response**

### Step 4: Generate GitHub Actions Workflow

Generate `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Run ESLint
        run: npm run lint
      - name: Run Prettier
        run: npm run format:check

  typecheck:
    name: Type Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Run TypeScript compiler
        run: npm run typecheck

  test:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Run tests
        run: npm test -- --coverage
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/coverage-final.json
          fail_ci_if_error: false

  e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Install Playwright browsers
        run: npx playwright install --with-deps
      - name: Build application
        run: npm run build
      - name: Run E2E tests
        run: npm run test:e2e
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30

  build:
    name: Build Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm ci
      - name: Build application
        run: npm run build
```

### Step 5: Add package.json Scripts

Add if not present:

```json
{
  "scripts": {
    "lint": "next lint",
    "format:check": "prettier --check .",
    "format": "prettier --write .",
    "typecheck": "tsc --noEmit",
    "test": "vitest",
    "test:e2e": "playwright test"
  }
}
```

### Step 6: Check Config Files

Suggest generating missing config files if needed.

### Step 7: Guide Next Actions

> CI/CD pipeline complete!
>
> **Generated files**:
> - `.github/workflows/ci.yml` - GitHub Actions workflow
>
> **Next steps:**
> 1. Push to GitHub: `git add . && git commit -m "Add CI/CD" && git push`
> 2. Check execution status in GitHub Actions tab

---

## Troubleshooting

### Error: `npm ci` fails

**Cause**: `package-lock.json` is outdated

**Solution**:
```bash
npm install
git add package-lock.json
git commit -m "Update package-lock.json"
git push
```

### Error: Playwright installation fails

**Solution**: Add to workflow
```yaml
- name: Install Playwright browsers
  run: npx playwright install --with-deps chromium
```

### Error: Build fails

**Solution**: Add environment variables to GitHub Secrets
```yaml
- name: Build application
  run: npm run build
  env:
    NEXT_PUBLIC_API_URL: ${{ secrets.NEXT_PUBLIC_API_URL }}
```
