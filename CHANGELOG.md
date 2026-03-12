# Changelog

Change history for claude-code-harness.

> **📝 Writing Guidelines**: Focus on user-facing changes. Keep internal fixes brief.

## [Unreleased]

---

## [3.10.1] - 2026-03-12

### テーマ: Claude Code 公式ドキュメント深層統合 — 12 機能追加 + Auto Mode 既定化 + SubagentStart/Stop matcher 強化

**公式ドキュメント 60 ページの精査により発見した未追跡機能 12 項目を Feature Table に追加。Breezing の teammate 実行では Auto Mode を既定化しつつ、SubagentStart/SubagentStop hooks に agent type 別 matcher を追加して Worker/Reviewer/Scaffolder/Video Generator の起動・停止を個別にトラッキング可能に。**

---

#### 1. SubagentStart/SubagentStop matcher 強化

**今まで**: `SubagentStart`/`SubagentStop` hooks は全エージェント一律で `subagent-tracker` を起動。team-composition.md では「SubagentStart: 未実装」と誤記載。

**今後**: agent type 別の matcher（`worker`, `reviewer`, `scaffolder`, `video-scene-generator`）を追加。各エージェントの起動・停止を個別にトラッキングし、ロール別のメトリクス収集を可能に。team-composition.md の Quality Gate Hooks テーブルも実態に合わせて更新。

#### 2. Feature Table に 12 機能追加

**今まで**: Chrome Integration, LSP サーバー統合, Task Dependencies, `/btw`, Plugin CLI コマンド群等の公式ドキュメント記載機能が Feature Table に未登録。

**今後**: 以下を Feature Table（概要テーブル + 機能詳細セクション）に追加:
- Chrome Integration (`--chrome`, beta)
- LSP サーバー統合 (`.lsp.json`)
- SubagentStart/SubagentStop matcher
- Agent Teams: Task Dependencies
- `--teammate-mode` CLI フラグ
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
- `cleanupPeriodDays` 設定
- `/btw` サイドクエスチョン
- Plugin CLI コマンド群
- Remote Control 強化
- `skills` フィールド in agent frontmatter

#### 3. CLAUDE.md Feature Table サマリー更新

**今まで**: CLAUDE.md の要約テーブルに Chrome Integration, LSP, matcher, Task Dependencies 等が含まれていなかった。

**今後**: 最もインパクトの大きい 6 機能を CLAUDE.md の要約テーブルに追加。

#### 4. Breezing の Auto Mode を既定化

**今まで**: Auto Mode は `--auto-mode` 指定時だけ有効化する段階移行扱いで、Breezing の既定値は `bypassPermissions` 前提だった。

**今後**: `/breezing` と `/harness-work --breezing` は teammate 実行時に Auto Mode を既定で有効化する。`--auto-mode` は後方互換の明示再指定として維持し、project template / frontmatter には公式 docs に載っている `bypassPermissions` を残す。

---

## [3.10.0] - 2026-03-11

### テーマ: Claude Code ドキュメント機能 10 項目の Harness 統合 + Status Line 実装

**Claude Code の公式ドキュメントに記載された新機能（Sandboxing, Model Configuration, Checkpointing, Code Review, Status Line 等）を Feature Table に統合し、Harness 専用ステータスラインスクリプトを新規追加。**

---

#### 1. Sandboxing (`/sandbox`) 統合

**今まで**: Worker の Bash コマンドは `bypassPermissions` + hooks で制御していた。OS レベルのファイルシステム/ネットワーク隔離は Harness の運用ガイドに含まれていなかった。

**今後**: Claude Code のネイティブ Sandboxing（macOS Seatbelt / Linux bubblewrap）を `bypassPermissions` の**補完レイヤー**として位置づけ。段階導入計画（Phase 0→1→2）を `team-composition.md` に追加。Worker の Bash に OS レベルの安全境界を段階的に導入する方針。

#### 2. Model Configuration 3 機能

**今まで**: Worker/Reviewer のモデルはエージェント定義の `model: sonnet` で固定。Lead も単一モデルで Plan と Execute を実行していた。

**今後**:
- **`opusplan` エイリアス**: Lead セッションで Plan 時に Opus、Execute 時に Sonnet を自動切替
- **`CLAUDE_CODE_SUBAGENT_MODEL`**: 全サブエージェントのモデルを環境変数で一括指定（CI でのコスト削減に有用）
- **`availableModels`**: エンタープライズ環境でのモデルガバナンス

#### 3. Checkpointing (`/rewind`) 対応

**今まで**: セッション中にファイル編集が期待通りでなかった場合、手動で git revert するか、最初からやり直す必要があった。

**今後**: `Esc+Esc` または `/rewind` でセッション内の任意のポイントに巻き戻し可能。「ここから要約」で冗長なデバッグセッションのコンテキスト窓を選択的に回収。`harness-work` のセルフレビューフェーズでの安全な探索に活用。

#### 4. Code Review (managed service) 対応

**今まで**: Harness の `harness-review` はローカルエージェントによるコードレビューのみ。

**今後**: Anthropic インフラ上のマルチエージェント PR レビュー（Teams/Enterprise 向け Research Preview）を Feature Table に追加。`REVIEW.md` によるレビュー固有ガイダンスの仕組みを文書化。ローカルレビュー（`harness-review`）と managed レビューは補完的な二重検査として位置づけ。

#### 5. Harness Status Line スクリプト新規追加

**今まで**: Claude Code の `/statusline` 機能は存在していたが、Harness 固有のステータス表示がなかった。

**今後**: `scripts/statusline-harness.sh` を新規追加。以下を 2 行で常時表示:
- Line 1: モデル名 + git ブランチ + staged/modified ファイル数 + エージェント名/ワークツリー名
- Line 2: コンテキスト使用率バー（70% 黄、90% 赤）+ セッションコスト + 経過時間 + 出力スタイル名

```bash
# 設定方法
/statusline use scripts/statusline-harness.sh
```

#### 6. Feature Table 拡充（10 項目追加）

`docs/CLAUDE-feature-table.md` と `CLAUDE.md` サマリーに以下を追加:
- Sandboxing (`/sandbox`)
- `opusplan` モデルエイリアス
- `CLAUDE_CODE_SUBAGENT_MODEL` 環境変数
- `availableModels` 設定
- Checkpointing (`/rewind`)
- Code Review (managed service)
- Status Line (`/statusline`)
- 1M Context Window (`sonnet[1m]`)
- Per-model Prompt Caching Control
- `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

---

## [3.9.0] - 2026-03-11

### テーマ: Output Styles 統合 + Agent 定義強化 + Agent Teams 公式ベストプラクティス整合

**Claude Code 公式ドキュメントの Output Styles / Agent Teams / エージェント frontmatter の最新仕様を Harness に反映し、運用体験を向上。**

> **Release note**: 下書きとして積み上がっていた `v3.7.3` / `v3.8.0` 相当の変更は、この `v3.9.0` 正式リリースに統合した。

---

#### 1. Harness Output Style 新規追加

**今まで**: Plan/Work/Review の進捗報告や Quality Gate 結果のフォーマットが統一されておらず、各スキル・エージェントが独自の出力形式で報告していた。

**今後**: `.claude/output-styles/harness-ops.md` を新設。`/output-style harness-ops` で有効化すると、以下が構造化されて出力される:
- 進捗報告（実施/現在地/次アクション形式）
- Quality Gate 結果（Build/Test/Lint の表形式）
- Review 判定（APPROVE/REQUEST_CHANGES の構造化フォーマット）
- エスカレーション（3回ルール違反時の標準出力形式）
- 判断ポイント（最大3選択肢、推奨先頭）

```bash
/output-style harness-ops
```

#### 2. エージェント定義に `permissionMode` を明示追加

**今まで**: Worker/Reviewer/Scaffolder の権限モードは spawn 時に `mode: "bypassPermissions"` として指定。エージェント定義自体には権限情報がなく、Lead の spawn コードに依存していた。

**今後**: Claude Code 公式ドキュメントで `permissionMode` がエージェント frontmatter の正式フィールドとして文書化されたことを受け、3エージェント全ての frontmatter に `permissionMode: bypassPermissions` を追加。定義レベルでの宣言的権限管理を実現。

```yaml
# agents-v3/worker.md
permissionMode: bypassPermissions  # 新規追加
```

#### 3. Agent Teams 公式ベストプラクティス整合

**今まで**: Harness のチーム運用は独自のパターンに基づいていた。Claude Code の Agent Teams は「実験的」というステータスのみで、公式ガイダンスが限定的だった。

**今後**: `agent-teams.md` が独立した公式ドキュメントに昇格。`agents-v3/team-composition.md` に以下を反映:
- **タスク粒度ガイドライン**: 5-6 tasks/teammate の公式推奨値
- **`teammateMode` 設定**: `"auto"` / `"in-process"` / `"tmux"` の3モード
- **Plan Approval パターン**: Worker に plan mode を要求する公式フロー
- **Quality Gate Hooks**: `TeammateIdle`/`TaskCompleted` の exit 2 フィードバックパターン
- **チームサイズ**: 3-5 teammates の公式推奨（Harness の Worker 1-3 + Reviewer 1 と整合確認）

#### 4. Feature Table 拡充（3項目追加）

`docs/CLAUDE-feature-table.md` に以下を追加:
- Output Styles 統合
- `permissionMode` in agent frontmatter
- Agent Teams 公式ベストプラクティス整合

#### 5. Pre-merge 整合修正

**今まで**: README のバージョンバッジ、compare link、Auto Mode の段階表記、`validate-plugin` の core dependency step、opencode mirror が一部不整合で、required checks を安定して通せない状態だった。

**今後**: 版表記と compare link を同期し、Auto Mode は「staged rollout / RP 開始後に検証」へ表現を是正。`validate-plugin` は `core/package.json` をキャッシュキーにして `npm install` を使う構成へ修正し、opencode mirror も再生成前提で整える。

---

### Included: Claude Code v2.1.72 互換対応

**Claude Code v2.1.72 の全新機能・修正を Harness に反映。Effort レベル簡素化、ExitWorktree ツール、Agent tool model パラメータ復活、並列ツール呼び出し修正など、12 項目の機能を Feature Table とエージェント定義に追記。**

---

#### 1. ExitWorktree ツール対応

**今まで**: worktree セッションからの離脱はセッション終了時のプロンプトに依存。Worker エージェントが実装完了後にプログラム的に worktree を閉じる手段がなかった。

**今後**: CC v2.1.72 の `ExitWorktree` ツールにより、Worker が実装完了後に明示的に worktree を離脱可能。`agents-v3/worker.md` に「Worktree 操作」セクションを追加し、`ExitWorktree` の活用方法を文書化。

#### 2. Effort レベル簡素化（`max` 廃止）

**今まで**: effort レベルに `max` が存在していたが、Harness のドキュメントでは `ultrathink` → high effort の対応のみ使用。

**今後**: CC v2.1.72 で `max` が廃止、3段階 `low(○)/medium(◐)/high(●)` に統一。Harness のドキュメントをシンボル付きで更新。影響ファイル:
- `skills-v3/harness-work/SKILL.md` + 3 ミラー
- `agents-v3/worker.md`
- `agents-v3/reviewer.md`
- `agents-v3/team-composition.md`

#### 3. Agent tool `model` パラメータ復活

**今まで**: per-invocation model override が利用不可だった期間があり、エージェント定義の `model` フィールドのみで運用。

**今後**: CC v2.1.72 で Agent tool の `model` パラメータが復活。タスク特性に応じた動的モデル選択が再び可能に。`agents-v3/team-composition.md` に Phase 2 検討項目として記載。

#### 4. Feature Table 拡充（12 項目追加）

`CLAUDE.md` と `docs/CLAUDE-feature-table.md` に以下を追加:
- `ExitWorktree` ツール
- Effort levels 簡素化
- Agent tool `model` パラメータ復活
- `/plan` description 引数
- 並列ツール呼び出し修正
- Worktree isolation 修正
- `/clear` バックグラウンドエージェント保持
- Hooks 修正群（4 件）
- HTML コメント非表示
- Bash auto-approval 追加
- プロンプトキャッシュ修正

各機能の詳細セクションも `docs/CLAUDE-feature-table.md` に追記。

#### 5. バージョンヘッダー更新

`CLAUDE.md` と `docs/CLAUDE-feature-table.md` のヘッダーを `2.1.71+` → `2.1.72+` に更新。

---

### Included: Claude Code 公式ドキュメント整合

**Claude Code v2.1.71+ の公式ドキュメントに追加された新機能・フィールドを Harness のドキュメントに反映し、Auto Mode Phase 1 移行マーカーを更新。**

---

#### 1. Feature Table 拡充（9 項目追加）

**今まで**: v2.1.71 リリース時点の機能のみ記載。公式ドキュメントで追加されたサブエージェントの新フィールドや Agent Teams の実験フラグが未反映。

**今後**: 以下の機能を Feature Table に追加:
- Subagent `background` フィールド
- Subagent `local` メモリスコープ
- Agent Teams 実験フラグ (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)
- `/agents` コマンド（対話的管理 UI）
- Desktop Scheduled Tasks
- `CronCreate/CronList/CronDelete` ツール
- `CLAUDE_CODE_DISABLE_CRON` 環境変数
- `--agents` CLI フラグ

各機能の詳細セクションも `docs/CLAUDE-feature-table.md` に追記。

#### 2. Auto Mode Phase 1 開始予定表記へ更新

**今まで**: 「Phase 0 (現在)」「Phase 1 (RP 開始)」と記載。RP 開始日 2026-03-12 以前の表記。

**今後**: 「Phase 0 (pre-RP)」「Phase 1 (RP 開始後)」に更新。影響ファイル:
- `docs/CLAUDE-feature-table.md`
- `CLAUDE.md` Feature Table
- `agents-v3/team-composition.md`

#### 3. Agent Teams 公式ドキュメント対応

**今まで**: Harness の breezing が Agent Teams を使用しているが、公式の有効化手順が未記載。

**今後**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数の設定方法と `teammateMode` 設定を `agents-v3/team-composition.md` に追記。

---

## [3.7.2] - 2026-03-10

### Fixed
- **Hook stdout purity**: `session-init` and usage tracking hooks now discard telemetry output so hook consumers receive the JSON payload only.
- **Quiet session summary output**: `session-init` / `session-resume` no longer leak standalone `0` lines when Plans counts are zero matches.

### Changed
- **Regression coverage**: Added direct-execution tests for snapshot summary output and quiet usage tracking hooks to keep hook output stable.

---

## [3.7.1] - 2026-03-09

### テーマ: チーム実行の安全性向上

**Breezing（Agent Teams）の実行基盤を3つの観点から強化: エージェント型名の統一、Auto Mode への段階的移行準備、Worker の Worktree 隔離。**

---

#### 1. エージェント定義の統一

**今まで**: Worker や Reviewer のエージェント型名がファイルごとにバラバラでした。`breezing/SKILL.md` では `general-purpose`、`team-composition.md` では `claude-code-harness:worker` と書かれており、per-agent hooks（エージェント種別ごとのガードレール）が正しく発火しない問題がありました。

**今後**: 全ファイルで `claude-code-harness:worker` / `claude-code-harness:reviewer` に統一。Worker 専用の PreToolUse ガード（Write/Edit 時のチェック）と Reviewer 専用の Stop ログ（完了時の記録）が確実に適用されます。

#### 2. Auto Mode への準備（`--auto-mode`）

**今まで**: Breezing では Worker がバックグラウンド実行のため許可プロンプトを表示できず、`bypassPermissions`（全権限スキップ）を使っていました。動くけれど「全権限をスキップ」するため、意図しないファイル書き換えや危険なコマンドも素通りするリスクがありました。

**今後**: Claude Code 2.1.71+ の Auto Mode に対応する `--auto-mode` フラグを追加。Auto Mode は許可リスト方式で「定義済みの安全な操作だけを自動承認」し、危険な操作（`rm -rf`、`git push --force` 等）はブロックします。3段階で移行します:

- Phase 0（現在）: `--auto-mode` はオプトイン
- Phase 1（検証後）: `--auto-mode` をデフォルトに
- Phase 2（安定後）: `bypassPermissions` を廃止

```bash
/breezing --auto-mode              # Auto Mode で実行
/harness-work --breezing --auto-mode
```

#### 3. Worker の Worktree 隔離

**今まで**: 複数の Worker を並列実行したとき、同じファイルを2つの Worker が同時に編集すると競合が発生していました。Lead が「同じファイルを触るタスクは同じ Worker に割り当てる」ルールで回避していましたが、完璧ではありませんでした。

**今後**: Worker エージェント定義に `isolation: worktree` を追加。各 Worker は自動的に git worktree（独立した作業ディレクトリ）で動作するため、同じファイルを編集しても物理的に別ディレクトリなので衝突しません。完了後に Lead がマージします。

---

## [3.7.0] - 2026-03-08

### テーマ: 状態中心アーキテクチャへの転換

**まさお理論（マクロハーネス・ミクロハーネス・Project OS）を適用し、「会話が切れても作業が途切れない」仕組みを5つの機能で構築しました。**

---

#### 1. 失敗タスクの自動再チケット化

**今まで**: タスク実装後にテスト/CI が失敗すると、最大3回リトライして止まるだけでした。止まった後は「何が原因だったか」を自分で調べ、Plans.md に手動で修正タスクを追加し、再度 `/work` を実行する必要がありました。

**今後**: 3回失敗で止まるとき、Harness が失敗原因を分類（`assertion_error`、`import_error` 等）し、修正タスク案を state に保存します。`approve fix <task_id>` で承認すると Plans.md に `.fix` タスクとして追加されます。

```
失敗原因分析:
  カテゴリ: assertion_error
  修正タスク案: 26.1.1.fix — getByStatus の戻り値を修正
  DoD: npm test が全パスすること

