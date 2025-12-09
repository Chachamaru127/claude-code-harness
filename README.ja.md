# cursor-cc-plugins v3.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Safety First](https://img.shields.io/badge/Safety-First-green)](docs/ADMIN_GUIDE.md)

**Cursor が PM、Claude Code が Worker として協調する「2エージェント開発ワークフロー」プラグイン。**

Plans.md と共通のスキルレイヤーを共有しながら、Cursor が要件整理・タスク分解を行い、Claude Code が実装・テスト・修正を担当します。Solo モード（Claude Code のみ）も利用可能ですが、**推奨は 2-Agent 構成**です。

[English](README.md) | 日本語

![2つのAI、1つのシームレスなワークフロー - Cursorが計画、Claude Codeが構築](docs/images/workflow-ja.png)

---

## 目次

1. [2-Agent 概要](#1-2-agent-概要) - Cursor + Claude Code の役割分担
2. [クイックスタート](#2-クイックスタート) - セットアップと最初の一歩
3. [コマンド](#3-コマンド) - 使えるコマンド一覧
4. [セーフティと設定](#4-セーフティと設定) - セーフティ設定の概要
5. [Solo モード](#5-solo-モード) - Claude Code のみで使う場合
6. [ドキュメント](#6-ドキュメント) - 詳細ドキュメントへのリンク

---

## 1. 2-Agent 概要

このプラグインは、**2つのエージェントが役割分担して開発を進める**ことを前提に設計されています。

### Cursor (PM エージェント)

- ユーザーの要望を受けて**要件整理**
- Plans.md に**タスクを分解**して記述
- **進捗管理**や優先度の調整
- 完了報告を**レビュー**して本番デプロイ判断

### Claude Code (Worker エージェント)

- Plans.md のタスクをもとに**実装・リファクタ**
- **テスト**の追加・修正
- **CIエラー**の解析と修正（最大3回自動リトライ）
- **stagingデプロイ**まで担当

### 協調の仕組み

```
┌─────────────────┐                      ┌─────────────────┐
│  Cursor (PM)    │                      │  Claude Code    │
│                 │                      │   (Worker)      │
│  • 要件整理     │   Plans.md (共有)    │  • 実装         │
│  • タスク分解   │ ◄──────────────────► │  • テスト       │
│  • レビュー     │                      │  • CI修正       │
│  • 本番デプロイ │                      │  • Staging      │
└────────┬────────┘                      └────────┬────────┘
         │                                        │
         │   /assign-to-cc                        │
         └───────────────────────────────────────►│
                                                  │
         │◄───────────────────────────────────────┘
         │   /handoff-to-cursor
```

両者は **Plans.md** と **skills/ 以下の SKILL.md** を共有しながら協調します。

---

## 2. クイックスタート

### 推奨: 2-Agent モード (Cursor + Claude Code)

**これが本プラグインの標準の使い方です。**

#### Step 1: インストール (Claude Code)

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

#### Step 2: 2-Agent ファイルセットアップ (Claude Code)

```
/setup-2agent
```

作成されるファイル: `AGENTS.md`, `Plans.md`, `.cursor/commands/`

#### Step 3: 開発開始 (Cursor)

```
[Cursor] 「ブログアプリを作りたい」
         → Cursor が計画作成 → /assign-to-cc

[あなた] タスクをコピー → Claude Code に貼り付け

[Claude Code] /start-task → 実装 → /handoff-to-cursor

[あなた] 結果をコピー → Cursor に貼り付け

[Cursor] レビュー → 本番デプロイ
```

> 📖 詳細なワークフローは [docs/usage-2agent.md](docs/usage-2agent.md) を参照

---

### フォールバック: Solo モード (Claude Code のみ)

Cursor を使えない環境や、簡単なプロトタイプ用の**サブモード**です。

```bash
# インストール
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins

# 開始（直接 Claude Code に話しかける）
「Todoアプリを作りたい」
```

> 📖 Solo モードの詳細は [docs/usage-solo.md](docs/usage-solo.md) を参照

---

## 3. コマンド

| コマンド | 誰が使う | 何をするか |
|---------|----------|-----------|
| `/init` | Claude Code | プロジェクト作成・セットアップ |
| `/plan` | 両方 | 機能をタスクに分解 |
| `/work` | Claude Code | タスクを実行してコード生成 |
| `/review` | 両方 | コード品質チェック |
| `/sync-status` | 両方 | 進捗状況を確認 |
| `/start-task` | Claude Code | PM からのタスクを開始 |
| `/handoff-to-cursor` | Claude Code | 完了報告を生成 |
| `/setup-2agent` | Claude Code | 2-Agent 用ファイルを生成 |

### Cursor コマンド (/setup-2agent 実行後)

| コマンド | 何をするか |
|---------|-----------|
| `/assign-to-cc` | Claude Code にタスクを依頼 |
| `/review-cc-work` | Claude Code の完了報告をレビュー |

---

## 4. セーフティと設定

v3.0 では**セーフティファースト設計**を採用。意図しない破壊的操作から保護します。

### セーフティモード

| モード | 動作 | 使用場面 |
|--------|------|---------|
| `dry-run` | 変更なし、何が起きるか表示 | デフォルト・安全に探索 |
| `apply-local` | ローカル変更のみ、push なし | 通常の開発 |
| `apply-and-push` | git push を含む完全自動化 | CI/CD（要注意） |

### クイック設定

`cursor-cc.config.json`:

```json
{
  "safety": { "mode": "apply-local" },
  "git": { "protected_branches": ["main", "master"] },
  "paths": { "protected": [".env", "secrets/"] }
}
```

> 📖 詳細な設定は [docs/ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md) を参照

---

## 5. Solo モード

Solo モードは **2-Agent モードの簡易版**です。

| 機能 | Solo モード | 2-Agent モード |
|------|------------|---------------|
| 計画 | セルフ管理 | Cursor が担当 |
| コードレビュー | セルフレビュー | Cursor がレビュー |
| 本番デプロイ | 手動 | Cursor が判断 |
| 推奨用途 | プロトタイプ | 本番プロジェクト |

### 自然言語コマンド (Solo モード)

| 言い方 | 何が動くか |
|--------|-----------|
| 「ブログを作りたい」 | `/init` |
| 「ログイン機能を追加」 | `/plan` + `/work` |
| 「動かして」 | 開発サーバー起動 |
| 「チェックして」 | `/review` |

> 📖 Solo モードの詳細は [docs/usage-solo.md](docs/usage-solo.md) を参照

---

## 6. ドキュメント

### 使い方ガイド

| ドキュメント | 説明 |
|-------------|------|
| [usage-2agent.md](docs/usage-2agent.md) | 2-Agent モードの詳細ガイド |
| [usage-solo.md](docs/usage-solo.md) | Solo モードの詳細ガイド |
| [ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md) | チーム導入・セーフティ設定 |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Skill/Workflow/Profile 構造 |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | 制限事項と回避策 |

### アーキテクチャ (v3)

v3 は 3層の **Skill / Workflow / Profile** アーキテクチャを採用:

```
Profile (誰が使うか)  →  Workflow (どう流れるか)  →  Skill (何をするか)
```

#### SkillPort 連携

| SkillPort なし | SkillPort あり |
|---------------|---------------|
| Claude Code 内で完結 | Cursor からも同じ skills/ を利用可能 |
| セットアップ不要 | MCP 設定が必要 |
| 個人向け | チーム・マルチツール向け |

> 📖 詳細は [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) を参照

---

## v2 からのアップグレード

| 質問 | 回答 |
|------|------|
| プロジェクトが壊れる？ | **いいえ** - v2 のコマンドはそのまま動く |
| v3 で何が変わった？ | セーフティ設定、Skill/Workflow/Profile アーキテクチャ |
| 何か変更が必要？ | アドバンスド機能を使いたい場合のみ |

---

## インストール

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

---

## コントリビュート

ガイドラインは [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。

## リンク

- [GitHub リポジトリ](https://github.com/Chachamaru127/cursor-cc-plugins)
- [Claude Code ドキュメント](https://docs.anthropic.com/en/docs/claude-code)
- [問題を報告](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
