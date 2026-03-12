<p align="center">
  <img src="docs/images/claude-harness-logo-with-text.png" alt="Claude Harness" width="400">
</p>

<p align="center">
  <strong>Plan. Work. Review. Ship.</strong><br>
  <em>Claude Code を規律ある開発パートナーに変える</em>
</p>

<p align="center">
  <a href="VERSION"><img src="https://img.shields.io/badge/version-3.10.1-blue.svg" alt="Version"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  <a href="docs/CLAUDE_CODE_COMPATIBILITY.md"><img src="https://img.shields.io/badge/Claude_Code-v2.1+-purple.svg" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/Skills-5_Verbs-orange.svg" alt="Skills">
  <img src="https://img.shields.io/badge/Core-TypeScript-blue.svg" alt="TypeScript Core">
</p>

<p align="center">
  <a href="README.md">English</a> | 日本語
</p>

---

## なぜ Harness？

Claude Code は強力です。Harness はその力を、信頼しやすく、途中で崩れにくい開発フローへ変えます。

<p align="center">
  <img src="assets/readme-visuals-ja/generated/why-harness-pillars.svg" alt="Harness を入れると変わること: 計画の定着、実行時ガード、やり直せる検証" width="860">
</p>

5動詞スキルで流れを揃え、TypeScript ガードレールエンジンで実行を守り、検証は必要なときに同じ手順でやり直せます。

## 人気の Claude Code ハーネスと比べると

ここで見たいのは、Claude Code が理論上どこまでできるかではなく、ハーネスを入れたあとに **標準の進め方がどう変わるか** です。

これは **2026-03-06 時点** の **ユーザーに見える運用差** 比較であり、人気投票ではありません。
根拠とソース一覧: [docs/github-harness-plugin-benchmark.md](docs/github-harness-plugin-benchmark.md)

下のカードは、導入後に標準の進め方がどう変わるかだけを見せています。

<p align="center">
  <img src="assets/readme-visuals-ja/generated/harness-feature-matrix.svg" alt="Claude Harness、Superpowers、cc-sdd を導入した後の標準フロー比較" width="860">
</p>

Claude Harness は、計画・実装・レビュー・検証を崩れにくい標準フローとして回したい人に向いています。

対応 baseline と最新の検証スナップショットは [Claude Code 互換性](docs/CLAUDE_CODE_COMPATIBILITY.md) にまとめています。

---

## 動作要件

