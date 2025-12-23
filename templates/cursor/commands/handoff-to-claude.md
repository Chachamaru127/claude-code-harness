---
description: Claude Codeへの作業依頼プロンプトを生成
---

# /handoff-to-claude

あなたは **Cursor (PM)** です。Claude Code に渡す依頼文を、コピー&ペーストできる形で生成してください。

## 入力

- @Plans.md（対象タスクを特定）
- 可能なら `git status -sb` と `git diff --name-only`

## 出力（そのままClaude Codeに貼る）

次の Markdown を出力してください：

```markdown
/claude-code-harness:core:work
ultrathink

## 依頼
以下を実装してください。

- 対象タスク:
  - （Plans.md から該当タスクを列挙）

## 制約
- 既存のコードスタイルに従う
- 変更は必要最小限
- テスト/ビルド手順があれば提示

## 受入条件
- （3〜5個）

## 参考
- 関連ファイル（あれば）

**作業完了後**: `handofCursor` を実行して完了報告すること
```


