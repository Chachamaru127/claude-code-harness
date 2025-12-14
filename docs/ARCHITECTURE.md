# Claude Code Harness Architecture

## 1. 概要

`claude-code-harness`は、Claude Codeの能力を最大限に引き出すための、モジュール化された自律的な開発フレームワークです。中心的な設計思想は、**Plan → Work → Review**という体系的な開発サイクルを、**Skills**、**Rules**、**Hooks**という3つの主要な拡張機能でサポートすることです。

## 2. 3層アーキテクチャ

このプラグインは、再利用性と保守性を高めるために、以下の3層アーキテクチャを採用しています。

```mermaid
graph TD
    subgraph Profile Layer
        A[profiles/claude-worker.yaml]
    end
    subgraph Workflow Layer
        B[init.yaml, plan.yaml, work.yaml, review.yaml]
    end
    subgraph Skill Layer
        C[30+ SKILL.md files]
    end

    A -- references --> B;
    B -- uses --> C;
```

- **Skill Layer**: `SKILL.md`ファイルとして定義される、自己完結した知識ユニットです。特定のタスク（例：セキュリティレビュー、コード実装）を実行するための具体的な手順と知識が含まれています。
- **Workflow Layer**: `*.yaml`ファイルとして定義され、特定の開発フェーズ（例：`/work`）を実行するための**Skills**のオーケストレーションを行います。ステップの順序、条件分岐、エラーハンドリングなどを管理します。
- **Profile Layer**: プラグイン全体の動作を定義します。どのワークフローをどのコマンドに割り当てるか、どのSkillカテゴリを許可するかなどを指定します。

## 3. ディレクトリ構造

```
claude-code-harness/
├── .claude-plugin/         # プラグインメタデータ
│   └── plugin.json
├── skills/                 # Skill定義 (SKILL.md)
│   ├── core/               # コアスキル (常にロード)
│   ├── worker/             # 実装・レビュー用スキル
│   └── ci/                 # CI/CD関連スキル
├── workflows/              # Workflow定義 (YAML)
│   └── default/
├── commands/               # スラッシュコマンド定義 (Markdown)
├── agents/                 # サブエージェント定義 (Markdown)
├── hooks/                  # Hooks定義 (hooks.json)
├── scripts/                # 自動化用シェルスクリプト
├── docs/                   # ドキュメント
└── templates/              # 各種テンプレート
```

## 4. 主要コンポーネント

### 4.1. Skills

各スキルは、`description`（いつ使うべきか）と`allowed-tools`（使用許可ツール）を明記することで、Claudeによる自律的な発見と安全な実行をサポートします。

### 4.2. Rules

`claude-code-harness.config.schema.json` で厳密に定義された設定ファイルにより、安全性（`dry-run`モード）やパス制限（`protected`パス）を強制します。

### 4.3. Hooks

`hooks.json`で定義され、開発プロセスの重要なポイントで自動的にスクリプトを実行します。
- **SessionStart**: セッション開始時の環境チェック
- **PostToolUse**: ファイル編集後の自動テストや変更追跡
- **Stop**: セッション終了時のサマリー生成

### 4.4. 並列処理

`/harness-review`コマンドでは、`code-reviewer`サブエージェントを複数同時に起動し、セキュリティ、パフォーマンス、品質のレビューを並列実行することで、フィードバック時間を大幅に短縮します。
