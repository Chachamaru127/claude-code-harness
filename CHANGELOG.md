# Changelog

このプロジェクトのすべての注目すべき変更は、このファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に準拠しています。

## [Unreleased]

## [2.6.44] - 2026-01-08

### 🎯 あなたにとって何が変わるか

**`/harness-init` の対話回数が最大11回→最大2回に大幅削減。「おまかせ」で質問1回、完了後は自動決定された設定の詳細サマリーを表示します。**

### Changed

- **`/harness-init` 対話効率化（最大11回→最大2回）**
  - 質問統合: AskUserQuestion で「何を作る」「誰が使う」「おまかせ/詳細」を1回で質問
  - スマートデフォルト導入: 言語=ja、モード=.cursor/ 検出で自動判定、Skills Gate=自動設定
  - ファストトラック: 「おまかせ」「さくっと」で質問なし・確認1回で完了
  - 引数サポート: `/harness-init "ブログ" --mode=solo --stack=next-supabase`
  - 並列処理: 質問中にバックグラウンドでプロジェクト分析
  - Skills Gate 後回し: 初期負担軽減、`/skills-update` で後から調整可能
  - **完了報告の強化**: 自動決定された設定・生成ファイル・変更方法を詳細サマリーで提示

#### Before/After

| Before | After |
|--------|-------|
| 最大11回の対話ラウンド | 最小1回、最大2回の対話ラウンド |
| 言語選択→モード選択→詳細確認... | 統合質問1回で完了（おまかせ選択時） |
| Skills Gate 設定で必ず質問 | 自動設定、後から調整可能 |

- **エラーメッセージの日本語化**
  - `scripts/install-git-hooks.sh`: エラーと説明文を日本語化
  - `scripts/template-tracker.sh`: すべてのエラー・Usage・結果メッセージを日本語化
  - `scripts/claude-mem-mcp`: MCP 起動関連メッセージを日本語化
  - `tests/test-path-compatibility.sh`: テストサマリーを日本語化
  - `tests/test-frontmatter-integration.sh`: エラーメッセージとサマリーを日本語化

### Added

- **`/cc-cursor-cc` コマンド（計画検証ラウンドトリップ）**
  - Claude Code で壁打ちした内容を Cursor (PM) に検証依頼
  - 壁打ちコンテキストの自動抽出（やりたいこと、技術選択、決定事項、未決事項、懸念点）
  - Plans.md への仮タスク追加（`pm:検証待ち` マーカー付き）
  - Cursor 向けの検証依頼文を `/plan-with-cc` 形式で生成
  - フロー: Claude Code (壁打ち) → Cursor (検証・Plans.md更新) → Claude Code (実装)

- **`ask-project-type` スキル（曖昧ケース対応）**
  - プロジェクト判定が曖昧な場合にユーザーに確認
  - ワークフロー参照整合性テスト追加

## [2.6.37] - 2026-01-05

### 🎯 あなたにとって何が変わるか

**Claude がテストを改ざんした場合、次のターンで警告が表示されるようになりました。操作はブロックせず、Claude に「見られている」という認識を持たせることで報酬詐欺を抑止します。**

### Added

- **テスト改ざん検出フック（posttooluse-tampering-detector.sh）**
  - Write/Edit 後に改ざんパターンを検出し、Claude に警告を通知
  - 操作はブロックせず、`additionalContext` で次のターンに警告を注入
  - 検出パターン:
    - `it.skip()` / `describe.skip()` / `test.skip()` 追加
    - `it.only()` / `describe.only()` 追加（他テスト無効化）
    - `eslint-disable` / `@ts-ignore` / `@ts-nocheck` 追加
    - アサーション（`expect()` / `assert`）の削除
    - lint/CI 設定ファイルの緩和（`continue-on-error: true` など）
  - `.claude/state/tampering.log` に検出履歴を記録
  - 第3層防御（Hooks）の実装として CLAUDE.md を更新

## [2.6.36] - 2026-01-05

### Added

- **クロスプラットフォームパス処理ユーティリティ（path-utils.sh）**
  - Windows（Git Bash/MSYS2/Cygwin/WSL）、macOS、Linux に対応
  - `detect_os()` - OS 検出とキャッシュ
  - `is_absolute_path()` - Windows ドライブレター（`C:/`）、UNC パス（`//server`）対応
  - `normalize_path()` - バックスラッシュ→スラッシュ変換、重複スラッシュ除去
  - `paths_equal()` - クロスプラットフォームパス比較
  - `is_path_under()` - 親子関係判定

