---
name: adaptive-setup
description: "プロジェクト分析に基づいた適応型セットアップを実行するスキル。プロジェクトの状況に応じて適切なセットアップを自動選択する場合に使用します。"
allowed-tools: ["Read", "Write", "Bash"]
metadata:
  skillport:
    category: core
    tags: [setup, rules, adaptive, project-analysis]
    alwaysApply: false
---

# Adaptive Setup Skill

プロジェクトの状態を分析し、適応的にルールとコマンドを配置するスキル。

---

## 概要

従来の「テンプレートコピー」から「3フェーズ適応型セットアップ」に進化。

```
Phase 1: プロジェクト分析
    ↓
Phase 2: ルールカスタマイズ
    ↓
Phase 3: インタラクティブ確認
    ↓
配置完了
```

---

## Phase 1: プロジェクト分析

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
ANALYSIS=$("$PLUGIN_PATH/scripts/analyze-project.sh")
```

収集する情報：
- 技術スタック (Node.js, Python, Rust, etc.)
- フレームワーク (React, Next.js, Django, etc.)
- テストフレームワーク (Jest, Pytest, etc.)
- 既存の Linter/Formatter 設定
- 既存の Claude/Cursor 設定
- Git 情報 (Conventional Commits 等)
- 重要視されている事項

---

## Phase 2: ルールカスタマイズ

分析結果に基づいて：

1. **基本ルール選択**: workflow, plans-management, coding-standards, testing
2. **技術スタック別追加**: React/Next.js, Python, Rust 等のルール
3. **既存規約反映**: ESLint, Prettier 設定をルールに組み込み
4. **重要事項のルール化**: テスト必須、アクセシビリティ、セキュリティ等

---

## Phase 3: 確認と配置

ユーザーに分析結果と生成ルールを表示し、確認後に配置。

既存設定がある場合はマージ（上書きではない）。

---

## 関連ファイル

- `scripts/analyze-project.sh`
- `templates/rules/`
- `commands/setup-cursor.md`
