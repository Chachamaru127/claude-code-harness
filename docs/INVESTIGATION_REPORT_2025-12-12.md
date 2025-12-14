# claude-code-harness 調査結果（2025-12-12）

**対象**: `claude-code-harness`（VibeCoder向け Claude Code プラグイン）  
**作成日**: 2025-12-12  
**参照（公式/最新）**:
- Claude Code Plugins 概要: `https://docs.claude.com/en/docs/claude-code/plugins`
- Plugins reference（マニフェスト/構造の仕様）: `https://code.claude.com/docs/en/plugins-reference`
- Slash commands（frontmatter等）: `https://code.claude.com/docs/en/slash-commands`
- Hooks 設定ガイド（ブログ）: `https://claude.com/ja-jp/blog/how-to-configure-hooks`
- Skills 解説（ブログ）: `https://claude.com/ja-jp/blog/skills-explained`
- 参考: Claude Code Plugins README: `https://github.com/anthropics/claude-code/blob/main/plugins/README.md`
- 参考: Claude Code CHANGELOG: `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md`

---

## 結論（要点）

このリポジトリは **VibeCoder向けに Plan→Work→Review を型化した“開発ハーネス型プラグイン”**として方向性が明確で、構造も概ねプラグインらしいです。一方で、**最新の Claude Code プラグイン仕様への適合（特に `.claude-plugin/plugin.json` と commands/agents frontmatter、hooks の stdin/イベント入力取り扱い）**に不確実性があり、ここが実運用の詰まりポイントになり得ます。

---

## リポジトリ構造（把握）

- **Commands**: `commands/*.md`（21個）
- **Skills**: `skills/**/SKILL.md`（31個）
- **Agents**: `agents/*.md`（6個）
- **Hooks**: `hooks/hooks.json` + `scripts/*.sh`
- **Workflows**: `workflows/default/*.yaml`（5本: init/plan/work/review/start-task）
- **Safety/Config**: `claude-code-harness.config.schema.json`（dry-run 等の安全制御）

---

## 観察した改善点（優先度順）

### 1) 互換性・仕様適合（最優先）

#### 1-1. `.claude-plugin/plugin.json` のスキーマ適合が怪しい
- 現状の `plugin.json` は、**コマンド一覧を `{name, description}` の配列で持つ**形式になっています。
- しかし最新の **Plugins reference** では、`commands` は基本的に **「コマンドファイル/ディレクトリのパス（string/array）」**として扱われ、標準の `commands/` ディレクトリは自動ロードされます（詳細は `https://code.claude.com/docs/en/plugins-reference`）。
- `author` も、最新例では object 形式（`{"name": ...}`）が示されています。

**影響**: Claude Code のバージョンによっては、プラグインの読み込み/表示/補完が不安定になるリスク。

#### 1-2. `commands/*.md` の frontmatter 不足
- 多くの `commands/*.md` が `---` frontmatter を持たず、`description` / `allowed-tools` 等が定義されていません。
- 最新の Slash commands ドキュメントでは、frontmatter は強く推奨され、特に `description` はコマンドの発見性に影響します（`https://code.claude.com/docs/en/slash-commands`）。

**影響**: `/help` や補完での体験が落ちる、モデル自動実行（SlashCommand tool）の対象になりにくい可能性。

#### 1-3. `agents/*.md` の frontmatter 不足
- Agents も frontmatter（description/capabilities 等）が薄い/欠けるものが多い。
- 最新仕様上の推奨フォーマットに寄せる余地があります（`https://code.claude.com/docs/en/plugins-reference`）。

---

### 2) UX（VibeCoderの詰まりどころ）

#### 2-1. 組み込みコマンドとの衝突リスク
- Claude Code には組み込み `init` や `review` が存在します（`https://code.claude.com/docs/en/slash-commands` の built-in list 参照）。
- 本プラグインは **`/harness-init` / `/harness-review` に改名して衝突回避**する方針が取りやすいです（旧名コマンドは廃止推奨）。

**影響**: 実装ガイドが組み込み `init` と区別できない書き方だと、ユーザーが意図と違うコマンドを実行して混乱する。

#### 2-2. README/ガイドと実体の不整合
- README のコマンド表にある `/setup-cursor` が、`commands/` に見当たらない等の整合問題が疑われます。

---

### 3) Hooks の実効性（自動化が効いていない可能性）

#### 3-1. PostToolUse で呼ばれるスクリプト群の stdin/引数設計が不一致
- `hooks/hooks.json` の PostToolUse は tool イベント情報を stdin で渡す想定ですが、スクリプト側が **引数でファイルパスを受け取る設計**のものがあり、現状だと no-op になりやすいです。
  - 例: `track-changes.sh`, `auto-test-runner.sh`, `plans-watcher.sh` は `$1/$2` を見ています
  - 例外: `auto-cleanup-hook.sh` は stdin JSON を `jq` で読んでいます（こちらは正方向）

**影響**: 「変更追跡」「テスト推奨」「Plans.md監視」などの看板機能が実際には動いていない/動作が環境依存になる。

---

### 4) バージョン/履歴の一貫性

- `VERSION` が `1.0.0`、`.claude-plugin/plugin.json` は `2.0.0`、`CHANGELOG.md` は `cursor-cc-plugins` の `0.5.x` 系という見え方で、**一貫性が崩れています**。

**影響**: 配布/更新/サポート時の説明が難しくなる（利用者が「どのバージョンを使っているか」判断しづらい）。

---

## 安全性（良い点）

- `claude-code-harness.config.schema.json` に `dry-run` / `apply-local` / `apply-and-push` があり、安全設計の思想が明文化されています。
- `scripts/` 内の grep では、危険な `rm -rf` / `sudo` / `git push` などの露骨な破壊的コマンドは見当たりませんでした（少なくとも現状確認範囲）。

---

## 採点（暫定）

**総合**: 65 / 100（B-）  
（強み: 設計思想・スキル数・ワークフロー体系 / 弱み: 最新仕様適合・衝突UX・hooks実効性・版管理整合）

---

## 他AIレポートとの比較（共有いただいた分）

### `mpz/REVIEW_REPORT_Comp.md`（85/100）との差分ポイント
共有いただいたレポートは、主に「構造が揃っている」「license/keywords 追加」「commands 同期」などの観点で高評価です。  
今回の調査ではそこに加えて、**最新の Plugins reference / Slash commands / Hooks の仕様に対して、manifest・frontmatter・hooks stdin の“動く確度”に不安がある**点を重めに見ています。

### 未共有（Opus/Gemini）
指定パスの Opus/Gemini レポートは、この環境では存在を確認できませんでした。  
もし別場所にある場合は、ファイルパスをご提示いただければ追記比較します。


