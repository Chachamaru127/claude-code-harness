---
name: harness-plan
description: "HAR: Research-backed, team-validated task planning, Plans.md management, progress sync. Trigger: create a plan, add tasks, update Plans.md, mark complete, check progress. Do NOT load for: implementation, review, release."
description-en: "HAR: Research-backed, team-validated task planning, Plans.md management, progress sync. Trigger: create a plan, add tasks, update Plans.md, mark complete, check progress. Do NOT load for: implementation, review, release."
description-ja: "HAR:調査・採点・記憶確認・TeamAgent/サブエージェント検証つきのタスク計画、Plans.md管理、進捗同期を担当。計画作って、タスク追加、Plans.md更新、完了マーク、進捗確認で起動。実装・レビュー・リリースには使わない。"
kind: workflow
purpose: "Maintain co-required planning output for the spec.md product contract and Plans.md task contract"
trigger: "create a plan, add tasks, update Plans.md, check progress"
shape: workflow
role: generator
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Task"]
argument-hint: "[create|add|update|sync|sync --no-retro|--ci]"
user-invocable: true
effort: medium
---

# Harness Plan

Harness の統合プランニングスキル。
以下の3つの旧スキルを統合:

- `planning` (plan-with-agent) — アイデア → Plans.md への落とし込み
- `plans-management` — タスク状態管理・マーカー更新
- `sync-status` — Plans.md と実装の同期確認

## Quick Reference

| ユーザー入力 | サブコマンド | 動作 |
|------------|------------|------|
| "計画を作って" / `/harness-plan create` | `create` | Spec delta / skip reason → Plans.md task 生成 |
| "タスクを追加して" / `/harness-plan add` | `add` | Plans.md に新タスク追加 |
| "完了にして" / `/harness-plan update` | `update` | タスクマーカーを cc:完了 に変更 |
| "今どこ？" / `/harness-plan sync` | `sync` | 実装とPlans.mdを照合・同期 |
| `/harness-sync` | `sync` | 進捗確認（独立 sync surface と同等） |
| `/harness-plan create` | `create` | spec.md / Plans.md 二正本の計画作成 |
| `/harness-plan list` | `list` | `plans/manifest.json` の named Plans を一覧 |
| `/harness-plan switch <name>` | `switch` | active plan を `.claude/state/active-plan.json` に保存 |

## Literal companion commands（CC 2.1.108+）

- `/recap`: 久しぶりに戻った時に要約を取り直してから `sync` へ入る
- `/undo`: `/rewind` の別名。直前の plan 更新を即座に戻したい時にそのまま使う

## サブコマンド詳細

### 標準の計画品質契約

See [references/planning-quality.md](${CLAUDE_SKILL_DIR}/references/planning-quality.md)

`harness-plan` は、spec.md product contract and Plans.md task contract の co-required planning output を作る planning surface である。
precedence は `spec.md > sub-spec > Plans.md` のまま維持する。
Plans.md は task ledger、root `spec.md` は product contract であり、上下関係は崩さない。
渡された情報をそのまま Plans.md に落とさない。
計画作成や大きな task 追加では、最新情報・既存仕様・記憶・TeamAgent / サブエージェントによる複数視点の議論を確認し、
このプロダクトに取り入れるべき要素だけを task contract に変換する。
`/harness-plan create` は `Spec delta` または `Spec skip reason` と `Plans.md` task 生成をセットで返す。
出力には必ず `Spec delta` または `Spec skip reason` を含める。
`Spec delta` / `Spec skip reason` は Harness が生成し、consumer は承認・修正だけ行う。

**Non-trivial planning gate**:

単発・軽微タスクでない planning は、TeamAgent またはサブエージェント前提で扱う。
ここでの non-trivial は、複数 task / 複数 file / 複数 session / product behavior / API / data model / 権限 / 課金 / 外部連携 / 配布面 / セキュリティに影響する依頼を指す。
Task tool が使える場合は Product / Architecture / Security / QA / Skeptic の独立視点を走らせる。
使えない場合は `サブエージェント未使用` と明示し、同じ観点を単独で分けて評価する。

non-trivial planning の出力には、次の検証を必ず含める。

