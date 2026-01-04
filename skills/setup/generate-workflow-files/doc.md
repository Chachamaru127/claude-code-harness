---
name: generate-workflow-files
description: "ワークフロー用ファイル（AGENTS.md, CLAUDE.md, Plans.md）を生成するスキル。新しいワークフローファイルを生成する必要がある場合に使用します。"
allowed-tools: ["Read", "Write"]
metadata:
  skillport:
    category: core
    tags: [workflow, agents, plans, init]
    alwaysApply: false
---

# Generate Workflow Files

claude-code-harness のワークフローに必要なファイルを生成するスキル。

---

## 目的

2エージェント協調ワークフローに必要な以下のファイルを生成：
- `AGENTS.md` - エージェント間の共通ルール
- `CLAUDE.md` - Claude Code 固有の設定
- `Plans.md` - タスク管理ファイル

---

## 入力

| 項目 | 説明 |
|------|------|
| `project_type` | プロジェクトの種類 |
| `tech_stack` | 技術スタック |
| `requirements` | 要件リスト |
| `templates` | 使用するテンプレートファイル |

---

## 出力

| 項目 | 説明 |
|------|------|
| `generated_files` | 生成されたファイルのリスト |
| `workflow_ready` | ワークフロー準備完了フラグ |

---

## 生成ファイル

### AGENTS.md

```markdown
# AGENTS.md

## 0. 開発フロー概要
[プロジェクト固有のフローを記載]

## 1. エージェントの役割
- Cursor (PM): 計画、レビュー、承認
- Claude Code (Worker): 実装、テスト

## 2. 環境・前提条件
[技術スタックに基づく環境情報]

...
```

### CLAUDE.md

```markdown
# CLAUDE.md

## Claude Code の責務範囲
- 担当する作業
- 禁止事項

## コミットメッセージ規約
- feat: / fix: / docs: / refactor: / test: / chore:

...
```

### Plans.md

```markdown
# Plans.md

## 現在のフェーズ
[初期状態]

## タスク一覧
- [ ] cc:TODO - 初期セットアップ

...
```

---

## テンプレート変数

| 変数 | 説明 |
|------|------|
| `{{project_name}}` | プロジェクト名 |
| `{{tech_stack}}` | 技術スタック |
| `{{date}}` | 生成日 |
| `{{requirements}}` | 要件リスト |

---

## 実行手順

1. **テンプレートファイルの読み込み**
   - `templates/AGENTS.md.template`
   - `templates/CLAUDE.md.template`
   - `templates/Plans.md.template`

2. **変数の置換**
   - プロジェクト情報を反映

3. **ファイルの生成**
   - 既存ファイルがあれば確認を求める

4. **完了報告**
   - 生成されたファイル一覧を提示

---

## 注意事項

- 既存の AGENTS.md / CLAUDE.md / Plans.md がある場合は上書き確認
- 2エージェント設定でない場合は CLAUDE.md のみ生成することも可能
