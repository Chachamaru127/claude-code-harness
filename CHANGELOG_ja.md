# Changelog

このプロジェクトのすべての注目すべき変更は、このファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に準拠しています。

> **📝 記載ルール**: ユーザー体験に影響する変更を中心に記載。内部修正は簡潔に。

## [Unreleased]

### Added

- **Strategy Analyzer**: `/work all` がタスクスコープを分析し、最適な実行戦略（direct, parallel, breezing）を推奨。タスク数、独立タスク率、依存深度、失敗履歴に基づく判定
- **透明エスカレーション UX**: breezing 推奨時に `/work` が AskUserQuestion で戦略提案を表示（markdown preview で分析結果とコスト見積もり）
- **失敗時エスカレーション**: 同一タスクが 2 回以上の iteration で失敗した場合、breezing モードへの切り替えを提案（失敗分析と理由を提示）
- **`--from-work` インバウンド対応**: `/breezing` が `--from-work` フラグを受け取り、`/work` から invoke 時にスコープ確認をスキップ
- **`--no-breezing` オプション**: `/work` での breezing 推奨を抑制
- **`breezing_auto_approve` 設定**: confidence: high 時に確認なしで自動的に breezing を invoke

### Changed

- **CHANGELOG リンク定義修復**: 全バージョンの compare リンクを補完
- **CHANGELOG_ja.md 翻訳漏れ補完**: 5バージョン分のエントリを追加 (2.20.1, 2.17.6, 2.17.1, 2.17.0, 2.16.21)
- **README バージョン・数値更新**: バッジのバージョン、スキル数 (41)、エージェント数 (11) を実態に反映
- **CHANGELOG 非標準見出し正規化**: `### Internal` → `### Changed` に統合 (Keep a Changelog 準拠)

---

## [2.23.5] - 2026-02-23

### 🎯 あなたにとって何が変わるか

**Phase 13: Breezing 品質自動化と Codex ルール注入 — 改ざん検知、自動テスト実行、CI シグナル連携、AGENTS.md ルール同期、APPROVE ファストパス。**

| Before | After |
|--------|-------|
| テスト改ざん検知は skip パターンとアサーション削除のみ | 12+ パターン: 弱体化（`toBe → toBeTruthy`）、タイムアウト水増し、catch-all アサーション、Python skip デコレータ |
| auto-test-runner はテスト実行を推奨するだけで実際には実行しない | `HARNESS_AUTO_TEST=run` で実際にテストを実行し、結果を `additionalContext` で返す |
| CI 失敗は手動で検知が必要 | PostToolUse フックが `git push` 後の CI 失敗を検知し `ci-cd-fixer` 推奨シグナルを注入 |
| `.claude/rules/` は Claude Code 専用で Codex はルールを認識できなかった | `sync-rules-to-agents.sh` でルールを `codex/AGENTS.md` に自動同期; Codex 起動時にプロジェクトルールを読み込む |
| `codex exec` は前後処理なしで裸で呼び出されていた | `codex-exec-wrapper.sh` でルール同期、`[HARNESS-LEARNING]` 抽出、シークレットフィルタリングを処理 |
| Breezing Phase C は手動の APPROVE 確認が必要 | `review-result.json` + コミットハッシュチェックで即座に統合テストへのファストパスを実現 |
| Implementer 数は `min(独立タスク数, 3)` で固定 | `max(1, min(独立タスク数, --parallel, planner_max_parallel, 5))` で自動計算 |

### Added

- **改ざん検知（12+ パターン）**: アサーション弱体化、タイムアウト水増し、catch-all アサーション、Python skip デコレータ — `scripts/posttooluse-tampering-detector.sh`
- **`HARNESS_AUTO_TEST=run` モード**: `scripts/auto-test-runner.sh` が実際にテストを実行し `additionalContext` JSON で合否を返す
- **CI シグナル注入**: `scripts/hook-handlers/ci-status-checker.sh` が push 後の CI 失敗を検知して `breezing-signals.jsonl` に書き込み; `scripts/hook-handlers/breezing-signal-injector.sh` が UserPromptSubmit フックで未消費シグナルを注入
- **`sync-rules-to-agents.sh`**: `.claude/rules/*.md` を `codex/AGENTS.md` の Rules セクションに自動変換（ハッシュベースのドリフト検知付き）
- **`codex-exec-wrapper.sh`**: `codex exec` の前後処理ラッパー — ルール同期、`[HARNESS-LEARNING]` マーカー抽出、シークレットフィルタリング、`codex-learnings.md` へのアトミック書き戻し
- **APPROVE ファストパス（Phase C）**: `.claude/state/review-result.json` + HEAD コミットハッシュを確認し、APPROVE 記録済みの場合は手動確認をスキップ
- **`review-result.json` 自動記録**: Reviewer が SendMessage の `review_result_json` フィールドで報告; Lead が `.claude/state/review-result.json` に書き込み、ファストパス参照用に保存
- **ドキュメント再構成**: `docs/CLAUDE-feature-table.md`、`docs/CLAUDE-skill-catalog.md`、`docs/CLAUDE-commands.md` — CLAUDE.md から詳細リファレンスを分離
- **`harness.rules` — execpolicy ガードルール**: `npm test`/`yarn test`/`pnpm test` を自動許可; `git push --force`、`git reset --hard`、`rm -rf`、`git clean -f`、SQL 破壊的ステートメント（`DROP TABLE`、`DELETE FROM`）はユーザー確認を要求; `codex execpolicy check` で 20 パターンを検証済み

### Changed

- **CLAUDE.md を 120 行以下に圧縮**: Feature Table（5 件）、スキルカテゴリ表（5 カテゴリ）; 詳細は `docs/` に移管
- **Implementer 数自動決定**: `max(1, min(独立タスク数, --parallel N, planner_max_parallel, 5))` — スターブ防止 + ハード上限 5
- **`review-retake-loop.md`**: `review-result.json` 書き込み仕様を追加（JSON フォーマット、Reviewer→Lead 委任フロー、ファイルライフサイクル）
- **`execution-flow.md` Phase C**: APPROVE ファストパスチェックをステップ 2 として追加; フェーズ処理番号を更新
- **`team-composition.md`**: Extended 構成（5 Implementer）のコスト見積もり表を追加
- **`release-har` スキル全面再設計（Phase 14）**: Pre-flight チェック、構造化 git log、Conventional Commits 分類、Claude diff 要約（Highlights + Before/After）、SemVer 自動判定、dry-run プレビュー、4セクション Release Notes、Compare リンク自動生成、`--announce` オプション、`--dry-run` デフォルトゲートを追加。`references/release-notes-template.md`・`references/changelog-format.md` を新規作成

---

## [2.23.3] - 2026-02-22

### 🎯 あなたにとって何が変わるか

**breezing 以外の Codex 連携が `codex exec` 前提に統一され、Codex 配布パッケージにも `generate-slide` スキルが含まれるようになりました。**

| Before | After |
|--------|-------|
| `work`/`harness-review`/`codex-review` の文書で Codex MCP 表現と CLI 実行例が混在 | 非breezing領域は `codex exec` の CLI-only 運用として一貫した説明に統一 |
| `codex-worker-setup.sh` が MCP 登録状態をチェック | `codex exec` の実行可否を直接チェックする `codex_exec_ready` 方式に変更 |
| Codex パッケージ検証で非breezingの MCP 語彙回帰を検知できなかった | `tests/test-codex-package.sh` に CLI-only 回帰テストを追加 |
| `generate-slide` が source/opencode にはあるが Codex 配布には未収録 | `codex/.codex/skills/generate-slide/` を追加し parity テスト通過 |