承認: approve fix 26.1.1
却下: reject fix 26.1.1
```

将来的には、提案採用率80%以上で全自動化に昇格する計画です（D30）。

#### 2. セッションスナップショット（`/harness-sync --snapshot`）

**今まで**: セッションが切れた後の再開時、Plans.md を読み、git log を見て、自分で状況を把握する必要がありました。この「状況把握」に毎回時間がかかり、WIP タスクの進捗は Plans.md からは読み取れませんでした。

**今後**: `/harness-sync --snapshot` で、その瞬間の進捗を JSON に保存できます。次の SessionStart または `/resume` で最新スナップショット要約と前回比が自動表示されます。

```
スナップショット差分:

| 指標       | 前回 (03/08 22:00) | 今回       | 変化     |
|-----------|-------------------|-----------|---------|
| 完了タスク  | 8/16              | 13/16     | +5      |
| WIP タスク  | 2                 | 0         | -2      |
| TODO タスク | 6                 | 3         | -3      |
```

作業の「セーブポイント」のようなものです。

#### 3. Artifact Hash（タスクとコミットの紐付け）

**今まで**: Plans.md のタスクが `cc:完了` になっても、どのコミットで完了したか追跡できませんでした。「このタスクで何を変えたか」を知るには git log を手作業でたどる必要がありました。

**今後**: タスク完了時に、直近のコミットハッシュ（7文字短縮形）が Status に自動付与されます。

```markdown
| Task | 内容              | Status              |
|------|-------------------|---------------------|
| 26.1 | snapshot 機能追加  | cc:完了 [a1b2c3d]  |  ← 自動付与
```

`git show a1b2c3d` で、そのタスクの変更内容をいつでも確認できます。hash なしの `cc:完了` も引き続き有効（後方互換）。

#### 4. Progress Feed（Breezing 中の進捗表示）

**今まで**: `/breezing` で全タスクを並列実行するとき、完了するまでターミナルに進捗が表示されませんでした。10個以上のタスクがある場合、「今何個目が終わったか」がまったく見えず不安でした。

**今後**: Worker がタスクを完了するたびに、Lead が1行のプログレスサマリーを出力します。

```
📊 Progress: Task 1/16 完了 — "harness-work に失敗再チケット化を追加"
📊 Progress: Task 2/16 完了 — "harness-sync に --snapshot を追加"
📊 Progress: Task 3/16 完了 — "breezing にプログレスフィードを追加"
```

TaskCompleted hook の `systemMessage` も連動して進捗情報を出力します。

#### 5. Plans.md の Purpose 行

**今まで**: Phase ヘッダーには名前とタグだけ。「このフェーズの目的は何か」は本文を読まないと分かりませんでした。

**今後**: Phase ヘッダーの直後に、任意で `Purpose:` 行を1行追加できます。書かなくてもOK（強制ではありません）。ユーザーがフェーズの目的を述べた場合にのみ自動記載されます。

```markdown
### Phase 26.0: 失敗→再チケット化フロー [P0]

