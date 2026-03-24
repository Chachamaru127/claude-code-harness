---
name: harness-setup
description: "Unified setup skill for Harness v3. Project init, tool setup, 2-agent config, memory setup, and public skill mirror sync. Use when user mentions: setup, initialization, new project, CI setup, codex CLI setup, harness-mem, agent setup, symlinks, mirrors, harness-setup. Do NOT load for: implementation, code review, release, or planning."
description-en: "Unified setup skill for Harness v3. Project init, tool setup, 2-agent config, memory setup, and public skill mirror sync. Use when user mentions: setup, initialization, new project, CI setup, codex CLI setup, harness-mem, agent setup, symlinks, mirrors, harness-setup. Do NOT load for: implementation, code review, release, or planning."
description-ja: "Harness v3 統合セットアップスキル。プロジェクト初期化・ツール設定・2エージェント構成・メモリ設定・公開 skill mirror 同期を担当。以下で起動: セットアップ、初期化、新規プロジェクト、CIセットアップ、codex CLIセットアップ、harness-mem、エージェント設定、symlink、mirror、harness-setup。実装・レビュー・リリース・プランニングには使わない。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[init|ci|codex|harness-mem|mirrors|agents|localize]"
---

# Harness Setup (v3)

Harness v3 の統合セットアップスキル。
以下の旧スキルを統合:

- `setup` — 統合セットアップハブ
- `harness-init` — プロジェクト初期化
- `harness-update` — Harness アップデート
- `maintenance` — ファイル整理・クリーンアップ

## Quick Reference

| サブコマンド | 動作 |
|------------|------|
| `harness-setup init` | 新規プロジェクト初期化（CLAUDE.md + Plans.md + hooks）|
| `harness-setup ci` | CI/CD パイプライン設定 |
| `harness-setup codex` | Codex CLI インストール・設定 |
| `harness-setup harness-mem` | harness-mem 統合・メモリ設定 |
| `harness-setup mirrors` | skills-v3/ → 公開 mirror bundle 更新 |
| `harness-setup agents` | agents-v3/ エージェント設定 |
| `harness-setup localize` | CLAUDE.md ルールのローカライズ |

## サブコマンド詳細

### init — プロジェクト初期化

新規プロジェクトに Harness v3 を導入する。

**生成ファイル**:
```
project/
├── CLAUDE.md            # プロジェクト設定
├── Plans.md             # タスク管理（空テンプレート）
├── .claude/
│   ├── settings.json    # Claude Code 設定
│   └── hooks.json       # フック設定（v3 シム）
└── hooks/
    ├── pre-tool.sh      # 薄いシム（→ core/src/index.ts）
    └── post-tool.sh     # 薄いシム（→ core/src/index.ts）
```

**フロー**:
1. プロジェクト種別を検出（Node.js/Python/Go/Rust/その他）
2. 最小限の CLAUDE.md を生成
3. Plans.md テンプレートを生成
4. hooks.json を配置

### ci — CI/CD 設定

GitHub Actions ワークフローを設定する。

```yaml
# .github/workflows/ci.yml 生成例
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test
```

### codex — Codex CLI 設定

```bash
# インストール確認
which codex || npm install -g @openai/codex

# タイムアウトコマンド確認（macOS）
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
# macOS の場合: brew install coreutils
```

**使用パターン**:
```bash
${TIMEOUT:+$TIMEOUT 120} codex exec "$(cat /tmp/prompt.md)" 2>/dev/null
```

### harness-mem — メモリ設定

Unified Harness Memory の設定を行う。

```bash
# メモリディレクトリ作成
mkdir -p .claude/agent-memory/claude-code-harness-worker
mkdir -p .claude/agent-memory/claude-code-harness-reviewer

# MEMORY.md テンプレート配置
cat > .claude/agent-memory/claude-code-harness-worker/MEMORY.md << 'EOF'
# Worker Agent Memory

## Project Context
[プロジェクト概要]

## Patterns
[学習パターン]
EOF
```

### mirrors — 公開 skill bundle 同期

Windows の `core.symlinks=false` では repository symlink が通常ファイルになり、`harness-*` skill が command 一覧に出なくなることがあります。公開 bundle は実ディレクトリ mirror として同期します。

```bash
./scripts/sync-v3-skill-mirrors.sh
./scripts/sync-v3-skill-mirrors.sh --check
```

更新対象:

- `skills/`
- `codex/.codex/skills/`
- `opencode/skills/`

### agents — エージェント設定

agents-v3/ の3エージェント構成を設定する。

```
agents-v3/
├── worker.md      # 実装担当（task-worker + codex-implementer + error-recovery）
├── reviewer.md    # レビュー担当（code-reviewer + plan-critic）
└── scaffolder.md  # 足場担当（project-analyzer + scaffolder）
```

### localize — ルールローカライズ

`.claude/rules/` のルールを現プロジェクトに適応する。

```bash
# ルール一覧確認
ls .claude/rules/

# プロジェクト固有ルールの追加
cat >> .claude/rules/project-rules.md << 'EOF'
# Project-Specific Rules
[プロジェクト固有ルール]
EOF
```

## Plugin インストール (v2.1.71+ Marketplace)

v2.1.71 で Marketplace の安定性が大幅に改善された。

### 推奨インストール方式

```bash
# @ref 形式でバージョン固定（推奨）
claude plugin install owner/repo@v3.5.0

# 最新版
claude plugin install owner/repo
```

`owner/repo@vX.X.X` 形式を推奨。`@ref` パーサー修正により、タグ・ブランチ・コミットハッシュいずれも正確に解決される。

### アップデート

```bash
claude plugin update owner/repo
```

v2.1.71 で update 時の merge conflict が修正され、安定したアップデートが可能になった。

### その他の改善点

- MCP server 重複排除: 同一 MCP サーバーの多重登録を自動防止
- `/plugin uninstall` が `settings.local.json` を使用: ユーザーローカル設定に正確に反映

## Maintenance — ファイル整理

定期メンテナンスタスク:

| タスク | コマンド |
|--------|---------|
| 古いログ削除 | `find .claude/logs -mtime +30 -delete` |
| Plans.md 圧縮 | 完了タスクをアーカイブセクションに移動 |
| 古いトレース削除 | `tail -1000 .claude/state/agent-trace.jsonl > /tmp/trace && mv /tmp/trace .claude/state/agent-trace.jsonl` |

## 関連スキル

- `harness-plan` — セットアップ後にプロジェクト計画を作成
- `harness-work` — セットアップ後にタスクを実行
- `harness-review` — セットアップ設定をレビュー
