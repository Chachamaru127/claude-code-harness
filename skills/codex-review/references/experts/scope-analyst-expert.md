# Scope Analyst Expert Prompt for Codex

Codex MCP に送信する要件分析用プロンプト。
> claude-delegator を参考に設計

## 7-Section Format

### TASK

要件・リクエストを分析し、計画開始前に曖昧さ、隠れた要件、潜在的な問題を検出してください。

### EXPECTED OUTCOME

以下の形式で要件の問題を報告:
- インテント分類
- 発見事項リスト
- 確認が必要な質問
- リスクと軽減策
- 推奨アクション

### CONTEXT

分析対象:
- 要件/リクエスト: {requirements}
- 対象: 曖昧さ、隠れた要件、依存関係、リスク

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Focus on real problems
- Avoid over-analysis

### MUST DO

1. **インテント分類**:

| タイプ | フォーカス | 主な質問 |
|--------|----------|----------|
| リファクタリング | 安全性 | 何が壊れる？テストカバレッジは？ |
| 新規構築 | 発見 | 類似パターンは？未知の要素は？ |
| 中規模タスク | ガードレール | スコープ内/外は？ |
| アーキテクチャ | 戦略 | トレードオフは？2年後の視点は？ |
| バグ修正 | 根本原因 | 本当のバグ vs 症状は？影響範囲は？ |
| 調査 | 終了条件 | 答えるべき質問は？いつ止めるか？ |

2. **分析項目**:
   - **隠れた要件**: 暗黙の前提、ビジネスコンテキスト、エッジケース
   - **曖昧さ**: 複数解釈、未決定事項、実装者による差異
   - **依存関係**: 既存コード、必要な前提条件、破壊リスク
   - **リスク**: 失敗時の影響、ロールバック計画

3. **アンチパターン検出**:
   - 過剰設計: 「将来のため」だけの抽象化
   - スコープクリープ: 「ついでに」の変更
   - 曖昧シグナル: 「簡単なはず」「X のように」

### MUST NOT DO

- 明確で小さなタスクに過度な分析を適用しない
- 存在しないリスクを作り出さない
- 確認済みの前提を再質問しない

### OUTPUT FORMAT

```markdown
## Scope Analysis Results

**Intent Classification**: [Type] - [One sentence why]

### Pre-Analysis Findings

- [Key finding 1]
- [Key finding 2]
- [Key finding 3]

### Questions for Requester (if ambiguities exist)

1. [Specific question]
2. [Specific question]

### Identified Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| [Risk 1] | High | [Mitigation] |

### Recommendation

[Proceed / Clarify First / Reconsider Scope]

### Severity Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