Purpose: 自己修正ループ失敗時に「止まるだけ」から「次の一手を提案」へ転換
```

---

## [3.6.0] - 2026-03-08

### 🎯 What's Changed for You

**Solo mode PM framework: structured self-questioning built into every skill. Impact×Risk planning, DoD/Depends columns, Value-axis reviews, and retrospectives — no new commands, just smarter existing ones.**

| Before | After |
|--------|-------|
| Plans.md had 3 columns (Task, Content, Status) | Plans.md has 5 columns (+DoD, +Depends); v1 format dropped |
| Priority was 1-axis (Required/Recommended/Optional) | 2-axis Impact×Risk matrix with automatic `[needs-spike]` for high-risk items |
| Plan Review checked 4 axes (Clarity/Feasibility/Dependencies/Acceptance) | 5 axes (+Value: user problem fit, alternative analysis, Elephant detection) |
| No retrospective capability | `sync` auto-runs retro when completed tasks exist (`--no-retro` to skip) |
| Breezing Phase 0 was undefined | Structured 3-question pre-flight check (scope, dependencies, risk flags) |
| Solo mode jumped straight to implementation | Step 1.5 background confirmation (purpose + impact scope inference) |
| Task dependencies were implicit in Japanese text | Explicit `Depends` column enables dependency-graph-based task assignment |

---

### Added
- **Plans.md v2 format**: 5-column table with DoD (Definition of Done) and Depends columns
- **DoD auto-inference**: `harness-plan create` generates testable completion criteria from task keywords
- **Depends auto-inference**: Automatic dependency detection (DB→API→UI→Test ordering)
- **`[needs-spike]` marker**: High Impact × High Risk tasks get auto-generated spike (tech validation) tasks
- **Plan Review Value axis**: 5th review axis checking user problem fit, alternatives, and Elephant detection
- **DoD/Depends quality checks**: Empty DoD warnings, untestable DoD suggestions, circular dependency detection
- **Retrospective (default ON)**: `sync` auto-runs retro when `cc:完了` tasks ≥ 1; `--no-retro` to skip
- **Breezing Phase 0 structured check**: 3-question pre-flight (scope confirmation, dependency validation, risk flags)
- **Solo Step 1.5**: 30-second background confirmation inferring task purpose and impact scope
- **Dependency-graph task assignment**: Breezing assigns Depends=`-` tasks first, chains dependents on completion

### Changed
- **harness-plan create Step 5**: Upgraded from 1-axis to Impact×Risk 2-axis priority matrix
- **harness-plan SKILL.md**: Plans.md format specification updated to v2 with DoD/Depends guide
- **harness-plan sync**: v1 (3-column) format support removed; Plans.md is always 5-column
- **harness-review Plan Review**: Expanded from 4-axis to 5-axis evaluation
- **harness-work Solo flow**: Added Step 1.5 between task identification and WIP marking
- **breezing Flow Summary**: Phase 0 now has concrete check items instead of undefined discussion

---

## [3.5.0] - 2026-03-07

### 🎯 What's Changed for You

**Claude Code v2.1.70–v2.1.71 features fully integrated: `/loop` scheduling for active monitoring, `PostToolUseFailure` auto-escalation, safe background agents, and Marketplace `@ref` installs.**

| Before | After |
|--------|-------|
| Feature Table covered up to v2.1.69 | Feature Table now covers v2.1.70–v2.1.71 (12 new items) |
| No automatic escalation on repeated tool failures | `PostToolUseFailure` hook escalates after 3 consecutive failures within 60s |
| Breezing relied solely on passive TeammateIdle monitoring | `/loop 5m /sync-status` enables active polling alongside passive hooks |
| Background agents risked losing output after compaction | v2.1.71 fix documented; `run_in_background` usage guide added |
| Plugin install used plain `owner/repo` | `owner/repo@vX.X.X` ref pinning recommended (v2.1.71 parser fix) |

---

### Added
- **`PostToolUseFailure` hook handler**: 60秒ウィンドウの連続失敗カウンターと 3 回失敗時の自動エスカレーションを追加
- **Feature Table v2.1.70–v2.1.71**: `docs/CLAUDE-feature-table.md` に 12 項目を追加
- **Breezing `/loop` guide**: `TeammateIdle` と `/loop` の役割分担を説明する active monitoring ガイドを追加
- **Breezing Background Agent guide**: v2.1.71 の出力パス修正を踏まえた `run_in_background` 運用ガイドを追加
- **Marketplace `@ref` install guidance**: `owner/repo@vX.X.X` を推奨するセットアップ手順を追加

### Changed
- **CLAUDE.md Feature Table**: `/loop`、`PostToolUseFailure`、Background Agent 出力修正、Compaction 画像保持を反映
- **Feature adoption notes**: Plugin hooks 修正、`--print` hang 修正、並列 plugin install 修正、`--resume` スキル再注入廃止を Feature Table に整理
- **README version badges**: `3.5.0` に同期
- **Compatibility doc**: plugin version を `3.5.0` に更新

### Fixed
- Windows checkout with `core.symlinks=false` no longer hides `harness-*` command skills before SessionStart runs

### Security
- **Symlink-safe failure counter writes**: `post-tool-failure.sh` は `.claude` 親ディレクトリ、`.claude/state`、`tool-failure-counter.txt` の symlink を検出した場合に state 書き込みをスキップ

---

## [3.4.2] - 2026-03-06

### 🎯 What's Changed for You

**README now explains Claude Harness as a steadier operating model, not just a feature list, and `/harness-work all` now ships with rerunnable success and failure evidence that matches the real exit status.**

| Before | After |
|--------|-------|
| README mixed feature descriptions, comparison copy, and duplicate visual explanations | README now leads with clearer "what changes after install" messaging and SVG-driven comparisons |
| `/harness-work all` evidence existed, but the full runner could misread a failing test exit code | success / failure evidence runners now record the real command status, so the artifact contract matches what actually happened |

### Changed
- **README refresh (EN/JA)**: Reworked the hero and comparison sections around the default operating path after install, added new SVG cards, and removed duplicated explanation blocks.
- **Competitive positioning docs**: Added a dated harness comparison matrix, compatibility notes, distribution scope, claims audit, positioning notes, and release checklist docs so public claims stay grounded.
- **Codex package surface**: Clarified `harness-*` workflow surfaces in Codex docs and aligned setup scripts with path-based skill loading.

### Added
- **`/harness-work all` evidence pack**: Added success / failure fixtures, smoke/full runners, replay-aware success artifacts, and public docs for rerunnable verification.
- **README visual assets**: Added `why-harness-pillars` and default-flow comparison SVGs in both English and Japanese.

### Fixed
- **Evidence runner exit status capture**: Full success / failure runners now preserve the real `claude` and `npm test` exit codes instead of the inverted `!` status.
- **Claim drift checks**: Expanded `check-consistency.sh` to catch README badge drift, missing docs, stale positioning claims, and distribution-scope mismatches before release.

---

## [3.4.1] - 2026-03-06

### 🎯 What's Changed for You

**Fixed stale skill labels in the Claude Code 2.1.69+ feature tables (EN/JA), so the docs now match the actual harness skill set.**

| Before | After |
|--------|-------|
| `task-worker`, `code-reviewer`, `work`, `all skills` labels remained in README feature tables | Unified to current names: `harness-work`, `harness-review`, `all harness-* skills` |

### Changed
- **README (EN/JA) feature table cleanup**: Updated the "Skills" column under "Claude Code 2.1.69+ Features" to current harness naming.

### Fixed
- **Documentation drift**: Removed legacy skill aliases that could mislead users during `/breezing` and `/harness-work` onboarding.

---

## [3.4.0] - 2026-03-06

### 🎯 What's Changed for You

**Claude Code v2.1.69 対応を完了。teammate event 制御、skill reference 解決、開発フロー文書を一気に更新し、チーム実行の停止判定と互換性を強化しました。**

| Before | After |
|--------|-------|
| Teammate hooks were session_id-centric and always approve-only | `agent_id`/`agent_type` を活用し、`{"continue": false, "stopReason": "..."}` で停止を返せる |
| `InstructionsLoaded` event was not handled | Dedicated handler added and wired in both hooks.json files |
| SKILL references used relative `references/` paths | `${CLAUDE_SKILL_DIR}/references/...` に統一し、実行環境依存を削減 |
| Docs were centered on 2.1.68+ | Feature docs/README/command docs updated to 2.1.69+ |

### Added
- **InstructionsLoaded handler**: `scripts/hook-handlers/instructions-loaded.sh` を新規追加
- **Teammate stop response support**: `teammate-idle.sh` / `task-completed.sh` に `continue:false` 応答ロジックを追加
- **2.1.69 feature docs**: `${CLAUDE_SKILL_DIR}`, `agent_id/agent_type`, `/reload-plugins`, `includeGitInstructions: false`, `git-subdir` 運用方針を明文化

### Changed
- **PreToolUse breezing role guard**: role lookup を `agent_id` 優先・`session_id` fallback に拡張
- **SKILL reference path policy**: skills/codex/opencode の SKILL.md で references 参照を `${CLAUDE_SKILL_DIR}` ベースへ更新
- **check-consistency**: project template の `defaultMode` baseline を検証し、未文書化の値を配布しない方針を明記
- **Feature docs**: CLAUDE.md / README / README_ja / docs/CLAUDE-feature-table.md / docs/CLAUDE-commands.md 更新

### Fixed
- **Plans drift**: Phase 17/19 の未同期タスクマーカーを現実状態へ同期
- **continue:false parsing**: boolean `false` が落ちるケースを修正し、stopReason を確実に反映

---

## [3.3.1] - 2026-03-05

### 🎯 What's Changed for You

**All README visuals unified to brand-orange palette, logo regenerated with Nano Banana Pro, and duplicate content sections removed for a cleaner reading experience.**

| Before | After |
|--------|-------|
| Mixed indigo/blue/teal/purple SVGs | Unified orange palette (#F7931A hierarchy) |
| Hero comparison shown twice (SVG + table) | Single SVG visualization |
| /work all flow shown twice (mermaid + SVG) | Single SVG visualization |
| Review section had no visual | 4-perspective review card SVG added |
| 47KB logo (old design) | 53KB Nano Banana Pro logo with "Plan → Work → Review" tagline |

### Changed
- **8 SVGs recolored** (EN/JA): Unified orange brand palette across all README visuals
- **Logo regenerated**: Nano Banana Pro interlocking-loops icon + "Plan → Work → Review" tagline
- **README cleanup**: Removed duplicate mermaid/SVG and SVG/table sections in both EN/JA

### Added
- **Review perspectives SVG** (EN/JA): 4-angle code review visualization (Security, Performance, Quality, Accessibility)
- **3 JA generated SVGs**: hero-comparison, core-loop, safety-guardrails (Japanese localized versions)
- **Alternative logo**: `docs/images/claude-harness-logo-alt.png` (carabiner icon + color-split text)

---

## [3.3.0] - 2026-03-05

### 🎯 What's Changed for You

**Claude Code v2.1.68 introduced effort levels, agent hooks, and more. Harness v3.3.0 puts all of them to work — so you get smarter task execution, LLM-powered code guards, and fully automated worktree lifecycle out of the box.**

> Claude Code got new superpowers. Harness makes sure you actually use them.

| What Claude Code added | How Harness uses it |
|------------------------|---------------------|
| **Opus 4.6 medium effort default** — Claude now thinks less deeply by default | Harness auto-detects complex tasks (security, architecture, multi-file changes) and injects `ultrathink` to restore full thinking depth exactly when it matters |
| **Agent hooks (`type: "agent"`)** — hooks can now use LLM intelligence | 3 smart guards deployed: catches hardcoded secrets before commit, blocks session exit with unfinished tasks, runs lightweight code review after every write |
| **WorktreeCreate/Remove hooks** — lifecycle events for git worktrees | Breezing parallel workers now auto-initialize their workspace and clean up temp files when done. No more orphaned `/tmp` clutter |
| **`CLAUDE_ENV_FILE`** — session environment persistence | Harness version, effort defaults, and Breezing session IDs persist across hooks. Workers know who they are |
| **Prompt hooks expanded to all events** — no longer Stop-only | Every hook event can now use LLM judgment (was incorrectly documented as Stop-only) |

### Added
- **Effort level auto-tuning**: Multi-element scoring system (file count + directory criticality + task keywords + past failure history). Score ≥ 3 triggers `ultrathink` — meaning complex tasks get deep thinking, simple tasks stay fast
- **Agent hooks (3 deployments)**:
  - *PreToolUse quality guard*: LLM reviews every Write/Edit for secrets, TODO stubs, and security issues before they land
  - *Stop WIP guard*: Reads Plans.md and warns you if you're about to close a session with unfinished `cc:WIP` tasks
  - *PostToolUse code review*: Lightweight haiku-powered review runs after every file write
- **Worktree lifecycle automation**: `worktree-create.sh` sets up `.claude/state/worktree-info.json` with worker identity; `worktree-remove.sh` cleans Codex temp files and logs
- **Session environment persistence**: `session-env-setup.sh` writes `HARNESS_VERSION`, `HARNESS_EFFORT_DEFAULT=medium`, and `HARNESS_BREEZING_SESSION_ID` to `CLAUDE_ENV_FILE`
- **PreCompact agent hook**: Catches WIP tasks before context compaction — so important context isn't lost mid-task
- **HTTP hook template**: Ready-to-use PostToolUse metrics hook for external dashboards (localhost:9090)

### Changed
- **4-type hook system**: Harness now supports all 4 hook types — `command`, `prompt` (all events), `http`, and `agent`
- **Feature Table**: Updated from v2.1.63+ to v2.1.68+ with 30 tracked features
- **Worker/Reviewer/Team agents**: Now understand effort levels and when to request deeper thinking
- **PM templates**: All handoff templates include `ultrathink` with clear intent comments

### Fixed
- **Prompt hook documentation**: Removed incorrect "Stop/SubagentStop only" restriction (prompt hooks work on all events since v2.1.63)
- **Dead reference cleanup**: Removed link to deleted `guardrails-inheritance.md` in Feature Table

---

## [3.2.0] - 2026-03-04

### 🎯 What's Changed for You

**TDD is now enabled by default for all tasks, and Windows users get automatic symlink repair on session start.**

| Before | After |
|--------|-------|
| TDD only active with `[feature:tdd]` marker (opt-in) | TDD active by default; skip with `[skip:tdd]` (opt-out) |
| Windows users: v3 skills not recognized (broken symlinks) | Auto-detected and repaired on session start |
| Worker had no TDD phase in execution flow | TDD phase (Red→Green) integrated into Worker and Solo mode |

### Added
- **TDD-by-default**: TDD is now opt-out (`[skip:tdd]`) instead of opt-in (`[feature:tdd]`). All WIP tasks get TDD reminders unless explicitly skipped
- **`--no-tdd` option**: Skip TDD phase in `/harness-work` execution
- **Windows symlink auto-repair**: `fix-symlinks.sh` detects broken symlinks from Windows git clone and replaces them with directory copies
- **Session-init Step 1.5**: Symlink health check runs automatically before skill discovery

### Changed
- **tdd-order-check.sh**: `has_tdd_wip_task()` split into `has_active_wip_task()` + `is_tdd_skipped()` for clearer logic
- **harness-plan create.md**: Step 5.5 inverted from "TDD adoption criteria" to "TDD skip criteria"
- **worker.md**: Execution flow expanded from 10 to 12 steps with TDD judgment and Red phase
- **harness-work SKILL.md**: Solo mode expanded from 6 to 7 steps with TDD phase

---

## [3.1.0] - 2026-03-03

### 🎯 What's Changed for You

**Codex CLI 0.107.0 full compatibility, 15 deprecated skill stubs removed (−40,000 lines), and `/harness-work` now auto-selects the best execution mode based on task count.**

| Before | After |
|--------|-------|
| 15 deprecated redirect stubs cluttering skill listings | Clean 5-verb structure only |
| `/harness-work` always defaulted to Solo mode | Auto-detection: 1→Solo, 2-3→Parallel, 4+→Breezing |
| `--codex` could be confusing for users without Codex CLI | `--codex` is explicit-only, never auto-selected |
| MCP server references in Codex config | All MCP remnants removed, pure CLI integration |
| `--approval-policy` (non-official flag) in docs | Correct `-a never -s workspace-write` flags |

### Added
- **Auto Mode Detection**: `/harness-work` auto-selects Solo/Parallel/Breezing based on task count (1/2-3/4+)
- **Breezing backward-compatible alias**: `/breezing` delegates to `/harness-work --breezing`
- **Codex 環境フォールバック**: harness-review に Task ツール非対応時の Plans.md 直接操作パターン追加
- **Codex 環境注記**: team-composition.md, worker.md に Codex CLI 固有の制約と代替手段を記載
- **config.toml 拡充**: [notify] セクション（after_agent メモリブリッジ）、reviewer Read-only sandbox
- **.codexignore**: CLAUDE.md ノイズ化防止パターン追加
- **README visual improvement**: hero-comparison, core-loop, safety-guardrails images

### Changed
- **MCP 残骸除去**: config.toml, setup-codex.sh, codex-setup-local.sh から MCP サーバー参照を完全削除
- **codex exec フラグ正規化**: --approval-policy → -a (--ask-for-approval)、--sandbox → -s に統一
- **プロンプト渡し方式改善**: "$(cat file)" → stdin パイプ (`cat file | codex exec -`) に変更（ARG_MAX 対策）
- **codex-worker-engine.sh**: mcp-params.json → codex-exec-params.json にリネーム

### Fixed
- **/tmp/codex-prompt.md 固定パス**: mktemp 一意パスに変更（並列実行時の競合防止）
- **2>/dev/null エラー握りつぶし**: ログファイルリダイレクトに変更（デバッグ可能に）
- **Skill description quality**: gogcli-ops YAML fix, session-memory invalid tool removal, session-state non-standard fields cleanup

### Removed
- **15 DEPRECATED redirect stubs**: breezing(old), codex-review, handoff, harness-init, harness-update, impl, maintenance, parallel-workflows, planning, plans-management, release-har, setup, sync-status, troubleshoot, verify, work — all consolidated into 5-verb skills
- **Old -harness suffix stubs**: plan-harness, release-harness, review-harness, setup-harness, work-harness from skills-v3/
- **x-release-harness**: consolidated into harness-release

---

## [3.0.0] - 2026-03-02

### 🎯 What's Changed for You

**Harness v3: Full architectural rewrite — 42 skills unified to 5 verbs, 11 agents consolidated to 3, TypeScript engine replaces Bash guardrails, SQLite replaces scattered JSON state files.**

| Before | After |
|--------|-------|
| 42 skills spread across multiple dirs | 5 verb skills: `plan` / `execute` / `review` / `release` / `setup` |
| 11 agents with overlapping responsibilities | 3 agents: `worker` / `reviewer` / `scaffolder` |
| Bash scripts for guardrails (pretooluse-guard.sh etc.) | TypeScript engine in `core/` (strict, ESM, NodeNext) |
| JSON/JSONL state files scattered across dirs | SQLite single-file state via `better-sqlite3` |
| rsync-based mirror sync for codex/opencode | Symlink-based mirror (zero sync overhead) |
| No session lifecycle management | `core/engine/lifecycle.ts` unifies session-init/control/state/memory |

### Added

- **`core/` TypeScript engine**: Strict ESM module (`exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`, `NodeNext`). Includes guardrails, state, and engine subsystems
- **`core/src/guardrails/`**: Rules engine (R01-R09), pre-tool/post-tool/permission/tampering detection — all ported from Bash to TypeScript
- **`core/src/state/`**: SQLite state management via `better-sqlite3` with schema, store, and JSON→SQLite migration
- **`core/src/engine/lifecycle.ts`**: Session lifecycle — `initSession`, `transitionSession`, `finalizeSession`, `forkSession`, `resumeSession`
- **`skills-v3/`**: 5 verb skills with unified SKILL.md + references/
- **`agents-v3/`**: 3 consolidated agent definitions + team-composition.md
- **`tests/validate-plugin-v3.sh`**: v3 structural validator (6 checks, 34 assertions)
- **Symlink mirrors**: `codex/.codex/skills/` and `opencode/skills/` 5-verb dirs now symlinks to `skills-v3/`
- **`skills-v3/routing-rules.md`**: Trigger/exclusion keywords per skill verb

### Changed

- **Skills**: 42 → 5 (plan/execute/review/release/setup). Legacy `skills/` retained for backwards compatibility
- **Agents**: 11 → 3 (worker/reviewer/scaffolder). Legacy `agents/` retained for backwards compatibility
- **Hooks shims**: `hooks/pre-tool.sh`, `hooks/post-tool.sh`, `hooks/permission.sh` now delegate to `core/src/index.ts`
- **PermissionRequest**: Switched from v2 `run-script.js permission-request` to v3 TypeScript core (`hooks/permission.sh`)
- **`check-consistency.sh`**: Mirror check updated from rsync diff to symlink validation
- **CLAUDE.md**: Compact v3 version; architecture details moved to `.claude/rules/v3-architecture.md`
- **README.md / README_ja.md**: Updated for v3 (5 verb skills, 3 agents, TypeScript core, architecture diagram)

### Fixed

- **`core/src/state/store.ts`**: Fixed `better-sqlite3` type import — `typeof import("better-sqlite3").default` → `import type DatabaseConstructor from "better-sqlite3"` (ESM/CJS compatibility)
- **Duplicate `posttooluse-tampering-detector`**: Removed v2 script from PostToolUse `Write|Edit|Task` block (v3 `post-tool.ts` already handles tampering detection)

### Removed

- rsync-based mirror sync (replaced by symlinks)
- Standalone Bash guardrail scripts (replaced by `core/src/guardrails/`)
- Scattered JSON/JSONL state files (replaced by SQLite)
- Duplicate `posttooluse-tampering-detector` hook (consolidated into v3 post-tool engine)

---

## [2.26.1] - 2026-03-02

### Added

- **12 section-specific SVG illustrations**: 6 EN + 6 JA hand-crafted visuals embedded in both READMEs (before-after, /work all flow, parallel workers, safety shield, skills ecosystem, breezing agents)

### Fixed

- **review-loop.md APPROVE flow inconsistency**: Phase 3.5 Auto-Refinement step was missing from the APPROVE judgment table, causing inconsistency with SKILL.md and execution-flow.md

## [2.26.0] - 2026-03-02

### 🎯 What's Changed for You

**Claude Code v2.1.63 integration: `/work` now auto-simplifies code after review, `/breezing` can delegate horizontal tasks to `/batch`, and HTTP hooks enable external service notifications.**

| Before | After |
|--------|-------|
| `/work` flow: implement → review → commit | `/work` flow: implement → review → **auto-simplify** → commit |
| Horizontal migration tasks handled manually | `/breezing` auto-detects and delegates to `/batch` |
| Feature table covers up to v2.1.51 | Feature table covers up to v2.1.63 (27 features) |
| Hooks only support `command` and `prompt` types | Hooks now support `http` type (POST to external services) |

### Added

- **Phase 3.5 Auto-Refinement in `/work`**: After review APPROVE, `/simplify` runs automatically to clean up code. `--deep-simplify` adds `code-simplifier` plugin. `--no-simplify` skips
- **`/batch` delegation in `/breezing`**: Horizontal pattern detection (migrate/replace-all/add-to-all) auto-proposes `/batch` delegation for bulk changes
- **HTTP hooks documentation** (`.claude/rules/hooks-editing.md`): `type: "http"` spec with field reference, response behavior, command-vs-http comparison table, and 3 sample templates (Slack, metrics, dashboard)
- **7 new feature-table entries** (`docs/CLAUDE-feature-table.md`): `/simplify`, `/batch`, `code-simplifier` plugin, HTTP hooks, auto-memory worktree sharing, `/clear` skill cache reset, `ENABLE_CLAUDEAI_MCP_SERVERS`

### Changed

- **Version references**: `2.1.49+` → `2.1.63+` across CLAUDE.md and feature table
- **Feature count**: 20 → 27 in CLAUDE.md and feature table
- **`/breezing` guardrails**: Added auto-memory worktree sharing (v2.1.63) to inheritance table
- **`troubleshoot` skill**: Added `/clear` cache reset to CC v2.1.63+ diagnostics
- **`work-active.json` schema**: Added `simplify_mode: "default" | "deep" | "skip"` field

## [2.25.0] - 2026-02-24

### 🎯 What's Changed for You

**`CLAUDE_CODE_SIMPLE` モード（CC v2.1.50+）の影響を自動検出し、無効化される機能をユーザーに明示。サイレント障害を防止。**

| Before | After |
|--------|-------|
| SIMPLE モードで 37 スキル・11 エージェントがサイレントに無効化 | SessionStart/Setup フックが自動検出し、ターミナル + additionalContext で警告表示 |
| SIMPLE モードの影響範囲が不明（互換性マトリクスに 1 行のみ） | 専用ドキュメント `docs/SIMPLE_MODE_COMPATIBILITY.md` で全影響を網羅（スキル・エージェント・メモリ・ワークフロー） |
| 防御コード・検出ロジックがゼロ | `scripts/check-simple-mode.sh` ユーティリティで一貫した検出・多言語警告メッセージ |
| `/work`, `/breezing` 等が理由不明で動作しない | 「スキル無効」「エージェント無効」「フックのみ動作」の 3 分類で即座に状況把握可能 |

### Added

- **SIMPLE モード検出ユーティリティ** (`scripts/check-simple-mode.sh`): `is_simple_mode()` 関数と `simple_mode_warning()` 多言語メッセージ生成。全フック・スクリプトから source して使用可能
- **SessionStart SIMPLE モード警告**: `scripts/session-init.sh` がセッション開始時に `CLAUDE_CODE_SIMPLE` 環境変数を検出し、stderr バナー + additionalContext で詳細警告を出力
- **Setup hook SIMPLE モード警告**: `scripts/setup-hook.sh` が init/maintenance 時に SIMPLE モードを検出し、出力メッセージに警告を追加
- **`docs/SIMPLE_MODE_COMPATIBILITY.md`**: SIMPLE モード完全ガイド — 影響サマリ表、動作/非動作の全リスト、37 スキル・11 エージェントの影響度分類、検出方法、ワークアラウンド、開発者向け拡張ガイド

### Changed

- **互換性マトリクス強化** (`docs/CLAUDE_CODE_COMPATIBILITY.md`):
  - v2.1.50 SIMPLE モード行のステータスを「要注意」→「**対応済み**」に更新
  - 非互換セクションに SIMPLE モードの詳細影響（37 スキル・11 エージェント・メモリ無効化）と検出方法を追記
  - `SIMPLE_MODE_COMPATIBILITY.md` へのクロスリファレンスリンク追加

---

## [2.24.0] - 2026-02-24

### 🎯 What's Changed for You

**Claude Code v2.1.50〜v2.1.51 の新機能に対応。互換性マトリクス更新、メモリ安定性改善の恩恵、新 CLI コマンド活用。**

| Before | After |
|--------|-------|
| 互換性マトリクスが v2.1.49 で止まっていた | v2.1.50〜v2.1.51 の全機能を文書化、推奨バージョンを v2.1.51+ に引き上げ |
| WorktreeCreate/Remove hook が未知 | Breezing guardrails に将来対応として文書化 |
| エージェント spawn 失敗時の診断手段が限定的 | `claude agents list` (CC 2.1.50+) を troubleshoot スキルに追加 |
| バックグラウンドエージェント停止方法が未記載 | `Ctrl+F`（CC 2.1.49+）を breezing guardrails に追記、ESC 非推奨を明記 |

### Added

- **CC v2.1.50/v2.1.51 互換性マトリクス**: `docs/CLAUDE_CODE_COMPATIBILITY.md` に 17 項目追加（メモリリーク修正、完了タスク GC、WorktreeCreate/Remove hook、`claude agents` CLI、宣言的 worktree isolation、SIMPLE モード注意、remote-control 等）
- **`claude agents` CLI 診断**: `skills/troubleshoot/SKILL.md` にエージェント診断セクション追加（CC 2.1.50+）
- **WorktreeCreate/WorktreeRemove hook**: `skills/breezing/references/guardrails-inheritance.md` に将来対応として追記
- **Ctrl+F キーバインド**: breezing guardrails にバックグラウンドエージェント停止方法を追記（CC 2.1.49+、ESC 非推奨）
- **Feature Table 拡張**: `docs/CLAUDE-feature-table.md` に v2.1.50/v2.1.51 の 4 機能追加（メモリリーク修正、claude agents CLI、WorktreeCreate/Remove、remote-control）

### Changed

- **推奨 CC バージョン**: v2.1.49+ → **v2.1.51+** に引き上げ
- **Feature Table タイトル**: 2.1.49+ → 2.1.51+ に更新

---

## [2.23.6] - 2026-02-24

### Added

- **Auto-release workflow** (`release.yml`): Safety-net GitHub Release creation on `v*` tag push — prevents orphan tags if `release-har` is interrupted
- **CHANGELOG format validation in CI**: ISO 8601 date format, `[Unreleased]` section presence, non-standard heading warnings
- **Codex mirror sync check in CI**: `codex/.codex/skills/` ↔ `skills/` consistency validated in both `check-consistency.sh` and `opencode-compat.yml`
- **Branch Policy in release-har**: Explicitly documents that main direct push is allowed for solo projects (force push remains prohibited)

### Changed

- **CHANGELOG link definitions repaired**: All version compare links supplemented
- **CHANGELOG_ja.md translation gaps filled**: 5 versions added (2.20.1, 2.17.6, 2.17.1, 2.17.0, 2.16.21)
- **README version and count updated**: Badge version, skill count (41), agent count (11) updated to reflect reality
- **CHANGELOG non-standard headings normalized**: `### Internal` → `### Changed` (Keep a Changelog compliant)
- **Mirror compat workflow renamed**: `OpenCode Compatibility Check` → `Mirror Compatibility Check` (now covers both opencode and codex mirrors)
- **AGENTS.md template updated**: Removed `main` direct push prohibition for solo projects; force push remains prohibited
- **Tamper detection expanded** (`codex-worker-quality-gate.sh`): Python skip patterns, catch-all assertions, config relaxation detection

