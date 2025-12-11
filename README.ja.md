# cursor-cc-plugins

### Cursor ↔ Claude Code 2エージェント開発ワークフロー

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![2-Agent](https://img.shields.io/badge/2--Agent-Workflow-orange)](docs/usage-2agent.md)
[![Version](https://img.shields.io/badge/version-0.3.9-green)](CHANGELOG.md)

**Cursor（PM）が計画。Claude Code（Worker）が実装。2つのAI、1つのシームレスなワークフロー。**

このプラグインは **2エージェント開発ワークフロー** を実現します。Cursorが計画・タスク分解・レビューを担当し、Claude Codeが実装・テスト・stagingデプロイを担当します。Soloモード（Claude Code単体）もフォールバックとして利用可能です。

[English](README.md) | 日本語

![Cursor が計画、Claude Code が構築](docs/images/workflow-ja.png)

---

## どう動く？

```
あなた: 「ブログアプリを作りたい」

    ↓ Cursor (PM) が計画を立てる

Cursor: 「タスクを整理しました。Claude Code に依頼します」

    ↓ あなたがコピー＆ペーストで Claude Code に渡す

Claude Code (Worker): 「実装完了！レビューお願いします」

    ↓ あなたがコピー＆ペーストで Cursor に戻す

Cursor: 「レビューOK。デプロイしましょう」
```

**計画 → 実装 → レビュー のサイクルを、2つの専門AIが実現。**

---

## クイックスタート

### Step 1: インストール

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

### Step 2: セットアップ ⭐

```bash
/setup-2agent
```

生成されるファイル: `AGENTS.md`, `Plans.md`, `.cursor/commands/`

### Step 3: Cursor で開始

Cursor を開いて、作りたいものを伝える：

```
あなた → Cursor: 「ECサイトを作りたい」
Cursor: 「いいですね！タスクに分解しますね...」
```

実装が必要になったら、Cursor が Claude Code へのタスクを出力します。

---

## ワークフロー

```
┌─────────────────┐                      ┌─────────────────┐
│  Cursor (PM)    │                      │  Claude Code    │
│                 │                      │   (Worker)      │
│  • 計画         │   Plans.md (共有)    │  • 実装         │
│  • レビュー     │ ◄──────────────────► │  • テスト       │
│  • 本番デプロイ │                      │  • Staging      │
└────────┬────────┘                      └────────┬────────┘
         │   /handoff-to-claude                        │
         └───────────────────────────────────────►│
         │◄───────────────────────────────────────┘
         │   /handoff-to-cursor
```

**あなたがコピー＆ペーストで Cursor と Claude Code を橋渡し。** 何が起きているか常に把握でき、安全です。

---

## コマンド

### Claude Code コマンド

| コマンド | 説明 |
|---------|------|
| `/setup-2agent` | **最初に実行**。ワークフローファイルを作成 |
| `/update-2agent` | 既存セットアップを最新版に更新 |
| `/init` | 新規プロジェクトを初期化 |
| `/plan` | 計画を立てる |
| `/work` | タスクを実装 |
| `/review` | 変更をレビュー |
| `/start-task` | Cursor からのタスクを受け取る |
| `/handoff-to-cursor` | 完了報告を Cursor に送る |
| `/sync-status` | Plans.md の状態を同期 |
| `/health-check` | 環境診断 |
| `/cleanup` | ファイル整理（Plans.md のアーカイブなど） |

### Cursor コマンド

| コマンド | 説明 |
|---------|------|
| `/handoff-to-claude` | タスクを Claude Code に送る |
| `/review-cc-work` | Claude Code の作業をレビュー |
| `/start-session` | セッション開始→計画→依頼まで自動化 |
| `/project-overview` | プロジェクト全体を確認 |
| `/plan-with-cc` | Claude Code と一緒に計画 |

> 新規プロジェクトの場合は `/setup-2agent` の後に `/init` を実行。

---

## Solo モード（フォールバック）

Cursor がない？Claude Code 単体でも動きます：

```bash
「Todoアプリを作りたい」
```

Solo モードはシンプルですが、PM/Worker分離やクロスレビューのメリットはありません。

> 詳細: [docs/usage-solo.md](docs/usage-solo.md)

---

## 機能

- **2エージェントワークフロー**: PM/Worker の役割分担で責務を明確化
- **セーフティファースト**: デフォルトで dry-run モード、保護ブランチ、3回ルール
- **VibeCoder フレンドリー**: 非技術者向けの自然言語インターフェース
- **自動整理機能** (v0.3.7+): PostToolUse フックによる自動ファイルサイズ監視
- **差分更新**: `/update-2agent` でシームレスなバージョンアップグレード
- **カスタマイズ可能**: `cursor-cc.config.json` でチーム固有の設定

---

## ドキュメント

| ドキュメント | 説明 |
|-------------|------|
| [2エージェントガイド](docs/usage-2agent.md) | ワークフローの詳細 |
| [Soloガイド](docs/usage-solo.md) | Claude Code 単体 |
| [管理者ガイド](docs/ADMIN_GUIDE.md) | チーム導入・安全設定 |
| [アーキテクチャ](docs/ARCHITECTURE.md) | 技術的な内部構造 |
| [制限事項](docs/LIMITATIONS.md) | 既知の制約 |

---

## リンク

- [GitHub](https://github.com/Chachamaru127/cursor-cc-plugins)
- [問題を報告](https://github.com/Chachamaru127/cursor-cc-plugins/issues)

MIT License
