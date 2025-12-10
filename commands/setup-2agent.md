# /setup-2agent - 2エージェント体制セットアップ

Cursor (PM) と Claude Code (Worker) の2エージェント体制を一発でセットアップします。
両方のエージェントに必要なファイルを自動生成します。

---

## このコマンドの特徴

- **ワンコマンドセットアップ**: 必要なファイルを全て自動生成
- **Cursor側設定も生成**: `.cursor/commands/` にPM用コマンドを配置
- **テンプレートベース**: `templates/` の詳細版テンプレートを使用
- **バージョン管理**: 更新が必要な場合に通知

---

## ⚠️ `/init` との違い

| コマンド | 目的 | いつ使う |
|---------|------|---------|
| **`/setup-2agent`** | 2-Agent体制のファイルセットアップ | プラグイン導入直後（1回） |
| `/init` | 新規プロジェクト作成 | 新しいアプリを作りたい時 |

**正しい順序**:
1. `/setup-2agent` - 2-Agent 用ファイルをセットアップ
2. `/init` - 新しいプロジェクトを作成（必要な場合のみ）
3. `/plan` + `/work` - 機能追加

---

## 使い方

```
/setup-2agent
```

または自然言語で：
- 「2エージェント体制をセットアップして」
- 「Cursorと連携できるようにして」

---

## 生成されるファイル

```
./
├── AGENTS.md              # 開発フロー概要（両エージェント共通）
├── CLAUDE.md              # Claude Code 専用設定
├── Plans.md               # タスク管理（共有）
├── .cursor-cc-version     # バージョン管理
├── .cursor/
│   └── commands/
│       ├── assign-to-cc.md      # タスク依頼コマンド
│       └── review-cc-work.md    # 完了レビューコマンド
└── .claude/
    └── memory/
        ├── session-log.md       # セッションログ
        ├── decisions.md         # 決定事項記録
        └── patterns.md          # パターン記録
```

---

## 実行フロー

> **Note**: このコマンドは `workflows/default/setup-2agent.yaml` に従って実行されます。
> 詳細な手順は各スキル（`ccp-generate-workflow-files`, `ccp-setup-2agent-files`）で定義されています。

### Phase 1: 状態確認

1. `.cursor-cc-version` をチェックしてセットアップ状態を判定
2. プラグインバージョンと比較

| 状態 | 判定 | 動作 |
|------|------|------|
| ファイルなし | 新規セットアップ | 全ファイル作成 |
| 同じバージョン | 最新 | スキップ（上書き確認） |
| 古いバージョン | 更新あり | 更新を適用 |

### Phase 2: ワークフローファイル生成

`ccp-generate-workflow-files` スキルが以下を生成:

- **AGENTS.md** ← `templates/AGENTS.md.template`
- **CLAUDE.md** ← `templates/CLAUDE.md.template`
- **Plans.md** ← `templates/Plans.md.template`

### Phase 3: 補助ファイル配置

`ccp-setup-2agent-files` スキルが以下を配置:

- **.cursor/commands/** ← `templates/cursor/commands/` からコピー
- **.claude/memory/** ← 初期構造を作成
- **.cursor-cc-version** ← `templates/.cursor-cc-version.template` から生成

---

## VibeCoder向け案内

| やりたいこと | どちらで言う | 言い方 |
|-------------|-------------|--------|
| タスクを依頼 | Cursor | 「〇〇を実装して」→ `/assign-to-cc` |
| 実装する | Claude Code | 「次のタスク」→ `/start-task` |
| 完了報告 | Claude Code | 「終わった」→ `/handoff-to-cursor` |
| レビュー | Cursor | 「確認して」→ `/review-cc-work` |

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `workflows/default/setup-2agent.yaml` | ワークフロー定義 |
| `skills/core/ccp-generate-workflow-files/SKILL.md` | AGENTS.md等の生成スキル |
| `skills/core/ccp-setup-2agent-files/SKILL.md` | Cursorコマンド等の配置スキル |
| `templates/` | テンプレートファイル |

---

## 注意事項

- 既存の AGENTS.md, CLAUDE.md, Plans.md がある場合は上書き確認
- Cursor のカスタムコマンドは `.cursor/commands/` に配置
- Plans.md は両エージェントで共有・編集
