<!-- Generated from CLAUDE.md by build-opencode.js -->
<!-- codex compatible version of Claude Code Harness -->

# AGENTS.md - Codex harness 開発ガイド

このファイルは Codex CLI がこのリポジトリで作業する際の指針です。

## プロジェクト概要

**Harness** は、Codex CLI を「Plan → Work → Review」の型で運用するためのガイドです。

**特殊な点**: このプロジェクトは「ハーネス自身を使ってハーネスを改善する」自己参照的な構成です。

## Codex CLI の前提

- Codex は `${CODEX_HOME:-~/.codex}/skills/<skill-name>/SKILL.md`（ユーザーベース）と `.codex/skills/...`（プロジェクト上書き）を読み込み、`$skill-name` で明示呼び出しする
- Codex は `AGENTS.override.md` を優先し、次に `AGENTS.md`、必要なら設定された fallback 名を参照する
- Codex は hooks 対応済み（`PreToolUse` 等、`.codex/hooks.json`、`permissionDecision:"deny"` / exit 2 で事前ブロック可）。Harness は現状 hook 未配線で、暫定ガードは `.codex/rules/*.rules` の `prefix_rule()`
- **Install (0.134.0+)**: 公式 installer は GitHub release の `install.sh` (curl) と `install.ps1` (PowerShell)。Harness `setup-codex.sh` は skill/config コピーのみで CLI 本体はインストールしない
- **Profiles (0.134.0+)**: `--profile` が primary selector。legacy profile v1 config は拒否される。詳細: `docs/codex-permission-profiles-policy.md`

## Language

User-facing responses follow the explicit session or project language. If no
language is configured, use English. Use Japanese only when `i18n.language: ja`,
`CLAUDE_CODE_HARNESS_LANG=ja`, or an explicit session instruction requests
Japanese output.

## 開発ルール

### コミットメッセージ

