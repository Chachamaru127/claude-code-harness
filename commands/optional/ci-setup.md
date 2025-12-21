---
description: "[オプション] CI/CD構築（GitHub Actions）"
description-en: "[Optional] Set up CI/CD (GitHub Actions)"
---

# /ci-setup - CI/CD構築（GitHub Actions）

GitHub Actionsを使用したCI/CDパイプラインを自動構築します。

## バイブコーダー向け（こう言えばOK）

- 「**CIを入れて**」→ このコマンド
- 「**PRでテストが走るようにして**」→ PR/Push時のチェックを整備します
- 「**何を走らせればいいか分からない**」→ プロジェクトを解析して lint/typecheck/test/build を提案します

## できること（成果物）

- `.github/workflows/*` を追加し、lint/typecheck/test/build などを自動実行
- 失敗時の原因切り分けと修正案まで一緒に出す（安全第一）

**機能**:
- ✅ Lint（ESLint, Prettier）
- ✅ Type Check（TypeScript）
- ✅ Unit Test（Jest, Vitest）
- ✅ E2E Test（Playwright）
- ✅ Build Check

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `generate-workflow-files` - ワークフローファイル生成
- `ci-analyze-failures` - CI失敗分析
- `ci-fix-failing-tests` - テスト修正

---

## 🔧 型チェック・Lint の統合

CI/CD構築時に型チェックとlintを統合して、より堅牢なパイプラインを構築します。

### 型チェック・Lint を CI に統合

GitHub Actions で型チェックとlintを実行することで、コード品質を維持：

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
        run: npm run type-check  # または tsc --noEmit

      - name: Run lint
        run: npm run lint
```

### CI 失敗時のデバッグフロー

CI が失敗した場合、ローカルでLSPツールを使って問題を特定：

```
CI 失敗時のデバッグフロー:

1. エラーログを確認
2. ローカルでLSPツール（definition, references, diagnostics）を使って問題を分析
3. Go-to-definition で問題の原因を追跡
4. Find-references で影響範囲を確認
5. 修正後、再度 type-check/lint で検証
```

### VibeCoder 向けの言い方

| やりたいこと | 言い方 |
|-------------|--------|
| CI エラーの原因を調べたい | 「LSP definition/references でこのエラーを調査して」 |
| 型エラーを事前にチェック | 「push 前に type-check を実行して」 |

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md) または `/lsp-setup` コマンドを実行してください。

---

## 使い方

```
/ci-setup
```

→ `.github/workflows/ci.yml` を生成

---

## 実行フロー

### Step 1: プロジェクトタイプの確認

> 🎯 **プロジェクトのタイプを教えてください：**
>
> 1. Next.js（App Router）
> 2. Next.js（Pages Router）
> 3. React（Vite）
> 4. その他
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

### Step 2: テストフレームワークの確認

> 🧪 **使用しているテストフレームワークを教えてください：**
>
> 1. Jest
> 2. Vitest
> 3. 両方
> 4. なし
>
> 番号で答えてください（デフォルト: 2）

**回答を待つ**

### Step 3: E2Eテストの確認

> 🎭 **E2Eテストを実行しますか？**
>
> 1. はい（Playwright）
> 2. いいえ
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

### Step 4: GitHub Actionsワークフローの生成

以下のファイルを生成：

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

### Step 5: package.jsonスクリプトの追加

`package.json` に以下のスクリプトを追加（存在しない場合）：

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

### Step 6: 設定ファイルの確認

必要な設定ファイルが存在しない場合、生成を提案：

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

### Step 7: 次のアクションを案内

> ✅ **CI/CDパイプラインが完成しました！**
>
> 📄 **生成したファイル**:
> - `.github/workflows/ci.yml` - GitHub Actionsワークフロー
> - `.eslintrc.json` - ESLint設定（必要に応じて）
> - `.prettierrc` - Prettier設定（必要に応じて）
> - `tsconfig.json` - TypeScript設定（必要に応じて）
>
> **次にやること：**
> 1. GitHubにプッシュ: `git add . && git commit -m "Add CI/CD" && git push`
> 2. GitHubのActionsタブで実行状況を確認
> 3. （オプション）Codecovトークンを設定: Settings > Secrets > CODECOV_TOKEN
>
> 💡 **ヒント**: Pull Requestを作成すると、自動的にCIが実行されます。

---

## カスタマイズ例

### 1. 特定のブランチでのみ実行

```yaml
on:
  push:
    branches: [main]  # mainブランチのみ
```

### 2. 特定のファイル変更時のみ実行

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'app/**'
      - 'package.json'
```

### 3. スケジュール実行

```yaml
on:
  schedule:
    - cron: '0 0 * * *'  # 毎日0時に実行
```

### 4. 並列実行の無効化

```yaml
jobs:
  test:
    needs: [lint, typecheck]  # lint, typecheckが成功してから実行
```

---

## トラブルシューティング

### エラー: `npm ci` が失敗する

**原因**: `package-lock.json` が古い

**解決策**:
```bash
npm install
git add package-lock.json
git commit -m "Update package-lock.json"
git push
```

### エラー: Playwrightのインストールが失敗する

**原因**: ブラウザのインストールに失敗

**解決策**: ワークフローに以下を追加
```yaml
- name: Install Playwright browsers
  run: npx playwright install --with-deps chromium
```

### エラー: ビルドが失敗する

**原因**: 環境変数が設定されていない

**解決策**: GitHub Secretsに環境変数を追加
```yaml
- name: Build application
  run: npm run build
  env:
    NEXT_PUBLIC_API_URL: ${{ secrets.NEXT_PUBLIC_API_URL }}
```

---

## 注意事項

- **初回実行**: 初回はすべてのジョブが実行されるため、時間がかかります（5-10分）
- **並列実行**: 複数のジョブが並列実行されるため、効率的です
- **キャッシュ**: `node_modules` がキャッシュされるため、2回目以降は高速です
- **無料枠**: GitHub Actionsは、パブリックリポジトリでは無料、プライベートリポジトリでは月2000分まで無料です

**このCIパイプラインにより、品質の高いコードを維持できます。**

---

## ⚠️ 開発用 vs リポジトリ用の判断

**生成するファイルをコミットする前に確認してください:**

| 質問 | Yes → | No → |
|------|-------|------|
| このプロジェクトの機能/品質に影響するか？ | リポジトリにコミット | 開発用（.gitignore） |
| エンドユーザーや他の開発者に必要か？ | リポジトリにコミット | 開発用（.gitignore） |

**例: プラグイン開発時の判断**

このコマンドでプラグインリポジトリ自体にCIを追加する場合:
- ✅ **リポジトリ用**: `validate-plugin.yml`（プラグインの検証に必要）
- ❌ **開発用**: ShellCheck や Markdown lint など、プラグイン自体の機能に関係ないもの

開発用ファイルは `.gitignore` に追加してからコミットしてください。
