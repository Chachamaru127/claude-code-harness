---
name: harness-setup
description: "HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI/Codex setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning."
description-en: "HAR: Project init, tool setup, agent config, memory setup, skill mirror sync. Trigger: setup, init, new project, CI/Codex setup, harness-mem, mirror. Do NOT load for: implementation, review, release, planning."
description-ja: "HAR:プロジェクト初期化・ツール設定・エージェント構成・メモリ設定・skill mirror 同期を担当。セットアップ、初期化、新規プロジェクト、CI/Codex CLI セットアップ、harness-mem、mirror で起動。実装・レビュー・リリース・プランニングには使わない。"
kind: workflow
purpose: "Initialize and repair Harness project configuration"
trigger: "setup, init, new project, CI/Codex setup, harness-mem, mirror"
shape: workflow
role: generator
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[init|ci|codex|harness-mem|mirrors|agents|localize]"
user-invocable: true
effort: medium
---

# Harness Setup

Harness の統合セットアップスキル。
以下の旧スキルを統合:

- `setup` — 統合セットアップハブ
- `harness-init` — プロジェクト初期化
- `harness-update` — Harness アップデート
- `maintenance` — ファイル整理・クリーンアップ

## Quick Reference

| サブコマンド | 動作 |
|------------|------|
| `/harness-setup init` | 新規プロジェクト初期化（CLAUDE.md + Plans.md + hooks + sync + doctor）|
| `/harness-setup ci` | CI/CD パイプライン設定 |
| `/harness-setup codex` | Codex CLI インストール・設定 |
| `/harness-setup harness-mem` | harness-mem 統合・メモリ設定 |
| `/harness-setup mirrors` | skills/ → 公開 mirror bundle 更新 |
| `/harness-setup agents` | agents/ エージェント設定 |
| `/harness-setup localize` | CLAUDE.md ルールのローカライズ |

> **Built-in slash discovery (CC 2.1.108+)**:
> `/init` のような built-in slash command も発見される。
> Harness 固有の bootstrap が必要な時だけ `/harness-setup init` と使い分ける。

> **Claude Code setup guidance (CC 2.1.120+)**:
> MCP `alwaysLoad`、`${CLAUDE_EFFORT}`、`claude plugin prune`、`claude project purge`、
> `ANTHROPIC_BEDROCK_SERVICE_TIER`、`claude_code.skill_activated.invocation_trigger`、
> Windows PowerShell primary shell、forked skills / subagents の deferred tools は
> `docs/claude-code-setup-mcp-telemetry-provider.md` を正本として扱う。

> **Codex plugin workflows**:
> Codex `/goal` と `Plans.md` を二重管理しない。
> plugin-bundled hooks は opt-in、external agent import は ownership 明記、
> MultiAgentV2 / `agents.max_threads = 8` は上限として扱い、
> sticky environments / app-server artifacts は safe default を優先する。
> Codex `0.130.0` stable の `codex remote-control`、large thread pagination、
> selected-environment `view_image`、live app-server config refresh、
> accurate turn diffs、plugin details bundled hooks、sharing discoverability controls は
> `docs/codex-plugin-workflows-policy.md` を正本として扱う。
> 詳細は `docs/codex-plugin-workflows-policy.md` を参照。

## サブコマンド詳細

### init — プロジェクト初期化

新規プロジェクトに Harness を導入する。

**生成ファイル**:
```
project/
├── CLAUDE.md            # プロジェクト設定
├── Plans.md             # タスク管理（空テンプレート）
├── .claude/
│   ├── settings.json    # Claude Code 設定
│   └── hooks.json       # フック設定（Go バイナリ）
└── hooks/
    ├── pre-tool.sh      # 薄いシム（→ core/src/index.ts）
    └── post-tool.sh     # 薄いシム（→ core/src/index.ts）
```

**フロー**:
1. プロジェクト種別を検出（Node.js/Python/Go/Rust/その他）
2. 最小限の CLAUDE.md を生成
3. Plans.md テンプレートを生成
4. hooks.json を配置
5. **Go バイナリ検証**: `harness version` でバイナリが利用可能か確認（v4.0 以降 Node.js 不要）
6. **プラグインファイル同期**: `harness sync` で `.claude-plugin/` 配下のファイルを最新に同期
7. **ヘルスチェック**: `harness doctor` で全チェック項目をパス。問題があれば修正案を提示

### Go バイナリ検証

