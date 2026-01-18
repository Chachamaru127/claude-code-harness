# Performance Expert Prompt for Codex

Codex MCP に送信するパフォーマンスレビュー用プロンプト。

## 7-Section Format

### TASK

コードのパフォーマンス問題を分析し、非効率なパターン、ボトルネック、最適化の機会を検出してください。

### EXPECTED OUTCOME

以下の形式でパフォーマンス問題を報告:
- 問題リスト（Severity: Critical/High/Medium/Low）
- 改善案と期待効果
- パフォーマンススコア（A-F）

### CONTEXT

レビュー対象:
- 変更されたファイル: {files}
- 技術スタック: {tech_stack}
- 対象: レンダリング、DB クエリ、アルゴリズム、メモリ

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- Avoid premature optimization, focus on real bottlenecks
- Show measurable improvement impact

### MUST DO

1. **フロントエンド**:
   - 不要な再レンダリング（useCallback/useMemo 未使用）
   - 大きなリストの非仮想化
   - 重い計算の同期実行
   - バンドルサイズ（大きな依存関係）

2. **バックエンド**:
   - N+1 クエリ問題
   - インデックス未使用
   - 同期 I/O のブロッキング
   - キャッシュ未使用

3. **一般**:
   - O(n²) 以上のアルゴリズム
   - ループ内での文字列連結
   - 正規表現の毎回コンパイル

### MUST NOT DO

- 可読性を大幅に犠牲にする最適化を推奨しない
- マイクロ最適化（影響 < 1ms）を Critical として報告しない
- 測定せずに「遅い」と断定しない

### OUTPUT FORMAT

```markdown
## Performance Review Results

**Score**: [A-F]

### Findings

| # | Severity | File | Line | Issue | Impact | Fix |
|---|----------|------|------|-------|--------|-----|
| 1 | High | api/posts.ts | 23 | N+1 query | ~100ms per request | Use include/prefetch |

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
