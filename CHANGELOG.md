# Changelog

cursor-cc-plugins のバージョン履歴です。

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