---

## [2.23.5] - 2026-02-23

### 🎯 What's Changed for You

**Phase 13: Breezing quality automation and Codex rule injection — tamper detection, auto-test runner, CI signal handling, AGENTS.md rule sync, and APPROVE fast-path.**

| Before | After |
|--------|-------|
| Test tampering detection covered skip patterns and assertion deletion only | 12+ patterns: weakening (`toBe → toBeTruthy`), timeout inflation, catch-all assertions, Python skip decorators |
| Auto-test runner only recommended tests without running them | `HARNESS_AUTO_TEST=run` actually runs tests and feeds results back via `additionalContext` |
| CI failures required manual detection | PostToolUse hook detects CI failures after `git push` and injects `ci-cd-fixer` recommendation signals |
| `.claude/rules/` existed only for Claude Code; Codex had no rule awareness | `sync-rules-to-agents.sh` auto-syncs rules to `codex/AGENTS.md`; Codex reads full project rules on startup |
| `codex exec` called bare without pre/post processing | `codex-exec-wrapper.sh` handles rule sync, `[HARNESS-LEARNING]` extraction, and secret filtering |
| Breezing Phase C required manual APPROVE confirmation | `review-result.json` + commit hash check enables instant fast-path to integration tests |
| Implementer count fixed at `min(独立タスク数, 3)` | Auto-calculated as `max(1, min(独立タスク数, --parallel, planner_max_parallel, 5))` |