- `team_validation_mode`: `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable`
- `spec.md` / sub-spec / `Plans.md` の整合性
- harness-mem / harness-recall / repo memory による車輪の再発明防止確認
- プロダクト目的から外れていないか
- セキュリティ、権限、秘密情報、サプライチェーンに問題がないか
- lint / formatter baseline があるか。source code changes を含む plan で未設定なら、実装 task の前に setup task を置く
- ちゃんと動く計画か。つまり test / smoke / CI / review / release gate が task DoD に落ちているか

軽量 task は `team_validation_mode: not_required_lightweight` でよい。
non-trivial planning は `native` / `subagent` / `manual-pass` のいずれかを使う。
`unavailable` のまま Required にしてはいけない。
Product / Architecture / Security / QA / Skeptic は検証 perspective であり、agent_type 名ではない。
利用可能な TeamAgent / Task サブエージェントに perspective として依頼し、任意 agent spawn を要求しない。
Security gate は秘密情報の実読取を要求しない。
`.env` や secret の read が必要になる場合は Risk Gate として止め、許可された既存 guard / evidence で確認する。

**適用する場面**:

- `create` で新しい計画を作る
- `add` で product behavior / API / 権限 / 課金 / 外部連携 / 配布面に影響する task を足す
- ユーザーが外部プロダクト、競合、仕様案、改善案、比較材料を渡した
- 既存仕様や過去判断との衝突リスクがある

**軽く扱ってよい場面**:

- marker 更新だけの `update`
- status 照合だけの `sync`
- typo、format、README/CHANGELOG のみ
- 既存 spec とテストで正解が固定されている狭い変更

**品質フロー**:
1. 入力情報を分解し、評価対象・採点軸・不確かな事実を明示する
2. 最新情報を取得する。外部事実は WebSearch / 公式ドキュメント / 一次情報を優先し、重要点は複数ソースでクロスチェックする
3. 既存仕様・root `spec.md`・Plans.md・README・docs・CLAUDE.md・関連 skill を確認する
4. harness-mem / harness-recall / `.claude/agent-memory/` / `.claude/state/` など、利用可能な記憶面を project-scoped で確認する
5. non-trivial planning では TeamAgent / Task サブエージェントを使い、Product / Architecture / Security / QA / Skeptic など異なる視点で独立レビューする
6. source code changes を含む plan では lint / formatter baseline を確認し、未設定なら setup task を先行させる
7. 中立的な採点レビューを出し、Required / Recommended / Optional / Reject に分類する
8. `$easy` 形式で、提案内容・理由・どうなるのかを報告する
9. 採用する案だけを root `spec.md` / Plans.md / test task へ落とし込む

### create — 計画作成

See [references/create.md](${CLAUDE_SKILL_DIR}/references/create.md)

アイデア・要件をヒアリングし、実行可能な Plans.md を生成する。

**フロー**:
1. 会話コンテキスト確認（直前の議論から抽出 or 新規ヒアリング）
2. 何を作るか聞く（max 3問）
3. **計画品質チェック**（最新情報、既存仕様、記憶、TeamAgent / サブエージェント複数視点レビュー、採点）
4. 技術調査（WebSearch）
5. 機能リスト抽出
6. **spec.md / Plans.md 二正本チェック**（Spec delta または Spec skip reason + Plans.md task）
7. 優先度マトリクス（Required / Recommended / Optional / Reject）
8. TDD 採用判断（テスト設計）
9. Plans.md 生成（`cc:TODO` マーカー付き）
10. 次のアクション案内

### spec.md / Plans.md 二正本チェック（デフォルト）

Plans.md は「やるべきこと」の task contract、root `spec.md` は「何が正しいか」の product contract として扱う。
co-required planning output は両方の出力を必須にするという意味であり、precedence は `spec.md > sub-spec > Plans.md` のまま維持する。
実装がぶれる可能性がある時は、Plans.md 生成前に root `spec.md` を更新する。
`create` と product-impacting `add` は毎回 root `spec.md` を読む。

優先する保存先:

1. root `spec.md`
2. consumer repo に root `spec.md` がない時だけ、既存の project spec / architecture / product compass
3. consumer repo に root `spec.md` がない時だけ、`docs/spec/00-project-spec.md`
4. 既存規約がある repo では、その規約に沿った spec path

作成/更新が必要な条件:

- ユーザーに見える振る舞い、API、データモデル、権限、課金、外部連携を決める task
- 複数の実装方針があり、選び方で product behavior が変わる task
- 過去または今回の会話で「仕様が曖昧で実装がぶれた」兆候がある task
- Plans.md には作業内容があるが、project としての正解条件が安定文書にない task

