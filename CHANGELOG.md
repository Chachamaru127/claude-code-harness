# Changelog

claude-code-harness の変更履歴です。

> **📝 記載ルール**: このCHANGELOGは「ユーザー目線で何がどう変わったか」を記載します。
> - **Before/After** を明確に
> - 技術的な詳細より「使い方の変化」「体験の改善」を優先
> - 「あなたにとって何が嬉しいか」がわかるように
> - **参照元（Based on）**: Claude Code の公式機能を参照した場合はリンク付きで記載

---

## [2.5.9] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**LSP を使うための言語サーバー設定がより簡単に。`/lsp-setup` コマンドと `/harness-init` での自動チェックを追加。**

#### Before
- LSP を使いたいが、言語サーバーのインストール方法がわからなかった
- 既存プロジェクトに LSP 設定を追加する手順が不明確だった
- セットアップ時に LSP が使えるかどうか確認されなかった

#### After
- **`/lsp-setup`** コマンドで既存プロジェクトに LSP 設定を一括導入
- **`/harness-init`** で言語サーバーのインストール状況を自動チェック
- **言語別インストールコマンド**を `LSP_INTEGRATION.md` に追加
- **LSP vs Grep の使い分けガイド**で適切なツール選択が明確に

### VibeCoder 向けの使い方

| やりたいこと | 言い方 |
|-------------|--------|
| LSP を使えるようにしたい | 「`/lsp-setup`」 |
| 言語サーバーを確認 | 「LSP が使えるか確認して」 |

### 変更内容

#### 新規コマンド
- `/lsp-setup` - 既存プロジェクトへの LSP 設定導入（言語検出→サーバー確認→設定生成→動作確認）

#### コマンド更新
- `/harness-init` - Phase 3 に「Step 1.5: LSP 環境確認」を追加

#### ドキュメント更新
- `docs/LSP_INTEGRATION.md`:
  - 「言語サーバーのセットアップ（必須）」セクションを追加
  - 言語別インストールコマンド一覧を追加
  - 「LSP と Grep の使い分け」セクションを追加

---

## [2.5.8] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**Claude Code の LSP（Language Server Protocol）機能を全コマンド・スキルで活用できるように。コード理解・レビュー・リファクタリングの精度が大幅向上。**

#### Before
- コードの定義元や参照箇所を手動で検索していた
- 型エラーはビルド時にしか検出できなかった
- リネーム時に変更漏れが発生することがあった

#### After
- **Go-to-definition**: 関数やクラスの定義元へ即座にジャンプ
- **Find-references**: シンボルの使用箇所を一覧表示
- **LSP Diagnostics**: ビルド前に型エラー・警告を検出
- **LSP Rename**: シンボルを一括で安全にリネーム

### VibeCoder 向けの使い方

| やりたいこと | 言い方 |
|-------------|--------|
| 定義を見たい | 「この関数の定義はどこ？」 |
| 使用箇所を調べたい | 「この変数はどこで使われてる？」 |
| 名前を変えたい | 「`getData` を `fetchUserData` にリネームして」 |
| エラーをチェック | 「LSP診断を実行して」 |

### 変更内容

#### ドキュメント
- `docs/LSP_INTEGRATION.md` を新規追加（LSP活用ガイド）

#### コマンド（LSP活用セクションを追加）
- `/work` - 実装時のLSP活用（定義ジャンプ、診断）
- `/harness-review` - レビューでのLSP診断活用
- `/validate` - 検証フローにLSP診断を統合
- `/refactor` - LSP Rename による安全なリファクタリング
- `/ci-setup` - CI でのLSP診断活用

#### スキル（LSP活用セクションを追加）
- `impl` - 実装時のLSP活用
- `review` - レビューでのLSP活用
- `troubleshoot` - 問題解決でのLSP活用
- `verify` - 検証でのLSP活用
- `generate-claude-settings` - LSP設定の追加方法

#### 設定テンプレート
- `templates/claude/settings.security.json.template` に CCLSP（Claude Code LSP）MCPサーバー設定を追加