### Added

- **Codex 配布のスキル整合**: `generate-slide` を `codex/.codex/skills/` に追加
- **CLI-only 回帰ガード**: `tests/test-codex-package.sh` に非breezing対象の語彙チェックを追加
- **README 更新（EN/JA）**: `/generate-slide` のコマンド説明とスライド生成セクションを追記

### Changed

- **Codex 文書（非breezing）**: `work`、`harness-review`、`codex-review`、routing/setup 参照を `codex exec` 前提の表現に統一
- **Codex セットアップ参照**: `codex-mcp-setup.md` を Codex CLI セットアップ内容に刷新（ファイル名は互換のため維持）
- **README の Codex レビュー説明（EN/JA）**: セカンドオピニオンの実行経路を Codex CLI ベースとして明確化

### Fixed

- **セットアップ実挙動の不一致**: `scripts/codex-worker-setup.sh` の MCP 登録確認を CLI 実行確認へ置換
- **Codex ミラー整合性**: `skills/` と `codex/.codex/skills/` の非breezing文書差分を同期

---

## [2.23.2] - 2026-02-22

### 🎯 あなたにとって何が変わるか

**Codex スキルが完全にネイティブなマルチエージェント用語を使用するようになり、CI チェックが通るようになりました。`--claude` レビュールーティングも明示的に文書化されました。**

| Before | After |
|--------|-------|
| Codex の breezing/work スキルに Claude Code 固有の用語（`delegate mode`、`TaskCreate`、`subagent_type` 等）が残存 | 82 箇所以上を Codex ネイティブ API の同等語句（`Phase B`、`spawn_agent`、`role` 等）に置換 |
| Codex の breezing/work SKILL.md に `review_engine` マトリクスがなかった | `codex` / `claude` 列を含む `review_engine` 比較テーブルを追加 |
| `--claude + --codex-review` のコンフリクトが未文書化 | 排他ルールを明記: 同時指定は実行前にエラー |
| 状態ファイルが `.claude/state/` パスを参照 | `${CODEX_HOME:-~/.codex}/state/harness/` パスに統一 |
| `opencode/` に古い breezing ファイルが残存 | `opencode/` を再ビルド — breezing を削除（開発専用スキル） |

### Fixed

