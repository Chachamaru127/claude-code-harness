# Codex 並列レビュー実行ガイド

Codex モード時に複数のエキスパートを並列で呼び出すためのオーケストレーション手順。

## 概要

Codex モードでは、Claude がオーケストレーターとして**最大 8 つのエキスパート**を MCP 経由で並列呼び出しします（プロジェクト種別・変更内容に応じて不要なエキスパートは除外）。

```
Claude (オーケストレーター)
    ↓
並列 MCP 呼び出し
    ├── Security Expert
    ├── Accessibility Expert
    ├── Performance Expert
    ├── Quality Expert
    ├── SEO Expert
    ├── Architect Expert
    ├── Plan Reviewer Expert
    └── Scope Analyst Expert
    ↓
結果統合 → コミット判定
```

---

## ⚠️ 並列呼び出し必須ルール（MANDATORY）

**このルールは絶対に守ること。違反した場合、レビュー品質が大幅に低下します。**

### 禁止事項

| 禁止 | 理由 |
|------|------|
| ❌ 1回の MCP 呼び出しで複数エキスパートをまとめる | 各エキスパートの専門性が薄まる |
| ❌ 「セキュリティとパフォーマンスと品質を見て」と1回で依頼 | 観点が混在し、深い分析ができない |
| ❌ experts/*.md を読まずに汎用プロンプトを送る | 専門家プロンプトの知見が活かされない |

### 必須事項

| 必須 | 方法 |
|------|------|
| ✅ 各エキスパートを **個別の MCP 呼び出し** で実行 | `mcp__codex__codex` を8回呼び出し |
| ✅ experts/*.md から **個別にプロンプトを読み込む** | `security-expert.md` → Security 呼び出し → `accessibility-expert.md` → Accessibility 呼び出し... |
| ✅ **1つのレスポンス内で8つの MCP 呼び出しを並列実行** | Claude の並列ツール呼び出し機能を使用 |

### 正しい実行パターン

```
1. 設定とプロジェクト種別から有効なエキスパートを判定
2. 有効なエキスパートのみ、1つのレスポンス内で同時に実行:

mcp__codex__codex({prompt: security-expert.md の内容})
mcp__codex__codex({prompt: performance-expert.md の内容})
mcp__codex__codex({prompt: quality-expert.md の内容})
... (有効なもののみ)

→ 必要なエキスパートのみ並列実行
→ 無関係な観点はスキップしてコスト削減
```

### なぜ分けるのか

| 1回でまとめた場合 | 8回に分けた場合 |
|------------------|-----------------|
| 各観点が2-3行で浅い | 各観点が詳細に分析される |
| 重要な問題を見落とす | 専門家視点で漏れなく検出 |
| 「問題なし」で終わりやすい | 具体的な改善提案が出る |

---

## 実行フロー

### Step 0: 残コンテキスト確認

Codex 並列レビューの前に**残コンテキストが 30%以下なら /compact を実行**してください。

> **注意**: /compact 後も余裕が少ない場合はそのまま Step 1 に進みます。

### Step 1: 設定確認

```yaml
# .claude-code-harness.config.yaml から読み込み
review:
  mode: codex
  codex:
    enabled: true
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

### Step 2: 変更ファイルの収集

```bash
# git diff で変更ファイルを取得
git diff --name-only HEAD~1
```

### Step 3: 呼び出すエキスパートの判定（フィルタリング）

**全エキスパートを毎回呼ぶのではなく、必要なもののみ選択する。**

#### 3.1 設定ベースのフィルタリング

`.claude-code-harness.config.yaml` で `false` のエキスパートは除外:

```yaml
experts:
  security: true       # ✅ 呼び出す
  accessibility: false # ❌ スキップ
  performance: true    # ✅ 呼び出す
  ...
```

#### 3.2 プロジェクト種別による自動除外

| プロジェクト種別 | 自動除外するエキスパート |
|-----------------|------------------------|
| CLI / バックエンドAPI | Accessibility, SEO |
| ライブラリ / SDK | Accessibility, SEO |
| Webフロントエンド | （全て有効） |
| モバイルアプリ | SEO |
| 計画/レビューのみ | Security, Performance, Quality（コード変更なし時） |

**判定方法**:
```
1. 変更ファイルのパスを確認:
   - src/components/, pages/, app/ → Webフロントエンド → Accessibility, SEO 有効
   - src/api/, server/, cli/ → バックエンド/CLI → Accessibility, SEO 除外
   - *.md のみ → ドキュメント変更 → Quality, Architect, Plan Reviewer, Scope Analyst を優先

2. package.json / pyproject.toml を確認:
   - react, vue, next → Webフロントエンド
   - express, fastify, flask → バックエンド
   - commander, yargs → CLI
```

#### 3.3 変更内容による除外

| 変更内容 | 優先するエキスパート | 除外可能 |
|---------|---------------------|---------|
| Plans.md のみ変更 | Plan Reviewer, Scope Analyst | Security, Performance, Quality, Accessibility, SEO, Architect |
| テストファイルのみ変更 | Security, Quality, Performance | Architect, Plan Reviewer, Scope Analyst |
| README / ドキュメントのみ | Quality, Architect, Plan Reviewer, Scope Analyst | Security, Performance, Accessibility |

#### 3.4 最終的な呼び出しリスト決定

```
設定で有効 AND プロジェクトに関連 AND 変更内容に関連
→ 呼び出すエキスパートリスト

例1: Webフロントエンドでコード変更あり
→ Security, Accessibility, Performance, Quality, SEO, Architect
→ 6エキスパート並列（Plan Reviewer, Scope Analyst は除外）

例2: CLI プラグインでドキュメントのみ変更
→ Quality, Architect, Plan Reviewer, Scope Analyst
→ 4エキスパート並列（Security, Performance, Accessibility, SEO は除外）
```

### Step 4: エキスパートプロンプトの準備

**Step 3 で決定したエキスパートのみ**、`experts/*.md` からプロンプトを読み込み:
- `{files}`: 変更ファイルリスト
- `{tech_stack}`: 検出された技術スタック
- `{plan_content}`: Plans.md の内容（Plan Reviewer 用）
- `{requirements}`: 要件内容（Scope Analyst 用）

### Step 5: 並列 MCP 呼び出し

**実行モード**: 並列エキスパートは **MCP 固定**（Claude 組み込み並列機能を活用）

> 単発 `/codex-review` は exec だが、並列は mcp の方がシェル管理不要で効率的

**重要**: Step 3 で決定した有効なエキスパートのみ呼び出し

```typescript
// 並列呼び出しの概念コード
const enabledExperts = Object.entries(config.review.codex.experts)
  .filter(([_, enabled]) => enabled)
  .map(([name]) => name);

// 並列実行
const results = await Promise.all(
  enabledExperts.map(expert =>
    mcp__codex__codex({
      prompt: getPromptForExpert(expert, files, techStack),
      sandbox: "read-only"
    })
  )
);
```

### Step 5.1: 出力制限ルール（Context 溢れ防止）

各エキスパートの応答は以下の制約に従う（experts/*.md に埋め込み済み）:

| 制約 | 内容 |
|------|------|
| 言語 | **English only**（トークン節約、Claude が統合時に日本語化） |
| 最大文字数 | 500 文字 |
| 件数制限 | Critical/High: 全件、Medium/Low: 各3件まで |
| 問題なし | `Score: A / No issues.` のみ |

> **理由**: 8エキスパート並列で Context 溢れを防止

### Step 6: 結果統合

各エキスパートからの結果を統合:

```markdown
## 📊 Codex 並列レビュー結果

### エキスパート別サマリー

| Expert | Score | Critical | High | Medium | Low |
|--------|-------|----------|------|--------|-----|
| Security | B | 0 | 1 | 2 | 3 |
| Accessibility | A | 0 | 0 | 1 | 2 |
| Performance | C | 0 | 2 | 3 | 1 |
| Quality | B | 0 | 0 | 4 | 5 |
| SEO | A | 0 | 0 | 0 | 2 |
| Architect | B | 0 | 1 | 1 | 0 |
| Plan Reviewer | APPROVE | - | - | - | - |
| Scope Analyst | Proceed | - | - | - | - |

### 統合 Findings

| # | Expert | Severity | File | Issue |
|---|--------|----------|------|-------|
| 1 | Security | High | src/api/auth.ts:45 | SQL Injection |
| 2 | Performance | High | src/api/posts.ts:23 | N+1 Query |
| 3 | Architect | High | src/services/ | Circular dependency |
```

### Step 7: コミット判定

統合結果から最終判定を算出:

| 集計 | 判定 |
|------|------|
| Critical ≥ 1 | REJECT |
| High ≥ 1 または Medium > 3 | REQUEST CHANGES |
| それ以外 | APPROVE |

## エラーハンドリング

### 一部エキスパート失敗時

```markdown
⚠️ 一部のエキスパートでエラーが発生しました

| Expert | Status |
|--------|--------|
| Security | ✅ 成功 |
| Performance | ❌ タイムアウト |
| Quality | ✅ 成功 |

失敗したエキスパートをスキップして判定を続行しますか？
```

### 全エキスパート失敗時

```markdown
❌ Codex エキスパートとの通信に失敗しました

原因: MCP サーバー接続エラー

フォールバック: Claude 単体でレビューを実行しますか？
```

## 自動修正ループ

REQUEST CHANGES 判定時の自動修正フロー:

```
REQUEST CHANGES 判定
    ↓
修正対象の抽出（High/Medium の Findings）
    ↓
Claude が修正実行
    ↓
再度 Codex 並列レビュー
    │
    ├── APPROVE → 完了
    ├── REQUEST CHANGES → ループ（リトライ: ${current}/${max_retries}）
    └── REJECT → 手動対応必要
```

### リトライ制限

- デフォルト: 最大 3 回
- 設定: `review.judgment.max_retries`

### リトライ超過時

```markdown
## ⚠️ 自動修正上限に到達

${max_retries} 回の自動修正を試みましたが、以下の問題が残っています:

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | High | src/api/users.ts | N+1 Query |

**推奨アクション**:
1. 手動で上記を修正
2. 再度 `/harness-review` を実行
```

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `experts/security-expert.md` | セキュリティエキスパートプロンプト |
| `experts/accessibility-expert.md` | a11y エキスパートプロンプト |
| `experts/performance-expert.md` | パフォーマンスエキスパートプロンプト |
| `experts/quality-expert.md` | 品質エキスパートプロンプト |
| `experts/seo-expert.md` | SEO エキスパートプロンプト |
| `experts/architect-expert.md` | 設計エキスパートプロンプト |
| `experts/plan-reviewer-expert.md` | 計画レビューエキスパートプロンプト |
| `experts/scope-analyst-expert.md` | 要件分析エキスパートプロンプト |
| `commit-judgment-logic.md` | コミット判定ロジック |
