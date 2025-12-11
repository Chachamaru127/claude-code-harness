# Changelog

cursor-cc-plugins のバージョン履歴です。

---

## [0.4.8] - 2025-12-12

### Added
- 🎯 **ルールのプロジェクトローカライズ機能**
  - `scripts/analyze-project.sh` - プロジェクト構造を自動分析
  - `scripts/localize-rules.sh` - ルールをプロジェクトに最適化
  - `/localize-rules` コマンド - 既存プロジェクトでルールを再ローカライズ

### Changed
- `/setup-2agent` 実行時にプロジェクト構造を分析し、ルールを自動ローカライズ
  - 言語検出（TypeScript, Python, Go, Rust, Ruby, Java, Kotlin）
  - ソースディレクトリ検出（src/, app/, lib/ など）
  - テストディレクトリ検出（tests/, __tests__/, spec/ など）
  - 言語固有のルールセクション追加（TypeScript, Python, React 固有ルール）

### Documentation
- ローカライズ機能のドキュメントを追加

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
- `.cursor-cc-config.yaml` 設定ファイル
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
- `/plan`, `/work`, `/review` に「モード別の使い分け」セクション追加
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
