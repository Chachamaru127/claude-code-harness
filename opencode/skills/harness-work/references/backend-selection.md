# Execution Backend Selection — Full Detail

Role-scoped constraints, non-`claude` topology, self_review gate exception, cursor banner,
cherry-pick gate, natural-language trigger, and the two Mode 1 opt-in configurations for
`harness-work` / `breezing`.

## Role-scoped 制約

バックエンドは **role-scoped**。解決済みバックエンドを使うのは実装（worker）ロールだけ。
Reviewer と Advisor の両ロールは常に brain（`--host claude`）に固定する。
Primary reviewer を cursor / codex バックエンドに routing しない（diff を生成した同一コンテキストが自分の出力をレビューしてはならない — spec.md Execution Backend Contract の self-review scope 契約）。
例外は **fresh-context advisory pre-review** のみ: diff を生成した session と会話状態を共有しない cursor `review` tier（composer-2.5-fast、read-only）が brain 一次レビューの前段で advisory findings を出すことは許可。primary verdict（`APPROVE | REQUEST_CHANGES`）は brain のみが出す。

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host cursor --role worker --field model
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host claude --role reviewer --field model
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host claude --role advisor --field model
```

> モデル名の正本は `model-routing.sh` 側。`composer-2.5-fast` は参照値であり、実際の解決は上記コマンドに従う（drift 防止）。

## 非 `claude` バックエンドのトポロジー（Worker 介在なし）

backend が `codex` または `cursor` の場合、**Lead は Worker agent (`claude-code-harness:worker`) を spawn しない**。
代わりに Lead 自身が `cursor-companion.sh` / `codex-companion.sh` を直接呼ぶ。Worker 層の介在は backend=`claude` のときだけ。

| backend | 経路 |
|---------|------|
| `claude`（既定） | Lead → Worker (`claude-code-harness:worker` agent) → … → Lead review → cherry-pick |
| `codex` | Lead → `codex-companion.sh task --write` → Lead review → cherry-pick |
| `cursor` | Lead → `cursor-companion.sh task --write --workspace <isolated-wt>` → Lead review → cherry-pick |

非 claude backend で Worker を間に挟むと、Lead → Worker → companion → composer/codex と二段委譲になり、Worker の存在意義（agent 契約による self_review 5 件のゲート）が空回りする（非 claude では `worker-report.v1` も `self_review` も生成されないため）。Lead は Worker をスキップして companion を直接呼ぶ。

非 claude backend の companion 呼び出しでも、Lead は先に専用 worktree を作り、companion stdout を `companion-result.v1` 相当の `{baseCommit, commit, worktreePath, branch, files_changed, summary}` に正規化してから既存の Lead review / cherry-pick 経路へ渡す。`REQUEST_CHANGES` 時は `SendMessage` を使わず、同じ worktree で `cursor-companion.sh` / `codex-companion.sh` を再実行し、`baseCommit..HEAD` を再レビューして range cherry-pick する。

## 非 `claude` バックエンドの self_review ゲート

backend が `codex` または `cursor` の場合、`worker-report.v1` も `self_review` 配列も生成されない。
そのため Lead は self_review ゲートを**スキップ**し、Lead の diff レビューを唯一の品質ゲートとする（既存の codex path と同じ扱い）。

## cursor バックエンドの banner（委託前に必須）

backend が `cursor` のとき、Lead は委託前に次の 1 行 banner を必ず出力する:

```
⚠️ cursor backend: model=composer-2.5-fast / R01-R13 ガードレールは cursor-agent 内部に適用されない / 出力は Lead レビューまで untrusted
```

cursor の write 委託は専用 `.git` を持つ worktree 内で実行し、Lead が main へ cherry-pick する（cherry-pick 経路で R01-R13 が適用される）。
ガバナンス詳細は `.claude/rules/cursor-cli-only.md` を参照。

## Lead の cherry-pick 前ゲート（contract grep を必須）

非 claude backend (cursor / codex) の出力を main にとり込む前に、Lead は **目視 diff + contract grep の二段ゲート**を必ず通す。目視 diff だけで APPROVE しない。

| ゲート | コマンド | 検知できるもの |
|--------|----------|----------------|
| diff 目視 | `git show <sha>` | 変更が意図どおりか・他ファイル touch なしか・support tier 表記不変か |
| contract grep | `bash tests/test-support-claim-wording.sh` | 公開 support 表記の破壊 |
| contract grep | `bash scripts/ci/check-consistency.sh` | i18n / locale / mirror / capability matrix の固定文字列契約破壊 |
| contract grep | `bash tests/validate-plugin.sh` | plugin 配布契約・hook 配線 |

**全 PASS のときだけ cherry-pick**。1 件でも fail なら revert または composer に再委託（同一文字列契約を保つよう明示）。

理由: docs / README / locale / capability-matrix / spec.md には grep で監視される **固定文字列契約**がある（例: `README_ja.md` の `5動詞ワークフロー`）。composer は表面的な言語的重複を機械的に削減する傾向があり、目視 diff では「綺麗な dedup」に見えても固定句を破壊しうる。

## 自然言語 backend trigger

ユーザーが `composer` / `コンポーザー` / `Composer で` / `composer 2.5` / `composer モード` と言った場合は、`cursor backend` 指定として扱う。
これは `--cursor` と同じ intent だが、backend の確定値は必ず `resolve-impl-backend.sh` で解決する。
解決時は明示 override として `--backend cursor` を渡し、env / project / user file / default より優先させる。
Lead は `composer` を Claude Worker 内の追加 agent と解釈せず、非 `claude` backend の規約どおり Worker agent を挟まずに `cursor-companion.sh` を直接呼ぶ。

## Mode 1 — Producer → Sub-Lead → Composer 階層

`harness work --team`（Breezing の Go orchestrator 経路）で **Mode 1 producer hierarchy** を有効にする opt-in 配線。正本は `spec.md`「Mode 1 — orchestrated Producer hierarchy」節。実装: `go/internal/sublead/sublead.go`、`go/cmd/harness/work_team.go`。

| 層 | 役割 | 備考 |
|----|------|------|
| **Producer（Lead）** | Claude Code 固定。lane 単位で Sub-Lead に委譲し、`companion-result.v1` を集約 | 人間が話す CLI = Lead |
| **Sub-Lead** | lane 1 件を mini-plan に分解し、subtask を並列 fan-out | orchestrator-spawned **headless CLI**（Lead と同一 CLI backend） |
| **Composer 2.5** | subtask の実装担当（cursor backend） | `productionCompanionWorker` → `cursor-companion.sh`；lane ごとに `companion-result.v1` で集約 |

**hub-spoke のみ**: subWorker 同士は peer results や channel を受け取らない。Sub-Lead が inner `breezing.Orchestrator` で fan-out し、lane 結果を 1 つの `companion-result.v1` に畳む。

**有効化**: `HARNESS_TEAM_HIERARCHY=sublead`（**default OFF**）。未設定時は flat companion worker（Lead が task ごとに companion を直接呼ぶ従来経路）。

## review→iterate ループ

cross-CLI の品質ゲートを worker 出力に wrap する opt-in 配線。実装: `go/internal/reviewiterate/run.go`、`go/cmd/harness/work_team_reviewiterate.go`。

**有効化**: `HARNESS_REVIEW_ITERATE=on`（**default OFF**）。`teamWorkerFactory` が inner worker（flat companion または Sub-Lead 配下 subWorker）を `wrapWorkerWithReviewIterate` で包む。

| 段階 | 動作 |
|------|------|
| 1. advisory fan-out | 複数 lens（例: correctness / security / scope）で **fresh-context** headless reviewer CLI を並列起動（producing session と会話状態を共有しない） |
| 2. brain primary verdict | **primary verdict（`APPROVE` / `REQUEST_CHANGES`）は brain（claude host / Lead）のみ**が出す。advisory reviewer は findings のみ |
| 3. refinement re-dispatch | brain が `REQUEST_CHANGES` なら、findings を精緻化プロンプトに畳み、**同 worktree** に inner `WorkerFunc` で再投入 |
| 4. 反復上限 | `MaxIters` 到達で未収束 → `Outcome.Escalated=true` + `EscalationNote` を付けて human escalation |

**反復上限 env**: `HARNESS_REVIEW_ITERATE_MAX`（未設定時 default `3`）。`reviewiterate.Config.MaxIters` に渡される。

cross-CLI review は **OK まで反復**する（DoD 未達なら精緻化タスクを同 worktree に再投入、N 回未収束で human escalation）。
