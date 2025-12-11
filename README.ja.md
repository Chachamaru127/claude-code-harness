# cursor-cc-plugins

### Cursor ↔ Claude Code 2エージェント開発ワークフロー

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![2-Agent](https://img.shields.io/badge/2--Agent-Workflow-orange)](docs/usage-2agent.md)
[![Version](https://img.shields.io/badge/version-0.5.1-green)](CHANGELOG.md)

**Cursor（PM）が計画。Claude Code（Worker）が実装。2つのAI、1つのシームレスなワークフロー。**

このプラグインは **2エージェント開発ワークフロー** を実現します。Cursorが計画・タスク分解・レビューを担当し、Claude Codeが実装・テスト・stagingデプロイを担当します。Soloモード（Claude Code単体）もフォールバックとして利用可能です。

[English](README.md) | 日本語

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
/install cursor-cc-plugins
```

### Step 2: セットアップ

```bash
/setup-2agent
```

生成されるファイル:
```
./
├── AGENTS.md              # 開発フロー概要（共有）
├── CLAUDE.md              # Claude Code 専用設定
├── Plans.md               # タスク管理（共有）
├── .cursor-cc-version     # バージョン管理
├── .cursor/
│   └── commands/          # Cursor PM コマンド
│       ├── start-session.md
│       ├── handoff-to-claude.md
│       ├── review-cc-work.md
│       ├── plan-with-cc.md
│       └── project-overview.md
└── .claude/
    ├── rules/             # ワークフロールール (v0.4.0+)
    │   ├── workflow.md
    │   └── coding-standards.md
    └── memory/            # セッションメモリ
        ├── session-log.md
        ├── decisions.md
        └── patterns.md
```

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
         │   /handoff-to-claude                   │
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

## 機能

### コア機能
- **2エージェントワークフロー**: PM/Worker の役割分担で責務を明確化
- **セーフティファースト**: デフォルトで dry-run モード、保護ブランチ、3回ルール
- **VibeCoder フレンドリー**: 非技術者向けの自然言語インターフェース
- **差分更新**: `/update-2agent` でシームレスなバージョンアップグレード

### v0.4.0+ 新機能
- **Claude Rules** (`.claude/rules/`): YAML frontmatter `paths:` で条件付きルール適用
- **Plugin Hooks** (`hooks/hooks.json`): SessionStart / PostToolUse フックで自動化
- **Named Sessions**: `/rename {名前}` と `/resume {名前}` でセッション追跡
- **Session Memory** (`.claude/memory/`): 決定事項・パターン・セッションログを永続化
- **CI 整合性チェック**: プラグインの整合性を自動検証
- **Self-Healing CI**: `scripts/ci/diagnose-and-fix.sh` で問題の自動検出と修正

### 自動整理機能 (v0.3.7+)
- PostToolUse フックによる自動ファイルサイズ監視
- `.cursor-cc-config.yaml` で閾値をカスタマイズ可能

---

## Solo モード（フォールバック）

Cursor がない？Claude Code 単体でも動きます：

```bash
「Todoアプリを作りたい」
```

Solo モードはシンプルですが、PM/Worker分離やクロスレビューのメリットはありません。

> 詳細: [docs/usage-solo.md](docs/usage-solo.md)

---

## 更新方法

新しいバージョンがリリースされたら：

```bash
/update-2agent
```

Plans.md のタスクを保持しながら、テンプレートとコマンドを更新します。

---

## ドキュメント

| ドキュメント | 説明 |
|-------------|------|
| [2エージェントガイド](docs/usage-2agent.md) | ワークフローの詳細 |
| [Soloガイド](docs/usage-solo.md) | Claude Code 単体 |
| [管理者ガイド](docs/ADMIN_GUIDE.md) | チーム導入・安全設定 |
| [変更履歴](CHANGELOG.md) | バージョン履歴 |

---

## リンク

- [GitHub](https://github.com/Chachamaru127/cursor-cc-plugins)
- [問題を報告](https://github.com/Chachamaru127/cursor-cc-plugins/issues)

MIT License