- **Codex 用語マイグレーション**: `codex/.codex/skills/breezing/` と `codex/.codex/skills/work/` の 13 ファイルで 82 箇所以上のレガシー Claude Code 用語を置換 — `delegate mode` → `Phase B`、`TaskCreate` → `spawn_agent`、`subagent_type` → `role:`/`spawn_agent()`、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` → `config.toml [features] multi_agent`、`.claude/state/` → `${CODEX_HOME}/state/harness/`
- **`--claude` レビュールーティング**: `breezing/SKILL.md` と `work/SKILL.md` の両方に `review_engine` マトリクステーブルと `--claude + --codex-review` コンフリクトルールを追加
- **OpenCode 同期**: `opencode/` を再ビルドして古い breezing ファイルと routing-rules.md を削除

---

## [2.23.1] - 2026-02-22

### 🎯 あなたにとって何が変わるか

**Codex CLI セットアップがファイルを上書きせずマージするようになり、README のセットアップ手順も折りたたみブロックで見やすくなりました。**

| Before | After |
|--------|-------|
| `setup-codex.sh` が同期のたびにコピー先の全ファイルを上書きしていた | マージ戦略: 新規ファイルは追加、既存ファイルはバックアップ後更新、ユーザー作成ファイルは保持 |
| Codex CLI Setup が README のトップレベルセクションだった | 折りたたみ `<details>` ブロックに移動し、ステップバイステップのクイックスタートを追加 |
| `config.toml` に 4 つのエージェント定義 | 9 エージェント: `task_worker`、`code_reviewer`、`codex_implementer`、`plan_analyst`、`plan_critic` を追加 |

### Changed

- **README (EN/JA)**: Codex CLI Setup セクションをトップレベルから折りたたみ `<details>` ブロックに移動。前提条件、3 ステップクイックスタート、フラグ一覧表を追加
- **`setup-codex.sh`**: `sync_named_children()` を 3 ウェイマージ戦略で書き換え — 新規ファイルはコピー、既存ファイルはバックアップ後更新、コピー先のみのファイルは保持。ログ出力が `(N new, N updated, N preserved, N skipped)` 形式に
- **`codex-setup-local.sh`**: 同じマージ戦略をプロジェクトローカル版セットアップスクリプトにも適用

### Added

- **`merge_dir_recursive()`** ヘルパー: 両セットアップスクリプトにバックアップ付き再帰的ディレクトリマージ機能を追加
- **5 つの新 Codex エージェント定義**（`setup-codex.sh` の `config.toml` 生成）: `task_worker`、`code_reviewer`、`codex_implementer`、`plan_analyst`、`plan_critic`（Breezing ロール）
- 冪等なエージェント注入: 既存の `config.toml` には不足しているエージェントエントリのみ追加（重複なし）

---

## [2.23.0] - 2026-02-21

### 🎯 あなたにとって何が変わるか

**Codex breezing に独自の Phase 0（計画議論）が追加されました — Codex ネイティブのマルチエージェント API を使って、Planner と Critic が実装前に計画を分析します。**

| Before | After |
|--------|-------|
| Codex breezing の Phase 0 はデッドコード（Claude 専用 API を参照していた） | Phase 0 が `spawn_agent`/`send_input`/`wait`/`close_agent` でネイティブ動作 |
| `config.toml` に 4 つのエージェント定義 | `plan_analyst`、`plan_critic`、`task_worker`、`code_reviewer`、`codex_implementer` を含む 9 定義 |
| breezing の全リファレンスファイルが Claude と Codex で同一だった | 3 ファイルがプラットフォーム固有の実装で意図的に分岐 |

### Added

- **Codex Phase 0（計画議論）**: Claude Agent Teams から Codex ネイティブマルチエージェント API（`spawn_agent`/`send_input`/`wait`/`close_agent`）に移植
- **5 つの新 Codex エージェント定義**（`config.toml`）: `plan_analyst`、`plan_critic`、`task_worker`、`code_reviewer`、`codex_implementer`
- **ミラー同期 divergence 管理**（D24、P20）: breezing の 3 ファイル（`planning-discussion.md`、`execution-flow.md`、`team-composition.md`）を rsync 除外対象に設定し、Codex ネイティブ実装を保護

### Changed

- **Codex `planning-discussion.md`**: Codex ネイティブ API で全面書き換え — Planner ↔ Critic の対話を Lead 中継パターン（`send_input` + `wait` ループ）で実装
- **Codex `execution-flow.md`**: Phase 0 + Phase A の spawn ロジックを `spawn_agent()` 形式に更新。環境チェックを `config.toml [features] multi_agent = true` 参照に変更
- **Codex `team-composition.md`**: 全ロール定義を更新 — `subagent_type` 削除、`spawn_agent()` 形式、`SendMessage` → `send_input()`、`shutdown_request` → `close_agent()`

---

## [2.22.0] - 2026-02-21

### 🎯 あなたにとって何が変わるか

**Harness をインストールした瞬間からセキュリティガードレールが有効になります — `/harness-init` は不要です。権限ポリシーは最小権限原則で強化され、セッションログもプライバシー安全になりました。**

| Before | After |
|--------|-------|
| セキュリティ設定（deny/ask ルール）の有効化には `/harness-init` の実行が必要だった | CC 2.1.49+ ではインストール直後から Plugin settings が自動適用される |
| Plugin settings に広範な `allow` ルールがあり、DB CLI の保護がなかった | 最小権限: 包括的 `allow` を削除、`psql`/`mysql`/`mongo` の deny を追加 |
| `stop-session-evaluator.sh` は入力を読まず常に `{"ok":true}` を返すだけだった | `last_assistant_message` を読み取り、長さ+ハッシュのみ保存（プライバシー安全）、アトミック書き込み対応 |
| 設定ファイル変更時のフックがなかった | 新しい `ConfigChange` フックが breezing アクティブ時に設定変更をタイムラインに記録 |
| `npm install` / `bun install` が確認なしで実行された | パッケージマネージャのインストールにユーザー確認が必要に（`ask` ルール） |

### Added

- **Plugin settings.json** (`.claude-plugin/settings.json`): プラグインと共に配布されるデフォルトのセキュリティ権限設定 — インストール直後から有効（CC 2.1.49+）
  - **Deny**: `.env`、secrets、SSH 鍵（`id_rsa`、`id_ed25519`）、`.aws/`、`.ssh/`、`.npmrc`、`sudo`、`rm -rf/-fr`、DB CLI（`psql`、`mysql`、`mongo`）
  - **Ask**: 破壊的 git（`push --force`、`reset --hard`、`clean -f`、`rebase`、`merge`）、パッケージインストール（`npm/bun/pnpm install`）、`npx`/`npm exec`
- **`ConfigChange` フック** (`scripts/hook-handlers/config-change.sh`): breezing アクティブ時に設定ファイルの変更を `breezing-timeline.jsonl` に記録。常に非ブロッキング
  - `file_path` をリポジトリ相対パスに正規化してタイムラインに記録
  - ポータブルなタイムアウト検出（`timeout`/`gtimeout`/`dd` フォールバック）
- **`stop-session-evaluator.sh` での `last_assistant_message` 対応**: CC 2.1.47+ の Stop ペイロードを読み取り
  - メッセージの長さ + SHA-256 ハッシュのみ保存（平文なし — プライバシー・バイ・デザイン）
  - `mktemp` によるアトミック書き込み（TOCTOU 修正）
  - ポータブルなハッシュ検出（`shasum`/`sha256sum`）
- **CC 2.1.49 互換性マトリクス** (`docs/CLAUDE_CODE_COMPATIBILITY.md`): v2.1.43-v2.1.49 のエントリを追加。Plugin settings.json、Worktree isolation、Background agents、ConfigChange hook、Sonnet 4.6、WASM memory fix をカバー

### Changed

- **Breezing: Worktree isolation 対応**（CC 2.1.49+）: `guardrails-inheritance.md` に `isolation: "worktree"` を記述 — 並列 Implementer が同一ファイルを編集しても git worktree 分離により衝突しない
- **Breezing: Agent model フィールド修正**（CC 2.1.47+）: エージェント spawn 時の model フィールド動作変更をガードレールに記述
- **Breezing: Background agents**（`background: true`）: `video-scene-generator` エージェントが非ブロッキングバックグラウンド実行に対応
- **Breezing: opencode ミラー完全同期**: breezing の全10リファレンスファイル（execution-flow, team-composition, review-retake-loop, session-resilience, planning-discussion, plans-to-tasklist, codex-engine, codex-review-integration, guardrails-inheritance, SKILL.md）を `opencode/skills/breezing/` に初めて同期
- **Breezing: Codex ミラー更新**: `codex/.codex/skills/breezing/` の全リファレンスファイルを最新版に更新
- **Work スキル**: Codex ミラーの auto-commit, auto-iteration, codex-engine, error-handling, execution-flow, parallel-execution, review-loop, scope-dialog, session-management を大幅更新
- **`quick-install.sh`**: デフォルトのセキュリティ設定が自動適用される旨の案内メッセージを追加
- **`claude-settings.md` スキル**: CC 2.1.49+ では plugin settings が自動適用されるため、手動での `settings.json` 生成はプロジェクト固有の追加設定が必要な場合のみと注記を追加
- **`settings.security.json.template`**: `_harness_version` を更新、plugin settings との役割分担を明記する `_harness_note` を追加、`rm -rf/-fr` の deny バリアントを統一
- **バージョン参照**: 16 以上のスキル・エージェントファイルで CC 2.1.38 → 2.1.49 に更新

### Security

- **最小権限の強制**: plugin settings.json から過度に広い `allow` を削除。すべての権限を明示的な deny または ask に
- **DB CLI deny ルール**: `psql`、`mysql`、`mongod`、`mongo` をデフォルトでブロックし、誤操作によるデータ破壊を防止
- **シークレットパスの拡張**: `id_ed25519`、再帰的 `.ssh/`、`.aws/`、`.npmrc` を deny パターンに追加
- **プライバシー安全なセッションログ**: `last_assistant_message` を平文ではなく長さ+ハッシュで保存
- **アトミックファイル書き込み**: `session.json` の更新に `mktemp` + `mv` を使用し、TOCTOU 競合条件を防止
- Codex 3 エキスパート（Security/Quality/Architect）全員がハードニングレビューで A 評価

---

## [2.21.0] - 2026-02-20

### 🎯 あなたにとって何が変わるか

**Breezing がコーディング開始前にプランをレビューするようになりました。Phase 0（Planning Discussion）がデフォルトで実行されます — `--no-discuss` でスキップ可能。**

| Before | After |
|--------|-------|
| `/breezing` は即座にコーディングを開始 | 実装前に Planner + Critic がプランをレビュー |
| タスク登録前のバリデーションなし | V1〜V5 チェック（スコープ、曖昧性、owns 重複、依存関係、TDD） |
| 全タスクを一度に登録 | 8タスク以上は自動的にプログレッシブバッチに分割 |
| Implementer 間は Lead 経由でのみ通信 | Implementer 同士が直接メッセージ可能 |

### Added

- **Breezing Planning Discussion（Phase 0）**: 実装前に Planner + Critic のチームメイトがプランを精査（デフォルト有効、`--no-discuss` でスキップ）
- **タスク粒度バリデーション（V1〜V5）**: TaskCreate 前にスコープ、曖昧性、owns 重複、依存関係の整合性、TDD マーカーを検証
- **プログレッシブバッチ戦略**: 8タスク以上の場合に自動バッチ分割、60% 完了でトリガー
- **Implementer 間の直接通信（パターン D）**: SendMessage による Implementer 同士のナレッジ共有
- **フック駆動シグナル**: `task-completed.sh` が `partial_review_recommended` と `next_batch_recommended` シグナルを生成
- **Spec Driven Development 統合**: Plans.md の `[feature:tdd]` マーカーがテストファースト型タスク生成をトリガー
- **新エージェント**: `plan-analyst`（タスク分析）と `plan-critic`（Red Teaming レビュー）を Phase 0 用に追加

### Fixed

- **シグナル閾値比較**: `task-completed.sh` の `-eq` を `-ge` に変更。同時完了で閾値を飛び越すケースに対応
- **シグナル重複防止**: シグナル発行前に既存シグナルの存在チェックを追加
- **シグナル生成フォールバック**: `jq` が利用不可の場合に `python3` フォールバックを追加
- **完了カウント修正**: バッチスコープ内の `grep -c` 過剰カウントを修正（リテイク回数に関係なく task_id ごとに1回カウント）
- **ドキュメント整合性**: execution-flow.md、team-composition.md、planning-discussion.md 間のラウンド数・V1-V4 スキップポリシーの矛盾を解消
- **シグナルのセッションスコープ**: シグナルに `session_id` を含め、セッション単位で重複排除。前セッションのシグナルが新セッションを抑制しない
- **grep パターン安全性**: task_id 検索の `grep -q` を `grep -Fq`（固定文字列マッチ）に変更。正規表現メタ文字のインジェクション防止
- **stdin パイプ安全性**: JSON を jq/python3 にパイプする際の `echo` を `printf '%s'` に変更。エッジケースの文字化け防止
- **DRY シグナル構築**: `_build_signal_json` ヘルパーを抽出し、シグナルパスの jq/python3 フォールバック重複を排除
- **Phase 0 ハンドオフ永続化**: Compaction 耐性のため breezing-active.json に `handoff` ペイロードを追加（Phase 0 → Phase A 間）
- **Resume 時の stale-ID 照合**: セッション再開時に旧タスク ID を新 ID にマッピングするルールを追加。アクティブ ID セットに対する完了判定

---

## [2.20.13] - 2026-02-19

### 🎯 あなたにとって何が変わるか

**Codex 実行はネイティブ・マルチエージェント前提に統一され、`--claude` 指定時は実装とレビューの両方が Claude 委譲に固定されました。**

| Before | After |
|--------|-------|
| Codex スキル文書に旧タスクチーム語彙や旧状態パスが混在 | Codex ネイティブのマルチエージェント語彙（`spawn_agent` / `wait` / `send_input` / `resume_agent` / `close_agent`）と CODEX_HOME 状態パスに統一 |
| `--claude` の説明が一部で「実装委譲のみ」に見える箇所があった | `--claude` は「実装 + レビューとも Claude 委譲」に統一 |
| setup 後の `multi_agent` / ロール既定値が暗黙 | setup スクリプトが `config.toml` に `features.multi_agent=true` と harness 用 `[agents.*]` 既定を自動補完 |

### Changed

- Codex 配布の `work` / `breezing` 文書をネイティブ・マルチエージェント前提へ全面更新し、旧タスクチーム語彙を除去。
- Codex スキル文書の状態保存先を `${CODEX_HOME:-~/.codex}/state/harness/` に統一。
- `--claude + --codex-review` の同時指定を開始前エラーとして明記。
- Codex README と setup リファレンスを、マルチエージェント既定とロール宣言前提に整合。
- `tests/test-codex-package.sh` と CI を強化し、旧語彙の再流入とマルチエージェント必須キーワード/設定欠落を検知可能に。

### Fixed

- `work` / `breezing` の両方で、`--claude` 時のレビュー経路を Claude 固定として明示。

---

## [2.20.11] - 2026-02-19

### Changed

- **Harness UI を配布対象外へ移動**: UI 本体・スキル・テンプレート・フックスクリプトを配布ペイロードから除外
- **SessionStart フックを簡素化**: startup/resume から `harness-ui-register` 呼び出しを削除

### Fixed

- **Issue #50 対応**: 絶対パスを含む memory wrapper スクリプトへの配布経路依存を解消
  - 配布インデックスから 8 スクリプト（`scripts/harness-mem*`, `scripts/hook-handlers/memory-*.sh`）を除外
  - hooks/config から当該 wrapper 参照を削除

---

## [2.20.10] - 2026-02-18

### 🎯 あなたにとって何が変わるか

**Codex Harness がユーザーベース導入を標準化。Codex 実行は Codex-first となり、Claude 委譲は `--claude` で明示指定になりました。**

| Before | After |
|--------|-------|
| Codex 設定はプロジェクトごとの `.codex` コピーが前提 | `${CODEX_HOME:-~/.codex}` へのユーザーベース導入が既定（`--project` は任意） |
| Codex 実装は `--codex` 指定が主導線 | Codex が既定実装エンジン、`--claude` で明示委譲 |
| Codex セットアップ文書に project/user スコープ混在 | README と setup リファレンスを日英でユーザーベースに統一 |

### Changed

- `scripts/setup-codex.sh` / `scripts/codex-setup-local.sh` を更新し、スキル・ルールの導入先を既定で `${CODEX_HOME:-~/.codex}` に変更。
- 必要時のみプロジェクト導入できる `--project` フォールバックを追加。
- Codex 配布ドキュメントと setup リファレンス（JP/EN）をユーザーベース既定に統一。
- Codex スキルのルーティング/実行説明を再整理し、実装要求は Codex-first の `/work`、Claude 委譲は `--claude` で明示化。
- `/breezing` の復旧・状態管理ドキュメント（`impl_mode`）を Codex-first 実行モデルに整合。
- README・setup リファレンス・Codex 配布ドキュメント間の記述ずれを解消。

---
## [2.20.9] - 2026-02-15

### 🎯 あなたにとって何が変わるか

**Codex モード時の `harness-review` は、Claude CLI（`claude -p`）へ委譲されることがドキュメント上で一貫しました。**

| Before | After |
|--------|-------|
| Codex 側レビュー文書で Codex/MCP と委譲先の表現が混在 | Codex 側文書で `claude -p` 委譲フローに表現を統一 |

### Changed

- Codex 側レビュー文書を更新し、レビュー モード説明・統合フロー・検出ガイダンスを `claude -p` 委譲前提に統一。
- Codex レビュー関連ドキュメントの用語不整合を解消。

---
## [2.20.8] - 2026-02-14

### Changed

- **Claude Code 2.1.41/2.1.42 対応**: 互換性マトリクスと推奨バージョンを v2.1.41+ に引き上げ
  - `docs/CLAUDE_CODE_COMPATIBILITY.md` に v2.1.39〜v2.1.42 の4バージョン・30+行の機能対応を追加
  - 推奨バージョンを v2.1.38+ → **v2.1.41+** に引き上げ（Agent Teams の Bedrock/Vertex/Foundry モデルID修正、Hook stderr 表示修正が主因）
- **Breezing Bedrock/Vertex/Foundry 注記**: `guardrails-inheritance.md` に CC 2.1.41+ 必須の注記追加
- **セッション `/rename` 自動命名**: session スキルに CC 2.1.41+ のセッション名自動生成ドキュメント追加
- **トラブルシュート `claude auth` コマンド**: 診断テーブルに CC 2.1.41+ の `claude auth login/status/logout` を追加

---
## [2.20.7] - 2026-02-14

### Fixed

- **Stop フックの「JSON validation failed」エラー (#42)**: 信頼性の低い `type: "prompt"` フックを確定的な `type: "command"` フック（`stop-session-evaluator.sh`）に置換
  - 根本原因: prompt type フックが LLM に JSON 形式での応答を指示していたが、モデルが自然言語を返すことが多く、毎ターン JSON パースエラーが発生
  - 新しいコマンドベースの評価スクリプトは常に有効な JSON を出力し、バリデーションエラーを完全に排除
  - `hooks/hooks.json` と `.claude-plugin/hooks.json` の両方を同期して更新

---
## [2.20.6] - 2026-02-14

### Fixed

- **session-auto-broadcast.sh の hookEventName バリデーションエラー** (#41):
  - `hookEventName` を `"AutoBroadcast"` → `"PostToolUse"` に修正（4箇所）
  - `session-broadcast.sh` の `hookEventName` を `"Broadcast"` → `"PostToolUse"` に修正
  - subprocess の stdout 汚染を防止（`>/dev/null` リダイレクト追加）
  - `test-hook-event-names.sh` テスト追加（hookEventName 一貫性の回帰テスト）

---
## [2.20.5] - 2026-02-12

### Fixed

- **Breezing `--codex` の subagent_type 選択を強制化**: `--codex` フラグが Implementer spawn 時に無視される問題を修正
  - 根本原因: `execution-flow.md` の Step 3 が `task-worker` をハードコードし、`--codex` 分岐が存在しなかった
  - SKILL.md、execution-flow.md、team-composition.md に `impl_mode` による必須分岐を追加
  - 3つの「絶対禁止」ルールを追加: codex モードでは `codex-implementer` 必須、standard モードでは `task-worker` 必須、codex モードの Lead はソースコードの直接 Write/Edit 禁止
  - 並列 spawn の明示指示を追加: N 個の Implementer を同時 spawn（`N = min(独立タスク数, --parallel N, 3)`）
  - Compaction Recovery が `impl_mode` に基づき正しい subagent_type を復元するよう修正

---

## [2.20.4] - 2026-02-11

### Fixed

- **Codex MCP → CLI 移行（Phase 7 完了）**:
  - `pretooluse-guard.sh`（4箇所）と `codex-worker-engine.sh`（1箇所）の `mcp__codex__codex` テキスト参照を `codex exec (CLI)` に置換
  - `codex-review/SKILL.md` から MCP レガシー注記を削除
  - `.claude/rules/codex-cli-only.md` ルールを追加（再発防止）
  - PreToolUse フック failsafe を追加: `mcp__codex__*` ツール呼び出しを `emit_deny` + `msg()` パターンでローカライズメッセージ付き拒否
  - opencode/codex ミラーの開発専用スキル（`test-*`, `x-promo`, `x-release-harness`）を `.gitignore` に追加

### Security

- **Codex MCP 二重防御**: 廃止済み MCP 使用に対する3層防御（テキスト修正 + フックブロック + ルールファイル）。Codex レビュー: Security A, Architect B

---

## [2.20.3] - 2026-02-10

### Fixed

- **フックハンドラのセキュリティ強化** (Codex レビュー Round 1-3):
  - 手動 JSON エスケープを `jq -nc --arg` / `python3 json.dumps` に置換（安全な JSON 構築）
  - Python コードインジェクション脆弱性を修正: データを `sys.argv`/`stdin` 経由で渡すように変更
  - `set -euo pipefail` 下での `grep` 失敗を `|| true` で修正
  - `grep -F` による固定文字列マッチング（正規表現メタ文字問題を回避）
  - `.claude/state` ディレクトリに `chmod 700` を追加
  - description 切り詰め時の `tostring` 型安全ガードを追加
  - TeammateIdle イベントの 5 秒重複抑制を追加
  - JSONL ローテーション（500 → 400 行）で無制限増加を防止

---

## [2.20.2] - 2026-02-10

### Added

- **TeammateIdle/TaskCompleted フックハンドラ**: `scripts/hook-handlers/teammate-idle.sh` と `task-completed.sh` を新規作成。Agent Teams のイベントを `.claude/state/breezing-timeline.jsonl` に記録
- **3層メモリアーキテクチャ (D22)**: Claude Code 自動メモリ、Harness SSOT、Agent Memory の共存設計を `decisions.md` に記録
- **Task(agent_type) パターン (P18)**: サブエージェント種別制限構文を `patterns.md` に記録

### Changed

- **Claude Code 2.1.38+ 対応**: CLAUDE.md の Feature Table に 6 行追加（TeammateIdle/TaskCompleted Hook、Agent Memory、Fast mode、自動メモリ記録、スキルバジェットスケーリング、Task(agent_type) 制限）
- **バージョン参照更新**: 全スキル・エージェントの「CC 2.1.30+」を「CC 2.1.38+」に更新（16+ ファイル）
- **スキルバジェットスケーリング**: `skill-editing.md` の 500 行ハードルールを推奨に緩和、CC 2.1.32+ の 2% スケーリングを注記
- **セッションメモリ**: `session-memory/SKILL.md` と `memory/SKILL.md` に「自動メモリとの関係（D22）」セクション追加
- **Breezing 実行フロー**: `execution-flow.md` のフック実装状態を「実装済み」に更新
- **ガードレール継承**: 安全メカニズムテーブルに Task(agent_type) を追加

---

## [2.20.1] - 2026-02-10

### Fixed

- **PostToolUse フック構文エラー**: `posttooluse-tampering-detector.sh` でヒアドック内の `|| true` がコマンド置換内にあることによる bash パースエラーを修正
- **全フックの python3 フォールバック**: 全10フックスクリプトでヒアドック形式の python3 フォールバックを `python3 -c` に置換（stdin 競合の解消）
- **POSIX 準拠**: 安全な入力パイプのため `echo` を `printf '%s'` に変更、`echo -e` を `printf '%b'` に変更
- **パターンマッチング**: 6つのパターンチェックで `echo | grep -qE` を `[[ =~ ]]`（単語境界付き）に置換
- **エラーハンドリング**: `set -euo pipefail` を `set +e` に変更（他の全 PostToolUse スクリプトと統一）
- **バイリンガル警告**: フックスクリプトに英語・日本語両方の警告メッセージを追加

---

## [2.20.0] - 2026-02-08

### 🎯 あなたにとって何が変わるか

**28スキルを19に統合。Breezing の Phase A/B/C 分離、Teammate 権限修正、リポジトリクリーンアップを実施。**

| Before | After |
|--------|-------|
| `memory`, `sync-ssot-from-memory`, `cursor-mem` の3スキル | `memory` 1つに統合（SSOT昇格・記憶検索を references に移設） |
| `setup` 系が6スキルに分散 | `setup` 1つに統合（ルーティングテーブルで分岐） |
| `ci`, `agent-browser`, `x-release-harness` がメニューに露出 | `user-invocable: false` で非表示化（自動ロード経由でアクセス可能） |
| `/breezing` 開始直後に bypass permissions が失われる | Phase A で bypass 維持 → Phase B でのみ delegate |
| 完了ステージでも delegate mode のまま | Phase C で delegate 解除 → Lead が直接コミット可能 |
| Teammate が "prompts unavailable" で Bash 自動拒否 | `mode: "bypassPermissions"` + PreToolUse hooks で安全に解決 |
| ビルド成果物・開発専用ドキュメントが git に追跡されていた | 33ファイルを untrack、.gitignore 更新 |

### Changed

- **スキル統合 (28 → 19)**:
  - `/memory`: `sync-ssot-from-memory` と `cursor-mem` を吸収
  - `/setup`: `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` を吸収
  - `/troubleshoot`: CI 障害トリガーを description に追加
- **Breezing Phase 分離**: Phase A (Pre-delegate) / Phase B (Delegate) / Phase C (Post-delegate) の3段階に構造化
  - Phase A: ユーザーのパーミッションモードを維持したまま Team 初期化・spawn
  - Phase B: delegate mode で Lead は調整専念（TaskCreate/TaskUpdate/SendMessage のみ）
  - Phase C: delegate 解除後に統合検証・コミット・クリーンアップ
- **Teammate 権限モデル**: 全 Teammate spawn に `mode: "bypassPermissions"` を指定
  - PreToolUse hooks は権限システムと独立して発火（公式仕様）
  - 安全層: disallowedTools + spawn prompt 制約 + .claude/rules/ + Lead 監視
- **英語リリース**: GitHub リリースノートを英語に統一。リリースルール・スキルを更新
- **全関連ドキュメント更新**: execution-flow.md, team-composition.md, codex-engine.md, guardrails-inheritance.md, session-resilience.md

### Added

- `skills/memory/references/cursor-mem-search.md` - Cursor 連携メモリ検索リファレンス
- `skills/setup/references/harness-mem.md` - Harness-Mem セットアップリファレンス
- `skills/setup/references/localize-rules.md` - ルールローカライズリファレンス
- **Codex 初回チェックフック**: `/codex-review` 初回使用時に `check-codex.sh` を自動実行（`once: true`）
- **timeout/gtimeout 検出**: macOS ユーザー向けに `brew install coreutils` を案内

### Fixed

- **Codex レビュー指摘 22 件修正**: pretooluse-guard の JSON パース統合（5→1 jq call）、symlink セキュリティガード追加、session-monitor の `eval` 除去
- **macOS 互換性**: 全ドキュメントの `timeout N codex exec` → `$TIMEOUT N codex exec` に置換（GNU coreutils 非依存化）
- **Teammate Bash 自動拒否**: バックグラウンド Teammate の "prompts unavailable" エラーを解決

### Removed

- **33ファイルを untrack**: `mcp-server/dist/`（ビルド成果物 24件）、`docs/design/`（2件）、`docs/slides/`（1件）、`docs/claude-mem-japanese-setup.md`、開発専用ドキュメント（3件）、ロックファイル（2件）
- **アーカイブ済みスキル**: `sync-ssot-from-memory`, `cursor-mem`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` → `skills/_archived/`