不要な条件:

- typo、format、dependency bump、README/CHANGELOG のみ
- 動作変更なしの狭い refactor
- 既存 spec とテストで正解が十分に固定されている修正

出力契約:

- `Spec delta`: product contract を更新する時に、対象 spec path と変更点を書く
- `Spec skip reason`: product contract を更新しない時に、理由を書く
- `Spec delta` / `Spec skip reason` は Harness が生成し、consumer は承認・修正だけ行う
- docs-only / mechanical task でも `Spec skip reason` を task context / sprint contract に残す
- missing search result、unavailable memory、未読ファイルを absent と断定しない。`not_observed != absent`
- ユーザーに spec を一から書かせない。agent が既存 spec と入力から最小 delta を作り、曖昧な時だけ判断分岐を出す

参照:

- `docs/plans/spec-ssot.md`

### create 完了時のセッション起動案内（必須）

`create` が終わったら、説明だけで終わらせず、**新しいセッションの起動コマンド** と
**起動後にそのまま入れる最初の指示プロンプト** をセットで案内する。

優先順位は次の通り:

1. 未完了タスクが 1 件だけ、または最初の 1 件だけ始めるのが自然
   - 起動コマンド: `claude`
   - 最初の入力: `/harness-work <task番号>`
2. 依存の薄いタスクが複数あり、まとめて進めるのが自然
   - 起動コマンド: `claude`
   - 最初の入力: `/breezing all`
   - 代替: `/harness-work all`
3. 長時間実行や再入が前提
   - 起動コマンド: `ENABLE_PROMPT_CACHING_1H=1 claude`
   - 最初の入力: `/harness-loop all`
   - 代替: `/breezing all`

最低でも次の 3 行を含める:

- `新しいセッションの起動コマンド:`
- `起動後の最初の入力:`
- `向いている場面:`

例:

```text
新しいセッションの起動コマンド: claude
起動後の最初の入力: /breezing all
向いている場面: Phase 1 の task が複数あり、まとめて進めるほうが自然なため
```

長時間系を勧める場合は、Claude Code セッション起動コマンドも併記する:

```text
新しいセッションの起動コマンド: ENABLE_PROMPT_CACHING_1H=1 claude
起動後の最初の入力: /harness-loop all
向いている場面: 5 分を超える待機や resume をまたぐ長時間タスクのため
```

補足:

- `scripts/claude-longrun.sh` はこのリポジトリの開発補助スクリプトで、plugin install 後の consumer 環境には配布されない
- そのため、consumer 向け案内では常に `ENABLE_PROMPT_CACHING_1H=1 claude` の 1 行コマンドを優先する
- リポジトリ開発中だけ同等のラッパーを使いたい場合、`bash scripts/claude-longrun.sh` はローカル checkout 上では利用してよい

**CI モード** (`--ci`):
ヒアリングなし。既存の Plans.md をそのまま利用してタスク分解のみ行う。

### add — タスク追加

Plans.md に新しいタスクを追加する。
product-impacting な追加では、上の「spec.md / Plans.md 二正本チェック」に従い `Spec delta` または `Spec skip reason` も出力する。

```
/harness-plan add タスク名: 詳細説明 [--phase フェーズ番号]
```

タスクは `cc:TODO` マーカーで追加される。

### update — マーカー更新

タスクのステータスマーカーを変更する。

```
/harness-plan update [タスク名|タスク番号] [WIP|完了|blocked]
```

マーカー対応表:

| コマンド | マーカー |
|---------|---------|
| `WIP` | `cc:WIP` |
| `完了` / `done` | `cc:完了` |
| `blocked` | `blocked` |
| `TODO` | `cc:TODO` |

### sync — 進捗同期

実装状況と Plans.md を照合し、差分を検出・更新する。

See [references/sync.md](${CLAUDE_SKILL_DIR}/references/sync.md)

**フロー**:
1. Plans.md の現状取得
2. Plans.md フォーマット検出（v1: 3 カラム / v2: 5 カラム）
3. git status / git log から実装状況取得
4. エージェントトレース確認（`.claude/state/agent-trace.jsonl`）
5. Plans.md と実装の差分検出
6. 未更新マーカーの自動修正提案
7. 次のアクション提示