```bash
# バイナリの存在と動作を確認
harness version
# 例: harness v4.0.0 (go1.22.0, darwin/arm64)
```

v4.0 以降、Harness のコアエンジンは Go バイナリに移行した。
Node.js は不要。バイナリは `bin/harness`（または PATH 上の `harness`）を使用する。

### プラグインファイル同期

```bash
# .claude-plugin/ 配下のファイルを最新に同期
harness sync

# 同期内容の確認のみ（変更なし）
harness sync --dry-run
```

`harness sync` は skills/ の SSOT から各 mirror（codex/.codex/skills/、opencode/skills/）へ
変更を伝播させる。init 後に必ず実行すること。

### ヘルスチェック

```bash
# 全チェック項目を実行
harness doctor
```

`harness doctor` は以下を確認する:

| チェック項目 | 内容 |
|------------|------|
| バイナリ | `harness version` が正常に返るか |
| プラグイン設定 | `.claude-plugin/plugin.json` の形式が正しいか |
| hooks 配置 | hooks が正しいパスに存在するか |
| mirror 同期 | skills/ と mirror の内容が一致しているか |
| CLAUDE.md | 必須セクションが存在するか |

問題が検出された場合は修正コマンドを提示する。

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
# インストール確認（Codex CLI は Node.js ベース。Harness 本体とは別物）
which codex || npm install -g @openai/codex

# タイムアウトコマンド確認（macOS）
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
# macOS の場合: brew install coreutils
```

> **注意**: Harness v4.0 本体（`harness` コマンド）は Node.js 不要の Go バイナリ。
> Codex CLI（`codex` コマンド）は別ツールであり、引き続き Node.js が必要。

### Codex provider / model metadata policy (0.123.0+ / 0.130.0)

Codex `0.123.0` 以降の provider / model guidance と、Codex `0.130.0` stable の Bedrock `aws login` guidance は
`docs/codex-provider-setup-policy.md` を正本として扱う。

要点:

- Bedrock を使う場合は、Codex built-in provider の `amazon-bedrock` を使う。
- AWS profile は user / project の Codex config で `[model_providers.amazon-bedrock.aws]` に置く。
- AWS console-login credentials from `aws login` profiles は AWS 側の profile material として扱う。
- Harness は AWS credential、console-login cache、provider endpoint を書き込まない。
- Harness の配布用 Codex config には `model = "gpt-5.4"` を setup default として固定しない。
- Harness の配布用 Codex config には `model_provider = "amazon-bedrock"` も setup default として固定しない。
- `gpt-5.4` は Codex 本体の current model metadata として扱い、古い `gpt-5.2-codex` などを推奨 sample として残さない。
- Claude Code 側の `CLAUDE_CODE_USE_BEDROCK` / `ANTHROPIC_DEFAULT_*` / `modelOverrides` guidance と、Codex の `model_provider = "amazon-bedrock"` は混ぜない。

Bedrock を使う user / project だけが、必要に応じて次を追加する:

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

Claude Code 側の provider / MCP / telemetry guidance は
`docs/claude-code-setup-mcp-telemetry-provider.md` を参照する。
特に `ANTHROPIC_BEDROCK_SERVICE_TIER` は Bedrock 利用者の provider 環境だけで扱い、
Harness の plugin default / template / shared project settings には入れない。

### Codex app-server / plugin workflow policy (0.130.0)

Codex `0.130.0` stable (`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) の app-server / plugin workflow guidance は
`docs/codex-plugin-workflows-policy.md` を正本として扱う。

要点:

- `codex remote-control` は headless remotely controllable app-server の明示起動 entrypoint。Harness setup は remote-control defaults を config に書かない。
- App-server clients can page large threads。長い loop / Breezing transcript は必要な page 範囲を確認する。
- `view_image` は multi-environment session の selected environments 経由で file を解決できる。artifact report には environment / workdir を添える。
- Live app-server threads pick up config changes without restart。ただし secret / provider / hook policy の変更は diff と verification で扱う。
- Turn diffs stay accurate across `apply_patch` including partial failures。最終判断は `git diff` と tests で確認する。
- Plugin details now show bundled hooks。install / share 前に bundled hooks を確認し、Harness bundled hooks は opt-in のままにする。
- Plugin sharing exposes link metadata and discoverability controls。公開範囲と metadata は release surface として確認する。
- Configurable OpenTelemetry trace metadata は debugging / triage 補助に限定し、個人情報・顧客情報・secret を入れない。
- Built-in MCPs first-class runtime servers は Codex runtime owned surface として扱い、plugin-provided MCP と所有者を混ぜない。
- `CODEX_HOME` environments TOML provider は user-level environment source。選択 environment を報告し、write turn は one primary environment に固定する。
- Remove skills list extra roots に依存せず、Harness mirror install または `[[skills.config]]` path-based loading を明示する。

