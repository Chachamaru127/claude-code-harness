# Changelog

claude-code-harness の変更履歴です。

---

## [2.0.7] - 2025-12-14

### Added
- ソロでも「PM ↔ Impl」の2ロール運用を再現するため、`/handoff-to-pm-claude` と `/handoff-to-impl-claude` を追加

### Changed
- Plans マーカーに `pm:依頼中` / `pm:確認済` を追加（`cursor:*` は互換として同義扱い）
- Plans 更新通知の出力先を `.claude/state/pm-notification.md` に追加（互換: `cursor-notification.md`）

---

## [2.0.6] - 2025-12-14

### Changed
- PreToolUseガードの確認/拒否メッセージを日本語化（`CLAUDE_CODE_HARNESS_LANG=en` で英語に切替可）

---

## [2.0.5] - 2025-12-14

### Changed
- `/work` と `/start-task` の使い分けがコマンド一覧で分かるように、description（表示文言）を改善

---

## [2.0.4] - 2025-12-14

### Changed
- CI: バージョン未更新時の **自動push（=CI二重実行の原因）** を廃止し、警告＋失敗に変更（pre-commit での自動更新を推奨）
- `cursor-cc.config.*` の互換表記/残骸を完全撤去し、`claude-code-harness.config.*` へ一本化
- コマンド説明を VibeCoder 向けに統一（各 `commands/*.md` に「こう言えばOK / 成果物」を追記）

---

## [2.0.3] - 2025-12-14

### Changed
- `cursor-cc` 表記を `claude-code-harness` へ統一
- 互換コマンド（`/init`, `/review`）を削除（移行期間終了）
- Cursor連携: `.claude-code-harness-version` / `.claude-code-harness.config.yaml` へ整理

---

## [2.0.2] - 2025-12-14

### Added
- CI/コミット前チェック: バージョン未更新時の **自動パッチバンプ**（CI + pre-commit）

---

## [2.0.1] - 2025-12-14

### Added
- README: 目次（TOC）を追加し、長文でも迷子にならない導線を整備
- GitHub Actions: `validate-plugin` / `check-consistency` を自動実行（`.github/workflows/validate-plugin.yml`）
- 設定ファイル: `claude-code-harness.config.schema.json` / `claude-code-harness.config.example.json` を追加

### Changed
- `CONTRIBUTING.md` のプロダクト名/導線/導入手順を現行に同期
- Marketplace メタデータを `claude-code-harness` に同期

---

## [2.0.0] - 2025-12-13

### Added
- PreToolUse/PermissionRequest hooks（ガードレール + 安全コマンド自動許可）
- Cursor連携用テンプレート（`templates/cursor/commands/*`）と `/setup-cursor`
- `/handoff-to-cursor`（Cursor(PM)向け完了報告）

### Changed
- `.claude-plugin/plugin.json` を最新Plugins reference準拠へ（authorをobject化、commands手動列挙を廃止）
- コマンド衝突回避: `/harness-init` `/harness-review` に統一（旧名コマンドは廃止）
- README/Docs を `/harness-init` `/harness-review` 前提に更新

### Fixed
- hooks の stdin JSON 入力対応を統一（PostToolUse系スクリプトの空振りを解消）
- CI整合性チェックの不足テンプレート問題を解消

---

## (Imported) cursor-cc-plugins history

以下の `0.5.x` 系は、ベースとなった `cursor-cc-plugins` の履歴を参考として残しています。

---

## [0.5.4] - 2025-12-12

### Fixed
- 🔧 **CI チェックリスト同期修正**
  - `setup-2agent.md` のチェックリストをスクリプトと同期
  - 末尾スラッシュを削除し、個別ファイルをリスト化
  - CI `check-checklist-sync.sh` が正常にパスするように修正

---

## [0.5.3] - 2025-12-12

### Added
- 🚀 **Phase 2: 並列タスク実行**
  - `/parallel-tasks` コマンド - 複数タスクを同時実行
  - 統合レポート生成 - 並列実行結果を一括報告
  - 依存関係自動判定 - 並列/直列実行を自動選択
  - `parallel-workflows` スキル更新