**レトロスペクティブ**（デフォルト ON）:
`cc:完了` タスクが 1 件以上あれば自動的に振り返りを実行する。
見積もり精度、ブロック原因パターン、スコープ変動を分析し、学びを記録。
`sync --no-retro` で明示的にスキップ可能。

### team mode / issue bridge

Plans.md は正本のまま維持し、GitHub Issue 連携は opt-in の team mode だけで使う。

- solo 開発では bridge を使わない
- team mode は tracking issue を 1 つ作り、その配下に task ごとの sub-issue payload を dry-run で生成する
- `scripts/plans-issue-bridge.sh` は実際に GitHub を更新せず、常に dry-run の payload を返す
- Plans.md への変更はこの bridge では行わない

参照:

- `docs/plans/team-mode.md`

### named Plans

複数の Plans.md を使う場合は `plans/manifest.json` を正本にして、名前で選択する。

```bash
scripts/plan-registry.sh list
scripts/plan-registry.sh switch roadmap
scripts/plans-issue-bridge.sh --plan roadmap --format markdown
node scripts/generate-sprint-contract.js --plan roadmap 9.1.1
```

運用ルール:

- 1 run では 1 つの named plan だけを使う
- long-running / CI / issue bridge では active pointer に頼らず `--plan <name>` を渡す
- manifest path は project root 相対のみ。絶対パス、`..`、repo 外 symlink は拒否される

参照:

- `docs/plans/named-plans.md`

## Plans.md フォーマット規約

### フォーマット

```markdown
# [プロジェクト名] Plans.md

作成日: YYYY-MM-DD

---

## Phase N: フェーズ名

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| N.1  | 説明 | テスト通過 | - | cc:TODO |
| N.2  | 説明 | lint エラー 0 | N.1 | cc:WIP |
| N.3  | 説明 | マイグレーション実行可能 | N.1, N.2 | cc:完了 |
```

**DoD（Definition of Done）**: 検証可能な完了条件を 1 行で記述。「いい感じ」「ちゃんと動く」は禁止。Yes/No で判定できる形にする。

**Depends**: タスク間の依存関係。`-`（依存なし）、タスク番号（`N.1`）、カンマ区切り（`N.1, N.2`）、フェーズ依存（`Phase N`）。

### TDD tags

Plans.md の task には、TDD 判定を明示するタグを内容または DoD に書ける。

| タグ | 意味 | `tdd_required` 推論 |
|------|------|--------------------|
| `[tdd:required]` | この task は先に失敗テストを書く必要がある | `true` |
| `[tdd:skip:<reason>]` | この task は理由つきで TDD を省略する | `false`, `skip_tdd_reason=<reason>` |

`<reason>` は空にしない。
例: `[tdd:skip:docs-only]`、`[tdd:skip:no-test-framework-detected]`。

タグがない場合の `tdd_required` は次の順で推論する。

1. Plans.md tag: `[tdd:required]` / `[tdd:skip:<reason>]`
2. files: `src/`, `app/`, `cmd/`, `lib/`, `pkg/`, `internal/`, `go/` など source 実装を含むなら required
3. TDD 推論: docs-only や test framework なしなら skip reason を付けて not required

### optional briefs / manifest

`harness-plan create` は、必要なときだけ brief を付ける。

- project spec SSOT は project 全体の正解条件を固定する文書で、必要時だけ作る
- UI を含むタスクでは `design brief`
- API を含むタスクでは `contract brief`
- brief は「何を作るか」を短く固定する補助資料で、Plans.md や spec SSOT を置き換えない
- skill frontmatter の一覧は `scripts/generate-skill-manifest.sh` で machine-readable JSON にできる

参照:

- `docs/plans/briefs-manifest.md`
- `docs/plans/spec-ssot.md`

### マーカー一覧

| マーカー | 意味 |
|---------|------|
| `pm:依頼中` | PM から依頼済み |
| `cc:TODO` | 未着手 |
| `cc:WIP` | 作業中 |
| `cc:完了` | Worker 作業完了 |
| `pm:確認済` | PM レビュー完了 |
| `blocked` | ブロック中（理由を必ず記載） |

## 関連スキル

- `harness-sync` — 実装と Plans.md を同期する
- `harness-work` — 計画したタスクを実装する
- `harness-review` — 実装のレビュー
- `harness-setup` — プロジェクト初期化
