# Claude harness

![Claude harness](docs/images/claude-harness-logo-with-text.png)

**思考の流れを妨げない開発体験 | Development experience that doesn't interrupt your flow**

Claude Code を「Plan → Work → Review」の型で自律運用し、個人開発を"もう1段"プロ品質へ引き上げる **開発ハーネス（Claude Code プラグイン）** です。

A **development harness (Claude Code plugin)** that autonomously operates Claude Code in a "Plan → Work → Review" cycle, elevating solo development to professional quality.

[![Version: 2.5.42](https://img.shields.io/badge/version-2.5.42-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)

**現在のハーネススコア**: **92 / 100（S）**（→ [採点基準](#個人開発ハーネスの採点基準--スコア)）

---

## 目次

- [3行でわかる](#3行でわかる)
- [これは何？](#これは何)
- [対象ユーザー](#対象ユーザー)
- [できること（要点）](#できること要点)
- [5分で体験（最短）](#5分で体験最短)
- [ユースケース（こう使うと刺さる）](#ユースケースこう使うと刺さる)
- [Hooks が自動でやってくれること（“使ってみよう”の決め手）](#hooks-が自動でやってくれること使ってみようの決め手)
- [使い方（おすすめパターン）](#使い方おすすめパターン)
- [コマンド（わかりやすいリファレンス）](#コマンドわかりやすいリファレンス)
- [個人開発ハーネスの採点基準 &amp; スコア](#個人開発ハーネスの採点基準--スコア)
- [アーキテクチャ（要約）](#アーキテクチャ要約)
- [リポジトリ構成（全体像）](#リポジトリ構成全体像)
- [ドキュメント](#ドキュメント)
- [信頼性 / 検証](#信頼性--検証)
- [プレゼンテーション](#プレゼンテーション)
- [参考（競合/関連）](#参考競合関連)
- [ライセンス](#ライセンス)

---

## 3行でわかる | In 3 Lines

- **`/plan-with-agent`**: 壁打ちの内容 or 新規ヒアリングから **Plans.md** を作成 | Create **Plans.md** from brainstorming or fresh interviews
- **`/work`**: Plans.md を実行して"動くコード"を積み上げる（並列実行対応） | Execute Plans.md to build working code (parallel execution)
- **`/harness-review` + Hooks**: 品質・安全・継続性を自動化して"雑にならない"状態を作る | Automate quality, safety, and continuity to prevent sloppiness

![3行でわかる](docs/images/quick-overview.png)

## これは何？ | What is this?

Claude Code の強み（実装スピード）を活かしつつ、個人開発で起きがちな問題をハーネスで解決します。

Leverages Claude Code's strength (implementation speed) while solving common solo development problems with the harness.

- **迷う（何をすべきか分からない）** → `/plan-with-agent` で会話や要望を Plans.md に整理 | **Lost** (don't know what to do) → Organize conversations and requests into Plans.md
- **雑になる（品質が落ちる）** → `/harness-review` で多観点レビュー（並列） | **Sloppy** (quality drops) → Multi-perspective review (parallel)
- **事故る（危険な操作）** → Hooks でガードレール（保護パス・危険コマンド） | **Accidents** (dangerous operations) → Guardrails via Hooks
- **忘れる（前提が抜ける）** → SSOT（decisions/patterns）で意思決定を蓄積 | **Forget** (lose context) → Accumulate decisions in SSOT

![個人開発を蝕む4つの見えない壁](docs/images/four-walls.png)

---

## 対象ユーザー | Target Users

- **個人開発者 / Indie Hacker**: 速さと品質を両立したい | Balance speed and quality
- **フリーランス/受託 | Freelancers**: レビュー結果を"提出できる形"にしたい | Get review results in deliverable format
- **VibeCoder（技術理解ありの非エンジニア）**: 自然言語で開発を回したい | Develop using natural language
- **Cursor 併用派**: （任意）2-agent運用で役割分担したい | (Optional) Role separation with 2-agent workflow

---

## できること（要点） | What You Can Do

### Plan → Work → Review を"自律ループ"にする | Create an Autonomous Loop

![思考と作業を分離する自律サイクル](docs/images/autonomous-cycle.png)

- `/plan-with-agent`: 会話の内容 or 新規ヒアリングから **Plans.md** を作成 | Create **Plans.md** from conversations or interviews
- `/work`: Plans.md を読み、タスクを並列実行で効率的に実装 | Read Plans.md and implement tasks efficiently (parallel execution)
- `/harness-review`: セキュリティ/性能/品質/アクセシビリティを多観点レビュー（並列） | Multi-perspective review: security, performance, quality, accessibility (parallel)

### 安全に任せられる（Hooks） | Safe Delegation via Hooks

![安全に任せられる自律型ガードレール](docs/images/hooks-guard.png)

- **PreToolUse Guard**（`scripts/pretooluse-guard.sh`）
  - `.git/`・`.env`・秘密鍵など **保護パスへのWrite/Editを拒否**
  - `sudo` を拒否、`git push` / `rm -rf` は確認要求
- **PermissionRequest 自動許可**（`scripts/permission-request.sh`）
  - `git status/diff/log`、`npm test`、`pytest` 等の **安全なコマンドは自動許可**
  - パイプ/リダイレクト/変数展開など "複雑そうなコマンド" は保守的に手動許可

### bypassPermissions 前提の運用（推奨）

- **方針**: `Edit` / `Write` を `permissions.ask` に入れず、**危険操作だけ** `deny` / `ask` で制御します（毎回の編集確認を避ける）
- **使い方（プロジェクト限定・未コミット推奨）**: `.claude/settings.local.json` で `permissions.defaultMode: "bypassPermissions"` を設定
  - テンプレ: `templates/claude/settings.local.json.template`

### テスト改ざん防止（品質保証） | Test Tampering Prevention (Quality Assurance)

Coding Agent がテスト失敗時に「楽をする」傾向（テスト改ざん、形骸化実装）を防ぐ **3層防御戦略** を実装しています。

Implements a **3-layer defense strategy** to prevent the Coding Agent from taking shortcuts when tests fail (test tampering, hollow implementations).

![テスト改ざん防止の3層防御](docs/images/quality-guard.png)

| 層 | 仕組み | 強制力 |
|----|--------|--------|
| 第1層: Rules | `.claude/rules/test-quality.md`、`implementation-quality.md` | 良心ベース（常時適用） |
| 第2層: Skills | `impl`、`verify` スキルに品質ガードレール内蔵 | 文脈的強制（スキル使用時） |
| 第3層: Hooks | PreToolUse で改ざんパターンを検出（オプション） | 技術的強制 |

**禁止パターン（自動で警告/ブロック）**:

- **テスト改ざん**: `it.skip()` への変更、アサーション削除、lint ルール緩和
- **形骸化実装**: テスト期待値のハードコード、スタブ、空実装

**出典**: びーぐる氏「Claude Codeにテストで楽をさせない技術」（Claude Code Meetup Tokyo 2025.12.22）

### "続きから自然に"再開できる（継続性） | Resume Naturally (Continuity)

![続きから自然に再開できるSSOTメモリ](docs/images/ssot-memory.png)

- **SSOTメモリ**（推奨）
  - `.claude/memory/decisions.md`: 決定（Why）
  - `.claude/memory/patterns.md`: 再利用パターン（How）
- セッション監視/変更追跡/Plans更新検知（`.claude/state/`）

### （任意）Cursor連携で 2-agent 運用

- `setup-cursor` スキル: `.cursor/commands/*.md` を生成し、**Cursor(PM)** と **Claude Code(Worker)** を役割分担
- `/handoff-to-cursor`: 完了報告テンプレを生成（Cursorへ貼り付け）

---

## 5分で体験（最短） | 5-Minute Quick Start

### 前提 | Prerequisites

- Claude Code が動くこと
- `git` / `node` / `npm`（プロジェクトにより）
- 推奨: `jq`（一部スクリプトのJSON処理で利用）

### 1) プラグインをインストール（推奨）

Claude Code の公式プラグインシステムを使います：

```bash
# あなたのプロジェクトで Claude Code を起動
cd /path/to/your-project
claude

# マーケットプレイスを追加
/plugin marketplace add Chachamaru127/claude-code-harness

# プラグインをインストール
/plugin install claude-code-harness@claude-code-harness-marketplace
```

**または**、インタラクティブUIで：

```bash
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin  # UI を開く → Discover タブ → claude-code-harness を選択 → Enter
```

<details>
<summary>📦 代替方法：ローカルクローン（開発者向け）</summary>

ローカルで開発・カスタマイズしたい場合：

```bash
# リポジトリをクローン
git clone https://github.com/Chachamaru127/claude-code-harness.git ~/claude-plugins/claude-code-harness

# プロジェクトで起動
cd /path/to/your-project
claude --plugin-dir ~/claude-plugins/claude-code-harness
```

</details>

### 2) 初期化（推奨）

```bash
/harness-init
```

### 3) ふだんの開発ループ

```bash
/plan-with-agent
/work
/harness-review
```

### 体験できる“変化”（Hooks出力の例）

> 実際の出力はプロジェクト状況で変わりますが、**「今どうなっているか」「次に何をすべきか」**が自然に見えるようになります。

- セッション開始時に Plans の状況が見える（`SessionStart`）

```text
📋 claude-code-harness: セッション初期化
📄 Plans.md: 検出
   - 進行中タスク: 1
   - 未着手タスク: 3
```

- ファイル編集後に「次に走らせるテスト」が提案される（`PostToolUse`）

```text
🧪 テスト実行推奨
📁 変更ファイル: src/foo.ts
🔗 関連テスト: src/foo.test.ts
📋 推奨コマンド: npm test
```

- Plans.md が膨らんだら整理を促される（`PostToolUse`）

```text
⚠️ Plans.md が 250 行です（上限: 200行）。/cleanup plans で古いタスクをアーカイブすることを推奨します。
```

---

## ユースケース（こう使うと刺さる） | Use Cases

### 1) 既存プロジェクトで「迷い」と「品質低下」を同時に潰す

```bash
/harness-init
/plan-with-agent
/work
/harness-review
```

レビューで指摘が出たら：

```bash
# 「指摘を修正して」と言えば auto-fix スキルが自動起動
/validate
```

### 2) 受託/納品で"安心して提出できる"状態にする

- **レビュー（多観点）**: `/harness-review`
- **自動修正**: 「指摘を修正して」→ auto-fix スキル
- **納品前検証**: `/validate`

必要なら **報告テンプレ**を生成（Cursor運用向け）：

```bash
/handoff-to-cursor
```

### 3) Cursor(PM) × Claude Code(Worker) で役割分担（任意）

「2-agent運用を始めたい」と言えば setup-cursor スキルが起動し、`.cursor/commands/*.md` を生成します。

- **Cursor側**: `/plan-with-cc` → `/handoff-to-claude`
- **Claude Code側**: `/work` → `/handoff-to-cursor`
- **Cursor側**: `/review-cc-work` → 承認/修正どちらでもハンドオフを自動生成

### 3.5) ソロでも PM ↔ Impl を分離（おすすめ）

スキルを活用して役割分担できます：

- **PM役**: `/plan-with-agent` → 「実装役に渡して」（handoff-to-impl スキル）
- **Impl役（Claude Code）**: `/work` → 「PMに完了報告」（handoff-to-pm スキル）
- **PM役**: レビューして `pm:確認済` に更新（必要なら再依頼）

### 4) レビューを待たない（並列・バックグラウンド）

`/harness-review` は観点別に分割でき、`Ctrl+B` でバックグラウンドへ送って実質並列にできます：

```text
/harness-review security
/harness-review performance
/harness-review quality
/harness-review accessibility
```

---

## Hooks が自動でやってくれること | What Hooks Do Automatically

このハーネスの体験価値の大半は **Hooks** です。
「安全」「継続」「気づき（テスト/整理/通知）」が、会話の邪魔をせずに差し込まれます。

Most of the harness's value comes from **Hooks**. They inject "safety", "continuity", and "awareness" (tests/cleanup/notifications) without interrupting your workflow.

### Hooks 一覧（何がいつ起きるか）

| イベント          | いつ                 | 何をする                                                                            | 主な成果物                                              |
| ----------------- | -------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------- |
| PreToolUse        | Write/Edit/Bash の前 | **保護パスへの書き込み拒否**、`sudo`拒否、`git push`/`rm -rf`は確認要求 | （ブロック/確認の判断）                                 |
| PermissionRequest | Bash 権限要求時      | `git status/diff/log` や `npm test` 等を**安全側で自動許可**              | （許可）                                                |
| SessionStart      | セッション開始時     | Plans の状態表示、セッション状態を保存                                              | `.claude/state/session.json`                          |
| PostToolUse       | 書き込み/編集後      | 変更追跡、テスト推奨、Plans更新検知、肥大化警告                                     | `.claude/state/*`                                     |
| Stop              | セッション終了時     | セッションサマリー表示、セッションログ追記、cleanup判定用コンテキスト収集           | `.claude/memory/session-log.md`（推奨: ローカル運用） |

### 生成/更新されるファイル（“何が増えるか”）

- `.claude/state/session.json`: セッション状態（変更ファイル履歴など）
- `.claude/state/test-recommendation.json`: テスト推奨（変更ファイル→推奨コマンド）
- `.claude/state/pm-notification.md`: PM向け通知（Plans.md更新時。互換: `.claude/state/cursor-notification.md`）
- `.claude/memory/session-log.md`: セッションログ（**ローカル運用推奨**。方針は `docs/MEMORY_POLICY.md`）

### Hooksの“うるささ”を避ける設計

- **必要な時だけ出す**: 例）テスト推奨はコード変更時のみ、cleanup警告は閾値超過時のみ
- **危険操作は自動実行しない**: `git push` / `rm -rf` は必ず確認

### しきい値（例: Plans.md の行数）を調整したい

`auto-cleanup-hook` は環境変数で調整できます（デフォルト: Plans 200行 / session-log 500行 / CLAUDE 100行）：

```bash
export PLANS_MAX_LINES=300
export SESSION_LOG_MAX_LINES=800
export CLAUDE_MD_MAX_LINES=150
```

---

## 使い方（おすすめパターン） | How to Use (Recommended Patterns)

### まずは Solo モード（Claude Code 単独） | Solo Mode (Claude Code Only)

個人開発なら、まずはこれで十分です。

```bash
/harness-init
/plan-with-agent
/work
/harness-review
```

### Cursor 併用（任意）

「2-agent運用を始めたい」と言えば setup-cursor スキルが起動します。

これで Cursor 側に以下のコマンドが生成されます（`.cursor/commands/`）:

- `/start-session`
- `/project-overview`
- `/plan-with-cc`
- `/handoff-to-claude`
- `/review-cc-work`

役割の推奨:

- **Cursor (PM)**: 計画・レビュー・タスク管理
- **Claude Code (Worker)**: 実装・テスト・デバッグ

---

## コマンド（わかりやすいリファレンス） | Commands Reference

> 迷ったら：まず **`/harness-init` → `/plan-with-agent` → `/work` → `/harness-review`**。
>
> When in doubt: Start with **`/harness-init` → `/plan-with-agent` → `/work` → `/harness-review`**.

### コア（Plan → Work → Review） | Core Commands

| コマンド             | 目的                 | いつ使う                       | 主な成果物                                              |
| -------------------- | -------------------- | ------------------------------ | ------------------------------------------------------- |
| `/harness-init`    | 初期化・導線づくり   | 最初に1回（新規/既存どちらも） | `Plans.md`/`AGENTS.md`/`CLAUDE.md`（+任意でSSOT） |
| `/plan-with-agent` | 計画作成             | 壁打ち後の整理/何を作るか決める | `Plans.md` 更新                                       |
| `/work`            | 実装（並列実行対応） | Plans のタスクを進める         | コード変更 +`Plans.md` 更新                           |
| `/harness-review`  | レビュー             | 実装後/PR前/納品前             | 多観点レビュー結果（必要なら修正へ）                    |
| `/skill-list`      | スキル一覧           | 使える機能を確認したい         | スキル一覧表示                                          |

### 品質/運用（信頼性を上げる） | Quality/Operations

| コマンド            | いつ・なぜ使うか（When/Why）                                       | 主な成果物                      |
| ------------------- | ------------------------------------------------------------------ | ------------------------------- |
| `/validate`       | デプロイ前やPR前に、環境・依存・ビルド・テストを一括検証したいとき | 検証レポート                    |
| `/harness-update` | ハーネスの新機能を使いたい、またはバグ修正を適用したいとき         | 更新されたプラグインファイル    |
| `/cleanup`        | Plans.mdやsession-log.mdが肥大化して見通しが悪くなったとき         | アーカイブ済みファイル          |
| `/sync-status`    | 「今どこまで進んだか」「次に何をすべきか」を確認したいとき         | Plans.md更新 + 次アクション提案 |
| `/refactor`       | 既存コードを安全に改善したいが、テストを壊したくないとき           | リファクタリング済みコード      |

### 実装支援 | Implementation Support

| コマンド      | いつ・なぜ使うか（When/Why）                       | 主な成果物                       |
| ------------- | -------------------------------------------------- | -------------------------------- |
| `/crud`     | データベース操作の定型コードを素早く生成したいとき | CRUD操作コード（検証・認可付き） |
| `/ci-setup` | GitHub Actionsで自動テスト・ビルドを回したいとき   | `.github/workflows/*.yml`      |

### Cursor連携 / ナレッジ | Cursor Integration / Knowledge

| コマンド                   | いつ・なぜ使うか（When/Why）                                     | 主な成果物                     |
| -------------------------- | ---------------------------------------------------------------- | ------------------------------ |
| `/handoff-to-cursor`     | Cursor(PM)に作業完了を報告したいとき（2-agent運用時）            | 完了報告テンプレート           |
| `/remember`              | 今回学んだパターンやルールを次回以降も使いたいとき               | Rules/Commands/Skills定義      |
| `/localize-rules`        | プロジェクト固有の命名規則やディレクトリ構造をルール化したいとき | カスタマイズされたルール       |
| `/sync-ssot-from-serena` | Serenaで記録した知識をプロジェクトのSSOTに反映したいとき         | 更新された decisions/patterns  |
| `/sync-project-specs`    | 作業後にPlans.mdやドキュメントが最新か確認したいとき             | 同期されたプロジェクトファイル |

### スキル（会話の中で自動呼び出し） | Skills (Auto-invoked in Conversation)

多くの機能はスキルに移行しました。`/skill-list` で一覧を確認できます。

Many features have been moved to skills. Use `/skill-list` to see all available skills.

| スキル              | 目的               | トリガー例                       |
| ------------------- | ------------------ | -------------------------------- |
| `analytics`       | Analytics統合      | 「アクセス解析を入れて」         |
| `auth`            | 認証機能           | 「ログイン機能を付けて」         |
| `auto-fix`        | 自動修正           | 「指摘を修正して」               |
| `component`       | UIコンポーネント   | 「ヒーローを作って」             |
| `deploy-setup`    | デプロイ設定       | 「Vercelにデプロイしたい」       |
| `feedback`        | フィードバック機能 | 「フィードバックフォームを追加」 |
| `health-check`    | 環境診断           | 「環境をチェックして」           |
| `payments`        | 決済機能           | 「Stripeで決済を付けたい」       |
| `setup-cursor`    | Cursor連携         | 「2-agent運用を始めたい」        |
| `handoff-to-impl` | PM→Impl依頼       | 「実装役に渡して」               |
| `handoff-to-pm`   | Impl→PM報告       | 「PMに完了報告」                 |

---

## 個人開発ハーネスの採点基準 & スコア

### 目的

個人開発で「速く作る」だけでなく、**継続して高品質に出す**ための“ハーネス要件”を 100点満点で評価します。

### グレード

- **S（90–100）**: 迷いなく回せる。品質と安全性がハーネスで担保される
- **A（80–89）**: 実用的。特定領域（安全/継続性/検証）のどれかがもう一歩
- **B（70–79）**: 便利だが運用が属人化しやすい
- **C（〜69）**: アイデア段階。仕組みの整合/検証が不足

### 採点表（このリポジトリ: v2.5.13）

| カテゴリ                |          配点 | 何を見るか                           |      本リポジトリ |
| ----------------------- | ------------: | ------------------------------------ | ----------------: |
| オンボーディング/発見性 |            15 | クイックスタート・導線・コマンド説明 |                14 |
| ワークフロー設計        |            20 | Plan→Work→Review の再現性/粒度     |                19 |
| 安全性/ガードレール     |            15 | 保護パス/危険操作/確認フロー         |                15 |
| 継続性/記憶（SSOT）     |            10 | decisions/patterns、再開しやすさ     |                 9 |
| 自動化/フィードバック   |            10 | 監視・テスト推奨・状態追跡           |                 9 |
| 拡張性/保守性           |            10 | 3層設計、テンプレ、分離              |                 8 |
| 品質保証/検証           |            10 | テスト/整合性チェック/再現性         |                 8 |
| ドキュメント/運用       |            10 | ガイド整備、運用ポリシー             |                10 |
| **合計**          | **100** |                                      | **92（S）** |

#### 根拠（抜粋）

- **コマンド/スキル/エージェントが実在し、検証スクリプトが通る**: `./tests/validate-plugin.sh`
- **安全性の実装が明確**: `hooks/hooks.json` + `scripts/pretooluse-guard.sh` / `scripts/permission-request.sh`
- **ワークフローがYAMLで定義され、再現性が高い**: `workflows/default/*.yaml`
- **SSOT方針が明文化**: `docs/MEMORY_POLICY.md`

#### 95点以上にするなら（提案）

- ✅ `CONTRIBUTING.md` のプロダクト名/導線を現行に同期（完了）
- ✅ GitHub Actions のCIを復活し、`validate-plugin` / `check-consistency` を自動実行（完了）
- ✅ `claude-code-harness.config.*` へ命名を統一（互換終了）（完了）

---

## アーキテクチャ（要約）

このプラグインは 3層（Profile → Workflow → Skill）で構成されています。

- **Profile**: `profiles/claude-worker.yaml`
- **Workflow**: `workflows/default/*.yaml`（init/plan/work/review）
- **Skill**: `skills/**/SKILL.md`

詳しくは `docs/ARCHITECTURE.md` を参照してください。

---

## リポジトリ構成（全体像）

```
claude-code-harness/
├── .claude-plugin/         # プラグインメタデータ（plugin.json）
├── commands/               # スラッシュコマンド（18）
├── workflows/              # ワークフロー定義（4）
├── skills/                 # スキル（61）
├── agents/                 # サブエージェント（6）
├── hooks/                  # Hooks 定義
├── scripts/                # Hooks/運用スクリプト
├── templates/              # 生成テンプレート（AGENTS/CLAUDE/Plans, Cursor commands 等）
└── docs/                   # 詳細ドキュメント
```

---

## ドキュメント

- [実装ガイド](IMPLEMENTATION_GUIDE.md)
- [開発フロー完全ガイド](DEVELOPMENT_FLOW_GUIDE.md)
- [メモリポリシー（SSOT）](docs/MEMORY_POLICY.md)
- [アーキテクチャ](docs/ARCHITECTURE.md)
- [Cursor統合（任意）](docs/CURSOR_INTEGRATION.md)
- [非同期サブエージェント](docs/ASYNC_SUBAGENTS.md)
- [変更履歴 / Changelog](CHANGELOG.md) | [English](CHANGELOG.en.md)

---

## 信頼性 / 検証

### 何を信頼できるか（このリポジトリの“保証範囲”）

- **構造が壊れていない**: `plugin.json` / `commands/` / `skills/` / `agents/` / `hooks/` が揃っている
- **参照が壊れていない**: コマンドが参照するテンプレや hooks.json の参照スクリプトが存在する
- **バージョンが一致している**: `VERSION` と `.claude-plugin/plugin.json` の `version` が同期している
- **ガードレールがある**: PreToolUse/PermissionRequest により危険操作を抑止（自動 `git push` 等はしない）

### すぐ検証する（コマンド）

```bash
# プラグイン構成の検証（存在/JSON/description 等）
./tests/validate-plugin.sh

# 整合性チェック（テンプレ/参照/バージョン/Hooks）
./scripts/ci/check-consistency.sh

# （CIが壊れた時に）診断と修正案（--fix で一部自動修正）
./scripts/ci/diagnose-and-fix.sh
```

---

## プレゼンテーション

開発体験の改善について、スライドはこちら：

1. [問題提起](docs/presentation/slide1_problem.png)
2. [解決策](docs/presentation/slide2_solution.png)
3. [具体的な体験](docs/presentation/slide3_experience.png)
4. [今すぐ始める](docs/presentation/slide4_cta.png)

---

## 謝辞 / Acknowledgements

- **階層型スキル構造のアイデア**: [AIまさお氏](https://note.com/masa_wunder) のフィードバックに基づいて実装
- **Hierarchical Skill Structure**: Implemented based on feedback from [AI Masao](https://note.com/masa_wunder)

---

## 参考（競合/関連）

README構成や導線設計の参考として、以下の公開例/公式資料も参照しています：

- [Claude Code Plugins（公式）](https://docs.claude.com/en/docs/claude-code/plugins)
- [anthropics/claude-code（公式プラグイン例）](https://github.com/anthropics/claude-code/blob/main/plugins/README.md)
- [davila7/claude-code-templates（テンプレ/導線の代表例）](https://github.com/davila7/claude-code-templates)
- [Dev-GOM/claude-code-marketplace（Hooks/設定/出力の見せ方が参考）](https://github.com/Dev-GOM/claude-code-marketplace)

---

## ライセンス / License

本プロジェクトは **MIT ライセンス** の下で提供されています。
This project is provided under the **MIT License**.

- 📄 [English Version (LICENSE.md)](LICENSE.md)
- 📄 [日本語版 (LICENSE.ja.md)](LICENSE.ja.md)

### 💡 要約 / Summary

**使用・改変・配布・商用利用・サブライセンスが自由にできます。**
**Free to use, modify, distribute, commercialize, and sublicense.**

詳細は LICENSE.md（英語）または LICENSE.ja.md（日本語）をご確認ください。
For details, see LICENSE.md (English) or LICENSE.ja.md (Japanese).