- 👁️ **Phase 3: 常駐監視エージェント**
  - `auto-test-runner.sh` - ソースコード変更時にテスト推奨
  - `plans-watcher.sh` - Plans.md 変更を監視し Cursor へ通知
  - `.claude/state/pm-notification.md` - PM への通知生成（互換: `.claude/state/cursor-notification.md`）
  - 関連テストファイルの自動検出

### Changed
- `hooks/hooks.json` に新しいフックを追加
  - PostToolUse: auto-test-runner.sh
  - PostToolUse: plans-watcher.sh

---

## [0.5.2] - 2025-12-12

### Added
- 📊 **セッション監視フック (Session Monitoring)**
  - `session-monitor.sh` - セッション開始時にプロジェクト状態を表示
  - `track-changes.sh` - ファイル変更を追跡し重要な変更を検出
  - `session-summary.sh` - セッション終了時にサマリーを生成
  - `.claude/state/session.json` に状態を永続化
  - Plans.md / CLAUDE.md / AGENTS.md の変更を自動検出

### Changed
- `hooks/hooks.json` に新しいフックを追加
  - SessionStart: session-monitor.sh
  - PostToolUse: track-changes.sh
  - Stop: session-summary.sh

---

## [0.5.1] - 2025-12-12

### Added
- 🧠 **`/remember` コマンド - 学習事項の自動ルール化**
  - 作業中に「これを覚えておいて」と言うだけで最適な形式に記録
  - Rules/Commands/Skills/Memory から最適な記録先を自動判断
  - 制約・禁止事項 → Rules
  - 操作手順 → Commands
  - 実装パターン → Skills
  - 決定事項 → Memory

### Fixed
- 重要パターン検出で日本語キーワードに対応
  - セキュリティ、テスト必須、アクセシビリティ、パフォーマンス等
  - AGENTS.md, CLAUDE.md も検索対象に追加

---

## [0.5.0] - 2025-12-12

### Added
- 🔍 **適応型セットアップ (Adaptive Setup)**
  - プロジェクトの技術スタック・既存設定を自動分析
  - `scripts/analyze-project.sh` - JSON形式で分析結果を出力
  - Node.js, Python, Rust, Go, Ruby, Java の検出
  - React, Next.js, Vue, Django, FastAPI 等のフレームワーク検出
  - ESLint, Prettier, Biome, Ruff 等のLinter/Formatter検出
  - 既存の Claude/Cursor 設定を尊重（上書きしない）
  - Conventional Commits パターンの検出
  - セキュリティ・テスト・アクセシビリティ等の重要事項検出

- 📁 **3フェーズセットアップフロー**
  - Phase 1: プロジェクト分析と結果表示
  - Phase 2: ルールカスタマイズ（LLMが最適化）
  - Phase 3: インタラクティブ確認と配置

- 🆕 **新規スキル・ドキュメント**
  - `skills/core/ccp-adaptive-setup/SKILL.md` - 適応型セットアップスキル
  - `docs/design/adaptive-setup.md` - 設計ドキュメント

### Changed
- `/setup-2agent` コマンドを適応型に更新
- `scripts/setup-2agent.sh` に `--analyze-only` オプション追加
- 既存設定がある場合は `/update-2agent` を案内

### Philosophy
- **非破壊的更新**: 既存のカスタマイズを上書きしない
- **プロジェクト理解**: 技術スタック・規約を把握してから配置
- **段階的確認**: 分析結果をユーザーに提示してから実行

---

## [0.4.7] - 2025-12-12

### Added
- 📜 **Claude Rules ベストプラクティス対応**
  - `paths:` YAML frontmatter で条件付きルール適用
  - `plans-management.md.template` - Plans.md 編集時のみ適用
  - `testing.md.template` - テストファイル編集時のみ適用

