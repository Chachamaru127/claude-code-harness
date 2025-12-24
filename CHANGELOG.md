# Changelog

このプロジェクトのすべての注目すべき変更は、このファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に準拠しています。

## [Unreleased]

## [2.5.35] - 2025-12-24

### 🎯 あなたにとって何が変わるか

**自分で作ったカスタムフックを消すことなく、安全にアップデートできるようになりました**

#### Before
- `/harness-update` はすべてのフック設定を削除対象としていた

#### After
- コマンドパスに `claude-code-harness` を含むフックのみを検出・削除
- ユーザー独自のカスタムフック（例: `/my-project/scripts/my-guard.sh`）はそのまま保持

### Changed

- フック検出ロジックをコマンドパスで判別するように改善
  - ハーネス由来のフックのみ警告・削除対象
  - ユーザー独自フックは保護

## [2.5.33] - 2025-12-24

### Added

- **既存ユーザー向けアップデート通知の強化**
  - セッション開始時に未導入の品質保護ルールを通知
  - 古いフック設定（`.claude/settings.json` の `hooks`）を検出・警告
  - `template-tracker.sh` が新規追加ファイルも `installsCount` として報告

### Fixed

- 新規追加されたルールファイルが既存ユーザーに通知されない問題を修正
- `/harness-update` で古いフック設定が検出・削除されない問題を修正

## [2.5.32] - 2025-12-24

### Added

- **テスト改ざん防止機能（3層防御戦略）**の統合
  - 第1層: Rules テンプレート（`test-quality.md`, `implementation-quality.md`）
  - 第2層: Skills 品質ガードレール（`impl`, `verify` スキルに統合）
  - 第3層: Hooks 設計書（オプション機能として文書化）
- `/harness-init` に品質保護ルール自動展開機能
- 品質ガードレール検証テスト（`test-quality-guardrails.sh`）

### Changed

- README.md に品質保証セクションを追加
- CLAUDE.md にテスト改ざん防止戦略を追加

## [2.5.30] - 2025-12-23

### Added

- フロントマターベースのメタデータ統合システム
  - テンプレートファイルに `_harness_template` と `_harness_version` を追加
  - `/harness-update` でバージョン差分検出が可能に

## [2.5.28] - 2025-12-23

### Added

- `handoff-to-claude` コマンドに `/work` と `ultrathink` オプションを追加

### Changed

