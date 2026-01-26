---
description: opencode.ai 用にプロジェクトをセットアップ
---

# /opencode-setup - OpenCode セットアップ

現在のプロジェクトに opencode.ai 互換のコマンド、スキル、設定ファイルを生成します。

## VibeCoder Quick Reference

- "**opencode でも使いたい**" → このコマンド
- "**GPT でも Harness 使いたい**" → opencode セットアップ
- "**マルチ LLM 開発したい**" → opencode 互換設定
- "**スキルも opencode で使いたい**" → このコマンドで自動対応

## Deliverables

- `.opencode/commands/` - opencode 用コマンド
- `.claude/skills/` - opencode 互換スキル（NotebookLM、レビュー等）
- `AGENTS.md` - opencode 用ルールファイル（CLAUDE.md 全文）
- `opencode.json` - MCP 設定（オプション）

---

## Usage

```bash
/opencode-setup
/opencode-setup --symlink  # スキルをシンボリックリンクで配置（開発者向け）
```

---

## Execution Flow

### Step 1: 確認

> 🔧 **opencode.ai 互換ファイルを生成します**
>
> 以下のファイルが作成されます：
> - `.opencode/commands/` - Harness コマンド
> - `.claude/skills/` - Harness スキル（NotebookLM、レビュー等）
> - `AGENTS.md` - ルールファイル（CLAUDE.md 全文）
>
> 続行しますか？ (y/n)

**ユーザーの回答を待つ**

### Step 2: ディレクトリ作成

```bash
mkdir -p .opencode/commands/core
mkdir -p .opencode/commands/optional
mkdir -p .claude/skills
```

### Step 3: コマンドファイルをコピー

Harness プラグインの `opencode/commands/` からコピー:

```bash
# プラグインディレクトリを特定
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $0))}"

# コマンドをコピー
cp -r "$PLUGIN_DIR/opencode/commands/"* .opencode/commands/
```

### Step 4: スキルをコピー

Harness プラグインの `opencode/skills/` からコピー:

```bash
# 既存の .claude/skills がある場合はバックアップ
if [ -d ".claude/skills" ]; then
  mv .claude/skills ".claude/skills.backup.$(date +%Y%m%d%H%M%S)"
  echo "既存の .claude/skills をバックアップしました"
fi

# スキルをコピー（デフォルト）
cp -r "$PLUGIN_DIR/opencode/skills/"* .claude/skills/

# または --symlink オプション指定時（UNIX/macOS のみ）
# ln -s "$PLUGIN_DIR/skills" .claude/skills
```

**コピー vs シンボリックリンク:**

| 方式 | メリット | デメリット |
|------|----------|------------|
| **コピー**（デフォルト） | Windows 対応、独立動作 | プラグイン更新時に再コピー必要 |
| **シンボリックリンク** | 常に最新、容量節約 | UNIX/macOS のみ、プラグイン削除で動作不能 |

### Step 5: AGENTS.md 生成

Harness プラグインの `opencode/AGENTS.md`（CLAUDE.md 全文コピー）をプロジェクトルートに配置:

```bash
# 既存の AGENTS.md がある場合はバックアップ
if [ -f "AGENTS.md" ]; then
  mv AGENTS.md "AGENTS.md.backup.$(date +%Y%m%d%H%M%S)"
  echo "既存の AGENTS.md をバックアップしました"
fi

# AGENTS.md をコピー
cp "$PLUGIN_DIR/opencode/AGENTS.md" AGENTS.md
```

### Step 6: MCP 設定（オプション）

> 🔧 **MCP サーバーも設定しますか？**
>
> MCP を設定すると、opencode から Harness のワークフローツールが使えます。
>
> 設定しますか？ (y/n)

**「y」の場合:**

`opencode.json` を生成:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "harness": {
      "type": "local",
      "enabled": true,
      "command": ["node", "<PLUGIN_DIR>/mcp-server/dist/index.js"]
    }
  }
}
```

### Step 7: 完了メッセージ

> ✅ **OpenCode セットアップ完了**
>
> 📁 **生成されたファイル:**
> - `.opencode/commands/` - Harness コマンド
> - `.claude/skills/` - Harness スキル
> - `AGENTS.md` - ルールファイル（CLAUDE.md 全文）
> - `opencode.json` - MCP 設定（選択時）
>
> **利用可能なスキル:**
> - `docs` - ドキュメント生成（NotebookLM YAML、スライド）
> - `impl` - 機能実装
> - `review` - コードレビュー
> - `verify` - ビルド検証・エラー復旧
> - `auth` - 認証・決済（Clerk, Stripe）
> - `deploy` - デプロイ（Vercel, Netlify）
>
> **使い方:**
> ```bash
> # opencode を起動
> opencode
>
> # コマンドを実行
> /plan-with-agent
> /work
> /harness-review
> ```
>
> **ドキュメント:** https://github.com/Chachamaru127/claude-code-harness

---

## Notes

- 既存の `.opencode/` ディレクトリがある場合は上書き確認
- `AGENTS.md` が既存の場合はバックアップを作成
- `.claude/skills/` が既存の場合はバックアップを作成
- MCP サーバーを使う場合は事前にビルドが必要
- **Windows ユーザー**: シンボリックリンクは管理者権限が必要なため、コピーを推奨

---

## Related Commands

- `/mcp-setup` - MCP サーバーセットアップ
- `/harness-init` - Harness プロジェクト初期化
- `/harness-update` - Harness 更新