### Added

- **Tamper detection (12+ patterns)**: assertion weakening, timeout inflation, catch-all assertions, Python skip decorators — `scripts/posttooluse-tampering-detector.sh`
- **`HARNESS_AUTO_TEST=run` mode**: `scripts/auto-test-runner.sh` actually runs tests and returns pass/fail via `additionalContext` JSON
- **CI signal injection**: `scripts/hook-handlers/ci-status-checker.sh` detects CI failures post-push and writes to `breezing-signals.jsonl`; `scripts/hook-handlers/breezing-signal-injector.sh` injects unconsumed signals via UserPromptSubmit hook
- **`sync-rules-to-agents.sh`**: Auto-converts `.claude/rules/*.md` to `codex/AGENTS.md` Rules section with hash-based drift detection
- **`codex-exec-wrapper.sh`**: Pre/post wrapper for `codex exec` — rule sync, `[HARNESS-LEARNING]` marker extraction, secret filtering, atomic write-back to `codex-learnings.md`
- **APPROVE fast-path (Phase C)**: Checks `.claude/state/review-result.json` + HEAD commit hash; skips manual confirmation when APPROVE is already recorded
- **`review-result.json` auto-record**: Reviewer reports `review_result_json` in SendMessage; Lead writes `.claude/state/review-result.json` for fast-path reference
- **Docs reorganization**: `docs/CLAUDE-feature-table.md`, `docs/CLAUDE-skill-catalog.md`, `docs/CLAUDE-commands.md` — detailed references extracted from CLAUDE.md
- **`harness.rules` — execpolicy guard rules**: `npm test`/`yarn test`/`pnpm test` auto-allowed; `git push --force`, `git reset --hard`, `rm -rf`, `git clean -f`, SQL destructive statements (`DROP TABLE`, `DELETE FROM`) require user confirmation via `codex execpolicy`; 20 patterns verified with `codex execpolicy check`

### Changed

- **CLAUDE.md compressed to 120 lines**: Feature Table (5 items), skill category table (5 categories); full details moved to `docs/`
- **Implementer count auto-determination**: `max(1, min(独立タスク数, --parallel N, planner_max_parallel, 5))` — starvation prevention + hard cap at 5
- **`review-retake-loop.md`**: Added `review-result.json` write spec with JSON format, Reviewer→Lead delegation flow, and file lifecycle
- **`execution-flow.md` Phase C**: APPROVE fast-path check added as step 2; phase processing renumbered
- **`team-composition.md`**: Extended configuration (5 Implementers) cost estimate table added
- **`release-har` skill redesigned (Phase 14)**: Full redesign with Pre-flight checks, structured git log, Conventional Commits classification, Claude diff summarization (Highlights + Before/After), SemVer auto-detection, dry-run preview, 4-section Release Notes, Compare link auto-generation, `--announce` option, and `--dry-run` default gate; `references/release-notes-template.md` and `references/changelog-format.md` added

---

## [2.23.3] - 2026-02-22

### 🎯 What's Changed for You

**Codex integration is now explicitly CLI-first (`codex exec`) outside breezing, and Codex package parity includes the new `generate-slide` skill.**

| Before | After |
|--------|-------|
| `work`/`harness-review`/`codex-review` docs mixed Codex MCP wording with CLI execution examples | Non-breezing Codex flows are documented as CLI-only (`codex exec`) with consistent setup and troubleshooting |
| `codex-worker-setup.sh` checked MCP registration state | Setup now checks `codex exec` readiness directly (`codex_exec_ready`) |
| Codex package parity test did not block non-breezing MCP vocabulary regressions | New CLI-only regression checks added to `tests/test-codex-package.sh` |
| `generate-slide` existed in source/opencode but not in Codex package | `codex/.codex/skills/generate-slide/` is now included and parity tests pass |

### Added

- **Codex package skill parity**: Added `generate-slide` skill files to `codex/.codex/skills/`
- **CLI-only regression guard**: Added non-breezing Codex vocabulary checks to `tests/test-codex-package.sh`
- **README updates (EN/JA)**: Added `/generate-slide` command docs and slide-generation feature section

### Changed

- **Codex docs (non-breezing)**: Updated `work`, `harness-review`, `codex-review`, routing/setup references to CLI-first terminology and behavior (`codex exec`)
- **Codex setup reference**: Reworked `codex-mcp-setup.md` content into Codex CLI setup flow (legacy filename retained for compatibility)
- **README Codex review section (EN/JA)**: Clarified Codex second-opinion execution path as Codex CLI-based

### Fixed

- **Setup behavior mismatch**: Replaced MCP registration check in `scripts/codex-worker-setup.sh` with actual CLI execution readiness check
- **Codex mirror consistency**: Synced updated non-breezing Codex skill docs between `skills/` and `codex/.codex/skills/`

---

## [2.23.2] - 2026-02-22

### 🎯 What's Changed for You

**Codex skills now use fully native multi-agent vocabulary — CI checks pass, and `--claude` review routing is explicitly documented.**

| Before | After |
|--------|-------|
| Codex breezing/work skills contained Claude Code-specific terms (`delegate mode`, `TaskCreate`, `subagent_type`, etc.) | All 82+ occurrences replaced with Codex native API equivalents (`Phase B`, `spawn_agent`, `role`, etc.) |
| No `review_engine` matrix in Codex breezing/work SKILL.md | `review_engine` comparison table added with `codex` / `claude` columns |
| `--claude + --codex-review` conflict undocumented | Explicit conflict rule: mutually exclusive, fails before execution |
| State files referenced `.claude/state/` paths | State files use `${CODEX_HOME:-~/.codex}/state/harness/` paths |
| `opencode/` contained stale breezing files | Rebuilt `opencode/` — breezing removed (dev-only skill) |

### Fixed

