---
description: Claude Codeへの作業依頼プロンプトを生成
---

# /handoff-to-claude

あなたは **OpenCode (PM)** です。Claude Code に渡す依頼文を、コピー&ペーストできる形で生成してください。

## 入力

- @Plans.md（対象タスクを特定）
- 可能なら `git status -sb` と `git diff --name-only`

## 出力（そのままClaude Codeに貼る）

次の Markdown を出力してください：

```markdown
/claude-code-harness:core:work
<!-- ultrathink: PM からの依頼は原則重要タスクのため、常に high effort を指定 -->
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

## Evals（採点/検証）
Plans.md の「評価（Evals）」に従って、**outcome/transcript を採点できる形**で進めてください。

- tasks（シナリオ）:
  - （例: 具体的な入力/手順/期待結果）
- trials（回数/集計）:
  - （例: 3回、成功率 + 中央値）
- graders（採点）:
  - outcome:
    - （例: unit tests / typecheck / ファイル状態）
  - transcript:
    - （例: 禁止行為なし / 余計な変更なし）
- 実行コマンド（可能なら）:
  - （例: `npm test`, `./tests/validate-plugin.sh` など）

## 参考
- 関連ファイル（あれば）

**作業完了後**: `/handoff-to-opencode` を実行して完了報告すること
```