### Changed

- **シェルスクリプトの I/O 最適化と堅牢性向上**
  - `analyze-project.sh`: ファイル読み込み最適化（12回→1回のキャッシュ）
  - `setup-existing-project.sh`: cd エラーハンドリング追加、sed エスケープ改善
  - `sync-plugin-cache.sh`: グローバル変数を関数パラメータに変更
  - `track-changes.sh`: mktemp エラーハンドリングと trap クリーンアップ追加

## [2.6.34] - 2026-01-05

### Changed

- **`/harness-update` コマンドの内容ベース更新検出**
  - バージョンが同一でもファイル内容が古い場合を検出（Step 2.5 追加）
  - `template-tracker.sh check` で内容レベルの更新をチェック
  - 更新対象リストベースの処理で全ファイル完了まで継続（Phase 2 Step 0）
  - 処理後の再検証で残りを検出、再試行/手動対応/スキップを選択可能（Phase 3 Step 1）
  - 進捗表示と完了レポートの改善

- **harness-ui MCP 設定を `/harness-ui-setup` 時のみ有効化**
  - `.mcp.json` をプラグインルートから `templates/mcp/harness-ui.mcp.json.template` に移動
  - `/harness-ui-setup` 実行時に MCP 設定を作成するステップ（Step 3.5）を追加
  - これにより、UI を使わないユーザーは MCP エラーに遭遇しなくなります

## [2.6.25] - 2025-01-04

### 🎯 あなたにとって何が変わるか

**`/plan-with-agent` コマンドにTDD採用判定と意図深掘り質問を追加。計画段階でテストケースを設計し、「動くけど違う」問題を防止します**

### Added

- **Step 5.5: TDD採用判定** - 6つの条件で自動判定
  - ビジネスロジック、データ変換、外部API、複数分岐、金銭/認証、曖昧な言葉
  - 条件に1つでも該当すればTDD採用

- **意図深掘り質問** - AskUserQuestion で必ず確認
  - 正常系: 一番よくある使われ方
  - 境界条件: ギリギリOK/NGの境目
  - エラー時: ユーザーへの見せ方
  - 暗黙の期待: 言語化されていないルール

- **暗黙知抽出テンプレート** - データ型別の追加質問
  - 数値: 0や負の値、小数点桁数
  - 日時: タイムゾーン、過去日許可
  - 文字列: 空文字、最大長、絵文字
  - リスト: 空リスト、上限、重複
  - 状態遷移: 戻れる、途中キャンセル、タイムアウト
  - ユーザー操作: 連打、途中離脱

- **Plans.md テンプレート更新** - テストケース設計テーブルを含む構造
  - 実装タスクの前にテストケースを明記
  - 正常系/境界/異常系/エッジケースの4分類

### Changed

- **マーカー判定ロジック強化**
  - `[feature:tdd]` マーカーは Step 5.5 通過必須
  - 「計算」「変換」「バリデーション」も TDD 対象に追加
  - 「決済」「金額」「課金」は security + TDD 両方適用

## [2.6.18] - 2025-12-30

### 🎯 あなたにとって何が変わるか

**Cursor × claude-mem 統合を公式実装に移行。ハーネス独自の `/cursor-mem` コマンドを廃止し、claude-mem v8.5.0+ の公式 Cursor サポートを使用します**

#### Before（v2.6.17）
- ハーネス独自の `/cursor-mem` コマンドでセットアップ
- `scripts/cursor-hooks/*.js` で記録処理
- 手動コンテキスト検索が必要

#### After（v2.6.18）
- **公式コマンド**: `bun run cursor:install` で一発セットアップ
- **自動コンテキスト注入**: `.cursor/rules/claude-mem-context.mdc` で自動
- **6種類のフック**: session-init, context-inject, save-observation, save-file-edit, session-summary
- **無料AI対応**: Gemini, OpenRouter サポート

### Removed

- **`/cursor-mem` コマンド**: `commands/optional/cursor-mem.md` を削除
  - 公式 `cursor:install` コマンドに移行
- **カスタムフックスクリプト**: `scripts/cursor-hooks/` を削除
  - `record-prompt.js`, `record-edit.js`, `record-stop.js`, `run-hook.sh`, `utils.js`
- **ドキュメント**: `docs/guides/cursor-mem-integration.md` を削除
- **テンプレート**: `.cursor/rules/claude-mem.md.template` を削除
- **サンプル**: `.cursor/hooks.json.example` を削除

### Changed