- **Codex vocabulary migration**: replaced 82+ legacy Claude Code terms across 13 files in `codex/.codex/skills/breezing/` and `codex/.codex/skills/work/` — `delegate mode` → `Phase B`, `TaskCreate` → `spawn_agent`, `subagent_type` → `role:`/`spawn_agent()`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` → `config.toml [features] multi_agent`, `.claude/state/` → `${CODEX_HOME}/state/harness/`
- **`--claude` review routing**: added `review_engine` matrix table and `--claude + --codex-review` conflict rule to both `breezing/SKILL.md` and `work/SKILL.md`
- **OpenCode sync**: rebuilt `opencode/` to remove stale breezing files and routing-rules.md

---

## [2.23.1] - 2026-02-22

### 🎯 What's Changed for You

**Codex CLI setup now merges files instead of overwriting, and README setup instructions are clearer with a collapsible quick-start.**

| Before | After |
|--------|-------|
| `setup-codex.sh` overwrote all destination files on every sync | Merge strategy: new files added, existing files updated, user-created files preserved |
| Codex CLI Setup was a top-level README section | Moved to collapsible `<details>` block with step-by-step quick-start |
| `config.toml` had 4 agent definitions | 9 agents: added `task_worker`, `code_reviewer`, `codex_implementer`, `plan_analyst`, `plan_critic` |

### Changed

- **README (EN/JA)**: Codex CLI Setup section moved from top-level to collapsible `<details>` block with prerequisites, 3-step quick-start, and flag reference table
- **`setup-codex.sh`**: `sync_named_children()` rewritten with 3-way merge strategy — new files are copied, existing files are backed up and updated, destination-only files are preserved; log output now shows `(N new, N updated, N preserved, N skipped)`
- **`codex-setup-local.sh`**: same merge strategy applied to project-local setup script

### Added

- **`merge_dir_recursive()`** helper in both setup scripts for recursive directory merging with backup
- **5 new Codex agent definitions** in `setup-codex.sh` `config.toml` generation: `task_worker`, `code_reviewer`, `codex_implementer`, `plan_analyst`, `plan_critic` (Breezing roles)
- Idempotent agent injection: existing `config.toml` files receive missing agent entries without duplicating existing ones

---

## [2.23.0] - 2026-02-21

### 🎯 What's Changed for You

**Codex breezing now has its own Phase 0 (Planning Discussion) using Codex's native multi-agent API — Planner and Critic agents analyze your plan before implementation begins.**

| Before | After |
|--------|-------|
| Codex breezing Phase 0 was dead code (referenced Claude-only APIs) | Phase 0 uses `spawn_agent`/`send_input`/`wait`/`close_agent` natively |
| `config.toml` had 4 agent definitions | 9 agents defined including `plan_analyst`, `plan_critic`, `task_worker`, `code_reviewer`, `codex_implementer` |
| All breezing reference files were identical between Claude and Codex | 3 files now intentionally diverge with platform-native implementations |

### Added

- **Codex Phase 0 (Planning Discussion)**: ported from Claude Agent Teams to Codex native multi-agent API (`spawn_agent`/`send_input`/`wait`/`close_agent`)
- **5 new Codex agent definitions** in `config.toml`: `plan_analyst`, `plan_critic`, `task_worker`, `code_reviewer`, `codex_implementer`
- **Mirror sync divergence management** (D24, P20): 3 breezing files (`planning-discussion.md`, `execution-flow.md`, `team-composition.md`) now excluded from rsync to preserve Codex-native implementations

### Changed

- **Codex `planning-discussion.md`**: fully rewritten with Codex native API — Planner ↔ Critic dialogue via Lead relay pattern using `send_input` + `wait` loops
- **Codex `execution-flow.md`**: Phase 0 + Phase A spawn logic updated to `spawn_agent()` format; environment check now references `config.toml [features] multi_agent = true`
- **Codex `team-composition.md`**: all role definitions updated — `subagent_type` removed, `spawn_agent()` format, `SendMessage` → `send_input()`, `shutdown_request` → `close_agent()`

---

## [2.22.0] - 2026-02-21

### 🎯 What's Changed for You

**Security guardrails now apply automatically from the moment you install Harness — no `/harness-init` required. Permission policy hardened with least-privilege defaults and privacy-safe session logging.**

| Before | After |
|--------|-------|
| Security settings (deny/ask rules) required running `/harness-init` | Plugin settings applied automatically on install (CC 2.1.49+) |
| Plugin settings had a broad `allow` rule; no DB CLI protection | Least-privilege: removed blanket `allow`; added deny for `psql`/`mysql`/`mongo` |
| `stop-session-evaluator.sh` always returned `{"ok":true}` without reading input | Hook reads `last_assistant_message`, stores length+hash only (privacy-safe) with atomic writes |
| No hook for configuration file changes | New `ConfigChange` hook records config changes to breezing timeline when active |
| `npm install` / `bun install` ran without confirmation | Package manager installs now require user confirmation (`ask` rule) |

### Added

- **Plugin settings.json** (`.claude-plugin/settings.json`): default security permissions distributed with the plugin — active from install (CC 2.1.49+)
  - **Deny**: `.env`, secrets, SSH keys (`id_rsa`, `id_ed25519`), `.aws/`, `.ssh/`, `.npmrc`, `sudo`, `rm -rf/-fr`, DB CLIs (`psql`, `mysql`, `mongo`)
  - **Ask**: destructive git (`push --force`, `reset --hard`, `clean -f`, `rebase`, `merge`), package installs (`npm/bun/pnpm install`), `npx`/`npm exec`
- **`ConfigChange` hook** (`scripts/hook-handlers/config-change.sh`): records configuration file changes to `breezing-timeline.jsonl` when breezing is active; always non-blocking
  - Normalizes `file_path` to repo-relative paths in timeline logs
  - Portable timeout detection (`timeout`/`gtimeout`/`dd` fallback)
- **`last_assistant_message` support** in `stop-session-evaluator.sh`: reads CC 2.1.47+ Stop payload
  - Stores message length + SHA-256 hash only (no plaintext — privacy by design)
  - Atomic writes via `mktemp` (TOCTOU fix)
  - Portable hash detection (`shasum`/`sha256sum`)
- **CC 2.1.49 compatibility matrix** (`docs/CLAUDE_CODE_COMPATIBILITY.md`): added v2.1.43-v2.1.49 entries covering Plugin settings.json, Worktree isolation, Background agents, ConfigChange hook, Sonnet 4.6, WASM memory fix

### Changed

- **Breezing: Worktree isolation support** (CC 2.1.49+): documented `isolation: "worktree"` in `guardrails-inheritance.md` — parallel Implementers can now work on the same files without conflicts via git worktree isolation
- **Breezing: Agent model field fix** (CC 2.1.47+): documented model field behavior change in guardrails for correct agent spawning
- **Breezing: Background agents** (`background: true`): `video-scene-generator` agent now supports non-blocking background execution
- **Breezing: opencode mirror full sync**: all 10 breezing reference files (execution-flow, team-composition, review-retake-loop, session-resilience, planning-discussion, plans-to-tasklist, codex-engine, codex-review-integration, guardrails-inheritance, SKILL.md) synced to `opencode/skills/breezing/` for the first time
- **Breezing: Codex mirror updates**: all breezing reference files in `codex/.codex/skills/breezing/` updated to latest
- **Work skill**: major Codex mirror updates for auto-commit, auto-iteration, codex-engine, error-handling, execution-flow, parallel-execution, review-loop, scope-dialog, session-management
- **`quick-install.sh`**: added note that default security permissions apply automatically — no manual configuration needed
- **`claude-settings.md` skill**: added note that CC 2.1.49+ auto-applies plugin settings; manual `settings.json` generation only needed for project-specific additions
- **`settings.security.json.template`**: updated `_harness_version` and added `_harness_note` clarifying role separation from plugin settings; unified `rm -rf/-fr` deny variants
- **Version references**: updated from CC 2.1.38 to 2.1.49 across 16+ skill and agent files

### Security

- **Least-privilege enforcement**: removed overly broad `allow` from plugin settings.json; all permissions now explicit deny or ask
- **DB CLI deny rules**: `psql`, `mysql`, `mongod`, `mongo` blocked by default to prevent accidental data operations
- **Secret path expansion**: added `id_ed25519`, recursive `.ssh/`, `.aws/`, `.npmrc` to deny patterns
- **Privacy-safe session logging**: `last_assistant_message` stored as length+hash, not plaintext
- **Atomic file writes**: `session.json` updates use `mktemp` + `mv` to prevent TOCTOU race conditions
- All 3 Codex experts (Security/Quality/Architect) scored A on hardening review

---

## [2.21.0] - 2026-02-20

### 🎯 What's Changed for You

**Breezing now reviews your plan before coding starts. Phase 0 (Planning Discussion) runs by default—skip with `--no-discuss`.**

| Before | After |
|--------|-------|
| `/breezing` jumps straight into coding | Plan reviewed by Planner + Critic before implementation |
| No task validation before execution | V1–V5 checks (scope, ambiguity, overlap, deps, TDD) |
| All tasks registered at once | 8+ tasks auto-split into progressive batches |
| Implementers communicate only via Lead | Implementers can message each other directly |

### Added

- **Breezing Planning Discussion (Phase 0)**: pre-execution plan review with Planner + Critic teammates (default-on, skip with `--no-discuss`)
- **Task granularity validation (V1–V5)**: validates task scope, ambiguity, owns overlap, dependency consistency, and TDD markers before TaskCreate
- **Progressive Batch strategy**: automatic batch splitting for 8+ tasks with 60% completion triggers
- **Implementer peer communication (Pattern D)**: direct Implementer-to-Implementer knowledge sharing via SendMessage
- **Hook-driven signals**: `task-completed.sh` now generates `partial_review_recommended` and `next_batch_recommended` signals
- **Spec Driven Development integration**: `[feature:tdd]` markers in Plans.md trigger test-first task generation
- **New agents**: `plan-analyst` (task analysis) and `plan-critic` (Red Teaming review) for Phase 0

### Fixed

- **Signal threshold comparison**: Changed `-eq` to `-ge` in `task-completed.sh` to handle simultaneous task completions that skip exact threshold
- **Signal deduplication**: Added existing signal check before emitting to prevent duplicate signals
- **Signal generation fallback**: Added `python3` fallback for signal JSON generation when `jq` is unavailable
- **Completion counting**: Fixed `grep -c` overcounting in batch scope (now counts each task_id once regardless of retakes)
- **Document consistency**: Resolved contradictions between execution-flow.md, team-composition.md, and planning-discussion.md regarding round counts and V1-V4 skip policy
- **Signal session scoping**: Signals now include `session_id` and dedup is session-scoped, preventing prior sessions from suppressing signals
- **grep pattern safety**: Changed `grep -q` to `grep -Fq` (fixed-string match) for task_id lookups, preventing regex meta-character injection
- **stdin piping safety**: Changed `echo` to `printf '%s'` for JSON piping to jq/python3, preventing edge-case mangling
- **DRY signal construction**: Extracted `_build_signal_json` helper to eliminate jq/python3 fallback duplication in signal paths
- **Phase 0 handoff persistence**: Added `handoff` payload to breezing-active.json for Compaction resilience between Phase 0 and Phase A
- **Resume stale-ID reconciliation**: Added rules for mapping old task IDs to new IDs during session resume, with completion evaluation against active ID set

---

## [2.20.13] - 2026-02-19

### What's Changed

**Codex execution is now documented and validated as native multi-agent first, with `--claude` forcing both implementation and review delegation to Claude.**

| Before | After |
|--------|-------|
| Codex skill docs still mixed legacy task-team vocabulary and old state paths | Codex skill docs are aligned to native multi-agent tool flow (`spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`) and CODEX_HOME state paths |
| `--claude` behavior could read as implementation-only delegation in some references | `--claude` is now consistently specified as implementation + review delegation to Claude |
| Setup could leave `multi_agent` / role defaults implicit | Setup scripts now ensure `features.multi_agent=true` and harness agent role defaults in target `config.toml` |

### Changed

- Rewrote Codex distribution docs for `work`/`breezing` to use native multi-agent flow terminology and removed legacy task-team wording.
- Standardized runtime state references to `${CODEX_HOME:-~/.codex}/state/harness/` across Codex skill docs.
- Added explicit flag conflict rule: `--claude + --codex-review` fails before execution.
- Updated Codex setup references and README to reflect native multi-agent defaults and role declarations.
- Strengthened `tests/test-codex-package.sh` and CI to guard against legacy vocabulary regressions and enforce required multi-agent keywords/config defaults.

### Fixed

- Fixed inconsistent review routing by making `--claude` mode explicitly require Claude reviewer routing in both `work` and `breezing`.

---
## [2.20.11] - 2026-02-19

### Changed

- **Harness UI moved out of distribution scope**: tracked UI assets/skills/templates/hooks are excluded from release payload
- **SessionStart hooks simplified**: removed `harness-ui-register` execution from startup/resume

### Fixed

- **Issue #50**: removed distribution-path dependency on memory wrapper scripts with hardcoded absolute paths
  - distribution no longer tracks the 8 wrapper files (`scripts/harness-mem*`, `scripts/hook-handlers/memory-*.sh`)
  - hooks/config no longer reference those wrapper scripts

---

## [2.20.10] - 2026-02-18

### What's Changed

**Codex Harness now defaults to user-based installation, and Codex command execution is Codex-first with explicit `--claude` delegation.**

| Before | After |
|--------|-------|
| Codex setup copied `.codex` per project by default | Setup defaults to user scope (`${CODEX_HOME:-~/.codex}`), with `--project` as opt-in |
| `/work --codex` and `/breezing --codex` were primary for Codex execution | Codex is default engine; `--claude` explicitly delegates implementation |
| Codex setup guidance was mixed between project/user scopes | README + setup references are aligned to user-based rollout (JP/EN) |

### Changed

- Updated Codex setup scripts (`scripts/setup-codex.sh`, `scripts/codex-setup-local.sh`) to install skills/rules to `${CODEX_HOME:-~/.codex}` by default.
- Added explicit fallback mode `--project` for project-local deployment when needed.
- Updated Codex distribution docs and setup references to user-based defaults in both English and Japanese.
- Reworked Codex skill routing/docs so implementation intents resolve to Codex-first `/work`, with `--claude` for intentional delegation.
- Aligned `/breezing` recovery/state docs (`impl_mode`) with Codex-first runtime semantics.
- Synced release-related references and command docs to avoid setup drift between README, setup skill references, and Codex distribution docs.

---
## [2.20.9] - 2026-02-15

### 🎯 What's Changed for You

**In Codex mode, `harness-review` guidance is now consistently documented as delegating to Claude CLI (`claude -p`).**

| Before | After |
|--------|-------|
| Codex-side review docs mixed Codex/MCP wording and delegation targets | Codex-side docs consistently describe Claude CLI (`claude -p`) delegation flow |

### Changed

- Updated Codex-side review docs to align review mode wording, integration flow, and detection guidance around `claude -p` delegation.
- Documentation consistency cleanup for Codex review-mode references.

---
## [2.20.8] - 2026-02-14

### Changed

- **Claude Code 2.1.41/2.1.42 adaptation**: Updated compatibility matrix and recommended version to v2.1.41+
  - Added v2.1.39〜v2.1.42 entries to `docs/CLAUDE_CODE_COMPATIBILITY.md` (4 new version sections, 30+ feature rows)
  - Recommended version raised from v2.1.38+ to **v2.1.41+** (Agent Teams Bedrock/Vertex/Foundry model ID fix, Hook stderr visibility fix)
- **Breezing Bedrock/Vertex/Foundry note**: Added CC 2.1.41+ requirement note to `guardrails-inheritance.md` for non-Anthropic API users
- **Session `/rename` auto-naming**: Added CC 2.1.41+ auto-generate session name documentation to session skill
- **Troubleshoot `claude auth` commands**: Added CC 2.1.41+ `claude auth login/status/logout` to diagnostic table

---
## [2.20.7] - 2026-02-14

### Fixed

- **Stop hook "JSON validation failed" on every turn (#42)**: Replaced unreliable `type: "prompt"` hook with deterministic `type: "command"` hook (`stop-session-evaluator.sh`)
  - Root cause: prompt-type hook instructed the LLM to respond in JSON, but the model frequently returned natural language, causing repeated JSON parse errors
  - New command-based evaluator always outputs valid JSON, eliminating validation failures entirely
  - Both `hooks/hooks.json` and `.claude-plugin/hooks.json` updated in sync

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

- **Breezing `--codex` subagent_type enforcement**: Fixed `--codex` flag being ignored during Implementer spawn
  - Root cause: `execution-flow.md` Step 3 hardcoded `task-worker` with no `--codex` branch
  - Added mandatory `impl_mode` branching to SKILL.md, execution-flow.md, and team-composition.md
  - Added three "absolute prohibition" rules: codex mode must use `codex-implementer`, standard mode must use `task-worker`, codex mode Lead must not Write/Edit source
  - Added explicit parallel spawn instruction: N Implementers spawned simultaneously (`N = min(independent_tasks, --parallel N, 3)`)
  - Compaction Recovery now restores correct subagent_type based on `impl_mode`

---

## [2.20.4] - 2026-02-11

### Fixed

- **Codex MCP → CLI migration (Phase 7 completion)**:
  - Replace all `mcp__codex__codex` text references with `codex exec (CLI)` in `pretooluse-guard.sh` (4 messages) and `codex-worker-engine.sh` (1 log message)
  - Remove MCP legacy note from `codex-review/SKILL.md`
  - Add `codex-cli-only.md` rule to `.claude/rules/` for prevention
  - Add PreToolUse hook failsafe: deny `mcp__codex__*` tool calls with localized message via `emit_deny` + `msg()` pattern
  - Add `.gitignore` patterns for opencode/codex mirror dev-only skills (`test-*`, `x-promo`, `x-release-harness`)

### Security

- **Codex MCP dual-defense**: Three-layer protection against deprecated MCP usage (text correction + hook block + rule file). Codex review: Security A, Architect B

---

## [2.20.3] - 2026-02-10

### Fixed

- **Hook handler security hardening** (Codex review Round 1-3):
  - Replace manual JSON string escaping with `jq -nc --arg` and `python3 json.dumps` for safe JSON construction
  - Fix Python code injection vulnerability: pass data via `sys.argv`/`stdin` instead of triple-quote interpolation
  - Fix `grep` failure under `set -euo pipefail` with `|| true`
  - Use `grep -F` for fixed-string matching (avoid regex metacharacter issues)
  - Add `chmod 700` on `.claude/state` directory
  - Add `tostring` guard for description truncation type safety
  - Add 5-second dedup for TeammateIdle events
  - Add JSONL rotation (500 → 400 lines) to prevent unbounded growth

---

## [2.20.2] - 2026-02-10

### Added

- **TeammateIdle/TaskCompleted hook handlers**: New `scripts/hook-handlers/teammate-idle.sh` and `task-completed.sh` log agent team events to `.claude/state/breezing-timeline.jsonl`
- **3-layer memory architecture (D22)**: Documented coexistence design for Claude Code auto memory, Harness SSOT, and Agent Memory in `decisions.md`
- **Task(agent_type) pattern (P18)**: Documented sub-agent type restriction syntax in `patterns.md`

### Changed

- **Claude Code 2.1.38+ adaptation**: Updated Feature Table in CLAUDE.md with 6 new rows (TeammateIdle/TaskCompleted Hook, Agent Memory, Fast mode, Auto Memory, Skill Budget Scaling, Task(agent_type))
- **Version references**: Updated all "CC 2.1.30+" references to "CC 2.1.38+" across 16+ skill and agent files
- **Skill budget scaling**: Relaxed 500-line hard rule to recommendation in `skill-editing.md`, noting CC 2.1.32+ 2% context window scaling
- **Session memory**: Added "Auto Memory Relationship (D22)" section to `session-memory/SKILL.md` and `memory/SKILL.md`
- **Breezing execution flow**: Updated hook implementation status to "implemented" in `execution-flow.md`
- **Guardrails inheritance**: Added Task(agent_type) to safety mechanism table

---

## [2.20.1] - 2026-02-10

### Fixed

- **PostToolUse hook syntax error**: Fix bash parser error in `posttooluse-tampering-detector.sh` caused by `|| true` after heredoc inside command substitution
- **python3 fallback in all hooks**: Replace heredoc python3 fallback with `python3 -c` in all 10 hook scripts to fix stdin conflict
- **POSIX compliance**: Replace `echo` with `printf '%s'` for safe input piping, `echo -e` with `printf '%b'`
- **Pattern matching**: Replace `echo | grep -qE` with `[[ =~ ]]` for 6 pattern checks (with word boundaries)
- **Error handling**: Change `set -euo pipefail` to `set +e` to match all other PostToolUse scripts
- **Bilingual warnings**: Add English + Japanese warning messages to hook scripts

---

## [2.20.0] - 2026-02-08

### 🎯 What's Changed for You

**28 skills consolidated to 19. Breezing now runs with Phase A/B/C separation, teammate permissions fixed, and repo cleaned up.**

| Before | After |
|--------|-------|
| `memory`, `sync-ssot-from-memory`, `cursor-mem` as 3 skills | Unified `memory` (SSOT promotion + memory search in references) |
| `setup`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` as 6 skills | Unified `setup` (routing table dispatches to references) |
| `ci`, `agent-browser`, `x-release-harness` visible as slash commands | Hidden with `user-invocable: false` (auto-load still works) |
| Delegate mode ON at breezing start → bypass permissions lost | Phase A (prep) maintains bypass → delegate only in Phase B |
| Delegate mode stays on during completion → commit restricted | Phase C exits delegate → Lead can commit directly |
| Teammates auto-denied Bash due to "prompts unavailable" | `mode: "bypassPermissions"` + PreToolUse hooks for safety |
| Build artifacts, dev docs, lock files tracked in git | 33 files untracked, .gitignore updated |

