# OpenCode Compatibility Plan

opencode.ai との互換対応設計ドキュメント。

## 背景

Claude Code のレートリミット時に、opencode + GPT モデルに切り替えて開発を継続したいというニーズに対応する。

## 互換性分析

### スキルシステム比較（v2.17.0+）

| 項目 | Harness (Claude Code) | opencode | 互換性 |
|------|----------------------|----------|--------|
| ディレクトリ | `skills/` (プラグイン), `.claude/skills/` (プロジェクト) | `.claude/skills/` | 互換 |
| フォーマット | SKILL.md + references/ | SKILL.md + references/ | 同じ |
| frontmatter | `name`, `description`, `allowed-tools` | `name`, `description`, `allowed-tools` | 互換 |
| 自動ロード | description ベースマッチング | description ベースマッチング | 同じ |
| ファイル参照 | なし | `@filename` | opencode追加機能 |
| シェル出力 | なし | `` !`cmd` `` | opencode追加機能 |

### 設定ファイル比較

| 項目 | Harness | opencode | 互換性 |
|------|---------|----------|--------|
| ルールファイル | `CLAUDE.md` | `AGENTS.md` | リネーム+調整 |
| 設定 | `.claude/settings.json` | `opencode.json` | 形式変換 |
| MCP設定 | `mcpServers: {}` | `mcp: { type: "local" }` | 形式変換 |

### 機能比較

| 機能 | Harness | opencode |
|------|---------|----------|
| LSP | `/lsp-setup` で手動 | 30+言語組み込み |
| Formatter | なし | 組み込み |
| プラグインシステム | `.claude-plugin/` | なし |
| MCP | 対応 | 対応 |

## アーキテクチャ設計

### ディレクトリ構造（v2.17.0+ Skills-first）

```
claude-code-harness/
├── skills/                      # スキル定義（メイン）
│   ├── impl/
│   ├── harness-review/
│   ├── verify/
│   └── ...
├── scripts/
│   ├── build-opencode.js        # 変換スクリプト
│   └── validate-opencode.js     # バリデーション
├── opencode/                    # opencode用出力
│   ├── skills/                  # 変換後スキル
│   │   ├── impl/
│   │   ├── harness-review/
│   │   └── ...
│   ├── AGENTS.md                # CLAUDE.mdから生成
│   ├── opencode.json            # MCP設定サンプル
│   └── README.md                # opencode用セットアップガイド
└── mcp-server/                  # 共通（変更不要）
```

### 変換ルール

#### 1. frontmatter 変換

```yaml
# Before (Harness)
---
description: 説明文
description-en: English description
---

# After (opencode)
---
description: 説明文
---
```

- `description-en` を削除
- `name` フィールドがあれば削除
- opencode固有フィールド (`agent`, `model`, `subtask`) は必要に応じて追加可能

#### 2. パス変換

| Harness | opencode |
|---------|----------|
| `.claude/commands/` | `.opencode/commands/` |
| `CLAUDE.md` | `AGENTS.md` |
| `.claude/settings.json` | `opencode.json` |

#### 3. MCP設定変換

```json
// Before (Harness - .claude/settings.json)
{
  "mcpServers": {
    "harness": {
      "command": "node",
      "args": ["path/to/mcp-server/dist/index.js"]
    }
  }
}

// After (opencode - opencode.json)
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "harness": {
      "type": "local",
      "enabled": true,
      "command": ["node", "path/to/mcp-server/dist/index.js"]
    }
  }
}
```

## 実装計画

### Phase 1: 基盤構築

| タスク | 成果物 | 優先度 |
|--------|--------|--------|
| 変換スクリプト作成 | `scripts/build-opencode.js` | 高 |
| バリデーションスクリプト | `scripts/validate-opencode.js` | 高 |
| opencode ディレクトリ作成 | `opencode/` | 高 |

### Phase 2: コンテンツ生成

| タスク | 成果物 | 優先度 |
|--------|--------|--------|
| AGENTS.md テンプレート | `opencode/AGENTS.md` | 高 |
| opencode.json サンプル | `opencode/opencode.json` | 高 |
| セットアップガイド | `opencode/README.md` | 中 |

### Phase 3: 自動化・品質保証

| タスク | 成果物 | 優先度 |
|--------|--------|--------|
| CI ワークフロー | `.github/workflows/opencode-compat.yml` | 中 |
| README 更新 | バッジ追加、セクション追加 | 低 |

## デグレ防止策

### CI による自動検証

```yaml
# .github/workflows/opencode-compat.yml
name: OpenCode Compatibility Check

on:
  push:
    paths:
      - 'commands/**'
      - 'CLAUDE.md'
  pull_request:
    paths:
      - 'commands/**'
      - 'CLAUDE.md'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Build opencode version
        run: node scripts/build-opencode.js

      - name: Validate opencode format
        run: node scripts/validate-opencode.js

      - name: Check for uncommitted changes
        run: |
          git diff --exit-code opencode/
          if [ $? -ne 0 ]; then
            echo "::error::opencode/ is out of sync. Run 'node scripts/build-opencode.js' and commit."
            exit 1
          fi
```

### リリース時の自動同期

```yaml
# リリースワークフローに追加
- name: Sync opencode version
  run: |
    node scripts/build-opencode.js
    git add opencode/
    git diff --cached --quiet || git commit -m "chore: sync opencode version"
```

## 使用方法（ユーザー向け）

### インストール

```bash
# 1. Harness をクローン
git clone https://github.com/Chachamaru127/claude-code-harness.git

# 2. opencode 用ファイルをプロジェクトにコピー
cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
cp claude-code-harness/opencode/opencode.json your-project/opencode.json

# 3. MCP サーバーをビルド
cd claude-code-harness/mcp-server
npm install && npm run build

# 4. opencode.json のパスを調整
# "command": ["node", "/actual/path/to/mcp-server/dist/index.js"]
```

### レートリミット時のワークフロー

```
[Claude Code + Harness] レートリミット発生
         ↓
[opencode + GPT] に切り替え
         ↓
  /work, /plan-with-agent 等を実行
         ↓
[Claude Code + Harness] 回復後
         ↓
  /session inbox でキャッチアップ
```

## 制限事項

### opencode で使えない機能

| 機能 | 理由 | 代替手段 |
|------|------|----------|
| プラグインシステム | opencode非対応 | 直接コマンドコピー |
| フック | 実装が異なる | opencode側で再実装必要 |
| `description-en` | opencode非対応 | 削除（日本語のみ） |

### MCP経由で使える機能

| 機能 | MCP ツール名 |
|------|-------------|
| プラン作成 | `harness_workflow_plan` |
| タスク実行 | `harness_workflow_work` |
| レビュー | `harness_workflow_review` |
| セッション通知 | `harness_session_broadcast` |
| 状態確認 | `harness_status` |

## 参考リンク

- [opencode.ai](https://opencode.ai/)
- [opencode Commands](https://opencode.ai/docs/commands/)
- [opencode MCP Servers](https://opencode.ai/docs/mcp-servers/)
- [Harness MCP Setup](../commands/optional/mcp-setup.md)