---

## [2.19.0] - 2026-02-08

### 🎯 あなたにとって何が変わるか

**5つの実装コマンドを `/work` と `/breezing` の2つに統一。両方 `--codex` 対応。**

| Before | After |
|--------|-------|
| `/work`, `/ultrawork`, `/breezing`, `/breezing-codex`, `/codex-worker` の5コマンド | `/work` と `/breezing` の2コマンドに統一 |
| コマンドの使い分けが複雑 | `/work` = Claude 実装、`/breezing` = チーム完走 |
| Codex は別コマンド (`/codex-worker`, `/breezing-codex`) | `--codex` フラグで統一切り替え |
| スコープ指定方法がコマンドごとに異なる | 両コマンド共通の対話式スコープ確認 |

### Changed

- **`/work` 全面改修**: 対話式スコープ確認 + タスク数に応じた自動戦略選択
  - 1タスク → 直接実装、2-3 → 並列、4+ → 自動反復（旧 ultrawork 統合）
  - `--codex` フラグで Codex 実装委託モード
  - 新リファレンス: scope-dialog.md, auto-iteration.md, codex-engine.md
- **`/breezing` 更新**: `--codex` フラグ統合（旧 breezing-codex 吸収）
  - 対話式スコープ確認の追加
  - Codex Implementer 連携を codex-engine.md に集約
