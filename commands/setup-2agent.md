# /setup-2agent - 2エージェント体制セットアップ

Cursor (PM) と Claude Code (Worker) の2エージェント体制を一発でセットアップします。
両方のエージェントに必要なファイルを自動生成します。

---

## ⚠️ 実行手順（必須）

**このコマンドを実行する際、以下の手順を必ず実行すること：**

### Step 1: セットアップスクリプトを実行

```bash
~/.claude/plugins/marketplaces/cursor-cc-marketplace/scripts/setup-2agent.sh
```

### Step 2: AGENTS.md, CLAUDE.md, Plans.md を生成

スクリプト実行後、テンプレートを使って以下を生成：
- AGENTS.md ← `templates/AGENTS.md.template`
- CLAUDE.md ← `templates/CLAUDE.md.template`
- Plans.md ← `templates/Plans.md.template`

### Step 3: 検証チェックリストを確認

スクリプトが作成するファイル（自動検証）：

- [ ] `.cursor/commands`
- [ ] `.cursor/commands/start-session.md`
- [ ] `.cursor/commands/handoff-to-claude.md`
- [ ] `.cursor/commands/review-cc-work.md`
- [ ] `.cursor/commands/plan-with-cc.md`
- [ ] `.cursor/commands/project-overview.md`
- [ ] `.claude/rules`
- [ ] `.claude/rules/workflow.md`
- [ ] `.claude/rules/coding-standards.md`
- [ ] `.claude/memory`
- [ ] `.claude/memory/session-log.md`
- [ ] `.claude/memory/decisions.md`
- [ ] `.claude/memory/patterns.md`
- [ ] `.cursor-cc-version`

Step 2 で Claude が生成するファイル：

- [ ] `AGENTS.md`
- [ ] `CLAUDE.md`
- [ ] `Plans.md`

**全てのチェックが通るまで完了とみなさないこと。**

---

## このコマンドの特徴

- **ワンコマンドセットアップ**: 必要なファイルを全て自動生成
- **Cursor側設定も生成**: `.cursor/commands/` にPM用コマンドを配置
- **テンプレートベース**: `templates/` の詳細版テンプレートを使用
- **バージョン管理**: 更新が必要な場合に通知
- **Case-Insensitive検出**: `plans.md` / `Plans.md` / `PLANS.MD` を同一視
- **既存ファイル対応**: 既存がある場合は `/update-2agent` を案内

---

## ⚠️ 他のコマンドとの違い

| コマンド | 目的 | いつ使う |
|---------|------|---------|
| **`/setup-2agent`** | 2-Agent体制の**初回**セットアップ | プラグイン導入直後（1回） |
| `/update-2agent` | 既存環境の**更新** | プラグイン更新後 |
| `/init` | 新規プロジェクト作成 | 新しいアプリを作りたい時 |

**正しい順序**:
1. `/setup-2agent` - 2-Agent 用ファイルをセットアップ（初回のみ）
2. `/init` - 新しいプロジェクトを作成（必要な場合のみ）
3. `/plan` + `/work` - 機能追加
4. `/update-2agent` - プラグイン更新時に実行

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
│       ├── handoff-to-claude.md      # タスク依頼コマンド
│       └── review-cc-work.md    # 完了レビューコマンド
└── .claude/
    ├── rules/                   # ワークフロールール（v0.4.0+）
    │   ├── workflow.md          # 2-Agent ワークフロールール
    │   └── coding-standards.md  # コーディング規約
    └── memory/
        ├── session-log.md       # セッションログ
        ├── decisions.md         # 決定事項記録
        └── patterns.md          # パターン記録
```

---

## 実行フロー

> **Note**: このコマンドは `workflows/default/setup-2agent.yaml` に従って実行されます。
> 詳細な手順は各スキル（`ccp-generate-workflow-files`, `ccp-setup-2agent-files`）で定義されています。

### Phase 0: Case-Insensitive ファイル検出

**重要**: ファイル名の大文字小文字の違いを吸収する

```bash
# Case-insensitive でファイルを検索
find . -maxdepth 1 -iname "agents.md" -type f 2>/dev/null | head -1
find . -maxdepth 1 -iname "claude.md" -type f 2>/dev/null | head -1
find . -maxdepth 1 -iname "plans.md" -type f 2>/dev/null | head -1
```

検出パターン（すべて同一ファイルとして扱う）:
- `AGENTS.md`, `agents.md`, `Agents.md`
- `CLAUDE.md`, `claude.md`, `Claude.md`
- `PLANS.md`, `plans.md`, `Plans.md`

### Phase 1: 状態確認と分岐

1. Case-insensitive で既存ファイルを検出
2. `.cursor-cc-version` をチェックしてセットアップ状態を判定
3. プラグインバージョンと比較

| 状態 | 判定 | 動作 |
|------|------|------|
| ファイルなし | 新規セットアップ | 全ファイル作成 |
| 既存あり・古いバージョン | 更新が必要 | **`/update-2agent` を案内** |
| 既存あり・同じバージョン | 最新 | スキップ（上書き確認） |

**既存ファイルがある場合の動作**:

```
⚠️ 既存の2エージェント体制が検出されました

検出ファイル:
- ./agents.md (推奨: AGENTS.md)
- ./Plans.md ✓
- .cursor-cc-version (v0.3.2)

更新する場合は `/update-2agent` を実行してください。
（タスク等のユーザーデータを保持しながら更新します）

強制的に上書きする場合は「上書きして」と言ってください。
```

### Phase 2: ワークフローファイル生成

`ccp-generate-workflow-files` スキルが以下を生成:

- **AGENTS.md** ← `templates/AGENTS.md.template`
- **CLAUDE.md** ← `templates/CLAUDE.md.template`
- **Plans.md** ← `templates/Plans.md.template`

### Phase 3: 補助ファイル配置

`ccp-setup-2agent-files` スキルが以下を配置:

- **.cursor/commands/** ← `templates/cursor/commands/` からコピー
- **.claude/rules/** ← `templates/rules/` からコピー（v0.4.0+）
- **.claude/memory/** ← 初期構造を作成
- **.cursor-cc-version** ← `templates/.cursor-cc-version.template` から生成

---

## VibeCoder向け案内

| やりたいこと | どちらで言う | 言い方 |
|-------------|-------------|--------|
| タスクを依頼 | Cursor | 「〇〇を実装して」→ `/handoff-to-claude` |
| 実装する | Claude Code | 「次のタスク」→ `/start-task` |
| 完了報告 | Claude Code | 「終わった」→ `/handoff-to-cursor` |
| レビュー | Cursor | 「確認して」→ `/review-cc-work` |

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `workflows/default/setup-2agent.yaml` | ワークフロー定義 |
| `workflows/default/update-2agent.yaml` | 更新ワークフロー定義 |
| `skills/core/ccp-generate-workflow-files/SKILL.md` | AGENTS.md等の生成スキル |
| `skills/core/ccp-setup-2agent-files/SKILL.md` | Cursorコマンド等の配置スキル |
| `skills/core/ccp-update-2agent-files/SKILL.md` | 更新スキル |
| `skills/core/ccp-merge-plans/SKILL.md` | Plans.mdマージスキル |
| `templates/` | テンプレートファイル |

---

## 注意事項

- **既存ファイルがある場合**: `/update-2agent` を使用（タスクを保持）
- **ファイル名の大文字小文字**: Case-insensitive で検出し、正規化を提案
- Cursor のカスタムコマンドは `.cursor/commands/` に配置
- Plans.md は両エージェントで共有・編集