- **Claude Code v2.1+** ([インストールガイド](https://docs.anthropic.com/claude-code))
- **Node.js 18+** (TypeScript コアエンジン & セーフティフック用)

---

## 30秒でインストール

```bash
# プロジェクトで Claude Code を起動
claude

# マーケットプレイスを追加してインストール
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace

# プロジェクトを初期化
/harness-setup
```

これだけ。`/harness-plan` から始めよう。

---

## 🪄 説明が長い？ならこれ: 検証前提の /work all

**読むのが面倒？** これだけ打てばいい:

```
/harness-work all
```

**計画承認後の最短導線はこれです。** 計画 → 並列実装 → レビュー → コミット。

<p align="center">
  <img src="assets/readme-visuals-ja/work-all-flow.svg" alt="/work all パイプライン" width="700">
</p>

> ⚠️ **実験的ワークフロー**: 計画を承認したら、Claude が完走します。実運用の前に [docs/evidence/work-all.md](docs/evidence/work-all.md) で成功系/失敗系の契約を確認してください。

---

## 5動詞ワークフロー

<p align="center">
  <img src="assets/readme-visuals-ja/generated/core-loop.svg" alt="Plan → Work → Review サイクル" width="560">
</p>

### 0. Setup（初期化）

```bash
/harness-setup
```

以後の作業が同じルールとコマンド面で走るように、プロジェクトファイルと初期設定を揃えます。

### 1. Plan（計画）

```bash
/harness-plan
```

> 「メールバリデーション付きのログインフォームが欲しい」

Harness が明確な受入条件付きの `Plans.md` を作成。

### 2. Work（実装）

```bash
/harness-work              # 並列数を自動検出
/harness-work --parallel 5 # 5ワーカーで同時実行
```

各ワーカーが実装、セルフレビュー、報告を行う。

<p align="center">
  <img src="assets/readme-visuals-ja/parallel-workers.svg" alt="並列ワーカー" width="640">
</p>

### 3. Review（レビュー）

```bash
/harness-review
```

<p align="center">
  <img src="assets/readme-visuals-ja/review-perspectives.svg" alt="4視点レビュー" width="640">
</p>

| 視点 | 焦点 |
|------|------|
| Security | 脆弱性、インジェクション、認証 |
| Performance | ボトルネック、メモリ、スケーリング |
| Quality | パターン、命名、保守性 |
| Accessibility | WCAG準拠、スクリーンリーダー |

### 4. Release（リリース）

```bash
/harness-release
```

実装とレビューの結果を前提に、CHANGELOG、タグ、リリース用のハンドオフをまとめます。

---

## セーフティファースト

<p align="center">
  <img src="assets/readme-visuals-ja/generated/safety-guardrails.svg" alt="安全保護システム" width="640">
</p>

Harness v3 は **TypeScript ガードレールエンジン**（`core/`）でコードベースを保護 — 9つの宣言的ルール（R01–R09）、コンパイル済み＆型チェック済み:

| ルール | 保護対象 | アクション |
|--------|----------|------------|
| R01 | `sudo` コマンド | **拒否** |
| R02 | `.git/`, `.env`, シークレット | 書き込み**拒否** |
| R03 | `rm -rf /`, 破壊的パス | **拒否** |
| R04 | `git push --force` | **拒否** |
| R05–R09 | モード固有のガード | コンテキスト判定 |
| Post | `it.skip`, アサーション改ざん | **警告** |
| Perm | `git status`, `npm test` | **自動許可** |

<p align="center">
  <img src="assets/readme-visuals-ja/safety-shield.svg" alt="セーフティシールド" width="600">
</p>

---

## 5動詞スキル、設定不要

v3 で42スキルを **5つの動詞スキル**に統合。まずは動詞から入り、必要になったときだけ Breezing、Codex、2-Agent を足せます。

<table>
<tr>
<td align="center" width="20%"><h3>/plan</h3>アイデア → Plans.md</td>
<td align="center" width="20%"><h3>/work</h3>並列実装</td>
<td align="center" width="20%"><h3>/review</h3>4視点コードレビュー</td>
<td align="center" width="20%"><h3>/release</h3>タグ + GitHub Release</td>
<td align="center" width="20%"><h3>/setup</h3>プロジェクト初期化</td>
</tr>
</table>

<p align="center">
  <img src="assets/readme-visuals-ja/skills-ecosystem.svg" alt="スキルエコシステム" width="640">
</p>

### 主要コマンド

| コマンド | 機能 | 旧コマンド |
|----------|------|-----------|
| `/harness-plan` | アイデア → `Plans.md` | `/plan-with-agent`, `/planning` |
| `/harness-work` | 並列実装 | `/work`, `/breezing`, `/impl` |
| `/harness-work all` | 承認済み計画 → 実装 → レビュー → コミット | `/work all` |
| `/harness-review` | 4視点コードレビュー | `/harness-review`, `/verify` |
| `/harness-release` | CHANGELOG、タグ、GitHub Release | `/release-har`, `/handoff` |
| `/harness-setup` | プロジェクト初期化 | `/harness-init`, `/setup` |
| `/memory` | SSOT ファイルを管理 | — |

---

## 誰のためのツール？

| あなたが | Harness でできること |
|----------|---------------------|
| **開発者** | 組み込み QA で高速に出荷 |
| **フリーランサー** | クライアントにレビューレポートを納品 |
| **インディーハッカー** | 壊さずに素早く動く |
| **VibeCoder** | 自然言語でアプリを構築 |
| **チームリード** | プロジェクト横断で標準を強制 |

---

## アーキテクチャ

```
claude-code-harness/
├── core/           # TypeScript ガードレールエンジン（strict ESM, NodeNext）
│   └── src/        #   guardrails/ state/ engine/
├── skills-v3/      # 5動詞スキル（plan/execute/review/release/setup）
├── agents-v3/      # 3エージェント（worker/reviewer/scaffolder）
├── hooks/          # 薄いシム → core/ エンジン
├── skills/         # 旧41スキル（互換性のため保持）
├── agents/         # 旧11エージェント（互換性のため保持）
├── scripts/        # v2 フックスクリプト（v3 core と共存）
└── templates/      # 生成テンプレート
```

---

## 高度な機能

<details>
<summary><strong>Breezing（Agent Teams）</strong></summary>

自律エージェントチームでタスクリストを一気に完走:

```bash
/harness-work breezing all                    # 計画レビュー + 並列実装
/harness-work breezing --no-discuss all       # 計画レビューをスキップして即実装
/harness-work breezing --codex all            # Codex エンジンに委託
```

<p align="center">
  <img src="assets/readme-visuals-ja/breezing-agents.svg" alt="Breezing エージェントチーム" width="640">
</p>

**Phase 0（計画議論）** がデフォルトで実行されます。Planner がタスクの品質を分析し、Critic が計画を批判的にチェック。あなたが承認してからコーディングが始まります。

| 機能 | 説明 |
|------|------|
| 計画議論 | Planner + Critic が計画をレビュー（デフォルトON） |
| タスク検証 (V1–V5) | スコープ・曖昧さ・重複・依存・TDD をチェック |
| Progressive Batching | 8タスク以上は自動でバッチ分割 |
| Hook シグナル | 部分レビューや次バッチの自動トリガー |

> **コスト**: デフォルトで約5.5倍のトークン（`--no-discuss` なら約4倍）。計画レビューにより手戻りが減るので投資対効果は高い。

</details>

<details>
<summary><strong>Codex エンジン</strong></summary>

実装タスクを OpenAI Codex に並列委託:

```bash
/harness-work --codex API エンドポイントを5つ実装して
```

Codex が実装 → セルフレビュー → 報告。Claude Code ワーカーと併用可能。

> **セットアップが必要**: [Codex CLI](https://github.com/openai/codex) をインストールし、APIキーを設定。

</details>

<details>
<summary><strong>Codex CLI セットアップ</strong></summary>

[Codex CLI](https://github.com/openai/codex) で Harness を利用できます。Claude Code は不要です。

**前提条件**: [Codex CLI](https://github.com/openai/codex)（`npm i -g @openai/codex`）、OpenAI API キー（`OPENAI_API_KEY`）、Git。

```bash
# 1. Harness リポジトリをクローン
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness

# 2. スキル/ルールをユーザースコープ（~/.codex）にインストール
./scripts/setup-codex.sh --user

# 3. プロジェクトに移動して作業開始
cd /path/to/your-project
codex
```

Codex 内で `$harness-plan`、`$harness-work`、`$breezing`、`$harness-review` を使ってワークフローを実行します。

| フラグ | 説明 |
|--------|------|
| `--user` | `~/.codex` にインストール（プロジェクト横断で共有、デフォルト） |
| `--project` | カレントディレクトリの `.codex/` にインストール |

> Claude Code ユーザーはセッション内で `/setup codex` を実行するだけで同じセットアップが適用されます。

</details>

<details>
<summary><strong>2-Agent モード（Cursor連携）</strong></summary>

Cursor を PM として、Claude Code を実装者として使用。

```bash
/harness-release handoff  # Cursor PM に報告
```

Plans.md が両者間で同期。

</details>

<details>
<summary><strong>Codex レビュー連携</strong></summary>

OpenAI Codex でセカンドオピニオンを追加：

```bash
/harness-review --codex  # 4視点 + Codex CLI
```

Codex が `codex exec` 経由で、16種のスペシャリストから4人の関連エキスパートを選出。

</details>

<details>
<summary><strong>スライド生成</strong></summary>

1枚のプロジェクト紹介スライドを自動生成：

```bash
/generate-slide
```

- 3つのビジュアルパターン（Minimalist / Infographic / Hero）
- 各パターン2候補を品質スコアリング
- 最良3枚を `out/slides/selected/` に出力

> **前提**: `GOOGLE_AI_API_KEY` と Google AI Studio の利用設定。

</details>

<details>
<summary><strong>動画生成</strong></summary>

JSON Schema 駆動のパイプラインでプロダクト動画を生成：

```bash
/generate-video
```

- JSON Schema を SSOT (Single Source of Truth) として使用
- 3層バリデーション: scene → scenario → E2E
- Remotion ベースの決定論的レンダリング

> **依存関係**: [Remotion](https://www.remotion.dev/) プロジェクトのセットアップと ffmpeg が必要。

</details>

<details>
<summary><strong>Agent Trace</strong></summary>

AI による編集操作を自動追跡：

```
.claude/state/agent-trace.jsonl
```

- Edit/Write 操作をタイムスタンプ付きで記録
- セッション終了時にプロジェクト名、現在のタスク、直近の編集を表示
- `/sync-status` で Plans.md と実際の変更を照合可能に

設定不要—デフォルトで有効。

</details>

---

## なぜ skill pack だけではなく Harness か？

skill pack はプロンプトを教えられます。Harness は実行時のふるまいまで強制します。

- **ガードレールエンジン** が破壊的な書き込み、シークレット露出、force push 系を実行経路で止めます。
- **Hooks と review フロー** が、実際に repo を触るツールの近くで品質確認を行います。
- **検証スクリプトと evidence pack** が、docs・配布物・`/harness-work all` の主張を再実行可能にします。

---

## トラブルシューティング

| 問題 | 解決策 |
|------|--------|
| コマンドが見つからない | まず `/harness-setup` を実行 |
| Windows で `harness-*` コマンドが出ない | プラグインを更新または再インストールしてください。公開 command skill は実ディレクトリで配布されるようになり、`core.symlinks=false` でも隠れなくなります。 |
| プラグインが読み込まれない | キャッシュをクリア: `rm -rf ~/.claude/plugins/cache/claude-code-harness-marketplace/` して再起動 |
| フックが動作しない | Node.js 18+ がインストールされているか確認 |

詳しいヘルプは [Issue を作成](https://github.com/Chachamaru127/claude-code-harness/issues)してください。

---

## アンインストール

```bash
/plugin uninstall claude-code-harness
```

プロジェクトファイル（Plans.md、SSOT ファイル）はそのまま残ります。

---

## Claude Code 2.1.71+ 対応機能

Harness は最新の Claude Code 機能をすぐに活用できます。

| 機能 | スキル | 用途 |
|------|--------|------|
| **Agent Memory** | harness-work, harness-review | セッション間の永続的な学習 |
| **TeammateIdle/TaskCompleted Hook** | breezing | チームの自動監視 |
| **Worktree 分離** | breezing | 同一ファイルへの並列書き込みを安全化 |
| **HTTP hooks** | hooks | Slack・ダッシュボード・メトリクスへの JSON POST |
| **Effort levels + ultrathink** | harness-work | 複雑なタスクに ultrathink を自動注入 |
| **Agent hooks** | hooks | LLM によるコード品質ガード（secrets・TODO スタブ・セキュリティ） |
| **`${CLAUDE_SKILL_DIR}` 変数** | 全 harness-* スキル | スキル内参照の実行環境依存を排除 |
| **`agent_id` / `agent_type` フィールド** | hooks, breezing | teammate 識別とロールガードを安定化 |
| **`{"continue": false}` teammate 応答** | breezing | 担当タスク完了時の自動停止 |
| **`/reload-plugins`** | 全 harness-* スキル | スキル/フック編集を即時反映 |
| **`/loop` + Cron スケジューリング** | breezing, harness-work | `/loop 5m /sync-status` による能動的ポーリング監視 |
| **PostToolUseFailure hook** | hooks | ツール連続失敗 3 回で自動 escalation |
| **Background Agent 出力修正** | breezing | `run_in_background` で出力パスが完了通知に含まれるように |
| **Compaction 画像保持** | 全 harness-* スキル | コンテキスト圧縮時に画像を保持 |
| **WorktreeCreate/Remove hook** | breezing | Worktree ライフサイクルの自動セットアップ・クリーンアップ |

全機能一覧: [docs/CLAUDE-feature-table.md](docs/CLAUDE-feature-table.md)

---

## ドキュメント

| リソース | 説明 |
|----------|------|
| [Changelog](CHANGELOG.md) | バージョン履歴 |
| [Claude Code 互換性](docs/CLAUDE_CODE_COMPATIBILITY.md) | 動作要件 |
| [Distribution Scope](docs/distribution-scope.md) | 配布対象 / 互換維持 / 開発専用の境界 |
| [Work All Evidence Pack](docs/evidence/work-all.md) | 成功系/失敗系の検証契約 |
| [Cursor 連携](docs/CURSOR_INTEGRATION.md) | 2-Agent セットアップ |
| [Benchmark Rubric](docs/benchmark-rubric.md) | static evidence と executed evidence の採点軸 |
| [Positioning Notes](docs/positioning-notes.md) | 公開向けの差別化メモ |

---

## コントリビュート

Issue と PR を歓迎します。[CONTRIBUTING.md](CONTRIBUTING.md) を参照。

---

## 謝辞

- [AI Masao](https://note.com/masa_wunder) — 階層的スキル設計
- [Beagle](https://github.com/beagleworks) — テスト改ざん防止パターン

---

## ライセンス

**MIT License** — 自由に使用、改変、商用利用可能。

[English](LICENSE.md) | [日本語](LICENSE.ja.md)