- **.gitignore**: 公式 Cursor フック用に更新
  - `/.cursor/hooks/` を追加（公式スクリプト）
  - `/.cursor/rules/claude-mem*.mdc` を追加（自動生成コンテキスト）

### Migration

claude-mem v8.5.0+ の公式 Cursor サポートを使用してください：

```bash
# リポジトリをクローン
git clone https://github.com/thedotmack/claude-mem.git
cd claude-mem
bun install

# Cursor フックをインストール
bun run cursor:install

# ステータス確認
bun run cursor:status
```

## [2.6.17] - 2025-12-30

### 🎯 あなたにとって何が変わるか

**Cursor Rules サポートを追加。Cursor 公式推奨の `.cursor/rules/` フォーマットで claude-mem 統合ルールを自動セットアップできます**

### Added

- **Cursor Rules 対応**: `/cursor-mem` コマンドで Cursor Rules を自動生成
  - **公式フォーマット**: `.cursor/rules/claude-mem.md` ([Cursor 公式ドキュメント](https://cursor.com/ja/docs/context/rules) 準拠)
  - **YAML frontmatter**: `description`, `alwaysApply` フィールドでメタデータ管理
  - **テンプレート方式**: `.cursor/rules/claude-mem.md.template` から自動コピー
  - **複数ルール対応**: 他の Rules ファイルと組み合わせ可能

- **セットアップスクリプト強化**: `scripts/setup-cursor-mem.sh`
  - Step 4 で Cursor Rules を自動生成
  - `.cursor/rules/` ディレクトリを自動作成
  - テンプレートからコピー処理を実装

- **検証スクリプト強化**: `scripts/validate-cursor-mem.sh`
  - Phase 5 で Cursor Rules を検証
  - テンプレートファイル存在確認
  - YAML frontmatter 構造チェック
  - `description`, `alwaysApply` フィールド検証

- **ドキュメント**: `commands/optional/cursor-mem.md`
  - Cursor Rules フォーマット説明セクション
  - 新フォーマットの特徴とメリット
  - バージョン管理ポリシー（テンプレート方式）

### Changed

- **.gitignore**: `.cursor/rules/` の管理方針を明確化
  - `.cursor/rules/claude-mem.md` を除外（ユーザー固有）
  - `.cursor/rules/*.template` を追跡（テンプレート）

## [2.6.16] - 2025-12-30

### 🎯 あなたにとって何が変わるか

**コマンドファイル編集時の SSOT（Single Source of Truth）ルールが明確化され、一貫性のあるコマンド開発が保証されます**

#### Before（v2.6.15）
- コマンドファイルのフォーマットが統一されていなかった
- `cursor-mem.md` に独自の `name:` フィールドが存在
- 命名規則やフォーマットルールが暗黙的

#### After（v2.6.16）
- **明文化されたルール**: `.claude/rules/command-editing.md` に全ルールを集約
- **標準フォーマット**: すべてのコマンドが `description` + `description-en` を使用
- **命名規則の明確化**: `harness-` プレフィックス、`{機能}-setup` パターン等を文書化
- **チェックリスト完備**: 編集時の確認項目を明示

### Added

- **コマンド編集ルール**: `.claude/rules/command-editing.md`
  - YAML frontmatter の標準フォーマット定義
  - ファイル命名規則（`harness-` プレフィックス、`{機能}-setup` パターン等）
  - 完全修飾名生成ルール（`{plugin}:{category}:{name}` 形式）
  - コマンドファイル構造テンプレート
  - 編集チェックリスト
  - 既知の例外の文書化（`harness-mem.md`）

### Changed

- **.gitignore**: `.claude/rules/` をバージョン管理対象に追加
  - ルールファイルは SSOT として Git で管理
  - プロジェクト全体で共有される基準

### Fixed

- **cursor-mem コマンド**: YAML frontmatter を標準フォーマットに修正
  - `name:` フィールドを削除（ファイル名から自動決定）
  - `description-en:` フィールドを追加
  - 他のコマンドと統一された形式に統一

### Benefits

- **一貫性保証**: すべてのコマンドが同じフォーマットに従う
- **新規コマンド作成が容易**: テンプレートとチェックリストを提供
- **SSOT 原則**: ルールが一箇所に集約され、メンテナンス性向上
- **プラグインシステム互換性**: 正しい完全修飾名が生成される

## [2.6.15] - 2025-12-30

### 🎯 あなたにとって何が変わるか

**Cursor でのタスク実行時に、claude-mem を自動的に活用するガイダンスが追加されました（レベル2：条件付き自動検索）**

#### Before（v2.6.14）
- セッション開始時のみ claude-mem を検索
- タスク実行中は手動で記録を検索する必要があった
- 過去の実装パターンや決定事項を見落とすリスク

#### After（v2.6.15）
- **タスクレベルのガイダンス**: 実装/バグ修正/レビュー時に自動で検索を推奨
- **条件付き検索**: 複雑なタスクのみ検索、単純な編集はスキップ
- **具体例付き**: クエリ例とワークフロー例を提供
- **パフォーマンス配慮**: 検索コストと価値のバランスを明記

### Added

- **タスクレベル検索ガイダンス**: `.cursorrules.example` に追加
  - **実装タスク**: 類似実装、アーキテクチャ決定、確立パターンを検索
    - 例: `query="[feature name] implementation", obs_type="feature"`
  - **バグ修正**: 関連バグ、過去の修正、根本原因分析を検索
    - 例: `query="[component] bug", obs_type="bugfix"`
  - **コードレビュー**: コーディング規約、過去のレビュー、品質ガイドラインを検索
    - 例: `query="code review", obs_type="decision"`
  - **単純な編集**: 検索をスキップ（タイポ修正、フォーマット、コメント更新）

- **検索戦略**: 効率的な検索のための4ステップガイド
  1. `get_recent_context` で最近の作業を確認
  2. タスク固有のキーワードで検索
  3. `obs_type` で観察タイプをフィルタ
  4. `limit=5-10` で結果を制限

- **ワークフロー例**: JWT認証実装時の検索フローを図示

- **パフォーマンス考慮事項**: 検索コストと価値のバランス、バッチ検索、キャッシング戦略

### Benefits

- **一貫性向上**: 過去の決定やパターンに従った実装が容易に
- **学習の再利用**: チーム内の知見を自動的に活用
- **バグ削減**: 過去の失敗から学び、同じミスを回避
- **効率化**: オーバーヘッドを最小限に抑えつつ、高価値な検索を実行
- **オプトイン**: 強制ではなくガイダンス形式で、柔軟に運用可能

## [2.6.14] - 2025-12-29

### 🎯 あなたにとって何が変わるか

**`/cursor-mem` コマンドが正式なハーネスコマンドとして確立され、セットアップの信頼性と再現性が大幅に向上しました**

#### Before（v2.6.13）
- セットアップの検証が手動で煩雑
- 設定の正確性を確認する方法が不明確
- ハーネスの他のコマンドとの連携が不明確

#### After（v2.6.14）
- **自動検証スクリプト**: `./scripts/validate-cursor-mem.sh` で全設定を一括チェック
- **SSOT 保証**: 検証スクリプトが設定の唯一の信頼できる情報源
- **ハーネス統合**: `/validate`, `/work`, `/sync-status` との連携が明確化
- **完全な再現性**: 冪等性、依存関係、バージョン管理が文書化

### Added

- **検証スクリプト**: `scripts/validate-cursor-mem.sh`
  - 7つのフェーズで包括的検証
    - Phase 1: Worker 起動確認
    - Phase 2: MCP 設定確認（グローバル/ローカル両対応）
    - Phase 3: フックスクリプト確認（存在 + 実行権限）
    - Phase 4: Hooks 設定確認（hooks.json の構造検証）
    - Phase 5: .cursorrules 確認
    - Phase 6: Claude-mem データベース確認（テーブル + 記録数）
    - Phase 7: ドキュメント確認
  - 色分けされた出力（✅ 成功、⚠️ 警告、❌ 失敗）
  - 詳細な検証結果サマリー
  - 問題発生時の修正方法を自動提示

### Changed

- **コマンドドキュメント**: `commands/optional/cursor-mem.md` を大幅強化
  - **セットアップ後の確認セクション**: 自動検証を推奨（SSOT として明記）
  - **ハーネスワークフローとの統合セクション**: 追加
    - セットアップフロー（/cursor-mem → validate-cursor-mem.sh → /validate）
    - 開発フロー（Cursor → claude-mem → Claude Code → Cursor のサイクル）
    - メモリ管理（claude-mem vs SSOT の使い分け）
  - **再現性の保証セクション**: 追加
    - 冪等性の保証（複数回実行しても安全）
    - 検証メカニズム（3段階のスクリプト）
    - バージョン管理（Git 管理対象の明確化）
    - 依存関係の明確化（Worker, DB, Node.js, Bash のバージョン要件）
  - **ハーネスコマンドセクション**: 関連コマンドへの参照を追加

- **検証スクリプトの修正**: `scripts/validate-cursor-mem.sh`
  - 算術展開のバグ修正（`((TOTAL_CHECKS++))` → `TOTAL_CHECKS=$((TOTAL_CHECKS + 1))`）
  - `set -e` 環境下での安全な動作を保証

### Fixed

- **Bash 算術展開の互換性問題**: `set -e` を使用時に `((var++))` がゼロ評価で終了する問題を修正

### Benefits

- **信頼性向上**: 全設定を自動検証し、問題を即座に検出
- **SSOT 確立**: 検証ロジックが一箇所に集約され、ドキュメントの重複を排除
- **再現性保証**: 冪等性と依存関係の明確化により、どの環境でも同じ結果
- **ハーネス統合**: 他のコマンドとの連携が明確になり、ワークフローが洗練
- **開発者体験向上**: 問題発生時の修正方法が自動提示され、トラブルシューティングが容易に

## [2.6.13] - 2025-12-27

### 🎯 あなたにとって何が変わるか

**Cursor での作業が自動的に claude-mem に記録され、Claude Code との間で作業履歴を完全に共有できるようになりました**

#### Before（v2.6.12）
- Cursor から claude-mem の記録を読み取ることは可能
- Cursor での作業は手動で記録する必要があった
- Claude Code ⇆ Cursor のデータ共有が片方向

#### After（v2.6.13）
- **Cursor での作業を自動記録**: プロンプト、ファイル編集、セッション完了
- **完全な双方向共有**: Claude Code ⇄ claude-mem ⇄ Cursor
- **ワンコマンドセットアップ**: `/cursor-mem` で全自動設定

### Added

- **Cursor Hooks 統合**: Cursor での作業を自動記録
  - `scripts/cursor-hooks/utils.js` - 共通ユーティリティ（Worker API 通信、プロジェクト検出、エラーハンドリング）
  - `scripts/cursor-hooks/record-prompt.js` - beforeSubmitPrompt フック（プロンプト記録）
  - `scripts/cursor-hooks/record-edit.js` - afterFileEdit フック（ファイル編集記録）
  - `scripts/cursor-hooks/record-stop.js` - stop フック（セッション完了記録）

- **設定テンプレート**:
  - `.cursor/hooks.json.example` - Cursor フック設定テンプレート
  - `.cursorrules.example` - セッション開始時の自動指示テンプレート

- **テストスイート**:
  - `tests/cursor-mem/test-plan.md` - 10個の詳細テストケース
    - TC1: プロジェクト検出テスト
    - TC2-4: 書き込みテスト（全フック）
    - TC5-6: 双方向読み取りテスト
    - TC7-8: エラーハンドリングテスト
    - TC9: パフォーマンステスト
    - TC10: 並行書き込みテスト
  - `tests/cursor-mem/verify-records.sh` - 記録検証スクリプト（統計表示、検索、詳細表示）

- **コマンド**:
  - `/cursor-mem` - Cursor × Claude-mem 統合のワンコマンドセットアップ
    - Worker 起動確認
    - MCP 設定スコープ選択（グローバル/ローカル）
    - hooks.json 自動生成
    - .cursorrules 自動生成
    - 動作確認テスト

- **セットアップスクリプト**:
  - `scripts/setup-cursor-mem.sh` - 対話的セットアップ（`--global`/`--local`/`--skip-test`/`--force` オプション対応）

### Changed

- **ドキュメント更新**:
  - `docs/guides/cursor-mem-integration.md` に「自動記録の設定」セクション追加
    - セットアップ手順（5ステップ）
    - 制限事項の明記（自動コンテキスト注入不可、カバレッジ 60-70%）
    - カバレッジ比較表
    - トラブルシューティング
  - `README.md` に「Cursor × Claude-mem 自動記録（v2.6.13）」セクション追加
  - `README.md` の `/cursor-mem` コマンドを知識・連携セクションに追加

- `.gitignore` の Cursor セクションを整理
  - `/.cursor/` （全体無視）→ `.cursor/hooks.json`（ユーザー固有）のみ無視に変更
  - `.cursor/hooks.json.example` をバージョン管理対象に

### Benefits

- **自動記録**: Cursor での全作業が claude-mem に自動保存（プロンプト、編集、完了）
- **双方向共有**: Claude Code と Cursor 間で作業履歴が完全に同期
- **2-Agent 強化**: PM（Cursor）と実装役（Claude Code）の連携が大幅改善
- **ワンコマンドセットアップ**: `/cursor-mem` で数十秒でセットアップ完了
- **厳格なテスト**: 10個のテストケースで品質保証

### Technical Details

**自動記録の仕組み**:
```
Cursor → Hooks → Worker API → claude-mem DB ← Claude Code
```

**記録内容**:
- UserPrompt: ユーザープロンプト + 添付ファイル
- Edit: ファイルパス + 編集内容（diff）
- SessionStop: セッション状態 + ループ回数

**エラーハンドリング**:
- Worker 未起動時も Cursor の動作をブロックしない
- 10秒タイムアウトでネットワークハングを防止
- グレースフルな失敗（stderr にエラー出力、Cursor は継続）

**プロジェクト検出**:
1. `workspace_roots[0]`（Cursor フックから取得）
2. `CLAUDE_MEM_PROJECT_CWD` 環境変数
3. `process.cwd()` フォールバック

### Fixed

- **Worker API "private" 判定問題を解決**:
  - 根本原因: セッション未初期化により全 observation が "private" でスキップされていた
  - 解決策: `record-prompt.js` で `/api/sessions/init` を呼び出してセッションを事前初期化
  - `utils.js` に `initSession()` 関数を追加（セッション作成 + プロンプト保存）
  - `utils.js` に `getProjectName()` 関数を追加（プロジェクト名抽出）
  - `recordObservation()` にレスポンスステータス確認を追加（"skipped" の検出）

- **Node.js v24 stdin 評価問題を wrapper スクリプトで解決**:
  - 問題: Node.js v24.10.0+ が stdin を TypeScript として評価し、JSON データで構文エラー
  - 影響: Cursor Hooks が `SyntaxError: Unexpected token ':'` で失敗
  - 解決策: `scripts/cursor-hooks/run-hook.sh` wrapper を作成して stdin を Node.js に直接渡す
  - `.cursor/hooks.json` をプロジェクトルートからの相対パスに修正（`../scripts/` → `scripts/`）
  - 動作確認: `exit code: 0` で正常完了、claude-mem に記録が保存される

- **ドキュメントの動作確認クエリを修正**:
  - 存在しない `tool_name` カラムへの参照を修正
  - 正しいスキーマ（`type`, `title`, `narrative`）を使用するように更新
  - 「自動記録の仕組み」セクションを追加（セッション初期化フローの説明）
  - Node.js v24 問題のトラブルシューティングセクションを追加

**技術詳細**:
- Worker API は `/api/sessions/observations` に送られた observation を "private" として拒否
- 原因: `user_prompts` テーブルに該当プロンプトが存在しないため
- 修正: beforeSubmitPrompt フックで事前に `/api/sessions/init` を呼び出し、プロンプトを登録
- 結果: 後続の observation が正常に記録されるようになった

**動作確認**:
```bash
# テスト実行結果
Session 15461, prompt #1 initialized ✅
Observation recorded: 10946-10951 ✅
  - 10946: discovery - Claude-Mem観測ツールの初期化
  - 10947: change - テストファイルの内容編集
  - 10948: change - セッション終了
```

### Limitations

- **自動コンテキスト注入不可**: Cursor の `beforeSubmitPrompt` フックがレスポンスを尊重しないため
- **エージェント応答は記録されない**: `afterAgentResponse` フックが存在しないため
- **カバレッジ**: Claude Code の 60-70% 程度（フック制限による）

## [2.6.12] - 2025-12-27

### Added

- **Cursor × Claude-mem MCP統合**: CursorからClaude-memにアクセス可能に
  - MCPラッパースクリプト (`scripts/claude-mem-mcp`)
    - ワーカー自動起動・ヘルスチェック
    - 最新バージョン動的検出
    - stdio モードでMCPサーバー実行
  - `cursor-mem` スキル追加 (`skills/cursor-mem/`)
    - Cursor Composerからclaude-memツールにアクセス
    - 検索・書き込み両対応
    - 日英トリガーワード対応
  - 統合ガイド (`docs/guides/cursor-mem-integration.md`)
  - 使用例集 (`skills/cursor-mem/examples.md`)
  - テスト手順書 (`TEST_CURSOR_INTEGRATION.md`)
  - `.cursor/mcp.json.example` サンプル提供

### Changed

- `commands/optional/harness-mem.md` にCursor統合セクション追加
- `.gitignore` に `.cursor/mcp.json` を追加

### Benefits

- **PM（Cursor）と実装（Claude Code）の役割分担**: 設計判断はCursorで記録、実装はClaude Codeが過去の判断を参照
- **双方向のデータ共有**: 同じメモリデータベースを共有（WALモードで並行書き込み対応）
- **クロスツール検索**: Cursorで記録した内容をClaude Codeで検索、その逆も可能

## [2.6.5] - 2025-12-26

### Added

- 英語版 README.en.md の追加
  - 日本語 README.md との言語切り替えナビゲーション

### Changed

- `/release` コマンドの改善
  - README.md の更新確認を必須化
  - GitHub Releases 作成ステップを追加

## [2.6.4] - 2025-12-26

### Changed

- README.md に品質判定ゲートシステム（v2.6.2）のドキュメントを追加

## [2.6.3] - 2025-12-26

### Changed

- `/release` コマンドに GitHub Releases 作成ステップを追加

## [2.6.2] - 2025-12-26

### 🎯 あなたにとって何が変わるか

**品質判定ゲートシステムが導入され、適切な場面で適切な品質基準（TDD/Security/a11y）が自動提案されるようになりました**

#### Before
- テスト改ざん防止（守り）のみ
- TDD/セキュリティ/a11y の提案がなかった
- 全タスクに同じ基準を適用

#### After
- タスク種別・ファイルパスに応じて品質基準を自動提案
- 強制ではなく提案（VibeCoder にも優しい）
- TDD/Security/a11y/Performance の4軸で判定

### Added

- 品質判定ゲートシステム（Phase 10）
  - `tdd-guidelines.md.template` - TDD 適用基準ルール
  - `security-guidelines.md.template` - セキュリティ注意パターン（OWASP Top 10 対応）
  - `quality-gates.md.template` - 総合判定マトリクス
- スキルに Step 0（品質判定ゲート）を追加
  - `impl`: TDD 推奨判定 + セキュリティチェック
  - `review`: カバレッジ/セキュリティ/a11y/パフォーマンス重点領域判定
  - `verify`: 再現テスト提案 + テスト vs 実装判定
  - `auth`: セキュリティチェックリスト自動表示
  - `ui`: a11y チェックリスト自動表示
  - `ci`: テスト改ざん防止（禁止パターン明示）
- `/plan-with-agent` に品質マーカー自動付与機能
  - 認証関連 → `[feature:security]`
  - UI → `[feature:a11y]`
  - ビジネスロジック → `[feature:tdd]`
  - バグ修正 → `[bugfix:reproduce-first]`
- `tdd-order-check.sh` PostToolUse Hook
  - TDD 推奨タスクで本体ファイルを先に編集 → 警告表示
  - ブロックはせず提案のみ
- VibeCoder 向け説明セクションを追加
  - `auth`, `review`, `ci` スキルに平易な説明を追加

### Changed

- スキルの Step 0 タイトルを「品質判定ゲート（〜）」形式に統一
- `tdd-order-check.sh` を macOS/Linux 両対応（jq 優先、sed フォールバック）

## [2.6.1] - 2025-12-25

### Added

- Skill 階層構造の自動リマインダー機能
  - `skill-child-reminder.sh` PostToolUse Hook
    - Skill ツール使用後に子スキル一覧を自動表示
    - 該当する doc.md の読み込みを促進
  - `skill-hierarchy.md` Rules テンプレート
    - セッション開始時に階層構造のガイドラインを提供
    - 親スキル → 子スキルの読み込みルールを明文化

### Changed

- `.claude-plugin/hooks.json` に Skill 用 PostToolUse Hook を追加

## [2.6.0] - 2025-12-25

### 🎯 あなたにとって何が変わるか

**Claude-mem を入れると、セッション跨ぎで「過去の学び」を活用できるようになりました**

#### Before
- 毎回ゼロからコンテキストを構築
- 同じミス（テスト改ざん等）を繰り返す可能性
- 過去のレビュー指摘・バグ修正パターンが引き継がれない

#### After
- `/harness-mem` で Claude-mem を統合
- 過去のガードレール発動履歴が表示される
- `impl`, `review`, `verify` スキルが過去の知見を自動参照
- 重要な観測は SSOT（decisions.md/patterns.md）に昇格可能

### Added

- `/harness-mem` コマンド - Claude-mem 統合セットアップ
  - インストール検出・インストール支援
  - 日本語化オプション
  - `harness` / `harness--ja` モードを自動設定
- `/sync-ssot-from-memory` コマンド - メモリから SSOT への昇格
  - Claude-mem と Serena 両対応
  - 重複防止のための観測ID追跡
- `memory-integration.md` Rules テンプレート
  - Claude-mem 有効時のスキル活用ガイド
- `harness.json` / `harness--ja.json` モードファイル
  - ハーネス特化の observation_types（10種）
  - ハーネス特化の observation_concepts（12種）
  - ユーザー意図（user-intent）の記録を強化
- Memory-Enhanced Skills 機能
  - `impl`: 過去の実装パターン・gotcha を自動参照
  - `review`: 過去の類似レビュー指摘を参照
  - `verify`: 過去のビルドエラー解決策・ガードレール履歴を参照
  - `session-init`: 過去のガードレール発動履歴・作業サマリーを表示

### Changed

- `skills-gate.md` に Memory-Enhanced Skills セクションを追加
- `template-registry.json` に `memory-integration.md` を登録

### Removed

- `/sync-ssot-from-serena` コマンド（`/sync-ssot-from-memory` に統合）

## [2.5.41] - 2025-12-25

### 🎯 あなたにとって何が変わるか

**Skills Gate が Rules + Hooks の2層構造になり、よりスムーズに動作するようになりました**

#### Before
- Skills Gate は Hook のみで強制（ブロックメッセージが毎回表示される可能性）
- ユーザーカスタムの Rules と ハーネス由来の Rules の区別がなかった

#### After
- **Rules（第1層）**: Claude が自発的に「スキルを使うべき」と認識
- **Hooks（第2層）**: 忘れた場合の最終防衛線としてのみ発動
- ユーザーカスタムの Rules は**自動保護**（上書きされない）

### Added

- `skills-gate.md` Rules テンプレートを追加
  - Skills Gate が有効な場合のみ自動展開
  - スキル使用の意義と使い方を Claude に認識させる
- Rules のマーカー + ハッシュ方式による管理
  - ハーネス由来: `_harness_template`, `_harness_version` で識別
  - ユーザーカスタム: マーカーなし → 自動保護
- 条件付きテンプレート機能
  - `template-registry.json` の `condition` フィールドで制御
  - 条件を満たす場合のみ展開・更新

### Changed

- `/harness-init`: Skills Gate 有効時のみ `skills-gate.md` を追加
- `/harness-update`: マーカー検出でユーザーカスタム Rules を保護
- Skills Gate の設計思想を明確化
  - Rules: ガイダンス・自発的行動誘導
  - Hooks: セキュリティ・最終防衛線

## [2.5.38] - 2025-12-24

### 🎯 あなたにとって何が変わるか

**`/harness-update` だけで、新しいスキルも自動的に追加されるようになりました**

#### Before
- プラグイン更新 (`/harness-update`) と Skills 設定更新 (`/skills-update`) は別々
- 新しいスキルが追加されても、既存プロジェクトには手動で追加が必要だった

#### After
- `/harness-update` 実行時に、新しいスキルを自動検出・提案
- 「yes」で一括追加、「選択」で個別選択が可能
- 削除されたスキルも検出して設定からクリーンアップ

### Added

- `/harness-update` に Skills 差分検出機能を統合
  - プラグイン側の利用可能スキル一覧を取得
  - プロジェクト側の `skills-config.json` と比較
  - 新規スキル・削除済みスキルを検出して提案

## [2.5.37] - 2025-12-24

### 🎯 あなたにとって何が変わるか

**壁打ちで話した内容を、そのまま計画にできるようになりました**

#### Before
- `/plan-with-agent` は受託開発向け（提案書が必須）
- 壁打ち後も最初からヒアリングをやり直す必要があった

#### After
- Step 0 で「今までの会話を踏まえる」を選択可能
- 会話から要件を自動抽出 → 確認 → 計画化
- 提案書はオプション（受託開発時のみ）

### Changed

- `/plan-with-agent` を汎用プラン構築コマンドに刷新
  - Step 0「会話コンテキスト確認」を追加
  - 受託開発特化から汎用ツールへ転換
  - ヒアリング文言を簡素化

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

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.44...HEAD
[2.6.44]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.37...v2.6.44
[2.6.36]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.34...v2.6.36
[2.6.34]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.33...v2.6.34
[2.6.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.4...v2.6.5
[2.6.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.3...v2.6.4
[2.6.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.2...v2.6.3
[2.6.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.1...v2.6.2
[2.6.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.41...v2.6.0
[2.5.41]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.37...v2.5.41
[2.5.37]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.35...v2.5.37
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
[2.6.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.6.0...v2.6.1
[2.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.5.41...v2.6.0
[2.0.0]: https://github.com/Chachamaru127/claude-code-harness/releases/tag/v2.0.0
