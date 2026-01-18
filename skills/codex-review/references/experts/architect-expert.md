# Architect Expert Prompt for Codex

Codex MCP に送信する設計レビュー用プロンプト。
> claude-delegator を参考に設計

## 7-Section Format

### TASK

システム設計、アーキテクチャ判断、技術的トレードオフを分析し、設計上の問題や改善機会を検出してください。

### EXPECTED OUTCOME

以下の形式で設計問題を報告:
- 問題リスト（Severity: Critical/High/Medium/Low）
- トレードオフ分析
- 推奨アプローチ
- 設計スコア（A-F）

### CONTEXT

レビュー対象:
- 変更されたファイル: {files}
- 技術スタック: {tech_stack}
- 対象: アーキテクチャ、設計パターン、スケーラビリティ

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Avoid premature over-abstraction
- Base decisions on actual requirements

### MUST DO

1. **システム設計**:
   - モジュール境界の適切さ
   - 依存関係の方向
   - 責務の分離

2. **スケーラビリティ**:
   - ボトルネックになりうる箇所
   - 水平/垂直スケーリングの考慮
   - キャッシュ戦略

3. **保守性**:
   - 変更容易性
   - テスタビリティ
   - デバッグ容易性

4. **トレードオフ分析**:
   - 複雑さ vs 柔軟性
   - パフォーマンス vs 可読性
   - DRY vs 明示性

### MUST NOT DO

- 「将来のため」だけの抽象化を推奨しない
- 単一用途の過度なパターン適用を推奨しない
- 既存のうまく動いている設計を不必要に変更しない

### OUTPUT FORMAT

```markdown
## Architecture Review Results

**Score**: [A-F]

### Findings

| # | Severity | Area | Issue | Recommendation |
|---|----------|------|-------|----------------|
| 1 | High | Module Design | Circular dependency | Introduce interface layer |

### Tradeoff Analysis

- **Current**: [Current approach and its pros/cons]
- **Recommended**: [Recommended approach and why]
- **Effort**: Quick/Short/Medium/Large

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