### Changed

- **Skill consolidation (28 → 19)**:
  - `/memory`: Absorbed `sync-ssot-from-memory` and `cursor-mem`
  - `/setup`: Absorbed `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules`
  - `/troubleshoot`: Added CI failure triggers to description
- **Breezing Phase separation**: Restructured execution flow into Phase A (Pre-delegate) / Phase B (Delegate) / Phase C (Post-delegate)
  - Phase A: Maintain user's permission mode while initializing Team and spawning teammates
  - Phase B: Delegate mode — Lead uses only TaskCreate/TaskUpdate/SendMessage
  - Phase C: Exit delegate, then run integration verification, commit, and cleanup
- **Teammate permission model**: All teammate spawns use `mode: "bypassPermissions"` with PreToolUse hooks as safety layer
  - PreToolUse hooks fire independently of permission system (official spec)
  - Safety layers: disallowedTools + spawn prompt constraints + .claude/rules/ + Lead monitoring
- **English-only releases**: GitHub release notes now written in English. Updated release rules and skills.
- **All related docs updated**: execution-flow.md, team-composition.md, codex-engine.md, guardrails-inheritance.md, session-resilience.md

### Added

- `skills/memory/references/cursor-mem-search.md` - Cursor memory search reference
- `skills/setup/references/harness-mem.md` - Harness-Mem setup reference
- `skills/setup/references/localize-rules.md` - Rule localization reference
- **Codex first-use check hook**: Auto-runs `check-codex.sh` on first `/codex-review` use (`once: true`)
- **timeout/gtimeout detection**: Guides macOS users to `brew install coreutils`

### Fixed

- **Codex review fixes (22 issues)**: pretooluse-guard JSON parse consolidation (5→1 jq call), symlink security guard, session-monitor `eval` removal
- **macOS compatibility**: All docs `timeout N codex exec` → `$TIMEOUT N codex exec` (GNU coreutils independent)
- **Teammate Bash auto-deny**: Resolved "prompts unavailable" error for background teammates

### Removed