- **pretooluse-guard.sh**: `ultrawork-active.json` → `work-active.json` に統一
  - 後方互換: 旧ファイル名もフォールバックで検出

### Removed

- **ultrawork** スキル → `/work all` で同等機能（`skills/_archived/` に移動）
- **breezing-codex** スキル → `/breezing --codex` で同等機能（`skills/_archived/` に移動）
- **codex-worker** スキル → `/work --codex` で同等機能（`skills/_archived/` に移動）

---

## [2.18.11] - 2026-02-06

### 🎯 あなたにとって何が変わるか

**`--codex` モード時、Claude は PM として振る舞い、Edit/Write が自動ブロックされるようになりました**

| Before | After |
|--------|-------|
| `--codex` 時も Claude が直接編集可能 | Claude の Edit/Write は Plans.md 以外ブロック |
| 役割分担が曖昧 | PM（Claude）と Worker（Codex）の明確な分離 |

### Added

- **breezing スキル**: Agent Teams を活用した完全自動タスク完走
  - Lead は delegate mode で調整専念、実装は Implementer、レビューは独立 Reviewer
  - `--codex-review` でマルチ AI レビュー統合
  - `/ultrawork` より大規模なタスクセット向け
- **Codex モードガード**: `pretooluse-guard.sh` に Codex モード検出を追加
  - Claude が PM 役として機能し、実装は Codex Worker に委譲
  - `ultrawork-active.json` の `codex_mode: true` で有効化
  - Plans.md の状態マーカー更新のみ許可