### 参照元（Based on）
- [Claude Code CLI v2.0.74](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) - LSP ツールの追加
- [CCLSP - Claude Code LSP Integration](https://github.com/ktnyt/cclsp) - MCP サーバー実装

---

## [2.5.7] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**`/harness-init` にセットアップ検証チェックリストを追加：2-Agent モードで Cursor コマンドが生成されない問題を防止。**

#### Before
- 2-Agent モードを選択したのに、`.cursor/commands/` ファイルが生成されないことがあった
- セットアップ完了後に Cursor を開いて、コマンドがないことに気づく
- 何が不足しているか分からず、手動で調査が必要だった

#### After
- **Phase 4: セットアップ検証**を追加 - 必須ファイルの自動チェック
- **視覚的なチェックリスト**（✅/❌）で不足ファイルを一目で確認
- **自動再生成**機能 - 不足ファイルを自動で生成して100%完了を保証
- **モード別検証** - Solo モード（7ファイル）/ 2-Agent モード（13ファイル）

### 変更内容
- `commands/core/harness-init.md` に Phase 4 を追加
- Solo モードと 2-Agent モードの必須ファイルチェックリストを定義
- 不足ファイルの自動検出と再生成ロジックを実装
- `.claude-code-harness-version` テンプレートに `setup_mode` フィールドを追加

---

## [2.5.6] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**`/harness-update` に破壊的変更の検出機能を追加：間違ったパーミッション構文や非推奨設定を自動修正。**

#### Before
- アップデート後も間違った設定（`"Bash(npm run *)"` など）が残ったまま
- 非推奨設定（`disableBypassPermissionsMode`）が削除されず、生産性が低下
- ユーザーが気づかない設定ミスが放置される

#### After
- **Phase 1.5: 破壊的変更の検出**を追加 - アップデート前に問題をスキャン
- **問題の可視化** - 間違った構文を diff 形式で表示（Before/After）
- **確認フロー** - 自動修正 / 個別確認 / スキップ / キャンセルを選択可能
- **自動修正** - sed/jq でパーミッション構文を置換、非推奨設定を削除

### 変更内容
- `commands/optional/harness-update.md` に Phase 1.5 を追加
- パーミッション構文の検出パターンを実装（スペース+`*`、コロンなし、など）
- `disableBypassPermissionsMode` の非推奨検出を追加
- `skills/setup/generate-claude-settings/doc.md` に破壊的変更の注記を追加

---

## [2.5.5] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**`/harness-update` コマンドを新設：既存プロジェクトを最新版に安全にアップデート。**

#### Before
- ハーネス導入済みプロジェクトを最新版に更新する方法がなかった
- `/harness-init` は新規プロジェクト向けで、既存プロジェクトには使いにくかった
- アップデート時に既存の設定やタスクが失われるリスクがあった

#### After
- **専用コマンド `/harness-update`** - 既存プロジェクト向けの安全なアップデート
- **バージョン自動検出** - `.claude-code-harness-version` で現在のバージョンを確認
- **自動バックアップ** - 更新前に `.claude-code-harness/backups/` にバックアップ
- **非破壊更新** - Plans.md のタスク、settings.json のカスタム設定を保持
- **選択的アップデート** - 特定のファイルだけ更新することも可能

### 変更内容
- `commands/optional/harness-update.md` を新規作成
- バージョン検出、バックアップ、マージ更新のフローを実装
- カスタム選択モードでファイル単位の更新に対応

---

## [2.5.4] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**パーミッション構文の明示的な例を追加：間違った settings.json が生成されるバグを修正。**

#### Before
- `generate-claude-settings` スキルで間違った構文（`"Bash(npm run *)"`）が生成されることがあった
- 正しい構文（`:*` vs `*`）が明示されておらず、Claude が間違えていた
- `disableBypassPermissionsMode` の扱いが曖昧だった

#### After
- **正しい構文と間違った構文の完全な例**を追加
- **構文ルールを明記** - プレフィックスマッチ（`Bash(command:*)`）、部分文字列マッチ（`Bash(:*substring:*)`）
- **重要セクションを追加** - スキル実行前に必ず確認する注意書き
- **3つのドキュメントを更新** - `generate-claude-settings`, `setup-2agent-files`, `harness-init`

### 変更内容
- `skills/setup/generate-claude-settings/doc.md` に正しい/間違った構文の例を追加
- `skills/2agent/setup-2agent-files/doc.md` の `disableBypassPermissionsMode` 説明を修正
- `commands/core/harness-init.md` にパーミッション構文の注意書きを追加

---

## [2.5.3] - 2025-12-20

### 🎯 あなたにとって何が変わるか

**スキル命名の統一：全 47 スキルから `ccp-` プレフィックスを削除し、シンプルで覚えやすい名前に。**

#### Before
- スキル名が `ccp-work-impl-feature`, `ccp-review-security` のように長かった
- `ccp-` プレフィックスの由来（Claude Code Plugin）が分かりにくく、意味がなかった
- 28 個のスキルディレクトリが `ccp-*` 形式で統一感がなかった

#### After
- **シンプルな命名**: `work-impl-feature`, `review-security` など直感的な名前に
- **47 件のスキル名を統一**: frontmatter `name:` から `ccp-` を削除
- **28 ディレクトリをリネーム**: `ccp-work-impl-feature/` → `work-impl-feature/`
- **回帰防止**: CI で `ccp-` 参照が戻らないことをチェック（9/9）

### 変更内容
- `skills/**/SKILL.md` の `name:` から `ccp-` プレフィックスを削除（7件）
- `skills/**/doc.md` の `name:` から `ccp-` プレフィックスを削除（40件）
- 28 個のスキルディレクトリをリネーム
- `workflows/default/*.yaml` の `skill:` 参照を新名称へ更新（4ファイル）
- `commands/**/*.md` のスキル参照を更新（7ファイル）
- `scripts/ci/check-consistency.sh` に ccp-* 廃止チェックを追加（9/9）
- `docs/design/adaptive-setup.md` の参照を更新

---

## [2.5.2] - 2025-12-19

### 🎯 あなたにとって何が変わるか

**スキルの自動起動精度が向上：21個のスキルが「WHEN + WHEN NOT」パターンに対応し、誤起動が減少。MCP ワイルドカード許可の設定例もドキュメント化。**

#### Before
- スキルの description が「何をするか」のみで、「何をしないか」が不明確だった
- MCP サーバーのツールを一括許可する方法がドキュメントになかった

#### After
- **全 21 スキルの description を統一**: `Use when...` + `Do NOT load for:...` パターンで誤起動を防止
- **MCP ワイルドカード例を追加**: `mcp__supabase__*` のような一括許可の設定方法をドキュメント化

### 変更内容
- `skills/*/SKILL.md` の description を「WHEN + WHEN NOT」パターンに更新（21ファイル）
- `skills/setup/ccp-generate-claude-settings/doc.md` に MCP ワイルドカード許可の説明を追加

### 参照元（Based on）
- [Young Leaders in Tech - Claude Code Skills](https://www.youngleadersintech.com/blog/claude-code-with-agent-skills) - "WHEN + WHEN NOT" description engineering パターン
- [Claude Code CLI v2.0.64](https://docs.anthropic.com/en/docs/claude-code) - `.claude/rules/` ディレクトリサポート

---

## [2.5.1] - 2025-12-19

### 🎯 あなたにとって何が変わるか

**bypassPermissions 前提の権限セットアップ：Edit/Write の確認を減らしつつ、危険操作は deny/ask で引き続きガード。**

#### Before
- `disableBypassPermissionsMode: "disable"` により bypassPermissions を有効化できないことがあった
- `permissions.ask` に `Edit` / `Write` が入っていると、編集のたびに確認が出て作業が止まりがちだった

#### After
- **bypassPermissions を許可**: `disableBypassPermissionsMode` をテンプレから撤去
- **プロジェクト限定で既定化**: `.claude/settings.local.json` のテンプレを追加（`defaultMode: "bypassPermissions"`）
- **回帰防止**: CI で bypassPermissions 前提運用が戻らないことをチェック（8/8）

### 変更内容
- `templates/claude/settings.security.json.template` から `disableBypassPermissionsMode` を撤去
- `templates/claude/settings.local.json.template` を追加（`defaultMode: "bypassPermissions"`）
- `commands/core/harness-init.md` と `skills/setup/ccp-generate-claude-settings/doc.md` を更新
- `scripts/ci/check-consistency.sh` に bypassPermissions 回帰チェックを追加（8/8）

### 参照元（Based on）
- [Claude Code 設定](https://code.claude.com/docs/ja/settings) - `permissions.defaultMode`, `disableBypassPermissionsMode`
- [IAM と権限の設定](https://code.claude.com/docs/ja/iam#configuring-permissions) - allow/ask/deny の優先順位

---

## [2.5.0] - 2025-12-19

### 🎯 あなたにとって何が変わるか

**SDD（Simple Development Discipline）アップグレード：Plans.md 中心のワークフローがさらに強化され、依存関係や並列実行の表現が可能に。**

#### Before
- `/start-task` と `/work` の2つのコマンドがあり、使い分けが必要だった
- Plans.md ではタスクの依存関係や並列可否を表現できなかった
- 仕様書類（proposal.md など）の配置場所がルートと `docs/` で混在
- constitution（開発原則）の設定がスキーマに定義されていなかった

#### After
- **`/start-task` 廃止**: `/work` に統合され、タスク開始から完了まで一貫したフロー
- **依存関係・並列記法**: Plans.md で `[depends:X]`, `[parallel:A,B]` などの拡張記法が使える
- **docs/ 統一**: `/plan-with-agent` の成果物が `docs/proposal.md`, `docs/technical-spec.md`, `docs/priority_matrix.md` に統一
- **constitution サポート**: `docs/constitution.md` で品質ゲート・DoD・原則を一元管理
- **回帰防止**: CI で `/start-task` 廃止と docs/ 正規化の回帰をチェック

### 変更内容

#### Phase 1: /start-task ワークフローの廃止
- `workflows/default/start-task.yaml` を削除
- プロファイル、テンプレート、スクリプトから start-task 参照を削除
- `/sync-status` → `/work` への統合完了

#### Phase 2: /work ワークフローの強化
- `workflows/default/work.yaml` に cc:WIP 自動遷移機能を追加
- `commands/core/work.md` にマーカー自動更新の説明を追加

#### Phase 3: Plans.md 管理機能の拡張
- `templates/Plans.md.template` に依存関係・並列記法を追加
- `templates/rules/plans-management.md.template` に拡張記法を追加
- `skills/plans-management/SKILL.md` に依存解析の視覚的例を追加

#### Phase 4: Constitution ファイルサポート
- `docs/constitution.md` の作成をサポート
- `claude-code-harness.config.schema.json` に `constitution` プロパティを追加
- 設定ファイルに i18n と constitution セクションを追加

#### Phase 5: 回帰防止チェックの強化
- `scripts/ci/check-consistency.sh` に以下を追加：
  - `/start-task` 廃止の回帰チェック（6/7）
  - docs/ 正規化チェック（7/7）- `technical-spec.md` も対象に追加

#### その他
- `commands/core/plan-with-agent.md` の成果物一覧を統一
- すべての検証テスト合格（35/35 plugin validation, 7/7 consistency checks）

### 参照元（Based on）
- [OpenSpec/spec-kit/cc-sdd](https://github.com/OpenSpec) - 依存関係・並列記法のコンセプト

---

## [2.4.1] - 2025-12-17

### 🎯 あなたにとって何が変わるか

**プラグイン名が「Claude harness」に変わりました。新しいロゴとヒーロー画像でブランドが一新。**

#### Before
- プラグイン名は「Claude Code Harness」
- ドキュメントやスクリプトに旧名称が混在

#### After
- **新名称「Claude harness」**: シンプルで覚えやすい名前に
- **新ロゴ・ヒーロー画像**: SVGロゴとPNGヒーロー画像を追加
- 全ドキュメントで名称を統一

### 変更内容
- plugin.json の name を `claude-harness` に変更
- README.md にロゴ・ヒーロー画像を設定
- 全ドキュメント（9ファイル）で名称を更新
- 旧ヒーロー画像（hero.png）を削除

---

## [2.4.0] - 2025-12-17

### 🎯 あなたにとって何が変わるか

**レビューやCI修正が並列実行で高速化。スキルがサブエージェントを自動起動します。**

#### Before
- `/harness-review` は4つの観点（セキュリティ/パフォーマンス/品質/アクセシビリティ）を順番にチェック
- 大規模なレビューは時間がかかる
- `agents/` のサブエージェント定義が活用されていなかった

#### After
- **並列レビュー**: 条件を満たす場合（観点>=2 & ファイル>=5）、Task tool で4つのサブエージェントを同時起動
- **CI修正の委譲**: 複雑なCI失敗は ci-cd-fixer サブエージェントに自動委譲
- **時間短縮**: 並列実行により最大75%の時間短縮（4観点のフルレビュー時）

### 変更内容
- CLAUDE.md にサブエージェント連携を追記（+2行のみ）
- `skills/review/SKILL.md` に並列サブエージェント起動ロジックを追加
- `skills/ci/SKILL.md` に ci-cd-fixer 連携を追加
- `commands/core/harness-review.md` の Task tool パターンを明確化

### 参照元（Based on）
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents) - Task tool による並列サブエージェント起動

---

## [2.3.4] - 2025-12-17

### 🎯 あなたにとって何が変わるか

**コード変更時にバージョンが自動で上がるようになりました。Windows でも動きます。**

#### Before
- コミット前に手動で `./scripts/sync-version.sh bump` を実行する必要があった
- 忘れると CI が失敗して二度手間

#### After
- **自動バージョンバンプ**: コード変更を含むコミット時に自動でパッチバージョンが上がる
- **Windows 対応**: Git for Windows があれば PowerShell/CMD からも動作
- バージョン忘れによる CI 失敗がなくなる

### 変更内容
- pre-commit フックのエンコーディング問題を修正（日本語→英語メッセージ）
- Windows 対応ドキュメントを `CONTRIBUTING.md` と `install-git-hooks.sh` に追加
- `./scripts/install-git-hooks.sh` で有効化

---

## [2.3.3] - 2025-12-17

### 🎯 あなたにとって何が変わるか

**スキルが目的別に整理されました。「何をしたいか」で見つけやすくなりました。**

#### Before
- スキルが `core/`, `optional/`, `worker/` に分散
- 「レビューしたい」→ どこにあるか分からない

#### After
- **14カテゴリに整理**: impl, review, verify, setup, 2agent, memory, principles, auth, deploy, ui, workflow, docs, ci, maintenance
- **目的で選べる**: 「レビューして」→ `review` カテゴリ、「デプロイして」→ `deploy` カテゴリ

### 変更内容
- スキルを目的別カテゴリに再編成（52ファイル変更）
- CLAUDE.md にスキルカテゴリ表を追加
- 旧カテゴリ（core, optional, worker）を削除

### 謝辞
- 階層型スキル構造のアイデア: [AIまさお氏](https://note.com/masa_wunder) のフィードバックに基づいて実装

---

## [2.3.2] - 2025-12-16

### 🎯 あなたにとって何が変わるか

**スキルがより確実に起動するようになりました。**

#### Before
- スキルの説明が曖昧で、意図しないスキルが起動することがあった

#### After
- **明確なトリガー語**: 各スキルに排他的なキーワードを設定
- **評価フロー**: 作業前に該当スキルがあるか自動評価

### 変更内容
- 全スキルの description を強化（トリガー語を明示）
- CLAUDE.md にスキル評価フローを追加

---

## [2.3.1] - 2025-12-16

### 🎯 あなたにとって何が変わるか

**日本語/英語を選べるようになりました。公式リポジトリへのPR提出が可能になります。**

#### Before
- コマンド説明が日本語のみ
- 英語ユーザーには使いづらい

#### After
- `/harness-init` で言語選択（JA/EN）
- 全16コマンドに英語説明を追加（`description-en`）
- 設定ファイルで `i18n.language` を指定可能

### 変更内容
- `/harness-init` に言語選択ステップを追加
- 全16コマンドに `description-en` フィールドを追加
- 設定スキーマに `i18n.language` オプションを追加
- 翻訳検証スクリプト `scripts/i18n/check-translations.sh` を追加
- ライセンスをMITに変更（公式リポジトリ貢献のため）

---

## [2.3.0] - 2025-12-16

### 🎯 あなたにとって何が変わるか

**ライセンスがMITに戻りました。公式リポジトリへの貢献が可能になります。**

#### Before (Proprietary License - v2.2.0)
- 再配布・販売が禁止
- 公式リポジトリへのPR提出が不可

#### After (MIT License)
- **配布・再配布が自由**: fork、PR、パッケージ化が可能
- **公式リポジトリへの貢献が可能**: Anthropic公式プラグインへのPR提出OK
- **使い方は変わらず**: 個人利用・商用利用・改変は引き続き自由

### 変更内容
- ライセンスを独自ライセンスからMITに変更
- LICENSE.md、LICENSE.ja.md を標準的なMITライセンス文に更新
- README.md のライセンスセクションを簡素化

---

## [2.2.1] - 2025-12-16

### 🎯 あなたにとって何が変わるか

**エージェントがより賢く動くようになりました。**

#### Before
- エージェントが何のツールを使えるか不明確
- 複数エージェントを並列実行しても見分けがつかない
- スキルの情報が1ファイルに詰め込まれ、トークン消費が非効率

#### After
- 各エージェントが使えるツールが明示され、適切なツールのみ使用
- エージェントに色（color）がつき、並列実行時に識別しやすい
- スキルが階層化され、必要な情報だけ読み込むため高速化

### 変更内容

#### エージェント定義の公式形式準拠（6ファイル）

```yaml
# Before
---
description: ...
capabilities: [...]
---

# After
---
name: code-reviewer
description: ...
tools: [Read, Grep, Glob, Bash]
model: sonnet
color: blue
---
```

| エージェント | 役割 | color |
|-------------|------|-------|
| code-reviewer | コードレビュー | 🔵 blue |
| ci-cd-fixer | CI修正 | 🟠 orange |
| error-recovery | エラー復旧 | 🔴 red |
| project-analyzer | プロジェクト分析 | 🟢 green |
| project-scaffolder | プロジェクト生成 | 🟣 purple |
| project-state-updater | 状態管理 | 🔵 cyan |

#### スキルのProgressive Disclosure構造化

```
# Before
skills/plans-management/
└── SKILL.md   # 全情報が1ファイル

# After
skills/plans-management/
├── SKILL.md              # コア情報のみ
├── references/
│   └── markers.md        # 詳細仕様（必要時のみ読込）
└── examples/
    └── task-lifecycle.md # 実例（必要時のみ読込）
```

**対象スキル**: plans-management, workflow-guide

---

## [2.2.0] - 2025-12-15

### 🎯 あなたにとって何が変わるか

**ライセンスが変わりました（使い方は変わりません）。**

#### Before (MIT License)
- 誰でも自由に再配布・販売可能
- 類似サービスを作って販売可能

#### After (Proprietary License)
- **あなたの使い方は変わりません**: 個人利用・商用利用・改変・AI利用は引き続き自由
- **禁止されること**: 再配布・販売・類似サービスの提供

### 変更内容
- ライセンスを MIT から独自ライセンスに変更
- LICENSE.md（英語）、LICENSE.ja.md（日本語）を追加
- README.md にライセンス説明セクションを追加（日英バイリンガル対応）

---

## [2.1.2] - 2025-12-15

### 🎯 あなたにとって何が変わるか

**`/work` だけで並列実行できるようになりました。**

#### Before
- 通常のタスク実行: `/work`
- 並列実行したい時: `/parallel-tasks`（別コマンド）

#### After
- **すべて `/work` でOK**: 独立したタスクが複数あれば自動で並列実行
- コマンドを覚える必要が減った（17 → 16コマンド）

### 変更内容
- `/parallel-tasks` を `/work` に統合
- `/work` が自動で依存関係を分析し、並列/直列を判断

---

## [2.1.1] - 2025-12-15

### 🎯 あなたにとって何が変わるか

**コマンドを覚える必要が大幅に減りました。**

#### Before
- 27個のコマンドを覚える必要があった
- `/analytics`, `/auth`, `/deploy-setup` など個別コマンドを実行

#### After
- **16個のコマンドだけ**でOK
- 残りは「認証を追加して」「デプロイ設定して」と**会話するだけ**で自動起動（スキル化）

### 変更内容
- コマンド数: 27個 → 17個に削減
- `/plan` → `/plan-with-agent` に名称変更
- `/skill-list` でスキル一覧を確認可能に
- 以下がスキル化（会話で自動起動）:
  - `/analytics`, `/auth`, `/auto-fix`, `/deploy-setup` など

---

## [2.0.9] - 2025-12-14

### Added
- 仕様書/運用ドキュメント（Plans/AGENTS/Rules）を最新運用（PM↔Impl, pm:*）へ同期する `/sync-project-specs` を追加

---

## [2.0.8] - 2025-12-14

### Changed
- PM/Impl ハンドオフ運用で Plans.md のマーカー更新を忘れにくくするため、ハンドオフ2コマンドにチェックリストを追加
- Stop hook で Plans.md の更新漏れを検知して日本語リマインドを表示（変更があった場合のみ）

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