### Changed
- `workflow.md.template` - `alwaysApply: true` で全体適用を明示
- `coding-standards.md.template` - コードファイルのみに `paths:` 指定
- セットアップスクリプトとCI整合性チェックを4ルールに対応

### Documentation
- Anthropic 公式ベストプラクティスを参照してルール構造を改善
- 段階的開示（必要な時だけルール適用）の原則を実装

---

## [0.4.6] - 2025-12-12

### Added
- 🧠 **Prompt-Based Hook でスマートクリーンアップ推奨**
  - `Stop` イベントで LLM (Claude Haiku) が cleanup を推奨
  - `scripts/collect-cleanup-context.sh` - プロジェクト状態を収集
  - 完了タスク数・日数・ファイルサイズを総合判断
  - 従来の行数チェックより賢い判断が可能に

### Changed
- `hooks/hooks.json` に `Stop` フックを追加
  - Command hook でコンテキスト収集
  - Prompt hook で LLM 評価
- `ccp-auto-cleanup` スキルドキュメントを更新

---

## [0.4.5] - 2025-12-11

### Added
- 📖 **CI README バージョンチェック**
  - `readme-version-sync` ジョブを追加
  - README.md / README.ja.md のバージョンバッジが VERSION ファイルと一致するか検証
  - 修正方法も提示

### Changed
- 📄 **README 大幅更新**
  - 実装の実態に合わせてドキュメントを刷新
  - v0.4.0+ 新機能セクション追加（Claude Rules, Plugin Hooks, Named Sessions, Session Memory, CI チェック, Self-Healing CI）
  - ファイル構成図を更新（`.claude/rules/`, `.claude/memory/` を追加）
  - インストールコマンドを `/install cursor-cc-plugins` 形式に統一

---

## [0.4.4] - 2025-12-11

### Changed
- 🔄 **コマンド名変更**: `assign-to-cc` → `handoff-to-claude`
  - より直感的なコマンド名に統一
  - 全ファイルの参照を更新
- 📛 **セッション名サポート強化**
  - `/handoff-to-claude` 出力にセッション名の推奨を追加
  - `/rename {project}-{feature}-{YYYYMMDD}` 形式でセッションを追跡

---

## [0.4.3] - 2025-12-11

### Added
- 🔧 **Self-Healing CI 機能**
  - `scripts/ci/diagnose-and-fix.sh` - CI 失敗時の自動診断＆修正スクリプト
  - 5種類のチェック（バージョン同期、チェックリスト、テンプレート、Hooks、バージョン変更）
  - `--fix` フラグで自動修正（バージョン同期、バージョン変更）
  - Claude が CI 失敗時に実行して修正案を取得可能

---

## [0.4.2] - 2025-12-11

### Added
- 🔢 **CI バージョン変更チェック強化**
  - `scripts/ci/check-version-bump.sh` 作成
  - コード変更があれば必ずバージョン更新を要求
  - PR モード / Push モード / ローカルモード対応

---

## [0.4.1] - 2025-12-11

### Added
- 🔧 **実行スクリプト化**
  - `scripts/setup-2agent.sh` - セットアップの確実な実行
  - `scripts/update-2agent.sh` - 更新の確実な実行
  - Claude の手順見落としを防止
- 🔍 **CI チェックリスト同期検証**
  - `scripts/ci/check-checklist-sync.sh`
  - スクリプトとコマンドのチェックリストが一致するか検証
- 🔢 **CI バージョン変更チェック**
  - コード変更時にバージョンが更新されているか検証

### Changed
- `/setup-2agent`, `/update-2agent` コマンドに「実行手順（必須）」セクション追加
- チェックリストにディレクトリも含めるよう更新

---

## [0.4.0] - 2025-12-11

### Added
- 📁 **`.claude/rules/` ディレクトリサポート**
  - `workflow.md` - 2-Agent ワークフロールール
  - `coding-standards.md` - コーディング規約（`paths:` YAML frontmatter で条件適用）
  - `/setup-2agent` で自動生成、`/update-2agent` で更新