[Conventional Commits](https://www.conventionalcommits.org/) に従う:

- `feat:` - 新機能
- `fix:` - バグ修正
- `docs:` - ドキュメント変更
- `refactor:` - リファクタリング
- `test:` - テスト追加/更新
- `chore:` - メンテナンス

### バージョン管理

バージョンは `VERSION` がソース・オブ・トゥルース。
通常の機能追加・docs 更新・CI 修正では `VERSION` と `.claude-plugin/plugin.json` を変更しない。
変更履歴は `CHANGELOG.md` の `[Unreleased]` に追記し、release を切るときだけ `./scripts/sync-version.sh bump` を使用する。

### CHANGELOG 記載ルール（必須）

**[Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) フォーマットに準拠**

各バージョンエントリには以下のセクションを使用:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- 新機能について

### Changed
- 既存機能の変更について

### Deprecated
- 間もなく削除される機能について

### Removed
- 削除された機能について

### Fixed
- バグ修正について

### Security
- 脆弱性に関する場合

#### Before/After（大きな変更時のみ）

| Before | After |
|--------|-------|
| 変更前の状態 | 変更後の状態 |
```

**セクション使い分け**:

| セクション | 使うとき |
|------------|----------|
| Added | 完全に新しい機能を追加したとき |
| Changed | 既存機能の動作や体験を変更したとき |
| Deprecated | 将来削除予定の機能を告知するとき |
| Removed | 機能やコマンドを削除したとき |
| Fixed | バグや不具合を修正したとき |
| Security | セキュリティ関連の修正をしたとき |

**Before/After テーブル**: 大きな体験変化（コマンド廃止・統合、ワークフロー変更、破壊的変更）があるときのみ追加。軽微な修正では省略可。

**バージョン比較リンク**: CHANGELOG.md 末尾に `[X.Y.Z]: https://github.com/.../compare/vPREV...vX.Y.Z` 形式で追加

### コードスタイル

- 明確で説明的な名前を使う
- 複雑なロジックにはコメントを追加
- コマンド/エージェント/スキルは単一責任に保つ

## リポジトリ構成

```
claude-code-harness/
├── codex/              # Codex CLI 配布物
├── commands/           # Claude Code 向けコマンド
├── agents/             # サブエージェント定義（Task tool で並列起動可能）
├── skills/             # エージェントスキル
├── scripts/            # シェルスクリプト（ガード、自動化）
├── templates/          # テンプレートファイル
├── docs/               # ドキュメント
└── tests/              # 検証スクリプト
```

## スキルの活用（重要）

### スキル評価フロー

> 💡 重いタスク（並列レビュー、CI修正ループ）では、スキルが `agents/` のサブエージェントを Task tool で並列起動します。

**作業を開始する前に、必ず以下のフローを実行すること:**

1. **評価**: 利用可能なスキルを確認し、今回の依頼に該当するものがあるか評価
2. **起動**: 該当するスキルがあれば、Skill ツールで起動してから作業開始
3. **実行**: スキルの手順に従って作業を進める

```
ユーザーの依頼
    ↓
スキルを評価（該当するものがあるか？）
    ↓
YES → Skill ツールで起動 → スキルの手順に従う
NO  → 通常の推論で対応
```

### スキルの階層構造

スキルは **親スキル（カテゴリ）** と **子スキル（具体的な機能）** の階層構造になっています。

```
skills/
├── impl/                  # 実装（機能追加、テスト作成）
├── harness-review/        # レビュー（品質、セキュリティ、パフォーマンス）
├── verify/                # 検証（ビルド、エラー復旧、修正適用）
├── setup/                 # セットアップ（CLAUDE.md、Plans.md生成）
├── 2agent/                # 2エージェント設定（PM連携、Cursor設定）
├── memory/                # メモリ管理（SSOT、decisions.md、patterns.md）
├── principles/            # 原則・ガイドライン（VibeCoder、差分編集）
├── auth/                  # 認証・決済（Clerk、Supabase、Stripe）
├── deploy/                # デプロイ（Vercel、Netlify、アナリティクス）
├── ui/                    # UI（コンポーネント、フィードバック）
├── handoff/               # ワークフロー（ハンドオフ、自動修正）
├── notebookLM/            # ドキュメント（NotebookLM、YAML）
├── ci/                    # CI/CD（失敗分析、テスト修正）
└── maintenance/           # メンテナンス（クリーンアップ）
```

**使い方:**
1. 親スキルを Skill ツールで起動
2. 親スキルがユーザーの意図に応じて適切な子スキル（doc.md）にルーティング
3. 子スキルの手順に従って作業実行

### 開発用スキル（非公開）

以下のスキルは開発・実験用であり、リポジトリには含まれません（.gitignore で除外）：

```
skills/
├── test-*/      # テスト用スキル
└── x-promo/     # X投稿作成スキル（開発用）
```

これらのスキルは個別の開発環境でのみ使用し、プラグイン配布には含めないこと。

### 主要スキルカテゴリ

| カテゴリ | 用途 | トリガー例 |
|---------|------|-----------|
| harness-plan | 計画、タスク分解、Plans.md 更新 | 「計画して」「タスク追加」「今どこ」 |
| harness-sync | 実装と Plans.md の同期 | 「進捗確認」「どこまで終わった」 |
| harness-work / breezing | 実装、並列実行、チーム実行 | 「実装して」「全部やって」「チームで進めて」 |
| harness-loop | 長時間の自律ループ実行、監視、停止 | 「長時間で回して」「loop で進めて」「止めて」 |
| harness-review | コードレビュー、品質チェック | 「レビューして」「セキュリティ」「パフォーマンス」 |
| harness-setup | プロジェクト初期化、Codex 配布更新 | 「セットアップ」「Codex設定」「初期化」 |
| 2agent | 2エージェント運用設定 | 「2-Agent」「Cursor設定」「PM連携」 |
| memory | SSOT管理、メモリ初期化 | 「SSOT」「decisions.md」「マージ」 |
| principles | 開発原則、ガイドライン | 「原則」「VibeCoder」「安全性」 |
| auth | 認証、決済機能 | 「ログイン」「Clerk」「Stripe」「決済」 |
| deploy | デプロイ、アナリティクス | 「デプロイ」「Vercel」「GA」 |
| ui | UIコンポーネント生成 | 「コンポーネント」「ヒーロー」「フォーム」 |
| handoff | ハンドオフ、自動修正 | 「ハンドオフ」「PMに報告」「自動修正」 |
| notebookLM | ドキュメント生成 | 「ドキュメント」「NotebookLM」「スライド」 |
| ci | CI/CD問題解決 | 「CIが落ちた」「テスト失敗」 |
| maintenance | ファイル整理 | 「整理して」「クリーンアップ」 |

## 開発フロー

1. **計画**: `$harness-plan` でタスクを Plans.md に落とす
2. **同期**: `$harness-sync` で現状と Plans.md のズレを確認する
3. **実装**: `$harness-work` または `$breezing` で Plans.md のタスクを実行
4. **長時間実行**: `$harness-loop` で 1 サイクルずつ自律実行
5. **レビュー**: `$harness-review` で品質チェック
6. **検証**: `./tests/validate-plugin.sh` で構造検証

## テスト方法

```bash
# プラグイン構造の検証
./tests/validate-plugin.sh
./scripts/ci/check-consistency.sh

# Codex CLI での確認（手動）
# - `${CODEX_HOME:-~/.codex}/skills` または `.codex/skills` が読み込まれること
# - `$harness-plan`, `$harness-sync`, `$harness-work`, `$breezing`, `$harness-review`, `$harness-loop` が認識されること
```

## 注意事項

- **自己参照に注意**: このリポジトリで `$harness-work` / `$breezing` を実行すると、自分自身のコードを編集することになる
- **Hooks**: Codex は hooks 対応済み（`PreToolUse` で事前ブロック可）。Harness は現状未配線で、暫定ガードは `.codex/rules/`
- **VERSION 同期**: 通常 PR では VERSION を触らず、release 時だけ更新
- **古い skill は退避される**: setup script は削除済み legacy Harness skill を `~/.codex/backups/` に移し、古いコマンドが残留しないようにする

## 主要コマンド（開発時に使用）

| コマンド | 用途 |
|---------|------|
| `$harness-plan` | 改善タスクを Plans.md に追加 |
| `$harness-sync` | 実装と Plans.md の状態を同期 |
| `$harness-work` | タスクを実装（必要に応じて並列化） |
| `$breezing` | Lead/Worker/Reviewer のチーム実行 |
| `$harness-loop` | Codex の長時間バックグラウンドループを開始 / 監視 / 停止 |
| `$harness-review` | 変更内容をレビュー |
| `$harness-setup codex` | Codex 配布物を更新し、古い skill を整理 |

### ハンドオフ

| コマンド | 用途 |
|---------|------|
| `$handoff-to-cursor` | Cursor 運用時の完了報告 |

**スキル（会話で自動起動）**:
- `handoff-to-impl` - 「実装役に渡して」→ PM → Impl への依頼
- `handoff-to-pm` - 「PMに完了報告」→ Impl → PM への完了報告

## SSOT（Single Source of Truth）

- `.claude/memory/decisions.md` - 決定事項（Why）
- `.claude/memory/patterns.md` - 再利用パターン（How）

## テスト改ざん防止（品質保証）

> 詳細: [D9: テスト改ざん防止の3層防御戦略](.claude/memory/decisions.md#d9-テスト改ざん防止の3層防御戦略)

Coding Agent がテスト失敗時に「楽をする」傾向（テスト改ざん、lint 緩和、形骸化実装）を防ぐための仕組みです。

### 3層防御戦略

| 層 | 仕組み | 強制力 |
|----|--------|--------|
| 第1層: Rules | `.codex/rules/harness.rules`（暫定） | 事前確認（prompt） |
| 第2層: Skills | `impl`, `verify` スキルに品質ガードレール内蔵 | 文脈的強制（スキル使用時） |
| 第3層: Hooks | Codex 対応済み・Harness 未配線（暫定は `.codex/rules/`） | 事前ブロック（配線後） |

### 禁止パターン

**テスト改ざん**:
- `it.skip()`, `test.skip()` への変更
- アサーションの削除・緩和
- eslint-disable コメントの追加

**形骸化実装**:
- テスト期待値のハードコード
- スタブ・モック・空実装
- 特定入力のみ動作するコード

### 困難な場合の対応フロー

```
1. 正直に報告（「この方法では実装が困難です」）
2. 理由を説明（技術的制約、前提条件の不備）
3. 選択肢を提示（代替案、段階的実装）
4. ユーザーの判断を仰ぐ
```

> ⚠️ **絶対にしてはいけないこと**: テストを改ざんして「成功」を偽装すること

<!-- sync-rules-to-agents: start -->

## Rules (from .claude/rules/)

> このセクションは `scripts/codex/sync-rules-to-agents.sh` によって自動生成されます。
> 直接編集しないでください。SSOT は `.claude/rules/` です。

| ルールファイル | 説明 |
|--------------|------|
| `active-watching-test-policy.md` | Active Watching Test Policy (pointer) |
| `autonomous-confirmation-scope.md` | Autonomous Confirmation Scope |
| `cc-update-policy.md` | CC アップデート追従ポリシー (pointer) |
| `claude-5-prompt-standard.md` | Claude 5 世代の agent prompt 監査基準（opus-4-7-prompt-audit.md の後継） |
| `codex-cli-only.md` | Codex Plugin Policy (pointer) |
| `commit-safety.md` | Commit Safety Rules |
| `cross-repo-handoff.md` | Cross-Repo Handoff Workflow (pointer) |
| `cursor-cli-only.md` | Cursor Execution Backend Policy (pointer) |
| `github-release.md` | GitHub Release Notes Rules (pointer) |
| `hooks-editing.md` | Rules for editing hook configuration (hooks.json) |
| `implementation-quality.md` | 実装品質ルール - 形骸化実装を禁止し、本質的な実装を促す |
| `migration-policy.md` | Migration Residue Policy (pointer) |
| `retired-alias-policy.md` | Retired Alias Policy (pointer) |
| `self-audit.md` | Self-Audit Rule |
| `shared-file-discipline.md` | Shared File Discipline |
| `shell-scripts.md` | Rules for editing shell scripts |
| `skill-editing.md` | "English description for auto-loading. Include trigger phrases." |
| `test-quality.md` | テスト品質保護ルール - テスト改ざんを禁止し、正しい実装を促す |
| `version-drift.md` | Version Drift Detection (pointer) |
| `versioning.md` | バージョニングルール (pointer) |
| `workflow-test-wiring.md` | Workflow Test Wiring Governance |

### active-watching-test-policy


<!-- 全文: .claude/rules/active-watching-test-policy.md -->

### autonomous-confirmation-scope


<!-- 全文: .claude/rules/autonomous-confirmation-scope.md -->

### cc-update-policy


<!-- 全文: .claude/rules/cc-update-policy.md -->

### claude-5-prompt-standard


# Claude 5 Prompt Standard

operator 承認: 2026-07-26（breezing 起動時の一括承認）。`.claude/rules/opus-4-7-prompt-audit.md`（Phase 44 / Opus 4.7 世代）の後継。

Claude 5 ガイダンス（2026-07）の要点は「例文の大量提示は探索空間を狭める」「ルールで縛るより判断に任せる」。旧基準の一部と衝突するため、契約（interface）条項だけ残し、書き方を縛る条項を撤廃した。

## 維持する規律（契約 = interface）

agent 間・agent-tool 間の**境界**を定義する条項は変えない。判断力の向上は「何を返すか」の契約を緩めない。

1. **出力 schema 名と列挙値は固定**: `worker-report.v1` / `advisor-request.v1` / `advisor-response.v1` / `review-result.v1` / `PLAN | CORRECTION | STOP` / `APPROVE | REQUEST_CHANGES` / `self_review[].rule`（既定 6: `dry-violation-none | plans-cc-markers-untouched | all-declared-symbols-called | dod-items-verified-with-evidence | no-existing-test-regression | tdd-red-evidence-attached`）/ `memory_updates[].scope`（`universal | task-specific`）
2. **回数上限は数字で書く**: 例「最大 3 回」「同じ原因の失敗が 2 回続いたら」。並列 worker 数の判定（1/2/3グループ）も同様
3. **Codex / Cursor 連携は wrapper command 経由のみ**: `bash scripts/codex-companion.sh task --write "..."` / `bash scripts/cursor-companion.sh task --write "..."`。raw `codex exec` / raw `cursor-agent` を標準手段にしない
4. **権限と責務境界は 1 行で判定できるようにする**: Lead だけが teammate を spawn する / Worker は `advisor-request.v1` を返し Advisor を直接 spawn しない / Reviewer は品質判定だけを行い実装しない
5. **effort は tier 指定、free-text marker 禁止**: `xhigh` は呼び出し側が選ぶ推論強度で、agent prompt が `ultrathink` 等から推測しない。`/ultrareview` は呼び出し側の entrypoint、agent 側の契約は `review-result.v1` のまま。`--auto-mode` は opt-in、既定値にしない

## 撤廃する規律(Claude 5 の判断に任せる)

1. **曖昧語 blanket 禁止の撤廃**: 「必要に応じて」「適宜」等 8 語を使うたび直後に条件補足を義務化する運用をやめる。文脈から妥当な範囲を判断できる
2. **行動指示ごとの逐語必須化の撤廃**: 「コマンド名 / パス / schema 名 / 数値閾値 / 真偽判定条件のいずれかを必ず含む」という全指示への一律適用をやめる。上記「維持する規律」に触れない判断は任せる
3. **例文の大量提示義務の撤廃**: before/after 例を多数記録・列挙する運用をやめる。例示は最小限(1 例)に留め、探索空間を狭めない

## 維持 / 撤廃 対比表

| 旧基準の項目 | 扱い |
|---|---|
| 出力 schema 名 + 列挙値の固定 | 維持 |
| 回数制御は数字で書く | 維持 |
| Codex wrapper command の完全一致 | 維持(Cursor も同列) |
| 2.1.111 運用ノブ(xhigh / `/ultrareview` / `--auto-mode`)分離 | 維持 |
| 権限と責務境界の 1 行判定 | 維持 |
| 並列 worker 数の数値条件 | 維持 |
| 行動指示への逐語要素(コマンド名等)の一律必須化 | 撤廃 |
| 曖昧語 8 語の使用時補足義務 | 撤廃 |
| before/after 例の大量記録義務 | 撤廃 |
| Phase 44 限定スコープ除外 | 撤廃(historical) |

## 関連

- `.claude/rules/workflow-test-wiring.md` — auditor 列挙値(`PASS | ADD_REQUIRED | APPEAL_REJECTED`)も「維持する規律 1」の対象
- `docs/effort-level-policy.md` / `docs/agent-view-policy.md` / `docs/ultrareview-policy.md` — 各運用ノブの詳細

<!-- 全文: .claude/rules/claude-5-prompt-standard.md -->

### codex-cli-only

> このルールは Claude Code 向けです。Codex 環境では適用しません。

<!-- 全文: .claude/rules/codex-cli-only.md -->

### commit-safety


<!-- 全文: .claude/rules/commit-safety.md -->

### cross-repo-handoff


<!-- 全文: .claude/rules/cross-repo-handoff.md -->

### cursor-cli-only


<!-- 全文: .claude/rules/cursor-cli-only.md -->

### github-release


<!-- 全文: .claude/rules/github-release.md -->

### hooks-editing


# Hooks Editing Rules

Rules applied when editing `hooks.json` files.

## Important: Dual hooks.json Sync (Required)

**Two hooks.json files exist and must always be in sync:**

```
hooks/hooks.json           ← Source file (for development)
.claude-plugin/hooks.json  ← For plugin distribution (sync required)
```

### Editing Flow

1. Edit `hooks/hooks.json`
2. Apply the same changes to `.claude-plugin/hooks.json`
3. Sync cache with `./scripts/sync-plugin-cache.sh`

```bash
# Always run after changes
./scripts/sync-plugin-cache.sh
```

## Hook Types

4 つのタイプが利用可能です: `command`（汎用）、`http`（外部連携）、`prompt`（LLM 単一判断）、`agent`（LLM エージェント判断）。後者2つは v2.1.63+ で全イベント対応。

> **CC v2.1.69+**: `InstructionsLoaded` イベント、`agent_id` / `agent_type` フィールド、`{"continue": false, "stopReason": "..."}` レスポンスが追加されました。
>
> **CC v2.1.76+**: `Elicitation`、`ElicitationResult`、`PostCompact` イベントが追加されました。
> MCP Elicitation はバックグラウンドエージェントでは UI 対話不能なため、フックで自動処理が必要です。
> PostCompact は PreCompact と対になり、コンパクション後のコンテキスト再注入に使用します。
>
> **CC v2.1.77+**: PreToolUse フックが `"allow"` を返しても、settings.json の `deny` ルールが優先されるようになりました。
> フック内で allow しても deny 設定があれば拒否されます。guardrail 設計時はこの優先順位に注意してください。
>
> **CC v2.1.78+**: `StopFailure` イベントが追加されました。API エラー（レート制限、認証失敗等）で
> セッション停止が失敗した際に発火します。エラーログと復旧処理に使用します。
>
> **CC v2.1.89+**: `PermissionDenied` イベントが追加されました。auto mode classifier がコマンドを拒否した際に発火します。
> `{retry: true}` を返すとモデルにリトライ可能であることを伝えられます。Breezing Worker の拒否追跡に使用。
>
> **CC v2.1.89+**: PreToolUse フックの `permissionDecision` に `"defer"` が追加されました。
> ヘッドレスセッション（`-p` モード）でフックが `"defer"` を返すとセッションが一時停止し、
> `claude -p --resume` で再開時にフックが再評価されます。Breezing Worker が判断困難な操作に遭遇した際の安全弁に活用できます。
>
> **CC v2.1.89+**: PreToolUse の `updatedInput` を `AskUserQuestion` と組み合わせると、
> ヘッドレスセッションが質問を外部 UI で収集して `permissionDecision: "allow"` と一緒に回答を注入できます。

<!-- 全文: .claude/rules/hooks-editing.md -->

### implementation-quality

## 絶対禁止事項

### 1. 形骸化実装（テストを通すだけの実装）

以下のパターンは**絶対に禁止**です：

| 禁止パターン | 例 | なぜダメか |
|------------|-----|-----------|
| ハードコード | テスト期待値をそのまま返す | 他の入力で動作しない |
| スタブ実装 | `return null`, `return []` | 機能していない |
| 決め打ち実装 | テストケースの値だけ対応 | 汎用性がない |
| コピペ実装 | テストの期待値辞書 | 意味のあるロジックがない |

### 禁止例：テスト期待値のハードコード

```python
# ❌ 絶対禁止
def slugify(text: str) -> str:
    answers_for_tests = {
        "HelloWorld": "hello-world",
        "Test Case": "test-case",
        "API Endpoint": "api-endpoint",
    }
    return answers_for_tests.get(text, "")
```

```python
# ✅ 正しい実装
def slugify(text: str) -> str:
    import re
    text = text.strip().lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text
```

### 2. 見かけだけの実装

```typescript
// ❌ 禁止：何もしていない
async function processData(data: Data[]): Promise<Result> {
  // TODO: implement later
  return {} as Result;
}

// ❌ 禁止：エラーを握りつぶす
async function fetchUser(id: string): Promise<User | null> {
  try {
    // ...
  } catch {
    return null; // エラーを隠蔽
  }
}
```

---

## 実装時のセルフチェック

実装を完了する前に、以下を確認してください：

<!-- 全文: .claude/rules/implementation-quality.md -->

### migration-policy


<!-- 全文: .claude/rules/migration-policy.md -->

### retired-alias-policy


<!-- 全文: .claude/rules/retired-alias-policy.md -->

### self-audit


<!-- 全文: .claude/rules/self-audit.md -->

### shared-file-discipline


<!-- 全文: .claude/rules/shared-file-discipline.md -->

### shell-scripts


# Shell Scripts Rules

Rules applied when editing shell scripts in the `scripts/` directory.

## Required Patterns

### 1. Header Format

```bash
#!/bin/bash
# script-name.sh
# One-line description of the script's purpose
#
# Usage: ./scripts/script-name.sh [arguments]

set -euo pipefail
```

### 2. JSON Output Format for Hook Scripts

Hook scripts (`*-hook.sh`, `stop-*.sh`, etc.) return results in JSON:

```bash
# On success
echo '{"decision": "approve", "reason": "explanation"}'

# On warning
echo '{"decision": "approve", "reason": "explanation", "systemMessage": "notification to user"}'

# On rejection
echo '{"decision": "deny", "reason": "reason"}'
```

### 3. Handling Environment Variables

```bash
# CLAUDE_PLUGIN_ROOT must always be verified
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  echo "Error: CLAUDE_PLUGIN_ROOT not set" >&2
  exit 1
fi

# PROJECT_ROOT fallback
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
```

## Prohibited

- ❌ Execution without `set -e`

<!-- 全文: .claude/rules/shell-scripts.md -->

### skill-editing

```

### 3. Available Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (matches directory name) |
| `description` | Yes | English description for auto-loading (include trigger phrases). Token-efficient. |
| `description-ja` | Recommended | Japanese description for i18n. Use `scripts/set-locale.sh ja` to swap into `description`. |
| `allowed-tools` | No | Tools the skill can use (allowlist — not a restriction list) |
| `disallowed-tools` | No | CC 2.1.152+: tools to remove from the model while the skill is active |
| `argument-hint` | No | Usage hint (e.g., `"[option1|option2]"`) |
| `disable-model-invocation` | No | Set `true` for dangerous operations |
| `user-invocable` | No | Set `false` for internal-only skills |
| `context` | No | `fork` for isolated context |
| `hooks` | No | Event hooks configuration |

### 4. File Size Guidelines

| Guideline | Recommendation |
|-----------|----------------|
| SKILL.md | 推奨 500 行以下 |
| Large content | Split into `references/` files |
| References | Use descriptive filenames |

> **Note (CC 2.1.32+)**: スキルの文字バジェットはコンテキスト窓の **2%** に自動スケールされます。
> 500 行はあくまで推奨値であり、実効上限はモデルのコンテキスト窓サイズに依存します。
> 大きなスキルファイルは自動的にトリミングされる可能性があるため、
> 重要な情報は SKILL.md の先頭付近に配置し、詳細は `references/` に分割してください。

### 5. Description Best Practices

The `description` field is critical for auto-loading. Include:
- What the skill does
- Trigger phrases (e.g., "Use when user mentions...")
- What NOT to load for (e.g., "Do NOT load for: ...")

**Good example**:
```yaml
description: "Manages CI/CD failures. Use when user mentions CI failures, build errors, or test failures. Do NOT load for: local builds or standard implementation."
```

## Client Mirror Contract (Phase 99.2)

`skills/` is the SSOT for shared skills; `skills-codex/` overrides Codex-only variants.
Mirrors are read-only distribution copies — never edit mirror roots directly:

| Mirror root | Source |
|-------------|--------|
| `codex/.codex/skills/` | `skills-codex/` when present, else `skills/` |

<!-- 全文: .claude/rules/skill-editing.md -->

### test-quality

## 絶対禁止事項

### 1. テスト改ざん（テストを通すための変更）

以下の行為は**絶対に禁止**です：

| 禁止パターン | 例 | 正しい対応 |
|------------|-----|-----------|
| テストを `skip` / `only` 化 | `it.skip(...)`, `describe.only(...)` | 実装を修正する |
| アサーションの削除・緩和 | `expect(x).toBe(y)` を削除 | 期待値が正しいか確認し、実装を修正 |
| 期待値の雑な書き換え | エラーに合わせて期待値を変更 | なぜテストが失敗しているか理解する |
| テストケースの削除 | 失敗するテストを消す | 実装が仕様を満たすよう修正 |
| モックの過剰使用 | 本来テストすべき部分をモック | 必要最小限のモックに留める |

### 2. 設定ファイル改ざん

以下のファイルの**緩和変更は禁止**です：

```
.eslintrc.*         # ルールを disable にしない
.prettierrc*        # フォーマットを緩めない
tsconfig.json       # strict を緩めない
biome.json          # lint ルールを無効化しない
.husky/**           # pre-commit フックを迂回しない
.github/workflows/** # CI チェックをスキップしない
```

### 3. 例外を設ける場合（必須手順）

やむを得ず上記を変更する場合は、**必ず以下の形式で承認を得てから**実行：

```markdown

<!-- 全文: .claude/rules/test-quality.md -->

### version-drift


<!-- 全文: .claude/rules/version-drift.md -->

### versioning


<!-- 全文: .claude/rules/versioning.md -->

### workflow-test-wiring


<!-- 全文: .claude/rules/workflow-test-wiring.md -->

<!-- sync-rules-to-agents: end -->

## North Star (3 層の野望)

- **L1 判断専念**: AI が plan / 実装 / 比較 / 検証を準備し、人間は最終判断のみ。
- **L2 ツール非依存**: 同一 Harness が Claude / Codex / Cursor のどれからでも効く。1 つの policy engine が 3 host を native hook で routing。2 つの向きを対等にサポート（#1 harness が駆動 / #2 host から使う）。
- **L3 協調（将来の本丸）**: 複数ツールが同一プロジェクトを、人間をコピペ係にせず協調。Mode 1 完全自律（v1 は Lead=Claude 固定）/ Mode 2 人間在席 peer co-drive。

正本: spec.md（Purpose / Execution Backend Contract / Mode 1・Mode 2）。

## Codex / Cursor hook の事実（誤解防止）

- **FACT-1**: Codex / Cursor は一級の hook ホスト。hook は config.toml に inline せず、`harness gen` が生成する `.codex/hooks.json` / `.cursor/hooks.json`（gitignore された build artifact）に入り、すべて `bin/harness hook pre-tool --host <h>` を呼ぶ。
- **FACT-2**: 「config.toml ships no inline hooks」≠「hook が無い」。混同しない。
- **FACT-3**: hook は 2 層。(a) enforcement（PreToolUse → R01-R13）は 3 host 対称に配線済み・生成可能。(b) Mode 2 delivery（inbox-check）は生成関数 `go/internal/hostgen.GenerateDeliveryHooksJSON` が実装+test 済みだが本番未配線（生成 hook に inbox-check は入らない）。Codex delivery は turn 境界（Stop）受信で、live monitor は Claude 専用。
- **FACT-4**: ホストが capability を欠くと断定する前に `harness gen` 出力を materialize して中身を確認する。not_observed != absent。

正本: spec.md「Codex/Cursor hook = generated, not inline (2-layer)」/ decisions.md D52 / patterns.md P36。
