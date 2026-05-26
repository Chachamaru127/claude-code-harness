---
name: harness-loop
description: "HAR: Codex-native long-running loop runner. Uses a real background runner that executes one ready batch per cycle through Breezing by default, with status/stop controls. Trigger: long-running, loop, autonomous, background, Codex. Do NOT load for: one-shot implementation, normal review, release."
description-en: "HAR: Codex-native long-running loop runner. Uses a real background runner that executes one ready batch per cycle through Breezing by default, with status/stop controls. Trigger: long-running, loop, autonomous, background, Codex. Do NOT load for: one-shot implementation, normal review, release."
description-ja: "HAR: Codex 専用の長時間ループ実行。実際のバックグラウンドランナーが ready batch を Breezing で進め、status / stop で監視できる。長時間、loop、ループ、autonomous、background、Codex で起動。"
kind: workflow
purpose: "Run long-lived Codex ready-batch execution loops"
trigger: "long-running, loop, autonomous, background, Codex"
shape: delegate
role: orchestrator
base: harness-work
pair: harness-sync
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Bash"]
argument-hint: "[all|TASK|START-END|START..END] [--max-cycles N] [--max-workers N|max] [--executor breezing|task] [--pacing worker|ci|plateau|night]"
disable-model-invocation: true
---

# Harness Loop

Codex 版の `harness-loop` は、説明だけの擬似ループではなく、
**実際にバックグラウンドで回るランナー**を起動する。

## ひとことで

`$harness-loop` は、1 回だけの実装依頼ではなく、
「今すぐ実行できる未完了タスクのまとまりを、Breezing で自動実行し続ける当番」を起動する入口。

ここでいう `ready batch` は、Depends が満たされていて、今すぐ並列実行できる `cc:TODO` / `cc:WIP` のまとまり。
1 cycle は 1 task ではなく、原則として 1 ready batch を処理する。

## たとえると

人が横でずっと見張る代わりに、
「同時に進められる作業をまとめて見つける → Breezing に任せる → 結果を確認する → 次のまとまりへ進む」
を繰り返す監督係を、裏で常駐させるイメージ。

## Quick Reference

| 入力 | 動作 |
|------|------|
| `$harness-loop all` | 未完了タスク全体を長時間ループで開始 |
| `$harness-loop 41.1-41.4` | 範囲を絞って開始 |
| `$harness-loop JLB3R-02..JLB3R-08` | Plans.md の task ID 順で範囲を絞って開始 |
| `$harness-loop all --max-cycles 3` | 最大 3 サイクルで停止 |
| `$harness-loop all --max-workers 4` | 1 cycle の ready batch を最大 4 worker までに制限 |
| `$harness-loop all --max-workers max` | ready batch 内で実行可能なタスク数を上限として並列化 |
| `$harness-loop all --plan roadmap` | named Plans の `roadmap` を対象にループ実行 |
| `$harness-loop all --executor task` | 旧来の 1 task per cycle local worker 実行へ逃がす |
| `$harness-loop all --pacing night` | サイクル間の待機を長めにする |
| `$harness-loop status` | 現在の実行状況を確認 |
| `$harness-loop stop` | 進行中ジョブを止めてループ停止要求を出す |

## 実行コマンド

### 開始

```bash
harness codex-loop start all
```

範囲指定:

```bash
harness codex-loop start 41.1-41.4 --max-cycles 5 --pacing worker
harness codex-loop start JLB3R-02..JLB3R-08 --max-cycles 5 --pacing worker
harness codex-loop start all --max-workers max --pacing worker
harness codex-loop start all --plan roadmap --max-cycles 5
harness codex-loop start all --executor task --max-cycles 5
```

`START..END` は、`Plans.md` に並んでいる task ID をそのまま使う範囲指定。
英字やハイフンを含む task ID は `..` を優先する。
`41.1-41.4` のような従来の数値レンジも引き続き使える。