### Changed

- **Codex レビュー改善**: 並列レビューの品質向上
  - SSOT（decisions.md/patterns.md）を考慮した文脈あるレビュー
  - 出力制限を 1500 → 2500 文字に緩和（十分な分析のため）
  - 終了条件を明確化（Critical/High = 0 で APPROVE）
  - 「重箱の隅つつき」問題を解消（Low/Medium のみは APPROVE）
- エキスパートテンプレートの軽微な修正

---

## [2.18.10] - 2026-02-06

### Added

- **エージェント永続メモリ**: 全7エージェントに `memory: project/user` 設定を追加
  - サブエージェントが会話間で制度的知識を蓄積可能に
  - セキュリティ: Read-only エージェント（code-reviewer, project-analyzer）は Bash/Write/Edit 禁止を維持
  - プライバシーガード: 各エージェントにシークレット/PII 保存禁止ルールを明記

---

## [2.18.7] - 2026-02-05

### Changed

- **Claude ガード**: 通常の `git push` では止めず、`-f/--force/--force-with-lease` のみ prompt するように変更しました。

---

## [2.18.6] - 2026-02-05

### Fixed

- **Codex ガード**: `.codex/rules/harness.rules` が安定してパースされ、`git clean -n` / `sudo -n true` のような安全コマンドで止まりにくくなりました（破壊的コマンドは prompt）。
- **Claude ガード**: `templates/claude/settings.security.json.template` のパーミッション構文を修正し、破壊的操作のみ prompt するように見直しました。

### Changed

- **Codex パッケージテスト**: rules の例（match/not_match）検証を追加し、起動時のパース失敗を防止。

---

## [2.18.5] - 2026-02-05

### Added

- **gogcli-ops スキル**: Google Workspace CLI 操作（Drive/Sheets/Docs/Slides）
  - 認証フロー / 複数アカウント選択
  - URL → ID 解決（`gog_parse_url.py`）
  - 原則 read-only、書き込みは明示確認

---

## [2.18.4] - 2026-02-04

### Added

- **Codex セットアップコマンド**: `/codex-setup` と `scripts/codex-setup-local.sh` を追加
- **Setup tools**: `/setup-tools codex` でセッション内セットアップ
- **Harness init/update**: `/harness-init` と `/harness-update` に Codex CLI 同期を追加

---

## [2.18.2] - 2026-02-04

### Added

- **Codex CLI 配布物**: `codex/.codex` に全スキルと暫定 Rules ガードを追加
- **Codex セットアップ**: `scripts/setup-codex.sh` と `codex/README.md` を追加
- **Codex AGENTS**: `$skill` 呼び出し向け `codex/AGENTS.md` を追加
- **Codex パッケージテスト**: `tests/test-codex-package.sh` を追加

### Changed

- **ドキュメント**: README に Codex CLI セットアップ手順を追記

---

## [2.18.1] - 2026-02-04

### Added

- **Aivis/VOICEVOX TTS 対応**: generate-video スキルで日本語 TTS プロバイダーを追加
  - `aivis`: Aivis Cloud API（speaker_id, intonation_scale 等）
  - `voicevox`: VOICEVOX（ずんだもん等のキャラクター音声）
  - サンプルキャラクター設定を追加

### Changed

- **MCP サーバーのオプション化**: `.mcp.json` を削除し、mcp-server を配布から除外
  - 必要なユーザーは別途セットアップ

