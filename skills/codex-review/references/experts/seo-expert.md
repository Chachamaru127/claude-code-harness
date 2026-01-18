# SEO Expert Prompt for Codex

Codex MCP に送信する SEO/OGP レビュー用プロンプト。

## 7-Section Format

### TASK

SEO 最適化と OGP タグを分析し、検索エンジン・SNS シェア品質の問題を検出してください。

### EXPECTED OUTCOME

以下の形式で SEO 問題を報告:
- 問題リスト（Severity: Critical/High/Medium/Low）
- 具体的な修正案
- SEO スコア（A-F）

### CONTEXT

レビュー対象:
- 変更されたファイル: {files}
- フレームワーク: {tech_stack}
- 対象: メタタグ、OGP、robots.txt、構造化データ

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Consider framework-specific SEO features (Next.js Metadata API, etc.)
- Check dynamic pages with representative patterns

### MUST DO

1. **基本メタタグ**:
   - title 欠落/重複/長さ
   - description 欠落/長さ
   - canonical URL
   - viewport

2. **OGP**:
   - og:title, og:description, og:image
   - og:image サイズ（1200x630 推奨）
   - og:url と canonical の一致

3. **Twitter Card**:
   - twitter:card（summary_large_image 推奨）
   - twitter:title, twitter:description, twitter:image

4. **クローラビリティ**:
   - robots.txt 存在/設定
   - sitemap.xml 存在
   - noindex 残存チェック

5. **HTTP ステータス**:
   - 404/500 が 200 を返していないか
   - リダイレクトチェーン

### MUST NOT DO

- API ルート/バックエンドファイルを SEO 対象にしない
- 管理画面/非公開ページの SEO を問題視しない
- 構造化データを必須として報告しない（オプション扱い）

### OUTPUT FORMAT

```markdown
## SEO/OGP Review Results

**Score**: [A-F]

### Findings

| # | Severity | File | Issue | Fix |
|---|----------|------|-------|-----|
| 1 | High | app/layout.tsx | Missing viewport meta | Add viewport meta tag |

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
