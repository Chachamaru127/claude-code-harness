# Claude Code Harness

![Claude Code Harness](docs/images/hero.png)

**思考の流れを妨げない開発体験**
Claude Code を「Plan → Work → Review」の型で自律運用し、個人開発を“もう1段”プロ品質へ引き上げる **開発ハーネス（Claude Code プラグイン）** です。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version: 2.0.5](https://img.shields.io/badge/version-2.0.5-blue.svg)](VERSION)

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
- [個人開発ハーネスの採点基準 & スコア](#個人開発ハーネスの採点基準--スコア)
- [アーキテクチャ（要約）](#アーキテクチャ要約)
- [リポジトリ構成（全体像）](#リポジトリ構成全体像)
- [差分履歴（現行 vs 直前）](#差分履歴現行-vs-直前)
- [ドキュメント](#ドキュメント)
- [信頼性 / 検証](#信頼性--検証)
- [プレゼンテーション](#プレゼンテーション)
- [参考（競合/関連）](#参考競合関連)
- [ライセンス](#ライセンス)

---

## 3行でわかる

- **`/plan`**: 「次に何をするか」を **Plans.md** に落として迷いを消す
- **`/work`**: Plans.md を実行して“動くコード”を積み上げる
- **`/harness-review` + Hooks**: 品質・安全・継続性を自動化して“雑にならない”状態を作る

## これは何？

Claude Code の強み（実装スピード）を活かしつつ、個人開発で起きがちな問題をハーネスで解決します。

- **迷う（何をすべきか分からない）** → `/plan` で「次の一手」をタスクリスト化
- **雑になる（品質が落ちる）** → `/harness-review` で多観点レビュー（並列）
- **事故る（危険な操作）** → Hooks でガードレール（保護パス・危険コマンド）
- **忘れる（前提が抜ける）** → SSOT（decisions/patterns）で意思決定を蓄積

---

## 対象ユーザー

- **個人開発者 / Indie Hacker**: 速さと品質を両立したい
- **フリーランス/受託**: レビュー結果を“提出できる形”にしたい
- **VibeCoder（技術理解ありの非エンジニア）**: 自然言語で開発を回したい
- **Cursor 併用派**: （任意）2-agent運用で役割分担したい

---

## できること（要点）

![主な特徴](docs/images/features.png)

### Plan → Work → Review を“自律ループ”にする

- `/plan`: 要望を **Plans.md** に落としてタスク分解
- `/work`: Plans.md を読み、タスクを実装してステータス更新
- `/harness-review`: セキュリティ/性能/品質/アクセシビリティを多観点レビュー（並列）

### 安全に任せられる（Hooks）

- **PreToolUse Guard**（`scripts/pretooluse-guard.sh`）
  - `.git/`・`.env`・秘密鍵など **保護パスへのWrite/Editを拒否**
  - `sudo` を拒否、`git push` / `rm -rf` は確認要求
- **PermissionRequest 自動許可**（`scripts/permission-request.sh`）
  - `git status/diff/log`、`npm test`、`pytest` 等の **安全なコマンドは自動許可**
  - パイプ/リダイレクト/変数展開など “複雑そうなコマンド” は保守的に手動許可

### “続きから自然に”再開できる（継続性）

- **SSOTメモリ**（推奨）
  - `.claude/memory/decisions.md`: 決定（Why）
  - `.claude/memory/patterns.md`: 再利用パターン（How）
- セッション監視/変更追跡/Plans更新検知（`.claude/state/`）

### （任意）Cursor連携で 2-agent 運用

- `/setup-cursor`: `.cursor/commands/*.md` を生成し、**Cursor(PM)** と **Claude Code(Worker)** を役割分担
- `/handoff-to-cursor`: 完了報告テンプレを生成（Cursorへ貼り付け）

---

## 5分で体験（最短）

### 前提

- Claude Code が動くこと
- `git` / `node` / `npm`（プロジェクトにより）
- 推奨: `jq`（一部スクリプトのJSON処理で利用）

### 1) プラグインをローカルに用意

このリポジトリを任意の場所にクローンします（例: `~/claude-plugins/claude-code-harness`）。

### 2) あなたのプロジェクトを Claude Code で開く

```bash
# あなたのプロジェクトのルートへ移動
cd /path/to/your-project

# プラグインを指定して起動
claude --plugin-dir /path/to/claude-code-harness
```

### 3) 初期化（推奨）

```bash
/harness-init
```

### 4) ふだんの開発ループ

```bash
/plan
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

## ユースケース（こう使うと刺さる）

### 1) 既存プロジェクトで「迷い」と「品質低下」を同時に潰す

```bash
/harness-init
/plan
/work
/harness-review
```

レビューで指摘が出たら：

```bash
/auto-fix
/validate
```

### 2) 受託/納品で“安心して提出できる”状態にする

- **レビュー（多観点）**: `/harness-review`
- **自動修正**: `/auto-fix`
- **納品前検証**: `/validate`

必要なら **報告テンプレ**を生成（Cursor運用向け）：

```bash
/handoff-to-cursor
```

### 3) Cursor(PM) × Claude Code(Worker) で役割分担（任意）

```bash
/setup-cursor
```

- **Cursor側**: `/plan-with-cc` → `/handoff-to-claude`
- **Claude Code側**: `/start-task` → `/work` → `/handoff-to-cursor`
- **Cursor側**: `/review-cc-work`

### 4) レビューを待たない（並列・バックグラウンド）

`/harness-review` は観点別に分割でき、`Ctrl+B` でバックグラウンドへ送って実質並列にできます：

```text
/harness-review security
/harness-review performance
/harness-review quality
/harness-review accessibility
```

---

## Hooks が自動でやってくれること（“使ってみよう”の決め手）

このハーネスの体験価値の大半は **Hooks** です。  
「安全」「継続」「気づき（テスト/整理/通知）」が、会話の邪魔をせずに差し込まれます。

### Hooks 一覧（何がいつ起きるか）

| イベント | いつ | 何をする | 主な成果物 |
| --- | --- | --- | --- |
| PreToolUse | Write/Edit/Bash の前 | **保護パスへの書き込み拒否**、`sudo`拒否、`git push`/`rm -rf`は確認要求 | （ブロック/確認の判断） |
| PermissionRequest | Bash 権限要求時 | `git status/diff/log` や `npm test` 等を**安全側で自動許可** | （許可） |
| SessionStart | セッション開始時 | Plans の状態表示、セッション状態を保存 | `.claude/state/session.json` |
| PostToolUse | 書き込み/編集後 | 変更追跡、テスト推奨、Plans更新検知、肥大化警告 | `.claude/state/*` |
| Stop | セッション終了時 | セッションサマリー表示、セッションログ追記、cleanup判定用コンテキスト収集 | `.claude/memory/session-log.md`（推奨: ローカル運用） |

### 生成/更新されるファイル（“何が増えるか”）

- `.claude/state/session.json`: セッション状態（変更ファイル履歴など）
- `.claude/state/test-recommendation.json`: テスト推奨（変更ファイル→推奨コマンド）
- `.claude/state/cursor-notification.md`: Cursor(PM)向け通知（Plans.md更新時）
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

## 使い方（おすすめパターン）

### まずは Solo モード（Claude Code 単独）

個人開発なら、まずはこれで十分です。

```bash
/harness-init
/plan
/work
/harness-review
```

### Cursor 併用（任意）

```bash
/setup-cursor
```

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

## コマンド（わかりやすいリファレンス）

> 迷ったら：まず **`/harness-init` → `/plan` → `/work` → `/harness-review`**。

### コア（Plan → Work → Review）

| コマンド | 目的 | いつ使う | 主な成果物 |
| --- | --- | --- | --- |
| `/harness-init` | 初期化・導線づくり | 最初に1回（新規/既存どちらも） | `Plans.md`/`AGENTS.md`/`CLAUDE.md`（+任意でSSOT） |
| `/plan` | 計画・合意形成 | 何を作るか決める/詰まった時 | `Plans.md` 更新 |
| `/work` | 実装 | Plans のタスクを進める | コード変更 + `Plans.md` 更新 |
| `/harness-review` | レビュー | 実装後/PR前/納品前 | 多観点レビュー結果（必要なら修正へ） |

### 品質/運用（信頼性を上げる）

| コマンド | 目的 |
| --- | --- |
| `/health-check` | 環境診断（依存/設定/利用可能機能の確認） |
| `/validate` | プロジェクト検証（env/依存/ビルド/テスト/デプロイ準備） |
| `/auto-fix` | レビュー指摘事項の自動修正 |
| `/cleanup` | Plans.md / session-log.md 等の自動整理 |
| `/sync-status` | Plans.mdの進捗集計・状態同期（Cursor報告用） |

### 実装支援（よくある機能を最短で）

| コマンド | 目的 |
| --- | --- |
| `/component` | UIコンポーネント生成（shadcn/ui 等） |
| `/auth` | 認証機能の実装（Clerk / Supabase Auth 等） |
| `/crud` | CRUD自動生成（検証・認可・本番対応） |
| `/payments` | 決済機能の実装（Stripe） |
| `/ci-setup` | CI/CD構築（GitHub Actions） |
| `/deploy-setup` | デプロイ自動化設定（Vercel/Netlify 等） |
| `/analytics` | Analytics統合（GA/Vercel Analytics 等） |
| `/feedback` | フィードバック収集機能の実装 |
| `/parallel-tasks` | 複数タスクの並列実行と統合レポート生成 |

### Cursor連携 / ナレッジ（任意）

| コマンド | 目的 |
| --- | --- |
| `/setup-cursor` | Cursor連携のセットアップ（.cursor/commands 生成） |
| `/start-task` | Cursorから受領したタスク開始のセットアップ |
| `/handoff-to-cursor` | Cursor(PM)向けの完了報告を生成 |
| `/remember` | 学習事項をRules/Commands/Skillsとして記録 |
| `/localize-rules` | プロジェクト構造に合わせてルールをローカライズ |
| `/sync-ssot-from-serena` | Serenaメモリを読み込み、decisions/patterns（SSOT）へ反映 |
| `/notebooklm-yaml` | NotebookLMのスライド用デザインYAMLを生成 |

---

## 個人開発ハーネスの採点基準 & スコア

### 目的

個人開発で「速く作る」だけでなく、**継続して高品質に出す**ための“ハーネス要件”を 100点満点で評価します。

### グレード

- **S（90–100）**: 迷いなく回せる。品質と安全性がハーネスで担保される
- **A（80–89）**: 実用的。特定領域（安全/継続性/検証）のどれかがもう一歩
- **B（70–79）**: 便利だが運用が属人化しやすい
- **C（〜69）**: アイデア段階。仕組みの整合/検証が不足

### 採点表（このリポジトリ: v2.0.3）

| カテゴリ | 配点 | 何を見るか | 本リポジトリ |
| --- | ---: | --- | ---: |
| オンボーディング/発見性 | 15 | クイックスタート・導線・コマンド説明 | 14 |
| ワークフロー設計 | 20 | Plan→Work→Review の再現性/粒度 | 19 |
| 安全性/ガードレール | 15 | 保護パス/危険操作/確認フロー | 15 |
| 継続性/記憶（SSOT） | 10 | decisions/patterns、再開しやすさ | 9 |
| 自動化/フィードバック | 10 | 監視・テスト推奨・状態追跡 | 9 |
| 拡張性/保守性 | 10 | 3層設計、テンプレ、分離 | 8 |
| 品質保証/検証 | 10 | テスト/整合性チェック/再現性 | 8 |
| ドキュメント/運用 | 10 | ガイド整備、運用ポリシー | 10 |
| **合計** | **100** |  | **92（S）** |

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
- **Workflow**: `workflows/default/*.yaml`（init/plan/work/review/start-task）
- **Skill**: `skills/**/SKILL.md`

詳しくは `docs/ARCHITECTURE.md` を参照してください。

---

## リポジトリ構成（全体像）

```
claude-code-harness/
├── .claude-plugin/         # プラグインメタデータ（plugin.json）
├── commands/               # スラッシュコマンド（25）
├── workflows/              # ワークフロー定義（5）
├── skills/                 # スキル（35）
├── agents/                 # サブエージェント（6）
├── hooks/                  # Hooks 定義
├── scripts/                # Hooks/運用スクリプト（20）
├── templates/              # 生成テンプレート（AGENTS/CLAUDE/Plans, Cursor commands 等）
└── docs/                   # 詳細ドキュメント
```

---

## 差分履歴（現行 vs 直前）

> 詳細は [CHANGELOG.md](CHANGELOG.md) を参照してください（0.5.x は Imported history として同梱）。

### 現行: v2.0.5（2025-12-14）

**Changed**

- `/work` と `/start-task` の使い分けがコマンド一覧で分かるように、description（表示文言）を改善

### 直前: v2.0.4（2025-12-14）

**Changed**

- CI: バージョン未更新時の **自動push（=二重実行）** を廃止し、警告＋失敗に変更（pre-commit 推奨）
- `cursor-cc.config.*` の互換表記/残骸を完全撤去し、`claude-code-harness.config.*` へ一本化
- コマンド説明を VibeCoder 向けに統一（各 `commands/*.md` に「こう言えばOK / 成果物」を追記）

### 直前: v2.0.3（2025-12-14）

**Changed**

- `cursor-cc` 表記を `claude-code-harness` へ統一
- 互換コマンド（`/init`, `/review`）を削除（移行期間終了）
- Cursor連携: `.claude-code-harness-version` / `.claude-code-harness.config.yaml` へ整理

### 直前: v2.0.2（2025-12-14）

**Added**

- CI/コミット前チェック: バージョン未更新時の **自動パッチバンプ**（CI + pre-commit）

### 直前: v2.0.1（2025-12-14）

**Added**

- README: 目次を追加（長文でも迷子にならない導線）
- GitHub Actions: `validate-plugin` / `check-consistency` を自動実行（`.github/workflows/validate-plugin.yml`）
- 設定ファイル: `claude-code-harness.config.*` を追加（命名を統一）

**Changed**

- `CONTRIBUTING.md` のプロダクト名/導線/導入手順を現行に同期
- 設定ファイル名の整理（互換終了）

### 直前: v2.0.0（2025-12-13）

**Added**

- PreToolUse/PermissionRequest hooks（ガードレール + 安全コマンド自動許可）
- Cursor連携用テンプレート（`templates/cursor/commands/*`）と `/setup-cursor`
- `/handoff-to-cursor`（Cursor(PM)向け完了報告）

**Changed**

- `.claude-plugin/plugin.json` を最新Plugins reference準拠へ（authorをobject化、commands手動列挙を廃止）
- コマンド衝突回避: `/harness-init` `/harness-review` に統一（旧名コマンドは廃止）
- README/Docs を `/harness-init` `/harness-review` 前提に更新

**Fixed**

- hooks の stdin JSON 入力対応を統一（PostToolUse系スクリプトの空振りを解消）
- CI整合性チェックの不足テンプレート問題を解消

### 直前: v0.5.4（2025-12-12）〜 v0.5.0（Imported history）

このリポジトリは **`cursor-cc-plugins`（0.4.x〜0.5.x）をforkして発展**しています。

- Adaptive Setup（プロジェクト分析）
- セッション監視フック（セッション開始/終了サマリー、変更追跡）
- `/parallel-tasks`（並列タスク実行）
- `/remember`（学習事項の自動ルール化）

### 移行メモ（重要）

- `/init`（互換） → **`/harness-init` を使用**
- `/review`（互換） → **`/harness-review` を使用**

---

## ドキュメント

- [実装ガイド](IMPLEMENTATION_GUIDE.md)
- [開発フロー完全ガイド](DEVELOPMENT_FLOW_GUIDE.md)
- [メモリポリシー（SSOT）](docs/MEMORY_POLICY.md)
- [アーキテクチャ](docs/ARCHITECTURE.md)
- [Cursor統合（任意）](docs/CURSOR_INTEGRATION.md)
- [非同期サブエージェント](docs/ASYNC_SUBAGENTS.md)
- [変更履歴](CHANGELOG.md)

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

## 参考（競合/関連）

README構成や導線設計の参考として、以下の公開例/公式資料も参照しています：

- [Claude Code Plugins（公式）](https://docs.claude.com/en/docs/claude-code/plugins)
- [anthropics/claude-code（公式プラグイン例）](https://github.com/anthropics/claude-code/blob/main/plugins/README.md)
- [davila7/claude-code-templates（テンプレ/導線の代表例）](https://github.com/davila7/claude-code-templates)
- [Dev-GOM/claude-code-marketplace（Hooks/設定/出力の見せ方が参考）](https://github.com/Dev-GOM/claude-code-marketplace)

---

## ライセンス

MIT License（[LICENSE](LICENSE)）


