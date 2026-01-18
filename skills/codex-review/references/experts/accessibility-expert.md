# Accessibility Expert Prompt for Codex

Codex MCP に送信するアクセシビリティレビュー用プロンプト。

## 7-Section Format

### TASK

Web アクセシビリティ（a11y）を分析し、WCAG 2.1 AA ガイドラインへの準拠を確認してください。

### EXPECTED OUTCOME

以下の形式で a11y 問題を報告:
- 問題リスト（Severity: Critical/High/Medium/Low）
- WCAG 基準への参照
- 修正案
- a11y スコア（A-F）

### CONTEXT

レビュー対象:
- 変更されたファイル: {files}
- フレームワーク: {tech_stack}
- 対象: UI コンポーネント、フォーム、画像、ナビゲーション

### CONSTRAINTS

- **English only, max 500 chars** (Claude integrates in Japanese)
- Critical/High: report all, Medium/Low: max 3 each
- No issues → `Score: A / No issues.`
- WCAG 2.1 AA baseline
- Consider framework-specific patterns (React/Vue/Svelte)

### MUST DO

1. **セマンティック HTML**: 見出し構造、ランドマーク、ボタン vs div
2. **画像・メディア**: alt 属性、装飾画像、動画キャプション
3. **フォーム**: ラベル、エラーメッセージ、必須フィールド
4. **キーボード**: フォーカス管理、トラップ防止、ESC 対応
5. **ARIA**: 冗長な ARIA 削除、動的コンテンツの aria-live

### MUST NOT DO

- 非 UI ファイル（API、ユーティリティ）を a11y 対象にしない
- 装飾画像に意味のある alt を要求しない
- aria-hidden の正しい使用を問題として報告しない

### OUTPUT FORMAT

```markdown
## Accessibility Review Results

**Score**: [A-F]

### Findings

| # | Severity | File | Line | Issue | WCAG | Fix |
|---|----------|------|------|-------|------|-----|
| 1 | High | components/Button.tsx | 12 | div used as button | 4.1.2 | Use <button> element |

### Summary

- Critical: X
- High: X
- Medium: X
- Low: X
```
