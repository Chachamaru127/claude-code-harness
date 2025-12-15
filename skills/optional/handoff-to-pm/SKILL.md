---
name: ccp-handoff-to-pm
description: "Impl Claude → PM Claude への完了報告を生成。2-Agent運用で実装完了を報告したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [handoff, 2-agent, report, completion]
    alwaysApply: false
---

# Handoff to PM Skill

実装役 Claude Code が、PM役 Claude Code へ貼り付けるための完了報告を生成するスキル。

---

## トリガーフレーズ

- 「PMに完了報告を書いて」
- 「実装が終わったので報告」
- 「PM Claudeへのハンドオフ」

---

## 出力フォーマット

```markdown
## 完了報告（Impl Claude → PM Claude）

### 概要（1〜3行）
- （何を達成したか）

### 変更点（要点）
- （ユーザーに見える変更）

### 変更ファイル
- （ファイル一覧）

### 動作確認 / テスト
- （実施した確認）
- （結果）

### 受け入れ基準（満たしたか）
- [ ] （基準1）→ ✅/⚠️
- [ ] （基準2）→ ✅/⚠️

### リスク / 注意点
- （あれば）

### 次のアクション候補
1. （案1）
2. （案2）
```

---

## 実行フロー

1. `git status` / `git diff` で変更範囲を把握
2. `Plans.md` の該当タスクを `cc:完了` に更新
3. 上記フォーマットで完了報告を生成