---

## [2.18.0] - 2026-02-04

### Added

- **Claude Code 2.1.38 対応**: 新機能との完全統合
  - **AgentTrace v0.3.0**: Task tool メトリクス対応（tokenCount, toolUses, duration）
  - **`/debug` コマンド連携**: troubleshoot スキルが複雑なセッション問題に `/debug` を案内
  - **PDF ページ範囲読み込み**: notebookLM, harness-review で `pages` パラメータ対応
  - **Git log 拡張フラグ**: `--format`, `--raw`, `--cherry-pick` を活用
  - **68% メモリ最適化**: `--resume` の恩恵をドキュメント化
  - **サブエージェント MCP アクセス**: MCP ツール共有のバグ修正対応

---

## [2.17.10] - 2026-02-04

### Added

- **PreCompact/SessionEnd フック**: セッション状態の自動保存・クリーンアップに対応
- **AgentTrace v0.2.0**: Attribution フィールド追加（プラグイン帰属情報の記録）
- **Sandbox 設定テンプレート**: `templates/settings/harness-sandbox.json` を追加

### Changed

- **context: fork 追加**: deploy/generate-video/memory/verify スキルで独立コンテキストを使用
- **release → release-harness**: Claude Code 組み込みコマンドとの名前衝突を回避

---

## [2.17.9] - 2026-02-04

### Changed

- **Codex モードをデフォルトに**: 新規プロジェクトの設定テンプレートで `review.mode: codex` がデフォルトに
- **Worktree 必要性判定**: `/ultrawork --codex` 実行時に Worktree が本当に必要か自動判定
  - タスク1つのみ、全タスク順次依存、ファイル重複あり → 直接実行モードにフォールバック
  - 不要な Worktree 作成オーバーヘッドを回避

---

## [2.17.8] - 2026-02-04

### Fixed

- **release スキル**: Skill ツールで `/release` が起動できない問題を修正
  - `disable-model-invocation: true` を削除

---

## [2.17.6] - 2026-02-04

### 🎯 あなたにとって何が変わるか

**generate-video スキルが JSON Schema 駆動のハイブリッドアーキテクチャに進化、README も刷新されました**

| Before | After |
|--------|-------|
| 動画生成の設定がコードに散在 | JSON Schema でシナリオを一元管理 |
| README の構成が長大 | TL;DR: Ultrawork セクションで即座に始められる |
| スキル説明が英語のみ | 28個のスキル description が日本語化 + ユーモア表現 |

### Added

