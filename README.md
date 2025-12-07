# cursor-cc-plugins

Cursor ↔ Claude Code 2エージェントワークフローを実現するプラグイン。

PM（Cursor）とWorker（Claude Code）の役割分担、Plans.md管理、CI/CD自動修正を提供します。

---

## 特徴

- **2エージェント体制**: Cursor（PM）と Claude Code（Worker）の明確な役割分担
- **Plans.md タスク管理**: マーカーベースの進捗追跡
- **CI/CD 自動修正**: 失敗時に最大3回まで自動修正、その後エスカレーション
- **VibeCoder 対応**: 技術的な知識がなくても使えるセットアップフロー

---

## インストール

```bash
# Claude Code のプラグインディレクトリにクローン
cd ~/.claude/plugins/
git clone https://github.com/Chachamaru127/cursor-cc-plugins
```

または、Claude Code マーケットプレースからインストール。

---

## クイックスタート

### 1. プロジェクトのセットアップ

```
/cursor-cc-plugins:init
```

対話形式で以下が生成されます：
- `AGENTS.md` - 開発フロー概要
- `CLAUDE.md` - Claude Code 固有設定
- `Plans.md` - タスク管理ファイル

### 2. タスクの依頼（Cursor側）

```
/assign-to-cc ユーザー認証機能を実装
```

### 3. タスクの開始（Claude Code側）

```
/cursor-cc-plugins:start-task
```

### 4. 完了報告（Claude Code側）

```
/cursor-cc-plugins:handoff-to-cursor
```

### 5. レビュー（Cursor側）

```
/review-cc-work
```

---

## コマンド一覧

| コマンド | 用途 | 実行者 |
|---------|------|--------|
| `/init` | プロジェクトセットアップ | Claude Code |
| `/start-task` | タスク開始 | Claude Code |
| `/handoff-to-cursor` | 完了報告 | Claude Code |
| `/sync-status` | 状態確認 | Claude Code |
| `/assign-to-cc` | タスク依頼 | Cursor |
| `/review-cc-work` | レビュー | Cursor |

---

## スキル一覧

| スキル | トリガーフレーズ |
|--------|------------------|
| session-init | 「セッション開始」「作業開始」 |
| workflow-guide | 「ワークフローについて教えて」 |
| plans-management | 「タスクを追加して」「Plans.md を更新して」 |

---

## エージェント一覧

| エージェント | 用途 |
|-------------|------|
| project-analyzer | 新規/既存プロジェクト判定 |
| ci-cd-fixer | CI失敗時の自動修正（3回まで） |
| project-state-updater | Plans.md 状態同期 |

---

## Plans.md マーカー

| マーカー | 意味 | 設定者 |
|---------|------|--------|
| `cursor:依頼中` | Cursor から依頼 | Cursor |
| `cc:TODO` | Claude Code 未着手 | どちらでも |
| `cc:WIP` | Claude Code 作業中 | Claude Code |
| `cc:完了` | Claude Code 完了 | Claude Code |
| `cursor:確認済` | Cursor 確認完了 | Cursor |
| `blocked` | ブロック中 | どちらでも |

---

## ワークフロー図

```
Cursor (PM)          Claude Code (Worker)
    │                       │
    │  1. タスク依頼        │
    │  (/assign-to-cc)      │
    │──────────────────────>│
    │                       │
    │                       │ 2. 実装・テスト・コミット
    │                       │    (/start-task)
    │                       │
    │  3. 完了報告          │
    │  (/handoff-to-cursor) │
    │<──────────────────────│
    │                       │
    │ 4. レビュー・本番判断  │
    │  (/review-cc-work)    │
    │                       │
```

---

## ライセンス

MIT License

---

## 貢献

Issue や Pull Request を歓迎します。

---

## 作者

Cursor-CC Plugins Contributors