`--max-workers` は、Breezing が 1 cycle で同時に動かす worker 数の上限。
`max` は、選択範囲内で Depends が満たされた ready task の数をそのまま上限にする。
`--executor task` は、Breezing ではなく local worker に 1 task だけ渡す互換用の逃げ道。
問題切り分けや、並列実行したくない危険な作業で使う。
複数 Plans.md がある repo では、長時間 run の起動時に `--plan NAME` を明示する。
runner は開始時に解決した Plans file を cycle 間で保持するため、途中で active plan を切り替えない。

### 状態確認

```bash
harness codex-loop status
harness codex-loop status --json
```

### 停止

```bash
harness codex-loop stop
```

## どう動くか

1. project root の `.claude/state/codex-loop/` に Harness loop の実行状態を書き出す
2. 受け取った selection を Plans.md から正規化する
3. Plans.md から Depends が満たされた `cc:TODO` / `cc:WIP` を集め、ready batch を作る
4. `--max-workers` で ready batch の同時実行数を制限する
5. 既定では Breezing executor が ready batch を Lead / Worker / Reviewer 分離で実行する
6. `--executor task` の時だけ、互換用 local worker が 1 task per cycle で `codex exec` を起動する（`CODEX_LOOP_TASK_DRIVER=companion` の時だけ `bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --background --write ...` を使う）
7. 高リスク task / 2 回目失敗 / plateau 直前では advisor consult を挟む
8. ready batch 完了後に review / checkpoint / plateau 判定を行う
9. まだ対象タスクが残っていれば、待機後に次サイクルへ進む

## Realtime Handoff / Silence Policy

Codex `0.123.0` 以降の background agent は realtime handoff で transcript delta を受け取れる。
この delta は「状況把握用の追記」であり、毎回ユーザーへ返答する合図ではない。

ひとことで: background agent は、必要な時だけ報告し、何も判断が変わらない時は明示的に沈黙する。

たとえると、見張り役が廊下でずっと実況するのではなく、異常・完了・判断待ちだけを知らせる形。

報告してよいタイミング:

- loop 開始、停止、`already running`、`stop` 受理など、ユーザー操作に関わる lifecycle 境界
- 1 ready batch cycle の最終結果、commit、`RESULT: APPROVED` / `RESULT: BLOCKED`
- Breezing Lead が task 完了を progress feed としてまとめて出す時
- task が blocked、validation failure、review `REQUEST_CHANGES`、plateau、advisor `STOP` で止まる時
- user が `status` を実行した時、または明示的に途中状況を聞いた時
- advisor / reviewer drift、contract readiness failure など、放置すると品質判定がずれる時

沈黙するタイミング:

- transcript delta を受け取っただけで、task / review / advisor の状態が変わっていない時
- `runner.log` / `jobs/*.log` に既に残る細かな stdout だけが増えた時
- `pacing` 待機中で、次 cycle まで新しい判断材料がない時

途中報告の頻度:

- default は「1 ready batch cycle につき最終報告 1 回」。
- Breezing の task-level progress feed は、batch 内の完了数が動いた時だけ出す。
- 長い cycle でも、material state change がない限り heartbeat は出さない。
- 詳細な流れは `harness codex-loop status --json` と project root の `.claude/state/codex-loop/runner.log` に寄せ、会話側には要点だけ出す。

Advisor / Reviewer drift との関係:

- silence policy は drift 検知を弱めるためのものではない。
- `advisor-request.v1` に response がない、`review-result.v1` が返らない、contract が未承認などの異常は必ず state / log に残し、必要ならユーザーへ報告する。
- Advisor は `PLAN` / `CORRECTION` / `STOP` の相談役、Reviewer は最終品質判定役のまま分離する。

## pacing

| 値 | 用途 | 待機秒数 |
|----|------|---------|
| `worker` | 通常の開発ループ | 270 |
| `ci` | 短めに確認したい時 | 270 |
| `plateau` | 行き詰まり気味の再試行 | 1200 |
| `night` | 長めの放置実行 | 3600 |

