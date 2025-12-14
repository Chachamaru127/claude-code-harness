---
description: デプロイ自動化設定（Vercel/Netlify 等）
---

# /deploy-setup - デプロイ自動化設定

Vercel/Netlifyへのデプロイを自動化します。

## バイブコーダー向け（こう言えばOK）

- 「**デプロイできるようにして**」→ このコマンド
- 「**Vercelに出したい**」→ `/deploy-setup vercel`
- 「**Netlifyに出したい**」→ `/deploy-setup netlify`
- 「**どっちが良いか分からない**」→ プロジェクト構成に合わせて提案します

## できること（成果物）

- デプロイ先に合わせた設定（環境変数/自動デプロイ/プレビュー）を整備
- 失敗しやすいポイント（環境変数/ビルド/ルーティング）を先に潰す

**機能**:
- ✅ Vercel/Netlifyプロジェクトの作成ガイド
- ✅ 環境変数の設定ガイド
- ✅ GitHub Actionsによる自動デプロイ
- ✅ プレビューデプロイ（Pull Request）

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `ccp-generate-workflow-files` - デプロイ設定生成
- `ccp-verify-build` - デプロイ前検証
- `ccp-error-recovery` - デプロイエラー復旧

---

## 使い方

```
/deploy-setup vercel
```

または

```
/deploy-setup netlify
```

→ デプロイ設定を生成

---

## 実行フロー

### Step 1: デプロイ先の確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どこにデプロイしますか？**
>
> 1. Vercel（推奨: Next.js）
> 2. Netlify（推奨: React/Vite）
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

---

## Vercelの場合

### Step 2: Vercelプロジェクトの作成ガイド

> 📦 **Vercelプロジェクトを作成してください：**
>
> 1. https://vercel.com にアクセス
> 2. 「Add New Project」をクリック
> 3. GitHubリポジトリを選択
> 4. 「Import」をクリック
>
> **環境変数を設定してください：**
> - Settings > Environment Variables
> - 以下の変数を追加:
>   ```
>   NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
>   CLERK_SECRET_KEY=sk_test_...
>   DATABASE_URL=postgresql://...
>   ```
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: GitHub Actionsワークフローの生成

#### `.github/workflows/deploy.yml`

```yaml
name: Deploy to Vercel

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    name: Deploy
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
      
      - name: Build
        run: npm run build
        env:
          NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: ${{ secrets.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY }}
          CLERK_SECRET_KEY: ${{ secrets.CLERK_SECRET_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
      
      - name: Deploy to Vercel (Production)
        if: github.ref == 'refs/heads/main'
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
      
      - name: Deploy to Vercel (Preview)
        if: github.event_name == 'pull_request'
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
```

### Step 4: GitHub Secretsの設定ガイド

> 🔐 **GitHub Secretsを設定してください：**
>
> 1. GitHubリポジトリの Settings > Secrets and variables > Actions
> 2. 「New repository secret」をクリック
> 3. 以下のシークレットを追加:
>
> **Vercel関連**:
> - `VERCEL_TOKEN`: Vercel > Settings > Tokens > Create Token
> - `VERCEL_ORG_ID`: Vercel > Settings > General > Organization ID
> - `VERCEL_PROJECT_ID`: Vercel > Project Settings > General > Project ID
>
> **環境変数**:
> - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
> - `CLERK_SECRET_KEY`
> - `DATABASE_URL`
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 5: vercel.jsonの生成

#### `vercel.json`

```json
{
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "framework": "nextjs",
  "regions": ["hnd1"],
  "env": {
    "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY": "@next-public-clerk-publishable-key",
    "CLERK_SECRET_KEY": "@clerk-secret-key",
    "DATABASE_URL": "@database-url"
  }
}
```

---

## Netlifyの場合

### Step 2: Netlifyプロジェクトの作成ガイド

> 📦 **Netlifyプロジェクトを作成してください：**
>
> 1. https://app.netlify.com にアクセス
> 2. 「Add new site」>「Import an existing project」をクリック
> 3. GitHubリポジトリを選択
> 4. Build settings:
>    - Build command: `npm run build`
>    - Publish directory: `dist`（Viteの場合）または `.next`（Next.jsの場合）
> 5. 「Deploy site」をクリック
>
> **環境変数を設定してください：**
> - Site settings > Environment variables
> - 以下の変数を追加:
>   ```
>   VITE_API_URL=https://...
>   ```
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: GitHub Actionsワークフローの生成