- CHANGELOG を [Keep a Changelog](https://keepachangelog.com/) フォーマットに統一

## [2.5.27] - 2025-12-23

### Fixed

- `/release` コマンドが表示されない問題を修正
  - `.gitignore` から除外を解除し、プラグインユーザーも使用可能に

## [2.5.26] - 2025-12-23

### Added

- プラグイン更新時のテンプレート追跡機能
  - セッション開始時に「テンプレート更新あり」を自動通知
  - `/harness-update` でファイルごとに上書き or マージを選択可能

#### Before/After

| Before | After |
|--------|-------|
| テンプレート更新されても既存ファイルは古いまま | 更新を自動検出し、安全にマージ支援 |

## [2.5.22] - 2025-12-23

### Fixed

- プラグイン更新が反映されない問題を修正
  - 新しいセッションを開始するだけで最新版が自動反映されるように

## [2.5.14] - 2025-12-22

### Changed

- `/review-cc-work` がレビュー後のハンドオフを自動生成するように改善
  - 承認時: 次タスクを自動分析して依頼文を生成
  - 修正依頼時: 指示を含む依頼文を生成

## [2.5.13] - 2025-12-21

### Added

- コード変更時の LSP 分析自動推奨機能
  - LSP 導入済みプロジェクトで、変更前の影響分析を自動で推奨
  - 公式 LSP プラグイン全10種をサポート

## [2.5.10] - 2025-12-21

### Added

- `/lsp-setup` コマンドで公式プラグインを自動検出・提案
  - 3ステップでセットアップ完了

## [2.5.9] - 2025-12-20

### Added

- 既存プロジェクトへの LSP 一括導入機能
- 言語別インストールコマンド一覧

## [2.5.8] - 2025-12-20

### Added

- LSP によるコード定義元・使用箇所の即時確認機能
  - 関数定義へのジャンプ
  - 変数の使用箇所一覧表示
  - ビルド前の型エラー検出

## [2.5.7] - 2025-12-20

### Fixed

- 2-Agent モードで Cursor コマンドが生成されないことがある問題を修正
  - セットアップ完了時に必須ファイルを自動チェック・再生成

## [2.5.6] - 2025-12-20

### Added

- `/harness-update` が破壊的変更を検出して自動修正を提案する機能

## [2.5.5] - 2025-12-20

### Added

- `/harness-update` コマンドで既存プロジェクトを安全にアップデート
  - 自動バックアップ、非破壊更新

## [2.5.4] - 2025-12-20

### Fixed

- settings.json の間違った構文が生成されるバグを修正

## [2.5.3] - 2025-12-20

### Changed

- スキル名をシンプルに変更（例: `ccp-work-impl-feature` → `impl-feature`）

## [2.5.2] - 2025-12-19

### Changed

- 各スキルに「いつ使う / いつ使わない」を明示してスキルの誤起動を軽減

### Added

- MCP ワイルドカード許可の設定例

## [2.5.1] - 2025-12-19

### Changed

- bypassPermissions で Edit/Write の確認を減らしつつ、危険操作はガード

## [2.5.0] - 2025-12-19

### Added

- Plans.md で依存関係記法 `[depends:X]`, `[parallel:A,B]` をサポート

### Removed

- `/start-task` コマンドを廃止（`/work` に統合）

#### Before/After

| Before | After |
|--------|-------|
| `/start-task` と `/work` の使い分けが必要 | `/work` だけでOK |
| タスクの依存関係を表現できない | 記法で依存関係を表現可能 |

## [2.4.1] - 2025-12-17

### Changed

- プラグイン名を「Claude harness」に変更
- 新しいロゴとヒーロー画像

## [2.4.0] - 2025-12-17

### Changed

- レビューや CI 修正を並列実行で高速化（最大75%の時間短縮）
  - 4つのサブエージェント（セキュリティ/パフォーマンス/品質/アクセシビリティ）を同時起動

## [2.3.4] - 2025-12-17

### Added

- pre-commit フックでコード変更時にパッチバージョンを自動バンプ
- Windows 対応

## [2.3.3] - 2025-12-17

### Changed

- スキルを14カテゴリに整理（impl, review, verify, setup, 2agent, memory, principles, auth, deploy, ui, workflow, docs, ci, maintenance）

## [2.3.2] - 2025-12-16

### Fixed

- スキルがより確実に起動するように改善

## [2.3.1] - 2025-12-16

### Added

- `/harness-init` で言語選択（日本語/英語）

## [2.3.0] - 2025-12-16

### Changed

- ライセンスを MIT に変更（公式リポジトリへの貢献が可能に）

## [2.2.1] - 2025-12-16

### Changed

- 各エージェントが使えるツールを明示
- 並列実行時に色で識別しやすく

## [2.2.0] - 2025-12-15

### Changed

- ライセンスを独自ライセンスに変更（後に MIT に戻りました）

## [2.1.2] - 2025-12-15

### Changed

- `/parallel-tasks` を `/work` に統合

## [2.1.1] - 2025-12-15

### Changed

- コマンド数を27個から16個に削減（残りはスキル化して会話で自動起動）

## [2.0.0] - 2025-12-13

### Added

- PreToolUse/PermissionRequest hooks によるガードレール機能
- `/handoff-to-cursor` コマンドで Cursor 連携

## 過去の履歴（v0.x - v1.x）

詳細は [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases) を参照してください。

### 主なマイルストーン

- **v0.5.0**: 適応型セットアップ（技術スタック自動検出）
- **v0.4.0**: Claude Rules、Plugin Hooks、Named Sessions 対応
- **v0.3.0**: 初期リリース（Plan → Work → Review サイクル）

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.35...HEAD
[2.5.35]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.33...v2.5.35
[2.5.33]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.32...v2.5.33
[2.5.32]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.30...v2.5.32
[2.5.30]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.28...v2.5.30
[2.5.28]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.27...v2.5.28
[2.5.27]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.26...v2.5.27
[2.5.26]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.22...v2.5.26
[2.5.22]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.14...v2.5.22
[2.5.14]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.13...v2.5.14
[2.5.13]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.10...v2.5.13
[2.5.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.9...v2.5.10
[2.5.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.8...v2.5.9
[2.5.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.7...v2.5.8
[2.5.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.6...v2.5.7
[2.5.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.5...v2.5.6
[2.5.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.4...v2.5.5
[2.5.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.3...v2.5.4
[2.5.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.2...v2.5.3
[2.5.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.1...v2.5.2
[2.5.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.4.1...v2.5.0
[2.4.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.3.4...v2.4.0
[2.3.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.3.3...v2.3.4
[2.3.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.3.2...v2.3.3
[2.3.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.2.1...v2.3.0
[2.2.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.1.2...v2.2.0
[2.1.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.0.0...v2.1.1
[2.0.0]: https://github.com/Chachamaru127/claude-code-harness/releases/tag/v2.0.0
