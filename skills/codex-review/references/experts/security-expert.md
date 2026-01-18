# Security Expert Prompt for Codex

Codex MCP に送信するセキュリティレビュー用プロンプト。

## 7-Section Format

### TASK

コードのセキュリティ脆弱性を分析し、OWASP Top 10 を含む一般的なセキュリティ問題を検出してください。

### EXPECTED OUTCOME

以下の形式でセキュリティ問題を報告:
- 問題リスト（Severity: Critical/High/Medium/Low）
- 各問題の修正案
- セキュリティスコア（A-F）

### CONTEXT

レビュー対象:
- 変更されたファイル: {files}
- 技術スタック: {tech_stack}
- 対象領域: 認証、認可、入力検証、データ保護

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Reduce false positives by considering context
- Consider framework-specific security features

### MUST DO

1. **インジェクション**: SQL、コマンド、XSS をチェック
2. **認証・認可**: ハードコード認証情報、弱い認証、権限チェック漏れ
3. **機密データ**: ログ出力、安全でない通信、.env のコミット
4. **設定ミス**: デバッグモード、CORS、セキュリティヘッダー
5. **Cookie**: HttpOnly、SameSite、Secure、Domain
6. **ファイルアップロード**: MIME、サイズ、拡張子、パストラバーサル
7. **決済**: 冪等性、金額改ざん、Webhook 署名

### MUST NOT DO

- テストファイルのセキュリティ警告を出さない
- 開発環境専用の設定を本番問題として報告しない
- 既知の安全なパターン（ORM のパラメータ化等）を誤検出しない

### OUTPUT FORMAT

```markdown
## Security Review Results

**Score**: [A-F]

### Findings

| # | Severity | File | Line | Issue | Fix |
|---|----------|------|------|-------|-----|
| 1 | Critical | path/to/file.ts | 45 | SQL Injection | Use parameterized query |

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