### Codex MCP diagnostics / plugin loading (0.123.0+)

Codex `0.123.0` 以降の MCP diagnostics / plugin MCP loading guidance は
`docs/codex-mcp-diagnostics.md` を正本として扱う。

要点:

- Codex TUI では、普段は `/mcp` で軽量に server 状態だけ確認する。
- MCP server が見えない、resources が出ない、resource templates が読めない時だけ `/mcp verbose` を使う。
- `/mcp verbose` では diagnostics / resources / resource templates を確認する。
- plugin 内 `.mcp.json` は `mcpServers` 形式と top-level server map 形式の両方を受け取れる前提で案内する。
- 新規 plugin では共有しやすい `mcpServers` 形式を優先する。
- 既存 plugin が top-level server map 形式なら、Codex 側の loading 改善を利用し、不要な書き換えを避ける。
- Claude Code 側の `claude mcp ...`、`.claude/mcp.json`、hook `type: "mcp_tool"` guidance と混ぜない。

`mcpServers` 形式:

```json
{
  "mcpServers": {
    "docs": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
```

top-level server map 形式:

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

### Codex sandbox / execution policy (0.123.0+)

Codex `0.123.0` 以降の `remote_sandbox_config` と `codex exec` shared flags guidance は
`docs/codex-sandbox-execution-policy.md` を正本として扱う。

要点:

- `remote_sandbox_config` は `requirements.toml` の host-specific sandbox policy として案内する。
- remote devbox / ephemeral CI runner / shared host のように、remote environment ごとの `allowed_sandbox_modes` を比較して決める。
- host matching は便利な分類だが、強い device authentication ではない。高リスク環境では broad wildcard を避ける。
- Harness の配布用 `codex/.codex/config.toml` には organization-specific な `remote_sandbox_config` を書かない。
- Codex `0.123.0` 以降は `codex exec` が root-level shared flags を継承するため、wrapper 側で重複した `--approval-policy` / `--sandbox` pairs を追加しない。
- `scripts/codex-companion.sh task --write` が `--sandbox workspace-write` を付けるのは、Harness の「書き込みタスク」という意図を exec-local に変換しているためであり、root shared flags の重複転送ではない。
- `scripts/codex/codex-exec-wrapper.sh` の `--full-auto` は 53.2.4 では維持する。変更する場合は別 task で approval / sandbox behavior の回帰テストを追加する。

requirements example:

```toml
allowed_sandbox_modes = ["read-only"]

[[remote_sandbox_config]]
hostname_patterns = ["devbox-*.corp.example.com"]
allowed_sandbox_modes = ["read-only", "workspace-write"]
```

**使用パターン**（公式プラグイン経由）:
```bash
bash scripts/codex-companion.sh task --write "タスク内容"
# または stdin 経由
cat /tmp/prompt.md | bash scripts/codex-companion.sh task --write
```

## Cursor 実装バックエンド導入（脳 Opus / 体 composer）

Cursor を Harness の実装（worker）バックエンドとして使うための導入手順。
レビュー / advisor ロールは Opus に固定し、cursor バックエンドへ切り替えない（`.claude/rules/cursor-cli-only.md` の Role scope）。

### 1. AI 実行可（バックエンド選択の永続化）

`set-impl-backend.sh` でバックエンドを永続化する。Harness / AI がこのステップを実行できる。

```bash
# プロジェクトスコープ（このプロジェクトの env.local に書く）
bash "${HARNESS_PLUGIN_ROOT}/scripts/set-impl-backend.sh" cursor

# ユーザースコープ（全プロジェクト共通: ${HOME}/.config/claude-harness/impl-backend.env）
bash "${HARNESS_PLUGIN_ROOT}/scripts/set-impl-backend.sh" --user cursor

# 現在解決されるバックエンドを表示して確認
bash "${HARNESS_PLUGIN_ROOT}/scripts/set-impl-backend.sh" --show
```

解決の優先順位: プロジェクト env.local がユーザースコープより優先される。

### 2. ユーザー手動（AI は編集不可。protected path + sandbox のため）

