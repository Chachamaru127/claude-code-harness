---
name: harness-review
description: "Reviews code for quality, security, performance, and accessibility issues. Use when user mentions reviews, code review, security, performance, quality checks, PRs, diffs, or change review. Do NOT load for: implementation work, new feature development, bug fixes, or setup."
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task"]
context: fork
---

# Review Skills

コードレビューと品質チェックを担当するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **変更レビュー** | See [references/changes-review.md](references/changes-review.md) |
| **品質チェック** | See [references/quality-review.md](references/quality-review.md) |
| **セキュリティ** | See [references/security-review.md](references/security-review.md) |
| **パフォーマンス** | See [references/performance-review.md](references/performance-review.md) |
| **アクセシビリティ** | See [references/accessibility-review.md](references/accessibility-review.md) |
| **SEO/OGP** | See [references/seo-review.md](references/seo-review.md) |
| **Codex 統合** | See [references/codex-integration.md](references/codex-integration.md) |
| **コミット判定** | See [references/commit-judgment-logic.md](references/commit-judgment-logic.md) |

## 実行手順

1. **品質判定ゲート**（Step 0）
2. **残コンテキスト確認（Codex モード時）**（Step 1）
3. ユーザーのリクエストを分類
4. **（Claude-mem 有効時）過去のレビュー指摘を検索**
5. 並列実行の判定（下記参照）
6. 上記の「機能詳細」から適切な参照ファイルを読む、または並列サブエージェント起動
7. 結果を統合してレビュー完了

### 入力の優先順位

- `files` が渡されている場合は **そのファイルのみ** を対象にレビューする
- `files` が渡されていない場合は `git_diff` から変更箇所を推定する
- `context_from: code_content` が渡されている場合は **その内容を優先** してレビューする

### Step 0: 品質判定ゲート（レビュー重点領域の特定）

レビュー開始前に変更内容を分析し、重点領域を特定:

```
変更ファイル分析
    ↓
┌─────────────────────────────────────────┐
│           品質判定ゲート                 │
├─────────────────────────────────────────┤
│  判定項目:                              │
│  ├── カバレッジ不足？（テストなし）     │
│  ├── セキュリティ注意？（auth/api/）    │
│  ├── a11y 注意？（UI コンポーネント）   │
│  └── パフォーマンス注意？（DB/ループ）  │
└─────────────────────────────────────────┘
          ↓
    重点レビュー領域を決定
```

#### カバレッジ判定

| 状況 | 指摘内容 |
|------|---------|
| 新規ファイルにテストなし | 「テストが不足しています」 |
| 変更ファイルのテストが古い | 「テストの更新を検討してください」 |
| カバレッジ < 60% | 「カバレッジ向上を推奨」 |

#### セキュリティ重点レビュー

| パス | 追加チェック項目 |
|------|-----------------|
| auth/, api/ | OWASP Top 10 チェックリスト |
| 入力処理 | サニタイズ、バリデーション |
| DB クエリ | パラメータ化確認 |

#### a11y 重点レビュー

| パス | チェック項目 |
|------|------------|
| src/components/ | alt, aria, キーボード操作 |
| src/pages/ | 見出し構造, フォーカス管理 |

#### パフォーマンス重点レビュー

| パターン | 警告内容 |
|---------|---------|
| ループ内 DB クエリ | N+1 クエリの可能性 |
| 大規模データ処理 | ページネーション検討 |
| useEffect 乱用 | レンダリング最適化 |

#### SEO/OGP 重点レビュー

| パス | チェック項目 |
|------|------------|
| src/pages/, app/ | title, description, canonical |
| public/ | robots.txt, sitemap.xml, OGP 画像 |
| layout.tsx, _document.tsx | viewport, OGP タグ, Twitter Card |

#### クロスプラットフォーム重点レビュー

| パス | チェック項目 |
|------|------------|
| src/components/, app/ | レスポンシブ（固定幅チェック） |
| *.css, *.scss, tailwind | 100vw 使用、overflow 設定 |
| public/ | favicon, apple-touch-icon |

#### 重点レビュー統合出力

```markdown
📊 品質判定結果 → 重点レビュー領域

| 判定 | 該当 | 対象ファイル |
|------|------|-------------|
| セキュリティ | ⚠️ | src/api/auth.ts |
| カバレッジ | ⚠️ | src/utils/helpers.ts (テストなし) |
| a11y | ✅ | - |
| パフォーマンス | ✅ | - |
| SEO/OGP | ⚠️ | app/layout.tsx (OGP 未設定) |
| クロスプラットフォーム | ✅ | - |

→ セキュリティ・カバレッジ・SEO を重点的にレビュー
```

#### LSP ベースの影響分析（推奨）

