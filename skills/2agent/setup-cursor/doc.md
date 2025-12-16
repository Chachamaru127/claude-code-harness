---
name: ccp-setup-cursor
description: "Cursor連携のセットアップ（.cursor/commands 生成）。Cursor と Claude Code で役割分担したい場合に使用します。"
allowed-tools: ["Read", "Write", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [cursor, setup, 2-agent, integration]
    alwaysApply: false
---

# Setup Cursor Skill

Cursor側のカスタムコマンド（`.cursor/commands/*.md`）を生成し、2-agent運用を開始できる状態にするスキル。

---

## トリガーフレーズ

- 「CursorとClaude Codeで役割分担したい」
- 「2-agent運用を始めたい」
- 「Cursor連携をセットアップして」
- 「計画はCursor、実装はClaudeに任せたい」

---

## 生成するファイル

- `.cursor/commands/start-session.md`
- `.cursor/commands/project-overview.md`
- `.cursor/commands/plan-with-cc.md`
- `.cursor/commands/handoff-to-claude.md`
- `.cursor/commands/review-cc-work.md`
- `.claude/memory/decisions.md`（SSOT）
- `.claude/memory/patterns.md`（SSOT）

---

## 実行フロー

1. `.cursor/commands/` を作成
2. 5つのコマンドファイルを生成
3. `.claude/memory/` を作成し、SSOTファイルを初期化
4. Cursorを再起動してコマンドが表示されることを案内
