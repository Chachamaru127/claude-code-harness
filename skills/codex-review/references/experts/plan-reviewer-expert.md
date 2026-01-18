# Plan Reviewer Expert Prompt for Codex

Codex MCP に送信する計画レビュー用プロンプト。
> claude-delegator を参考に設計

## 7-Section Format

### TASK

作業計画（Plans.md）を分析し、実装をブロックする可能性のあるギャップ、曖昧さ、不足コンテキストを検出してください。

### EXPECTED OUTCOME

以下の形式で計画の問題を報告:
- **[APPROVE / REJECT]** の判定
- 問題リスト（Severity: Critical/High/Medium/Low）
- 改善提案
- 計画スコア（A-F）

### CONTEXT

レビュー対象:
- 計画ファイル: {plan_content}
- 対象: タスク定義、受入条件、依存関係、コンテキスト

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Evaluate from "can this actually be implemented?" perspective
- Avoid overly strict criteria

### MUST DO

1. **作業内容の明確さ**:
   - 各タスクが WHERE（どこを見ればよいか）を指定しているか
   - 参照資料で 90%+ の確信が得られるか

2. **検証・受入条件**:
   - 完了を確認する具体的な方法があるか
   - 受入条件が測定可能/観察可能か

3. **コンテキスト完全性**:
   - 10% 以上の不確実性を引き起こす欠落情報はないか
   - 暗黙の前提が明示されているか

4. **全体像・ワークフロー**:
   - 目的が明確か
   - タスク間の依存関係が定義されているか
   - 「完了」の定義があるか

### MUST NOT DO

- 単純な 1 タスクの計画を過度に批判しない
- 明らかなコンテキストの再説明を要求しない
- 参照ファイルが存在する場合に「詳細がない」と判定しない

### OUTPUT FORMAT

```markdown
## Plan Review Results

**Verdict**: [APPROVE / REJECT]

**Score**: [A-F]

### Evaluation Summary

| Criteria | Assessment |
|----------|------------|
| Clarity | [Brief assessment] |
| Verifiability | [Brief assessment] |
| Completeness | [Brief assessment] |
| Big Picture | [Brief assessment] |

### Findings (if REJECT)

| # | Severity | Area | Issue | Suggestion |
|---|----------|------|-------|------------|
| 1 | High | Task Definition | Missing reference file | Add link to existing implementation |

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
