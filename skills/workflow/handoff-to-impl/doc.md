---
name: ccp-handoff-to-impl
description: "PM Claude → Impl Claude への依頼文を生成。2-Agent運用で実装役にタスクを渡したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [handoff, 2-agent, delegation, pm]
    alwaysApply: false
---

# Handoff to Impl Skill

PM役 Claude Code が、実装役 Claude Code（Impl Claude）へ貼り付けるための依頼文を生成するスキル。

---

## トリガーフレーズ

- 「このタスクを実装役Claudeに渡したい」
- 「実装役に依頼文を作って」
- 「Impl Claudeへのハンドオフ」

---

## 出力フォーマット

```markdown
## タスク依頼（PM Claude → Impl Claude）

### 背景 / 目的
- （なぜやるか）

### 期待する成果
- （何ができるようになればOKか）

### 受け入れ基準（必須）
- [ ] （基準1）
- [ ] （基準2）

### スコープ（やる / やらない）
- **やる**: （項目）
- **やらない**: （項目）

### 変更対象（目安）
- （ファイル/ディレクトリ）

### 制約 / 禁止事項
- （あれば）
```

---

## 実行フロー

1. `Plans.md` を読み込み、依頼対象タスクを特定
2. タスクに `pm:依頼中` マーカーを付与
3. 上記フォーマットで依頼文を生成