- **Untracked 33 files**: `mcp-server/dist/` (24 build artifacts), `docs/design/` (2), `docs/slides/` (1), `docs/claude-mem-japanese-setup.md`, dev-only docs (3), lock files (2)
- **Archived skills**: `sync-ssot-from-memory`, `cursor-mem`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` → `skills/_archived/`

---

## [2.19.0] - 2026-02-08

### 🎯 What's Changed for You

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
  - `--codex` フラグで Codex MCP 実装委託モード
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

### 🎯 What's Changed for You

**In `--codex` mode, Claude now acts as PM and Edit/Write are automatically blocked**

| Before | After |
|--------|-------|
| Claude could edit directly in `--codex` mode | Edit/Write blocked except for Plans.md |
| Ambiguous role separation | Clear PM (Claude) vs Worker (Codex) separation |

### Added

- **breezing skill (v2)**: Full auto task completion using Agent Teams
  - Lead in delegate mode (coordination only), Implementer for coding, independent Reviewer
  - `--codex-review` for multi-AI review integration
  - session_id-based Hook enforcement: Reviewer Read-only, Implementer file ownership (pretooluse-guard.sh)
  - Flexible flow: Lead-autonomous stages replace rigid Phase 0-4
  - State simplification: Agent Teams TaskList as SSOT, breezing-active.json metadata-only
  - Peer-to-peer: Reviewer↔Implementer direct dialogue for lightweight questions
  - Agent Trace: per-Teammate metrics in completion reports
- **Codex mode guard**: Added Codex mode detection to `pretooluse-guard.sh`
  - Claude functions as PM, delegating implementation to Codex Worker
  - Enabled via `codex_mode: true` in `ultrawork-active.json`
  - Only Plans.md state marker updates allowed

### Changed

- **Codex review improvements**: Enhanced parallel review quality
  - SSOT-aware reviews (considers decisions.md/patterns.md)
  - Output limit relaxed 1500 → 2500 chars for thorough analysis
  - Clear termination conditions (APPROVE when Critical/High = 0)
  - Fixed "nitpicking" issue (Low/Medium only → APPROVE)
- Minor expert template fixes

---

## [2.18.10] - 2026-02-06

### Added

- **Agent persistent memory**: Added `memory: project/user` to all 7 agents
  - Subagents can now build institutional knowledge across conversations
  - Security: Read-only agents (code-reviewer, project-analyzer) keep Bash/Write/Edit disabled
  - Privacy guards: Each agent documents forbidden data (secrets, PII, source code snippets)

---

## [2.18.7] - 2026-02-05

### Changed

- **Claude guardrails**: Stop prompting on normal `git push`; prompt only on `git push -f/--force/--force-with-lease`.

---

## [2.18.6] - 2026-02-05

### Fixed

- **Codex guardrails**: `harness.rules` now parses reliably and avoids prompting on safe commands (e.g. `git clean -n`, `sudo -n true`).
- **Claude guardrails**: `templates/claude/settings.security.json.template` now uses valid permission syntax (`:*`) and prompts only on destructive variants.

### Changed

- **Codex package test**: Added rule example validation to prevent startup parse errors.

---

## [2.18.5] - 2026-02-05

### Added

- **gogcli-ops skill**: Google Workspace CLI operations (Drive/Sheets/Docs/Slides)
  - Auth workflow and account selection
  - URL-to-ID resolution via `gog_parse_url.py`
  - Read-only by default, write requires confirmation

---

## [2.18.4] - 2026-02-04

### Added

- **Codex setup command**: Added `/codex-setup` skill and `scripts/codex-setup-local.sh`
- **Setup tools**: `/setup-tools codex` subcommand for in-session Codex setup
- **Harness init/update**: Optional Codex CLI sync during `/harness-init` and `/harness-update`

---

## [2.18.2] - 2026-02-04

### Added

- **Codex CLI distribution**: Added `codex/.codex` with full skills and temporary Rules guardrails
- **Codex setup**: Added `scripts/setup-codex.sh` and `codex/README.md`
- **Codex AGENTS**: Added `codex/AGENTS.md` tuned for `$skill` usage
- **Codex package test**: Added `tests/test-codex-package.sh`

### Changed

- **Docs**: README now includes Codex CLI setup instructions

---

## [2.18.1] - 2026-02-04

### Added

- **Aivis/VOICEVOX TTS support**: Added Japanese TTS providers to generate-video skill
  - `aivis`: Aivis Cloud API (speaker_id, intonation_scale, etc.)
  - `voicevox`: VOICEVOX (character voices like Zundamon)
  - Sample character configurations included

### Changed

- **MCP server optional**: Removed `.mcp.json`, excluded mcp-server from distribution
  - Users who need it can set up separately

---

## [2.18.0] - 2026-02-04

### Added

- **Claude Code 2.1.30 compatibility**: Full integration with new features
  - **AgentTrace v0.3.0**: Task tool metrics (tokenCount, toolUses, duration) in `docs/AGENT_TRACE_SCHEMA.md`
  - **`/debug` command integration**: troubleshoot skill now routes to `/debug` for complex session issues
  - **PDF page range reading**: notebookLM and harness-review support `pages` parameter for large documents
  - **Git log extended flags**: harness-review, CI, harness-release use `--format`, `--raw`, `--cherry-pick`
  - **OAuth `--client-id/--client-secret`**: codex-mcp-setup.md documents DCR-incompatible MCP setup
  - **68% memory optimization**: session-memory and session skills document `--resume` benefits
  - **Subagent MCP access**: task-worker and codex-worker document MCP tool sharing (bugfix in CC 2.1.30)
  - **Accessibility settings**: harness-ui documents `reducedMotion` setting

---

## [2.17.10] - 2026-02-04

### Added

- **PreCompact/SessionEnd hooks**: Support automatic session state save and cleanup
- **AgentTrace v0.2.0**: Added Attribution field for plugin attribution tracking
- **Sandbox settings template**: Added `templates/settings/harness-sandbox.json`

### Changed

- **context: fork added**: deploy/generate-video/memory/verify skills now use isolated context
- **release → harness-release**: Renamed to avoid conflict with Claude Code built-in command

---

## [2.17.9] - 2026-02-04

### Changed

- **Codex mode as default**: New project config template now defaults to `review.mode: codex`
- **Worktree necessity check**: `/ultrawork --codex` now auto-determines if Worktree is actually needed
  - Single task, all sequential dependencies, or file overlap → fallback to direct execution mode
  - Avoids unnecessary Worktree creation overhead

---

## [2.17.8] - 2026-02-04

### Fixed

- **release skill**: Fix `/release` not launching via Skill tool
  - Removed `disable-model-invocation: true`

---

## [2.17.6] - 2026-02-04

### 🎯 What's Changed for You

**generate-video スキルが JSON Schema 駆動のハイブリッドアーキテクチャに進化、README も刷新されました**

| Before | After |
|--------|-------|
| 動画生成の設定がコードに散在 | JSON Schema でシナリオを一元管理 |
| README の構成が長大 | TL;DR: Ultrawork セクションで即座に始められる |
| スキル説明が英語のみ | 28個のスキル description が日本語化 + ユーモア表現 |

### Added

- **generate-video JSON Schema Architecture** (#37)
  - `scenario-schema.json` でシナリオ構造を厳密定義
  - `validate-scenario.js` でセマンティック検証
  - `template-registry.js` でテンプレート管理
  - パストラバーサル攻撃対策を実装

- **TL;DR: Ultrawork セクション**: README に「説明が長い？これだけ」セクション追加
  - 日本語版にも「🪄 説明が長い？ならこれ: Ultrawork」として追加

### Changed

- **スキル description 日本語化**: 28個のスキルに日本語の説明とユーモア表現を追加
- **README 構成整理**: Install → TL;DR → Core Loop の流れに最適化
- **スキル数更新**: 42 → 45 スキル

### Fixed

- `validate-scenario.js`: セマンティックエラーフィルタリングのバグ修正
- `TransitionWrapper.tsx`: `slideIn` → `slide_in` でスキーマ命名規則に統一

---

## [2.17.3] - 2026-02-03

### 🎯 What's Changed for You

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

### 🎯 What's Changed for You

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

- **Agent Trace**: Track AI-generated code edits for session context visibility
  - `emit-agent-trace.js`: PostToolUse hook records Edit/Write operations to `.claude/state/agent-trace.jsonl`
  - `agent-trace-schema.json`: JSON Schema (v0.1.0) for trace records
  - Stop hook now shows project name, current task, and recent edits at session end
  - `sync-status` skill now includes Agent Trace data for progress verification
  - `session-memory` skill now reads Agent Trace for cross-session context

### Changed

- Stop hook (`session-summary.sh`) enhanced with Agent Trace information display
- VCS info retrieval optimized: single `git status --porcelain=2 -b -uno` call with 5s TTL cache
- Repo root detection no longer spawns git process (walks up directory tree)

### Fixed

- Security hardening for trace file operations (symlink checks, permission enforcement)
- Rotation concurrency protection with lock file (O_CREAT|O_EXCL pattern)

---

## [2.17.0] - 2026-02-03

### Added

- **Codex Worker**: Delegate implementation tasks to OpenAI Codex as parallel workers
  - `codex-worker` skill for single task delegation
  - `ultrawork --codex` for parallel worker execution with git worktrees
  - Quality gates: evidence verification, lint/type-check, test, tampering detection
  - File locking mechanism with TTL and heartbeat
  - Automatic Plans.md update on task completion

### Changed

- Skills `codex-worker` and `codex-review` now have explicit routing rules (Do NOT Load For sections)
- Improved skill description for better auto-loading accuracy
- Added 5 shell scripts: `codex-worker-setup.sh`, `codex-worker-engine.sh`, `codex-worker-lock.sh`, `codex-worker-quality-gate.sh`, `codex-worker-merge.sh`
- Added integration test: `tests/test-codex-worker.sh`
- Added reference documentation: `skills/codex-worker/references/*.md`

### Fixed

- Shell script security improvements (jq injection, git option injection, value validation)
- POSIX compatibility for grep patterns (`\s` to `[[:space:]]`)
- Arithmetic operation in `set -e` context

---

## [2.16.21] - 2026-02-03

### Changed

- `ultrawork` Codex Mode options (`--codex`, `--parallel`, `--worktree-base`) moved to Design Draft
  - These features are planned but not yet implemented
  - Documentation now clearly marks them as "(Design Draft / 未実装)"
- Added `skills/ultrawork/references/codex-mode.md` as design draft documentation
- Added Codex Worker scripts and references (untracked, for future implementation)

---

## [2.16.20] - 2026-02-03

### Changed

- Centralized skill routing rules to `skills/routing-rules.md` (SSOT pattern)
- Made `codex-review` and `codex-worker` routing deterministic (removed context judgment)

---

## [2.16.19] - 2026-02-03

### Fixed

- Reduced duplicate display of Stop hook reason (now outputs keywords only)

---

## [2.16.17] - 2026-02-03

### 🎯 What's Changed for You

**Skills now show usage hints in autocomplete**

| Before | After |
|--------|-------|
| `/harness-review` | `/harness-review [code|plan|scope]` |
| `/troubleshoot` | `/troubleshoot [build|test|runtime]` |

### Added

- Usage hints (`argument-hint`) added to 17 skills
- Inter-session notifications (useful for multi-session workflows)

### Changed

- Updated CI/tests/docs for Skills-only architecture

---

## [2.16.14] - 2026-02-02

### 🎯 What's Changed for You

**Implementation requests are now automatically registered in Plans.md**

| Before | After |
|--------|-------|
| Ad-hoc requests not tracked | All tasks recorded in Plans.md |
| Hard to track progress | `/sync-status` shows full picture |

---

## [2.16.11] - 2026-02-02

### 🎯 What's Changed for You

**Commands have been unified into Skills (usage unchanged)**

| Before | After |
|--------|-------|
| `/work`, `/harness-review` as commands | Same names, now powered by skills |
| Internal skills (impl, verify) in menu | Hidden (less noise) |
| `dev-browser`, `docs`, `video` | Renamed to `agent-browser`, `notebookLM`, `generate-video` |

### Changed

- README rewritten for VibeCoders (added troubleshooting, uninstall)
- CI scripts updated for Skills structure

---

## [2.16.5] - 2026-01-31

### 🎯 What's Changed for You

**`/generate-video` now supports AI images, BGM, subtitles, and visual effects**

| Before | After |
|--------|-------|
| Manual image preparation | AI auto-generates (Nano Banana Pro) |
| No BGM/subtitles | Royalty-free BGM, Japanese subtitles |
| Basic transitions only | GlitchText, Particles, and more |

---

## [2.16.0] - 2026-01-31

### 🎯 What's Changed for You

**`/ultrawork` now requires fewer confirmations for rm -rf and git push (experimental)**

| Before | After |
|--------|-------|
| rm -rf always asks | Only paths approved in plan auto-approved |
| git push always asks | Auto-approved during ultrawork (except force) |

---

## [2.15.0] - 2026-01-26

### 🎯 What's Changed for You

**Full OpenCode compatibility mode added**

| Before | After |
|--------|-------|
| Separate setup needed for OpenCode | `/setup-opencode` auto-configures |
| Different skills/ structure | Same skills work in both environments |

---

## [2.14.0] - 2026-01-16

### 🎯 What's Changed for You

**`/work --full` enables parallel task execution**

| Before | After |
|--------|-------|
| Tasks run one at a time | `--parallel 3` runs up to 3 concurrently |
| Manual completion checks | Each worker self-reviews autonomously |

---

## [2.13.0] - 2026-01-14

### 🎯 What's Changed for You

**Codex MCP parallel review added**

| Before | After |
|--------|-------|
| Claude reviews alone | 4 Codex experts review in parallel |
| One perspective at a time | Security/Quality/Performance/a11y simultaneously |

---

## [2.12.0] - 2026-01-10

### Added

- **Harness UI Dashboard** (`/harness-ui`) - Track progress in browser
- **Browser Automation** (`agent-browser`) - Page interactions & screenshots

---

## [2.11.0] - 2026-01-08

### Added

- **Inter-session Messaging** - Send/receive messages between Claude Code sessions
- **CRUD Auto-generation** (`crud` skill) - Generate endpoints with Zod validation

---

## [2.10.0] - 2026-01-04

### Added

- **LSP Integration** - Go-to-definition, Find-references for accurate code understanding
- **AST-Grep Integration** - Structural code pattern search

---

## Earlier Versions

For v2.9.x and earlier, see [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases).

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.1...HEAD
[3.10.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.0...v3.10.1
[3.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.9.0...v3.10.0
[3.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.2...v3.9.0
[3.7.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.1...v3.7.2
[3.7.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.0...v3.7.1
[3.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.6.0...v3.7.0
[3.4.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.0...v3.4.1
[3.4.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.1...v3.4.2
[3.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.2...v3.5.0
[3.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.1...v3.4.0
[3.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.0...v3.3.1
[3.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.2.0...v3.3.0
[2.26.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.26.0...v2.26.1
[2.26.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.25.0...v2.26.0
[2.25.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.24.0...v2.25.0
[2.24.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.6...v2.24.0
[2.23.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.5...v2.23.6
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
[2.20.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.11...v2.19.0
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
[2.17.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.6...v2.17.8
[2.17.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.3...v2.17.6
[2.17.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.2...v2.17.3
[2.17.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.1...v2.17.2
[2.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.0...v2.17.1
[2.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.21...v2.17.0
[2.16.21]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.20...v2.16.21
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