- **generate-video JSON Schema アーキテクチャ** (#37)
  - `scenario-schema.json` でシナリオ構造を厳密定義
  - `validate-scenario.js` でセマンティック検証
  - `template-registry.js` でテンプレート管理
  - パストラバーサル攻撃対策を実装
- **TL;DR: Ultrawork セクション**: README に「説明が長い？これだけ」セクション追加
  - 日本語版にも「説明が長い？ならこれ: Ultrawork」として追加

### Changed

- **スキル description 日本語化**: 28個のスキルに日本語の説明とユーモア表現を追加
- **README 構成整理**: Install → TL;DR → Core Loop の流れに最適化
- **スキル数更新**: 42 → 45 スキル

### Fixed

- `validate-scenario.js`: セマンティックエラーフィルタリングのバグ修正
- `TransitionWrapper.tsx`: `slideIn` → `slide_in` でスキーマ命名規則に統一

---

## [2.17.3] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**Ultrawork がレビュー後に自動で自己修正ループに入るようになりました**

| Before | After |
|--------|-------|
| レビュー後に手動でプロンプト入力が必要 | APPROVE まで自動修正ループ |
| Codex 有無を手動で指定 | Codex MCP 自動検出 + フォールバック |
| 改善方法が不明確 | 「🎯 How to Achieve A」で改善指針を明示 |

### Added

- **自己修正ループ**: `/harness-review` 実行後、APPROVE になるまで自動で修正を繰り返す
  - リトライ状態管理（`ultrawork-retry.json`）で進捗追跡
  - REJECT/STOP は即停止して手動介入を促す
  - 最大3回のリトライ後に STOP

- **検証全実行規則**: 存在する検証スクリプトを優先順で全て実行し、失敗で即停止

- **改善指針テンプレート**: 「🎯 How to Achieve A」セクションで A 評価達成方法を明示
  - Decision 別統一フォーマット（APPROVE/REQUEST CHANGES/REJECT/STOP）

### Changed

- **Codex 自動検出**: Codex MCP が利用可能な場合は自動で Codex モードに切り替え
  - 利用不可の場合はサブエージェント並列にフォールバック
  - `timeout_ms`（ミリ秒単位）でタイムアウト設定可能

- **差分計算改善**: `merge-base` 基準で変更ファイル数を算出
  - staged/unstaged 差分も含む
  - 初回コミット/マージにも対応

- **review_aspects 検出**: パスベースの正規表現で決定的に判定

---

## [2.17.2] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**Codex Worker 完了時に Plans.md が自動更新されるようになりました**

| Before | After |
|--------|-------|
| 作業完了後に手動で Plans.md を更新 | スキルが自動で `cc:done` に更新 |

### Added

- **Plans.md 自動更新**: Codex Worker スキル完了時に必ずタスク完了処理を実行
  - 該当タスクを自動特定
  - `[ ]` → `[x]`, `cc:WIP` → `cc:done` に更新
  - タスクが見つからない場合はユーザーに確認

### Changed

- Codex Worker スクリプト品質改善（共通ライブラリ化、セキュリティ強化）

---

## [2.17.1] - 2026-02-03

### Added

- **Agent Trace**: AI が生成したコード編集をセッションコンテキストで可視化
  - `emit-agent-trace.js`: PostToolUse フックが Edit/Write 操作を `.claude/state/agent-trace.jsonl` に記録
  - `agent-trace-schema.json`: トレースレコードの JSON Schema (v0.1.0)
  - Stop フックがセッション終了時にプロジェクト名・現在タスク・最近の編集を表示
  - `sync-status` スキルが進捗確認に Agent Trace データを活用
  - `session-memory` スキルがクロスセッションのコンテキストとして Agent Trace を読み取り

### Changed

- Stop フック（`session-summary.sh`）に Agent Trace 情報の表示を追加
- VCS 情報取得を最適化: `git status --porcelain=2 -b -uno` の1回呼び出し + 5秒 TTL キャッシュ
- リポジトリルート検出で git プロセスを起動しないように変更（ディレクトリツリーを上向きに探索）

### Fixed

- トレースファイル操作のセキュリティ強化（シンリンクチェック、パーミッション強制）
- ロックファイルによるローテーション並行保護（O_CREAT|O_EXCL パターン）

---

## [2.17.0] - 2026-02-03

### Added

- **Codex Worker**: 実装タスクを OpenAI Codex に並列ワーカーとして委譲
  - `codex-worker` スキルで単一タスクの委譲
  - `ultrawork --codex` で git worktree を使った並列ワーカー実行
  - 品質ゲート: 証拠検証、lint/型チェック、テスト、改ざん検知
  - TTL とハートビートによるファイルロック機構
  - タスク完了時の Plans.md 自動更新

### Changed

- `codex-worker` と `codex-review` スキルに明示的なルーティングルール（Do NOT Load For セクション）を追加
- スキルの自動ロード精度向上のため description を改善

### Fixed

- シェルスクリプトのセキュリティ改善（jq インジェクション、git オプションインジェクション、値バリデーション）
- grep パターンの POSIX 互換性（`\s` → `[[:space:]]`）
- `set -e` コンテキスト内の算術演算

### Changed

- 5つのシェルスクリプトを追加: `codex-worker-setup.sh`, `codex-worker-engine.sh`, `codex-worker-lock.sh`, `codex-worker-quality-gate.sh`, `codex-worker-merge.sh`
- 統合テストを追加: `tests/test-codex-worker.sh`
- リファレンスドキュメントを追加: `skills/codex-worker/references/*.md`

---

## [2.16.21] - 2026-02-03

### Changed

- `ultrawork` の Codex Mode オプション（`--codex`, `--parallel`, `--worktree-base`）をデザインドラフトに移動
  - これらの機能は計画中だが未実装
  - ドキュメントに「(Design Draft / 未実装)」と明記
- `skills/ultrawork/references/codex-mode.md` をデザインドラフトドキュメントとして追加
- Codex Worker スクリプトとリファレンスを追加（未追跡、将来の実装向け）

---

## [2.16.20] - 2026-02-03

### Added

- `ultrawork` スキルに Options テーブルと Quick Reference 例を追加（`--codex`, `--parallel`, `--worktree-base`）

### Changed

- スキルルーティングルールを `skills/routing-rules.md` に一元化（SSOT パターン導入）
- `codex-review` と `codex-worker` のルーティングを決定的に（文脈判定を排除）

---

## [2.16.19] - 2026-02-03

### Fixed

- Stop フックの reason が2回表示される問題を軽減（キーワードのみ出力に変更）

---

## [2.16.17] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**スキルの使い方ヒントがオートコンプリートに表示されるようになりました**

| Before | After |
|--------|-------|
| `/harness-review` | `/harness-review [code|plan|scope]` |
| `/troubleshoot` | `/troubleshoot [build|test|runtime]` |

### Added

- 17スキルに使い方ヒント（`argument-hint`）を追加
- セッション間通知機能（複数セッション連携時に便利）

### Changed

- CI/テスト/ドキュメントを Skills 移行後の構造に更新

---

## [2.16.14] - 2026-02-02

### 🎯 あなたにとって何が変わるか

**実装を依頼すると、自動的に Plans.md に登録されます**

| Before | After |
|--------|-------|
| 口頭依頼が Plans.md に残らない | すべてのタスクが Plans.md に記録 |
| 進捗が追いにくい | `/sync-status` で全体把握可能 |

---

## [2.16.11] - 2026-02-02

### 🎯 あなたにとって何が変わるか

**コマンドがスキルに統合されました（使い方は変わりません）**

| Before | After |
|--------|-------|
| `/work`, `/harness-review` がコマンドとして存在 | 同じ名前でスキルとして動作 |
| 内部スキル (impl, verify) がメニューに表示 | 非表示に（ノイズ軽減） |
| `dev-browser`, `docs`, `video` | `agent-browser`, `notebookLM`, `generate-video` に改名 |

### Changed

- README を VibeCoder 向けにリライト（トラブルシューティング・アンインストール追加）
- CI スクリプトを Skills 構造に対応

---

## [2.16.5] - 2026-01-31

### 🎯 あなたにとって何が変わるか

**`/generate-video` が AI 画像生成・BGM・字幕・視覚効果に対応**

| Before | After |
|--------|-------|
| 画像素材は手動で用意 | AI が自動生成（Nano Banana Pro） |
| BGM・字幕なし | 著作権フリー BGM、日本語字幕対応 |
| 基本トランジションのみ | GlitchText, Particles 等のエフェクト |

---

## [2.16.0] - 2026-01-31

### 🎯 あなたにとって何が変わるか

**`/ultrawork` で rm -rf と git push の確認回数が減りました（実験的機能）**

| Before | After |
|--------|-------|
| rm -rf で毎回確認 | 計画時に許可したパスのみ自動承認 |
| git push で毎回確認 | ultrawork 中は自動承認（force除く） |

---

## [2.15.0] - 2026-01-26

### 🎯 あなたにとって何が変わるか

**OpenCode との完全互換モードを追加**

| Before | After |
|--------|-------|
| OpenCode 向けに別途設定が必要 | `/setup-opencode` で自動セットアップ |
| skills/ 構造が異なる | 同一スキルが両環境で動作 |

---

## [2.14.0] - 2026-01-16

### 🎯 あなたにとって何が変わるか

**`/work --full` で並列タスク実行が可能に**

| Before | After |
|--------|-------|
| タスクを1つずつ実行 | `--parallel 3` で最大3並列実行 |
| 完了報告を手動で確認 | 各 worker が自律的にセルフレビュー |

---

## [2.13.0] - 2026-01-14

### 🎯 あなたにとって何が変わるか

**Codex MCP による並列レビューを追加**

| Before | After |
|--------|-------|
| Claude 単体でレビュー | Codex 4エキスパートが並列でレビュー |
| 一度に1観点 | セキュリティ/品質/パフォーマンス/a11y を同時チェック |

---

## [2.12.0] - 2026-01-10

### Added

- **Harness UI ダッシュボード** (`/harness-ui`) - ブラウザで進捗確認
- **ブラウザ自動化** (`agent-browser`) - ページ操作・スクリーンショット

---

## [2.11.0] - 2026-01-08

### Added

- **セッション間メッセージング** - 複数 Claude Code セッション間でメッセージ送受信
- **CRUD 自動生成** (`crud` スキル) - Zod バリデーション付きエンドポイント生成

---

## [2.10.0] - 2026-01-04

### Added

- **LSP 統合** - Go-to-definition, Find-references で正確なコード理解
- **AST-Grep 統合** - 構造的なコードパターン検索

---

## 過去バージョン

v2.9.x 以前の詳細は [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases) を参照してください。

[2.23.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.3...v2.23.5
[2.23.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.2...v2.23.3
[2.23.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.1...v2.23.2
[2.23.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.0...v2.23.1
[2.23.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.22.0...v2.23.0
[2.22.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.21.0...v2.22.0
[2.21.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.13...v2.21.0
[2.20.13]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.11...v2.20.13
[2.20.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.10...v2.20.11
[2.20.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.9...v2.20.10
[2.20.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.8...v2.20.9
[2.20.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.7...v2.20.8
[2.20.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.6...v2.20.7
[2.20.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.5...v2.20.6
[2.20.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.4...v2.20.5
[2.20.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.3...v2.20.4
[2.20.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.2...v2.20.3
[2.20.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.1...v2.20.2
[2.20.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.0...v2.20.1
[2.20.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.11...v2.20.0
[2.18.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.10...v2.18.11
[2.18.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.7...v2.18.10
[2.18.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.6...v2.18.7
[2.18.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.5...v2.18.6
[2.18.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.4...v2.18.5
[2.18.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.2...v2.18.4
[2.18.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.1...v2.18.2
[2.18.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.0...v2.18.1
[2.18.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.10...v2.18.0
[2.17.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.9...v2.17.10
[2.17.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.8...v2.17.9
[2.17.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.3...v2.17.8
[2.17.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.2...v2.17.3
[2.17.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.20...v2.17.2
[2.16.20]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.19...v2.16.20
[2.16.19]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.17...v2.16.19
[2.16.17]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.14...v2.16.17
[2.16.14]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.11...v2.16.14
[2.16.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.5...v2.16.11
[2.16.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.0...v2.16.5
[2.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.13.0...v2.14.0
[2.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.12.0...v2.13.0
[2.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.11.0...v2.12.0
[2.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.24...v2.10.0
