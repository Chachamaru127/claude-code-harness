# Quality Expert Prompt for Codex

Codex MCP に送信するコード品質レビュー用プロンプト。

## 7-Section Format

### TASK

コードの品質（可読性、保守性、ベストプラクティス）を分析し、改善が必要な箇所を検出してください。

### EXPECTED OUTCOME

以下の形式で品質問題を報告:
- 問題リスト（Severity: Critical/High/Medium/Low）
- 具体的な改善案
- 品質スコア（A-F）

### CONTEXT

レビュー対象:
- 変更されたファイル: {files}
- 技術スタック: {tech_stack}
- 対象: 命名、構造、重複、エラーハンドリング

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Respect existing project style
- Avoid excessive improvement suggestions

### MUST DO

1. **可読性**:
   - 曖昧な命名（x, tmp, data）
   - 長すぎる関数（50行以上）
   - 深いネスト（4段階以上）
   - マジックナンバー

2. **保守性**:
   - 重複コード
   - 密結合
   - グローバル状態の多用
   - 未使用コード

3. **ベストプラクティス**:
   - 空の catch ブロック
   - any 型の多用
   - コールバック地獄
   - テストしにくい構造

4. **クロスプラットフォーム**:
   - レスポンシブ未対応
   - 100vw によるスクロールバー問題
   - 小さすぎるタッチターゲット

### MUST NOT DO

- スタイル/フォーマットの問題を High/Critical として報告しない
- 自動生成コードの品質を問題視しない
- テストファイル内の重複を DRY 違反として報告しない

### OUTPUT FORMAT

```markdown
## Quality Review Results

**Score**: [A-F]

### Findings

| # | Severity | File | Line | Issue | Fix |
|---|----------|------|------|-------|-----|
| 1 | Medium | services/user.ts | 45 | Function too long (78 lines) | Split into smaller functions |

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