変更レビュー時に LSP ツールで影響範囲を確認:

| 変更タイプ | LSP 操作 | 確認内容 |
|-----------|---------|---------|
| 関数シグネチャ変更 | findReferences | 全呼び出し元が対応済みか |
| 型定義変更 | findReferences | 使用箇所での型互換性 |
| API 変更 | incomingCalls | 影響を受けるエンドポイント |

**レビューフロー**:
1. 変更ファイルを特定
2. `LSP.findReferences` で影響範囲を列挙
3. 影響を受けるファイルも含めてレビュー

**使用例**:
```
# 1. 変更された関数の参照箇所を確認
LSP operation=findReferences filePath="src/api/user.ts" line=42 character=15

# 2. 関数の呼び出し階層を確認
LSP operation=incomingCalls filePath="src/api/user.ts" line=42 character=15

# 3. 型定義の使用箇所を確認
LSP operation=findReferences filePath="src/types/api.ts" line=10 character=12
```

**出力例**:
```markdown
🔍 LSP 影響分析結果

変更: updateUserProfile() のシグネチャ変更

影響を受ける箇所:
├── src/pages/profile.tsx:89 ⚠️ 引数更新必要
├── src/pages/settings.tsx:145 ⚠️ 引数更新必要
├── tests/user.test.ts:67 ✅ 更新済み
└── src/api/admin.ts:23 ⚠️ 引数更新必要

→ 3箇所で引数の更新が必要
```

> **注**: LSP サーバーが設定されている言語でのみ動作します。

### Step 1: 残コンテキスト確認（Codex モード時）

Codex モード（`review.mode: codex`）の場合は、**残コンテキストが 30%以下なら /compact を先に実行**してください。

> **注意**: /compact 後も余裕が少ない場合は縮退せず続行します。

### Step 2: 過去のレビュー指摘検索（Memory-Enhanced）

Claude-mem が有効な場合、レビュー開始前に過去の類似指摘を検索:

```
# mem-search で過去のレビュー指摘を検索
mem-search: type:review "{変更ファイルのパターン}"
mem-search: concepts:security "{セキュリティ関連のキーワード}"
mem-search: concepts:gotcha "{変更箇所に関連するキーワード}"
```

**表示例**:

```markdown
📚 過去のレビュー指摘（関連あり）

| 日付 | 指摘内容 | ファイル |
|------|---------|---------|
| 2024-01-15 | XSS脆弱性: innerHTML 使用禁止 | src/components/*.tsx |
| 2024-01-20 | N+1クエリ: prefetch 必須 | src/api/*.ts |

💡 今回のレビューで上記パターンを重点チェック
```

> **注**: Claude-mem が未設定の場合、このステップはスキップされます。

## レビューモードの選択

レビュースキルは 2 つのモードで動作します:

```
設定確認: .claude-code-harness.config.yaml
    ↓
├── review.mode: default → Claude 単体レビュー
└── review.mode: codex   → Codex 並列レビュー（8 エキスパート）
```

### Default モード（Claude 単体）

Claude が直接レビューを実行。小〜中規模の変更に最適。

### Codex モード（並列エキスパート）

Codex MCP 経由で**最大 8 つの専門エキスパート**を **個別に並列呼び出し**（不要なエキスパートは除外）:

| エキスパート | 観点 | プロンプトファイル |
|-------------|------|-------------------|
| Security | OWASP Top 10、認証、インジェクション | `experts/security-expert.md` |
| Accessibility | WCAG 2.1 AA、セマンティック HTML | `experts/accessibility-expert.md` |
| Performance | N+1 クエリ、レンダリング、アルゴリズム | `experts/performance-expert.md` |
| Quality | 可読性、保守性、ベストプラクティス | `experts/quality-expert.md` |
| SEO | メタタグ、OGP、サイトマップ | `experts/seo-expert.md` |
| Architect | 設計、トレードオフ、スケーラビリティ | `experts/architect-expert.md` |
| Plan Reviewer | 計画の完全性、明確性、検証可能性 | `experts/plan-reviewer-expert.md` |
| Scope Analyst | 要件分析、曖昧さ検出、リスク | `experts/scope-analyst-expert.md` |

#### ⚠️ Codex モード実行時の必須ルール

**絶対に1回の MCP 呼び出しで複数エキスパートをまとめないこと。**

```
✅ 正しい: 8回の MCP 呼び出しを1つのレスポンス内で並列実行
❌ 間違い: 1回の呼び出しで「全観点をレビューして」と依頼
```

**実行手順**:
1. **呼び出すエキスパートを判定**（全部ではなく必要なもののみ）:
   - 設定で `enabled: false` → 除外
   - CLI/バックエンド → Accessibility, SEO 除外
   - ドキュメントのみ変更 → Quality, Architect, Plan Reviewer, Scope Analyst を優先（Security, Performance は除外可）
