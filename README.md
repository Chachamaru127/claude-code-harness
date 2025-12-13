# Claude Code Harness

![Claude Code Harness](docs/images/hero.png)

**思考の流れを妨げない開発体験**

Claude Code用の開発ハーネス。Plan → Work → Reviewの自律的なワークフローで、AI開発の体験を根本から改善します。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version: 2.0.0](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/Chachamaru127/claude-code-harness)

---

## 主な特徴

![主な特徴](docs/images/features.png)

### 🧠 思考の流れを妨げない

- **自律的なワークフロー**: Plan → Work → Reviewが自動で回る。何度も指示しなくていい
- **メモリ管理（SSOT）**: 判断や決定を記憶し、再利用。同じことを繰り返さない
- **セッション間の継続性**: 前回の続きから自然に再開できる

### 🛡️ 安心して任せられる

- **PreToolUse Guard**: 危険な操作を事前にブロック
- **保護されたパス**: `.git/`, `.env`への書き込み禁止
- **Dry-runモード**: 実行前に確認できる

### ⚡ 待たされない

- **並列レビュー**: セキュリティ、パフォーマンス、品質を同時チェック
- **バックグラウンド実行**: 他の作業をしながらレビュー
- **即座のフィードバック**: 問題を早期発見

---

## クイックスタート

### 新しいプロジェクト

```bash
# Claude Codeでプロジェクトを開く
claude --plugin-dir /path/to/claude-code-harness

# ハーネスを初期化
/harness-init
```

### 既存プロジェクト

```bash
# プロジェクトのルートで
/harness-init

# プロジェクトを分析して、既存のルールやスタイルを自動検出・適用
```

---

## 基本的な使い方

### 開発サイクル

```bash
# 1. 計画を立てる
/plan

# 2. 実装する
/work

# 3. レビューする（並列実行）
/harness-review
```

### その他の便利なコマンド

```bash
# CRUD機能を追加
/crud

# 認証機能を追加
/auth

# 決済機能を追加
/payments

# デプロイ設定
/deploy-setup

# Cursor連携（オプション）
/setup-cursor
```

---

## こんな体験ができます

### 新しいプロジェクト
**すぐに始められる**  
`/harness-init`で自動設定。設定に時間を取られず、すぐにコードが書ける

### 既存プロジェクト
**ルールを自動理解**  
プロジェクトを分析して、既存のルール、スタイル、慣習を自動検出して適用

### レビュー
**並列実行で高速**  
複数の観点を同時チェック。待ち時間がなく、すぐに次に進める

### セッション再開
**続きから自然に**  
前回の決定や判断を自動で読み込み。中断しても、すぐに元の流れに戻れる

---

## プレゼンテーション

開発体験の改善について、詳しくは以下のスライドをご覧ください：

1. [問題提起](docs/presentation/slide1_problem.png) - AI開発、本当に快適ですか？
2. [解決策](docs/presentation/slide2_solution.png) - 思考の流れを妨げない開発体験
3. [具体的な体験](docs/presentation/slide3_experience.png) - こんな体験ができます
4. [今すぐ始める](docs/presentation/slide4_cta.png) - 快適な開発体験を

---

## ワークフロー

```mermaid
graph LR
    A[/harness-init] --> B[/plan];
    B --> C[/work];
    C --> D[/harness-review];
    D -- 改善あり --> C;
    D -- 完了 --> E[Commit];
    E --> B;
```

---

## コマンド一覧

| コマンド | 説明 |
| :--- | :--- |
| `/harness-init` | プロジェクトの初期設定を行います（推奨） |
| `/plan` | 開発タスクの計画を作成・更新します |
| `/work` | 計画に基づいてコードを実装します |
| `/harness-review` | コードの品質を多角的にレビューします（並列実行・推奨） |
| `/crud` | CRUD機能を実装します |
| `/auth` | 認証機能を実装します |
| `/payments` | 決済機能を実装します（Stripe） |
| `/deploy-setup` | デプロイ自動化を設定します |
| `/start-task` | 特定のタスクを開始します |
| `/setup-cursor` | **[オプション]** Cursor連携を有効化します |
| `/handoff-to-cursor` | **[オプション]** Cursor(PM)向けの完了報告を生成します |
| `/health-check` | プロジェクトの健全性を診断します |
| `/cleanup` | 不要なファイルをクリーンアップします |
| `/localize-rules` | プロジェクト固有のルールを作成します |
| `/remember` | 長期的な記憶を管理します |
| `/parallel-tasks` | 複数のタスクを並列実行します |

---

## 非同期サブエージェントによる高度なワークフロー

Claude Codeの**非同期サブエージェント機能**を活用することで、複数のタスクをバックグラウンドで並列実行できます。

**主なユースケース**:
- **並列コードレビュー**: 複数の観点（セキュリティ、パフォーマンスなど）を同時に実行
- **長時間タスクの監視**: ビルドやテストをバックグラウンドで実行し、その間に他の作業を続ける

**使い方**:
1. タスクを開始（例: `/harness-review security`）
2. `Ctrl + B` でバックグラウンドに送る
3. 次のタスクを開始
4. 各タスクが完了すると自動的に通知

詳細は[docs/ASYNC_SUBAGENTS.md](docs/ASYNC_SUBAGENTS.md)をご覧ください。

---

## アーキテクチャ

3層アーキテクチャ（Profile → Workflow → Skill）により、高い再利用性と保守性を実現しています。

詳細は[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)をご覧ください。

---

## メモリ管理（SSOT）

プロジェクトの意思決定と再利用パターンは `.claude/memory/decisions.md` / `.claude/memory/patterns.md` を **SSOT** として運用することを推奨します。

詳細は[docs/MEMORY_POLICY.md](docs/MEMORY_POLICY.md)をご覧ください。

---

## Cursor連携（オプション）

`/setup-cursor`コマンドでCursorとの連携を有効化できます。

- **計画・レビュー**: CursorまたはClaude Codeのどちらでも可能
- **実装**: Claude Code専用

詳細は[docs/CURSOR_INTEGRATION.md](docs/CURSOR_INTEGRATION.md)をご覧ください。

---

## ドキュメント

- [実装ガイド](IMPLEMENTATION_GUIDE.md) - 詳細な実装ガイド
- [開発フローガイド](DEVELOPMENT_FLOW_GUIDE.md) - 開発フロー完全ガイド
- [メモリポリシー](docs/MEMORY_POLICY.md) - メモリ管理の方針
- [アーキテクチャ](docs/ARCHITECTURE.md) - システム設計
- [Cursor統合](docs/CURSOR_INTEGRATION.md) - Cursorとの連携
- [非同期サブエージェント](docs/ASYNC_SUBAGENTS.md) - 並列実行の詳細

---

## 貢献

バグ報告、機能提案、プルリクエストを歓迎します。

---

## ライセンス

MIT License

---

**今すぐ、快適な開発体験を**

```bash
/harness-init
```

設定は30秒。すぐに始められます。