- 🪝 **Plugin Hooks (`hooks/hooks.json`)**
  - `${CLAUDE_PLUGIN_ROOT}` 変数でプラグインルートを参照
  - `SessionStart` フック - セッション開始時に Plans.md ステータス表示
  - `PostToolUse` フック - ファイルサイズ自動チェック
- 📛 **Named Sessions**
  - `/start-session` で `{project}-{feature}-{YYYYMMDD}` 形式のセッション名を生成
  - `/rename` で名前変更、`/resume <name>` で再開
- 🔄 **CI 整合性チェック**
  - `.github/workflows/consistency-check.yml`
  - テンプレート存在、バージョン同期、Hooks 検証を自動実行
  - `scripts/ci/check-consistency.sh` でローカル検証も可能

### Changed
- `/update-2agent` に Phase 5.5（Claude Rules 更新）を追加
- スキル定義を v0.4.0 対応に更新
  - `ccp-setup-2agent-files` - Step 4 に rules 配置を追加
  - `ccp-update-2agent-files` - Step 8 に rules 更新を追加

---

## [0.3.9] - 2025-12-10

### Fixed
- `/update-2agent` に「足りないファイル検出」機能を追加
  - テンプレートが変更されていなくても、不足ファイルを追加
  - v0.3.6 → v0.3.7 更新時に hooks が追加されなかった問題を修正
- 更新完了時に「追加されたファイル」を表示

---

## [0.3.8] - 2025-12-10

### Fixed
- `/update-2agent` が全ファイルを更新するように修正
  - Cursor コマンド: 2個 → 5個（全て更新）
  - Hooks 設定の追加（v0.3.7の機能）
- 更新時に変更内容（Changelog）を表示するように改善

---

## [0.3.7] - 2025-12-10

### Added
- 🧹 **自動整理機能（PostToolUse Hooks）**
  - Plans.md への書き込み時に自動でサイズチェック
  - 閾値超過時に警告を表示
- `/cleanup` コマンド
  - 手動でファイル整理を実行
  - `--dry-run` オプションでプレビュー
- `.claude-code-harness.config.yaml` 設定ファイル
  - 閾値をプロジェクトごとにカスタマイズ可能
- `ccp-auto-cleanup` スキル
- `.claude/scripts/auto-cleanup-hook.sh`

### Changed
- `/setup-2agent` に Hooks 設定ステップを追加
- `session-init` にファイルサイズチェック（Step 0）を追加

---

## [0.3.6] - 2025-12-10

### Fixed
- `/start-session` テンプレートから時間見積もりを削除

---

## [0.3.5] - 2025-12-10

### Added
- Cursor コマンドを 2個 → 5個に拡充
  - `/start-session` - 統合フロー（セッション開始→計画→依頼まで自動）
  - `/project-overview` - プロジェクト全体確認
  - `/plan-with-cc` - 計画立案

### Changed
- `/plan`, `/work`, `/harness-review` に「モード別の使い分け」セクション追加
- セットアップ完了メッセージを改善（Cursor/Claude Code 別表示）

---

## [0.3.4] - 2025-12-10

### Added
- `/update-2agent` コマンド（差分更新）
- Case-insensitive ファイル検出（plans.md, Plans.md, PLANS.MD を同一視）
- `ccp-update-2agent-files` スキル
- `ccp-merge-plans` スキル（タスク保持マージ）

### Changed
- `/setup-2agent` に既存セットアップ検出機能追加

---

## [0.3.3] - 2025-12-10

### Changed
- バージョン管理の改善

---

## [0.3.2] - 2025-12-09

### Added
- 2エージェントワークフロー（Cursor PM + Claude Code Worker）
- `/setup-2agent` コマンド
- AGENTS.md, CLAUDE.md, Plans.md テンプレート
- `.cursor/commands/` テンプレート
- `.claude/memory/` 構造

---

## [0.3.0] - 2025-12-08

### Added
- 初期リリース
- Plan → Work → Review サイクル
- VibeCoder ガイド
- エラーリカバリー機能