## State Path Policy

Codex 版 `harness-loop` は、Codex native の会話・実行キャッシュと、Harness が共有する project state を分けて扱う。

- **Harness 共通 state**: project root の `.claude/state/` 配下に置く。Claude 側の advisor / review / checkpoint と共有するため、`harness codex-loop status` もここを読む。
- **Codex loop runner state**: project root の `.claude/state/codex-loop/` 配下に置く。これは「Codex 全体の正本」ではなく、Harness loop runner の job / cycle / log 用 state。
- **Codex native state**: `${CODEX_HOME:-~/.codex}` 配下に残る Codex 自身の thread / transcript / cache。Harness loop の task status、advisor history、review result の正本にはしない。
- **禁止**: `.Codex/` や `~/.Codex` を正本 path として案内しない。大文字 `Codex` ディレクトリは historical drift と見なす。

つまり、`.claude/state/codex-loop/` は「この project の Harness loop state」であり、Codex native state 全体の固定保存先ではない。

## 状態ファイル

以下はすべて project root 基準。

- `.claude/state/codex-loop/run.json`
- `.claude/state/codex-loop/cycles.jsonl`
- `.claude/state/codex-loop/runner.log`
- `.claude/state/codex-loop/current-job.json`
- `.claude/state/codex-loop/jobs/*.json`
- `.claude/state/codex-loop/jobs/*.log`
- `.claude/state/codex-loop/jobs/*.out`
- `.claude/state/advisor/history.jsonl`
- `.claude/state/advisor/last-request.json`
- `.claude/state/advisor/last-response.json`
- `.claude/state/locks/codex-loop.lock.d`

## Advisor Consult

Advisor は「代わりに実装する役」ではなく、「次の一手だけ返す相談役」。
loop では次の 3 箇所でだけ呼ぶ。

| タイミング | reason_code | 何をするか |
|-----------|-------------|-----------|
| 高リスク task の初回実行前 | `high-risk-preflight` | 先に固める観点を聞く |
| 同じ原因の 2 回目失敗後 | `retry-threshold` | 方針変更か局所修正かを聞く |
| plateau による停止直前 | `plateau-pre-escalation` | 本当に止めるべきかを聞く |

decision は 3 種だけ。

| decision | loop の扱い |
|----------|-------------|
| `PLAN` | advice を次の executor prompt 先頭に足して再実行 |
| `CORRECTION` | 局所修正の指示として再実行 |
| `STOP` | loop を停止し、理由を state と runner.log に残す |

同じ trigger は `trigger_hash = task_id + reason_code + normalized_error_signature` で 1 回だけ相談する。
相談回数は task ごとに最大 3 回で、それ以上はユーザー判断に上げる。

## 注意点

- これは **本当に裏で動く**。説明だけ返して終わるスキルではない。
- 同時に 2 本は起動できない。既に走っている場合は `already running` で止まる。
- 既定 executor は Breezing。旧来の 1 task per cycle 挙動が必要な時だけ `--executor task` を使う。
- 失敗したタスクを無理に飛ばして次へ進めるのではなく、基本はその場で止まって理由を残す。
- `status` と `runner.log` を見れば、今どこで止まっているか追いやすい。

## 具体例

「Phase 41 の残タスクを、今日の間は自動で回したい」なら:

```bash
harness codex-loop start 41.1-41.4 --max-cycles 8 --max-workers max --pacing worker
```

途中で様子を見る:

```bash
harness codex-loop status
```

夜になって止めたい:

```bash
harness codex-loop stop
```

## なぜこの形か

Codex では Claude の `/loop` と同じ wake-up 機構をそのまま使えない。
その代わり、**Codex loop runner** を土台にして、
Harness 側で状態管理と再入制御を持ち、実作業は Breezing の batch 実行に寄せる。
そうすると、長時間タスクでも「止める」「再開する」「今の状態を見る」が素直になり、
依存関係を満たした作業だけを安全にまとめて進められる。
