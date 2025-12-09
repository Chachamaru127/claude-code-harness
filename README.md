# cursor-cc-plugins v3.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)
[![Safety First](https://img.shields.io/badge/Safety-First-green)](docs/ADMIN_GUIDE.md)

**Cursor が PM、Claude Code が Worker として協調する「2エージェント開発ワークフロー」プラグイン。**

Plans.md と共通のスキルレイヤーを共有しながら、Cursor が要件整理・タスク分解を行い、Claude Code が実装・テスト・修正を担当します。Solo モード（Claude Code のみ）も利用可能ですが、**推奨は 2-Agent 構成**です。

English | [日本語](README.ja.md)

![Two AIs, One Seamless Workflow - Cursor plans, Claude Code builds](docs/images/workflow-en.png)

---

## Table of Contents

1. [2-Agent Overview](#1-2-agent-overview) - Cursor + Claude Code の役割分担
2. [Quick Start](#2-quick-start) - セットアップと最初の一歩
3. [Commands](#3-commands) - 使えるコマンド一覧
4. [Safety & Configuration](#4-safety--configuration) - セーフティ設定の概要
5. [Solo Mode](#5-solo-mode) - Claude Code のみで使う場合
6. [Documentation](#6-documentation) - 詳細ドキュメントへのリンク

---

## 1. 2-Agent Overview

このプラグインは、**2つのエージェントが役割分担して開発を進める**ことを前提に設計されています。

### Cursor (PM Agent)

- ユーザーの要望を受けて**要件整理**
- Plans.md に**タスクを分解**して記述
- **進捗管理**や優先度の調整
- 完了報告を**レビュー**して本番デプロイ判断

### Claude Code (Worker Agent)

- Plans.md のタスクをもとに**実装・リファクタ**
- **テスト**の追加・修正
- **CIエラー**の解析と修正（最大3回自動リトライ）
- **stagingデプロイ**まで担当

### How They Collaborate

```
┌─────────────────┐                      ┌─────────────────┐
│  Cursor (PM)    │                      │  Claude Code    │
│                 │                      │   (Worker)      │
│  • Requirements │   Plans.md (shared)  │  • Implement    │
│  • Task分解     │ ◄──────────────────► │  • Test         │
│  • Review       │                      │  • Fix CI       │
│  • Prod deploy  │                      │  • Staging      │
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

## 2. Quick Start

### Recommended: 2-Agent Mode (Cursor + Claude Code)

**これが本プラグインの標準の使い方です。**

#### Step 1: Install (Claude Code)

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

#### Step 2: Setup 2-Agent Files (Claude Code)

```
/setup-2agent
```

This creates: `AGENTS.md`, `Plans.md`, `.cursor/commands/`

#### Step 3: Start Development (Cursor)

```
[Cursor] "I want to build a blog app"
         → Cursor creates plan → /assign-to-cc

[You]    Copy task → Paste to Claude Code

[Claude Code] /start-task → implements → /handoff-to-cursor

[You]    Copy result → Paste to Cursor

[Cursor] Review → Deploy to production
```

> 📖 詳細なワークフローは [docs/usage-2agent.md](docs/usage-2agent.md) を参照

---

### Fallback: Solo Mode (Claude Code only)

Cursor を使えない環境や、簡単なプロトタイプ用の**サブモード**です。

```bash
# Install
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins

# Start (直接 Claude Code に話しかける)
"I want to build a todo app"
```

> 📖 Solo モードの詳細は [docs/usage-solo.md](docs/usage-solo.md) を参照

---

## 3. Commands

| Command | Who Uses | What It Does |
|---------|----------|--------------|
| `/init` | Claude Code | プロジェクト作成・セットアップ |
| `/plan` | Both | 機能をタスクに分解 |
| `/work` | Claude Code | タスクを実行してコード生成 |
| `/review` | Both | コード品質チェック |
| `/sync-status` | Both | 進捗状況を確認 |
| `/start-task` | Claude Code | PM からのタスクを開始 |
| `/handoff-to-cursor` | Claude Code | 完了報告を生成 |
| `/setup-2agent` | Claude Code | 2-Agent 用ファイルを生成 |

### Cursor Commands (after /setup-2agent)

| Command | What It Does |
|---------|--------------|
| `/assign-to-cc` | Claude Code にタスクを依頼 |
| `/review-cc-work` | Claude Code の完了報告をレビュー |

---

## 4. Safety & Configuration

v3.0 では**セーフティファースト設計**を採用。意図しない破壊的操作から保護します。

### Safety Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `dry-run` | 変更なし、何が起きるか表示 | デフォルト・安全に探索 |
| `apply-local` | ローカル変更のみ、push なし | 通常の開発 |
| `apply-and-push` | git push を含む完全自動化 | CI/CD（要注意） |

### Quick Config

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

## 5. Solo Mode

Solo Mode は **2-Agent モードの簡易版**です。

| Feature | Solo Mode | 2-Agent Mode |
|---------|-----------|--------------|
| Planning | セルフ管理 | Cursor が担当 |
| Code Review | セルフレビュー | Cursor がレビュー |
| Production Deploy | 手動 | Cursor が判断 |
| Best For | プロトタイプ | 本番プロジェクト |

### Natural Language (Solo Mode)

| Say This | What Runs |
|----------|-----------|
| "Build a blog" | `/init` |
| "Add login" | `/plan` + `/work` |
| "Run it" | Dev server starts |
| "Check it" | `/review` |

> 📖 Solo モードの詳細は [docs/usage-solo.md](docs/usage-solo.md) を参照

---

## 6. Documentation

### Usage Guides

| Document | Description |
|----------|-------------|
| [usage-2agent.md](docs/usage-2agent.md) | 2-Agent モードの詳細ガイド |
| [usage-solo.md](docs/usage-solo.md) | Solo モードの詳細ガイド |
| [ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md) | チーム導入・セーフティ設定 |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Skill/Workflow/Profile 構造 |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | 制限事項と回避策 |

### Architecture (v3)

v3 は 3層の **Skill / Workflow / Profile** アーキテクチャを採用:

```
Profile (誰が使うか)  →  Workflow (どう流れるか)  →  Skill (何をするか)
```

#### SkillPort Integration

| Without SkillPort | With SkillPort |
|-------------------|----------------|
| Claude Code 内で完結 | Cursor からも同じ skills/ を利用可能 |
| セットアップ不要 | MCP 設定が必要 |
| 個人向け | チーム・マルチツール向け |

> 📖 詳細は [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) を参照

---

## Upgrading from v2?

| Question | Answer |
|----------|--------|
| Does my project break? | **No** - v2 commands work the same |
| What's new? | Safety config, Skill/Workflow/Profile architecture |
| Do I need to change? | Only for Advanced features |

---

## Installation

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [GitHub Repository](https://github.com/Chachamaru127/cursor-cc-plugins)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Report Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
