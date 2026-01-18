---
description: "[Optional] Set up CI/CD (GitHub Actions)"
description-en: "[Optional] Set up CI/CD (GitHub Actions)"
---

# /ci-setup - CI/CD Setup (GitHub Actions)

Automatically builds a CI/CD pipeline using GitHub Actions.

## VibeCoder Quick Reference

- "**Add CI**" → this command
- "**Make tests run on PR**" → Sets up checks on PR/Push
- "**Don't know what to run**" → Analyzes project and suggests lint/typecheck/test/build

## Deliverables

- Add `.github/workflows/*` to auto-run lint/typecheck/test/build
- Provides failure cause analysis and fix suggestions (safety first)

**Features**:
- ✅ Lint (ESLint, Prettier)
- ✅ Type Check (TypeScript)
- ✅ Unit Test (Jest, Vitest)
- ✅ E2E Test (Playwright)
- ✅ Build Check

---

## 🔧 Auto-invoke Skills (Required)

**This command must explicitly invoke the following skills with the Skill tool**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `ci` | CI/CD (parent skill) | CI build/troubleshooting |

**How to call**:
```
Use Skill tool:
  skill: "claude-code-harness:ci"
```

**Child skills (auto-routing)**:
- `generate-workflow-files` - Workflow file generation
- `ci-analyze-failures` - CI failure analysis
- `ci-fix-failing-tests` - Test fix

> ⚠️ **Important**: Proceeding without calling skills won't record in usage statistics. Always call with Skill tool.

---

## 🔧 Type Check/Lint Integration

Integrates type checking and lint during CI/CD setup for more robust pipelines.

### Integrating Type Check/Lint into CI

Run type checking and lint in GitHub Actions to maintain code quality:

```yaml
  type-check-and-lint:
    name: Type Check & Lint
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

      - name: Run type check
        run: npm run type-check  # or tsc --noEmit

      - name: Run lint
        run: npm run lint
```

### CI Failure Debugging Flow

When CI fails, use LSP tools locally to identify issues:

```
CI failure debugging flow:

1. Check error logs
2. Analyze issues locally using LSP tools (definition, references, diagnostics)
3. Track problem source with Go-to-definition
4. Verify impact scope with Find-references
5. Re-validate with type-check/lint after fix
```

### VibeCoder Phrases

| What You Want | How to Say |
|---------------|------------|
| Investigate CI error cause | "Investigate this error with LSP definition/references" |
| Check type errors before push | "Run type-check before push" |

Details: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md) or run `/lsp-setup` command.

---

## Usage

```
/ci-setup
```

→ Generates `.github/workflows/ci.yml`

---

## Execution Flow

### Step 1: Confirm Project Type

> 🎯 **Tell us your project type:**
>
> 1. Next.js (App Router)
> 2. Next.js (Pages Router)
> 3. React (Vite)
> 4. Other
>
> Answer with a number (default: 1)

**Wait for response**

### Step 2: Confirm Test Framework

> 🧪 **Tell us your test framework:**
>
> 1. Jest
> 2. Vitest
> 3. Both
> 4. None
>
> Answer with a number (default: 2)

**Wait for response**

### Step 3: Confirm E2E Testing

> 🎭 **Run E2E tests?**
>
> 1. Yes (Playwright)
> 2. No
>
> Answer with a number (default: 1)

**Wait for response**

### Step 4: Generate GitHub Actions Workflow

Generate the following files:

#### `.github/workflows/ci.yml`

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

      - name: Check build output
        run: |
          if [ ! -d ".next" ]; then
            echo "Build output not found"
            exit 1
          fi
```

### Step 5: Add package.json Scripts

Add the following scripts to `package.json` (if not present):

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

Suggest generating missing config files if needed:

#### `.eslintrc.json`

```json
{
  "extends": ["next/core-web-vitals", "prettier"],
  "rules": {
    "no-console": ["warn", { "allow": ["warn", "error"] }],
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }]
  }
}
```

#### `.prettierrc`

```json
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "printWidth": 100
}
```

#### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "preserve",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "allowJs": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "incremental": true,
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

### Step 7: Guide Next Actions

> ✅ **CI/CD pipeline complete!**
>
> 📄 **Generated files**:
> - `.github/workflows/ci.yml` - GitHub Actions workflow
> - `.eslintrc.json` - ESLint config (if needed)
> - `.prettierrc` - Prettier config (if needed)
> - `tsconfig.json` - TypeScript config (if needed)
>
> **Next steps:**
> 1. Push to GitHub: `git add . && git commit -m "Add CI/CD" && git push`
> 2. Check execution status in GitHub Actions tab
> 3. (Optional) Set Codecov token: Settings > Secrets > CODECOV_TOKEN
>
> 💡 **Hint**: CI will automatically run when you create a Pull Request.

---

## Customization Examples

### 1. Run Only on Specific Branches

```yaml
on:
  push:
    branches: [main]  # main branch only
```

### 2. Run Only on Specific File Changes

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'app/**'
      - 'package.json'
```

### 3. Scheduled Execution

```yaml
on:
  schedule:
    - cron: '0 0 * * *'  # Run daily at midnight
```

### 4. Disable Parallel Execution

```yaml
jobs:
  test:
    needs: [lint, typecheck]  # Run after lint, typecheck succeed
```

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

**Cause**: Browser installation failed

**Solution**: Add the following to workflow
```yaml
- name: Install Playwright browsers
  run: npx playwright install --with-deps chromium
```

### Error: Build fails

**Cause**: Environment variables not set

**Solution**: Add environment variables to GitHub Secrets
```yaml
- name: Build application
  run: npm run build
  env:
    NEXT_PUBLIC_API_URL: ${{ secrets.NEXT_PUBLIC_API_URL }}
```

---

## Notes

- **First run**: First run executes all jobs, so it takes time (5-10 minutes)
- **Parallel execution**: Multiple jobs run in parallel for efficiency
- **Caching**: `node_modules` is cached, so subsequent runs are faster
- **Free tier**: GitHub Actions is free for public repos, 2000 minutes/month for private repos

**This CI pipeline helps maintain high-quality code.**

---

## ⚠️ Development vs Repository Decision

**Confirm before committing generated files:**

| Question | Yes → | No → |
|----------|-------|------|
| Does this affect project functionality/quality? | Commit to repo | Development only (.gitignore) |
| Needed by end users or other developers? | Commit to repo | Development only (.gitignore) |

**Example: When developing plugins**

When adding CI to the plugin repository itself:
- ✅ **Repository**: `validate-plugin.yml` (needed for plugin validation)
- ❌ **Development only**: ShellCheck or Markdown lint that don't affect the plugin itself

Add development files to `.gitignore` before committing.