#### `.github/workflows/deploy.yml`

```yaml
name: Deploy to Netlify

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    name: Deploy
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
      
      - name: Build
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.VITE_API_URL }}
      
      - name: Deploy to Netlify (Production)
        if: github.ref == 'refs/heads/main'
        uses: nwtgck/actions-netlify@v2
        with:
          publish-dir: './dist'
          production-deploy: true
          github-token: ${{ secrets.GITHUB_TOKEN }}
          deploy-message: 'Deploy from GitHub Actions'
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
      
      - name: Deploy to Netlify (Preview)
        if: github.event_name == 'pull_request'
        uses: nwtgck/actions-netlify@v2
        with:
          publish-dir: './dist'
          production-deploy: false
          github-token: ${{ secrets.GITHUB_TOKEN }}
          deploy-message: 'Preview deploy from PR #${{ github.event.number }}'
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
```

### Step 4: GitHub Secretsの設定ガイド

> 🔐 **GitHub Secretsを設定してください：**
>
> 1. GitHubリポジトリの Settings > Secrets and variables > Actions
> 2. 「New repository secret」をクリック
> 3. 以下のシークレットを追加:
>
> **Netlify関連**:
> - `NETLIFY_AUTH_TOKEN`: Netlify > User settings > Applications > Personal access tokens > New access token
> - `NETLIFY_SITE_ID`: Netlify > Site settings > General > Site details > API ID
>
> **環境変数**:
> - `VITE_API_URL`
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 5: netlify.tomlの生成

#### `netlify.toml`

```toml
[build]
  command = "npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "20"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-Content-Type-Options = "nosniff"
    Referrer-Policy = "no-referrer"
```

---

## 共通: 次のアクションを案内

> ✅ **デプロイ設定が完成しました！**
>
> 📄 **生成したファイル**:
> - `.github/workflows/deploy.yml` - GitHub Actionsワークフロー
> - `vercel.json` または `netlify.toml` - デプロイ設定
>
> **次にやること：**
> 1. GitHubにプッシュ: `git add . && git commit -m "Add deploy config" && git push`
> 2. GitHubのActionsタブで実行状況を確認
> 3. デプロイが完了したら、URLにアクセスして動作確認
>
> 💡 **ヒント**: Pull Requestを作成すると、プレビューデプロイが自動的に作成されます。

---

## カスタマイズ例

### 1. カスタムドメインの設定

**Vercel**:
1. Vercel > Project Settings > Domains
2. 「Add Domain」をクリック
3. DNSレコードを設定

**Netlify**:
1. Netlify > Site settings > Domain management
2. 「Add custom domain」をクリック
3. DNSレコードを設定

### 2. プレビューデプロイのコメント

Pull Requestにプレビュー URLをコメントする：

```yaml
- name: Comment PR
  uses: actions/github-script@v7
  if: github.event_name == 'pull_request'
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: '✅ Preview deployed to: ${{ steps.deploy.outputs.url }}'
      })
```

### 3. デプロイ前のテスト

```yaml
- name: Run tests
  run: npm test
  
- name: Deploy
  if: success()
  # デプロイ処理
```

---

## トラブルシューティング

### エラー: デプロイが失敗する

**原因**: 環境変数が設定されていない

**解決策**: GitHub SecretsとVercel/Netlifyの環境変数を確認

### エラー: ビルドが失敗する

**原因**: ローカルでは動くが、本番環境では失敗

**解決策**: 
```bash
# ローカルで本番ビルドを確認
npm run build
```

### エラー: 404エラーが発生する

**原因**: SPAのルーティングが正しく設定されていない

**解決策**: `vercel.json` または `netlify.toml` でリダイレクト設定を確認

---

## 注意事項

- **環境変数**: 本番環境とプレビュー環境で異なる値を設定できます
- **シークレット**: GitHub Secretsは暗号化されて保存されます
- **無料枠**: Vercel/Netlifyは、個人プロジェクトでは無料で使用できます
- **デプロイ時間**: 初回は5-10分、2回目以降はキャッシュにより1-3分

**このデプロイ設定により、コミットするだけで自動的にデプロイされます。**