以下 3 ファイルは `Edit/Write(.claude/settings*)` deny と self-audit guard、および `~/.cursor/*` が
plugin write 対象外であるため Harness / AI が編集できない。ユーザー自身がターミナル / エディタで設定する。

- **`~/.cursor/permissions.json`**: `terminalAllowlist` / `mcpAllowlist` を追加する。
  テンプレートは `.claude/rules/cursor-cli-only.md` の `~/.cursor/permissions.json` テンプレートを使う。
  `--force` / Run Everything（`--yolo`）は使わない（Cursor 公式が "Never use"）。
- **`.cursorignore`**: secrets（`.env`, `*.pem`, `*.key`, `.ssh`, `.aws`, `.git`）を列挙する。
  テンプレートは `.claude/rules/cursor-cli-only.md` の `.cursorignore` テンプレートを使う。
- **`~/.claude/settings.json` の sandbox（2 点）**: (1) `network.allowedDomains` に `*.cursor.sh` を追加、
  (2) 公式キー **`sandbox.filesystem.allowWrite`** に `~/.cursor` を追加する（cursor-agent は実行時に
  `~/.cursor/projects/...` と `~/.cursor/cli-config.json.tmp` へ状態を書くため、未許可だと
  `EPERM` で失敗する）。⚠️ **キー名は `allowWrite`**: `write` という名前にすると未知キーとして
  無視され設定が効かない（実測で確認）。`~/` は sandbox 側で展開される（公式例 `["~/.kube"]`）。
  両方揃うと per-run の
  sandbox 無効化なしで実行できる。手順は `docs/sandbox-allowlist-recipe.md` の jq merge レシピと
  `.claude/rules/cursor-cli-only.md` の「Sandbox 要件」に従う。CC 完全再起動後に有効化される。

### 3. 境界（cursor は candidate のまま）

cursor バックエンドは candidate の位置づけ。安全性は Cursor の allowlist（best-effort、bypass 可能）ではなく、
**専用 `.git` を持つ worktree での隔離実行 + Lead による diff レビュー + cherry-pick での本流取り込み**で担保する。
cursor-agent の出力は Lead レビューまで untrusted として扱う。詳細は `.claude/rules/cursor-cli-only.md` を参照。

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
./scripts/sync-skill-mirrors.sh
./scripts/sync-skill-mirrors.sh --check
```

更新対象:

- `skills/`
- `codex/.codex/skills/`
- `opencode/skills/`

### agents — エージェント設定

agents/ の3エージェント構成を設定する。

```
agents/
├── worker.md      # 実装担当（task-worker + codex-implementer + error-recovery）
└── reviewer.md    # レビュー担当（code-reviewer + plan-critic）
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
Claude Code 2.1.117-2.1.118 以降の plugin / managed settings 方針は
`docs/plugin-managed-settings-policy.md` を正本として扱う。

### 推奨インストール方式

```bash
# @ref 形式でバージョン固定（推奨）
claude plugin install owner/repo@v4.0.0

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

### Managed marketplace / dependency policy (v2.1.117+)

企業利用で plugin marketplace を制御する場合は、Claude Code 本体の managed settings を使う。
Harness は独自の marketplace resolver や dependency resolver を重ねない。

| 項目 | 用途 | Harness の扱い |
|------|------|----------------|
| `extraKnownMarketplaces` | チームに推奨 marketplace を案内・登録する | 通常の onboarding ではこちらを優先 |
| `blockedMarketplaces` | 特定 marketplace source をブロックする | managed settings 専用。通常ユーザー向け default には入れない |
| `strictKnownMarketplaces` | 許可した marketplace source だけ追加できるようにする | managed settings 専用。通常ユーザー向け default には入れない |
| plugin dependency auto-resolve | `dependencies` の自動 install / missing dependency hints | Claude Code 本体に任せる。Harness 独自 resolver は追加しない |
| plugin `themes/` directory | plugin が theme を配布する | 今回は P: 将来タスク。Harness は theme を同梱しない |

`DISABLE_AUTOUPDATER` は自動更新を止める。
`DISABLE_UPDATES` は手動 `claude update` まで止めるため、企業の固定バージョン運用向け。
Harness の project default にはどちらも入れず、必要な組織が managed settings または端末管理で設定する。

依存関係が欠けた場合は、まず Claude Code の `/plugin` Errors、`/doctor`、`claude plugin list --json` を確認する。
marketplace 未登録が原因なら `/plugin marketplace add` または `claude plugin marketplace add` で登録し、本体の auto-resolve に任せる。

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
