---
name: harness-loop
description: "HAR: Codex 専用の長時間ループ実行。バックグラウンドランナーで 1 サイクルずつ実務を進め、status / stop で監視できる。長時間、loop、ループ、autonomous、background、Codex で起動。Do NOT load for: 単発の実装、通常レビュー、リリース。"
description-en: "HAR: Codex-native long-running loop runner. Uses a real background runner, one cycle at a time, with status/stop controls. Trigger: long-running, loop, autonomous, background, Codex. Do NOT load for: one-shot implementation, normal review, release."
description-ja: "HAR: Codex 専用の長時間ループ実行。実際のバックグラウンドランナーが 1 サイクルずつ仕事を進め、status / stop で監視できる。長時間、loop、ループ、autonomous、background、Codex で起動。"
allowed-tools: ["Read", "Bash"]
argument-hint: "[all|TASK|START-END|START..END] [--max-cycles N] [--pacing worker|ci|plateau|night]"
disable-model-invocation: true
---

# Harness Loop

Codex 版の `harness-loop` は、説明だけの擬似ループではなく、
**実際にバックグラウンドで回るランナー**を起動する。

## ひとことで

`$harness-loop` は、1 回だけの実装依頼ではなく、
「未完了タスクを 1 件ずつ、自動で回していく当番」を起動する入口。

## たとえると

人が横でずっと見張る代わりに、
「次の作業を見つける → Codex に任せる → 結果を確認する → 次へ進む」
を繰り返す監督係を、裏で常駐させるイメージ。

## Quick Reference

| 入力 | 動作 |
|------|------|
| `$harness-loop all` | 未完了タスク全体を長時間ループで開始 |
| `$harness-loop 41.1-41.4` | 範囲を絞って開始 |
| `$harness-loop JLB3R-02..JLB3R-08` | Plans.md の task ID 順で範囲を絞って開始 |
| `$harness-loop all --max-cycles 3` | 最大 3 サイクルで停止 |
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
```

`START..END` は、`Plans.md` に並んでいる task ID をそのまま使う範囲指定。
英字やハイフンを含む task ID は `..` を優先する。
`41.1-41.4` のような従来の数値レンジも引き続き使える。

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

1. `.claude/state/codex-loop/` に実行状態を書き出す
2. 受け取った selection を Plans.md から正規化する
3. Plans.md から次の `cc:TODO` / `cc:WIP` を見つける
4. `generate-sprint-contract.js` など既存の Harness 資産で準備する
5. 既定では local worker が `codex exec` を起動する（`CODEX_LOOP_TASK_DRIVER=companion` の時だけ `scripts/codex-companion.sh task --background --write ...` を使う）
6. 高リスク task / 2 回目失敗 / plateau 直前では advisor consult を挟む
7. ジョブ完了後に review / checkpoint / plateau 判定を行う
8. まだ対象タスクが残っていれば、待機後に次サイクルへ進む

## pacing

| 値 | 用途 | 待機秒数 |
|----|------|---------|
| `worker` | 通常の開発ループ | 270 |
| `ci` | 短めに確認したい時 | 270 |
| `plateau` | 行き詰まり気味の再試行 | 1200 |
| `night` | 長めの放置実行 | 3600 |

## 状態ファイル

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
- 失敗したタスクを無理に飛ばして次へ進めるのではなく、基本はその場で止まって理由を残す。
- `status` と `runner.log` を見れば、今どこで止まっているか追いやすい。

## 具体例

「Phase 41 の残タスクを、今日の間は自動で回したい」なら:

```bash
harness codex-loop start 41.1-41.4 --max-cycles 8 --pacing worker
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
その代わり、**Codex companion の background job** を土台にして、
Harness 側で状態管理と再入制御を持つと、
長時間タスクでも「止める」「再開する」「今の状態を見る」が素直になる。
