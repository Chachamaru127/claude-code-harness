# Claude Code Harness

**Claude Code専用の開発ハーネス。自律的なPlan→Work→Reviewサイクルで高品質な開発を実現します。**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version: 1.0.0](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Chachamaru127/claude-code-harness)

## 概要

`claude-code-harness`は、Claude Codeの能力を最大限に引き出すための包括的な開発支援フレームワークです。**Skills**、**Rules**、**Hooks**といったClaude Codeの拡張機能をフル活用し、自律的な開発サイクルをサポートします。

このプラグインは、[cursor-cc-plugins](https://github.com/Chachamaru127/cursor-cc-plugins)をベースに、Claude Code単独での使用に最適化したものです。

## 主な特徴

- **自律的な開発サイクル**: `/plan`で計画を立て、`/work`で実装し、`/review`で品質をチェックする、体系的な開発フローを提供します。
- **30+のモジュール化されたSkills**: 再利用可能なスキル群により、複雑なタスクを効率的に実行します。各スキルは「いつ使うべきか」を明記し、Claudeの自律的な発見をサポートします。
- **セーフティファースト設計**: デフォルトで`dry-run`モード、保護されたパス設定など、安全性を最優先します。
- **包括的な自動化**: Hooks機能により、セッション開始時の初期化から、ファイル編集後の自動テスト、セッション終了時のサマリーまで、開発プロセスを自動化します。
- **並列処理による高速化**: `/review`コマンドでは、セキュリティ、パフォーマンス、品質のチェックを並列実行し、レビュー時間を短縮します。

## クイックスタート

### 1. インストール

このリポジトリをClaude Codeのプラグインとしてインストールします。

### 2. 初期設定

```bash
/init
```

プロジェクトの初期設定を行い、必要なファイル（Plans.md、CLAUDE.mdなど）を生成します。

### 3. 開発サイクル

```bash
# 計画を立てる
/plan

# 実装する
/work

# レビューする
/review
```

## ワークフロー

```mermaid
graph LR
    A[/init] --> B[/plan];
    B --> C[/work];
    C --> D[/review];
    D -- 改善あり --> C;
    D -- 完了 --> E[Commit];
    E --> B;
```

## コマンド一覧

| コマンド | 説明 |
| :--- | :--- |
| `/init` | プロジェクトの初期設定を行います |
| `/plan` | 開発タスクの計画を作成・更新します |
| `/work` | 計画に基づいてコードを実装します |
| `/review` | コードの品質を多角的にレビューします（並列実行） |
| `/start-task` | 特定のタスクを開始します |
| `/setup-cursor` | **[オプション]** Cursor連携を有効化します |
| `/health-check` | プロジェクトの健全性を診断します |
| `/cleanup` | 不要なファイルをクリーンアップします |
| `/localize-rules` | プロジェクト固有のルールを作成します |
| `/remember` | 長期的な記憶を管理します |
| `/parallel-tasks` | 複数のタスクを並列実行します |

## アーキテクチャ

3層アーキテクチャ（Profile → Workflow → Skill）により、高い再利用性と保守性を実現しています。

詳細は[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)をご覧ください。

## Cursor連携（オプション）

`/setup-cursor`コマンドでCursorとの連携を有効化できます。

- **計画・レビュー**: CursorまたはClaude Codeのどちらでも可能
- **実装**: Claude Code専用

詳細は[docs/CURSOR_INTEGRATION.md](docs/CURSOR_INTEGRATION.md)をご覧ください。

## cursor-cc-pluginsとの違い

| 項目 | cursor-cc-plugins | claude-code-harness |
| :--- | :--- | :--- |
| **対象** | Cursor + Claude Code（2エージェント） | Claude Code単独 |
| **ワークフロー** | PM（Cursor）とWorker（Claude Code）の分離 | 単一エージェントでの自律的な開発 |
| **Skills数** | 38個（PM専用含む） | 30+個（Claude Code専用） |
| **最適化** | 2エージェント間の連携 | Claude Codeの自律性と並列処理 |

## 貢献

バグ報告、機能提案、プルリクエストを歓迎します。

## ライセンス

MIT License

## クレジット

このプロジェクトは、[cursor-cc-plugins](https://github.com/Chachamaru127/cursor-cc-plugins)をベースに作成されました。