2. 有効なエキスパートの `experts/*.md` からプロンプトを **個別に読み込む**
3. 有効なエキスパートのみ `mcp__codex__codex` を **1つのレスポンス内で並列実行**
4. 各結果を統合して判定

**詳細**: [codex-review/references/codex-parallel-review.md](../codex-review/references/codex-parallel-review.md)

**Codex モード有効化**:
```bash
/codex-mode on
```

**詳細**: [references/codex-integration.md](references/codex-integration.md)

---

## 並列サブエージェント起動（Default モード）

以下の条件を**両方**満たす場合、Task tool で code-reviewer を並列起動:

- レビュー観点 >= 2（例: セキュリティ + パフォーマンス）
- 変更ファイル >= 5

**起動パターン（1つのレスポンス内で複数の Task tool を同時呼び出し）:**

```
Task tool 並列呼び出し:
  #1: subagent_type="code-reviewer"
      prompt="セキュリティ観点でレビュー: {files}"
  #2: subagent_type="code-reviewer"
      prompt="パフォーマンス観点でレビュー: {files}"
  #3: subagent_type="code-reviewer"
      prompt="コード品質観点でレビュー: {files}"
```

**小規模な場合（条件を満たさない）:**
- 子スキル（doc.md）を順次読み込んで直列実行

---

## 🔧 MCP Code Intelligence ツールの活用

レビューでは MCP ツール（AST-Grep, LSP）を活用して精度を向上します。

> **重要**: `/dev-tools-setup` で MCP サーバーが設定されている場合、標準ツール（Grep, Read）ではなく **MCP ツールを優先使用**してください。MCP ツールは構造的な検索が可能で、より正確な結果を得られます。

### AST-Grep MCP ツール（harness_ast_search）

**構造的なコードパターン検索**に使用します。正規表現ベースの Grep より精度が高く、コードスメル検出に最適です。

| 検出パターン | AST-Grep パターン | 用途 |
|-------------|------------------|------|
| Debug logs | `console.log($$$)` | リリース前の残留ログ検出 |
| Empty catch | `catch ($ERR) { }` | エラー握りつぶし検出 |
| Unused async | `async function $NAME($$$) { $BODY }` | await なし async 検出 |
| Magic numbers | 数値リテラル検索 | ハードコード定数検出 |

**使用例**:
```
harness_ast_search pattern="console.log($$$)" language="typescript" path="src/"
harness_ast_search pattern="catch ($ERR) { }" language="typescript" path="src/"
```

**出力例**:
```markdown
🔍 AST-Grep Code Smell Scan

Patterns checked:
- console.log($$$) → Debug logs
- catch ($ERR) { } → Empty catch blocks

Results:
├── 3x console.log found (src/api/*.ts)
├── 1x empty catch block (src/utils/error.ts:45)
└── 0x unused async
```

> **注**: `harness_ast_search` が利用できない場合は、`sg` コマンド（Bash）または Grep にフォールバックします。

---

## 🔧 LSP 機能の活用

レビューでは LSP（Language Server Protocol）を活用して精度を向上します。

> **MCP 版優先**: `harness_lsp_*` MCP ツールが利用可能な場合は、標準 LSP ツールより優先して使用してください。

### LSP をレビューに統合

| レビュー観点 | LSP 活用方法 |
|-------------|-------------|
| **品質** | Diagnostics で型エラー・未使用変数を自動検出 |
| **セキュリティ** | Find-references で機密データの流れを追跡 |
| **パフォーマンス** | Go-to-definition で重い処理の実装を確認 |

### LSP Diagnostics の出力例

```
📊 LSP 診断結果

| ファイル | エラー | 警告 |
|---------|--------|------|
| src/components/Form.tsx | 0 | 2 |
| src/utils/api.ts | 1 | 0 |

⚠️ 1件のエラーを検出
→ レビューで指摘事項に追加
```

### Find-references による影響分析

```
🔍 変更影響分析

変更: validateInput()

参照箇所:
├── src/pages/signup.tsx:34
├── src/pages/settings.tsx:56
└── tests/validate.test.ts:12

→ テストでカバー済み ✅
```

詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

---

## VibeCoder 向け

```markdown
📝 コードチェックを依頼するときの言い方

1. **「チェックして」**
   - 全体的に問題がないか見てもらう

2. **「セキュリティ大丈夫？」**
   - 悪意ある攻撃に耐えられるかチェック

3. **「遅くない？」**
   - 速度に問題がないかチェック

4. **「誰でも使える？」**
   - 障害のある方でも使えるかチェック

💡 ヒント: 「全部チェックして」と言えば、
4つの観点すべてを自動で確認します
```
