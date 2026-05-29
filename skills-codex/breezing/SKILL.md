---
name: breezing
description: "Team execution mode (Codex native) — backward-compatible alias for harness-work with team orchestration using Codex native subagent API."
description-en: "Team execution mode (Codex native) — backward-compatible alias for harness-work with team orchestration using Codex native subagent API."
description-ja: "チーム実行モード（Codex ネイティブ版）— harness-work のチーム協調エイリアス。breezing, チーム実行, 全部やって でトリガー。"
kind: workflow
purpose: "Wrap harness-work with Codex-native team execution orchestration"
trigger: "breezing, team execution, do everything"
shape: wrap
role: orchestrator
base: harness-work
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Bash", "spawn_agent", "send_input", "wait_agent", "close_agent"]
argument-hint: "[all|N-M|--max-workers N|--no-discuss]"
user-invocable: true
effort: high
---

# Breezing — Team Execution Mode (Codex Native)

> **この SKILL.md は Codex CLI ネイティブ版です。**
> Claude Code 版は `skills/breezing/SKILL.md` を参照してください。
> サブエージェント API は Codex の `spawn_agent` / `send_input` / `wait_agent` / `close_agent` を使用します。
> frontmatter の `allowed-tools` も、この4つの Codex native tool 名に合わせます。

**後方互換エイリアス**: `harness-work --breezing` をチーム実行モードで動かします。

## Quick Reference

```bash
breezing                        # スコープを聞いてから実行
breezing all                    # ready task を既定 max worker で完走
breezing 3-6                    # タスク3〜6を既定 max worker で完走
breezing --max-workers 2 all     # ready task の同時 spawn 上限を2に
breezing --max-workers 1 all     # 旧来の直列挙動に戻す
breezing --no-discuss all       # 計画議論スキップで全タスク完走
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--max-workers N` | ready task の同時 spawn 数上限（breezing 固有オプション）。`1` で旧来の直列挙動 | max |
| `--no-commit` | 非対応（Breezing では Worker の一時 commit と Lead の cherry-pick が必須） | - |
| `--no-discuss` | 計画議論スキップ | false |

## Execution

**このスキルは `harness-work --breezing` に委譲します。** 以下の設定で実行してください:

1. **引数を `harness-work --breezing` に渡す**（`--max-workers N` は breezing 固有オプションとして解釈し、`harness-work` の `--parallel` とは別概念）
2. **チーム実行モードを強制** — Lead → Worker spawn → 必要時 Advisor → companion review Reviewer の四者分離
3. **Lead は delegate 専念** — コードを直接書かない

### Execution Backend (persistent)

バックエンド選択（worker を `claude` / `codex` / `cursor` のどれで実装するか）の正本は
`harness-work` の「Execution Backend Selection（実装バックエンド選択）」を参照する。
そこに precedence、role-scope（review / advisor は Opus 固定）、self_review スキップ、cursor banner が定義されている。
`HARNESS_IMPL_BACKEND`（`bash "${HARNESS_PLUGIN_ROOT}/scripts/set-impl-backend.sh" cursor` で設定）が
per-run フラグなしの永続的な既定バックエンドを決める。

既定の worker 数は **max**。
ここでの max は「対象スコープ内で Depends が満たされ、今すぐ実行できる ready task の最大数」を意味する。
無制限に Worker を spawn する意味ではない。
依存待ちのタスクは、前段タスクが完了して ready になるまで spawn しない。
旧来の 1 件ずつ進める直列挙動に戻したい場合は `--max-workers 1` を指定する。

Worker の実装は並列化できるが、レビューと main への cherry-pick は直列で行う。
これは同じ main worktree への書き込み競合を避けるため。

### `harness-work` との違い

| 特徴 | `harness-work` | `breezing` (このスキル) |
|------|-----------------|------------------------|
| デフォルトモード | Solo / Sequential | **Breezing（チーム実行）** |
| 並列手段 | companion `task` Bash 並列 | **`spawn_agent` によるサブエージェント委譲** |
| Lead の役割 | 調整+実装 | **delegate (調整専念)** |
| レビュー | Lead 自己レビュー | **companion review 独立レビュー** |
| デフォルトスコープ | 次のタスク | **全部** |

### Team Composition（Codex Native）

| Role | 実行方式 | 権限 | 責務 |
|------|---------|------|------|
| Lead | (self) | 現セッション継承 | 調整・指揮・タスク分配・cherry-pick |
| Worker ×N | `spawn_agent({message, fork_context})` | セッション権限継承 | 実装（git worktree 分離） |
| Advisor | `claude-code-harness:advisor` | 読み取り専用 | 方針助言 (`PLAN` / `CORRECTION` / `STOP`) |
| Reviewer | companion `review --base` | read-only | 独立レビュー |

## Flow Summary

```
breezing [scope] [--max-workers N] [--no-discuss]
    │
    ↓ Load harness-work --breezing
    │
Phase 0: Planning Discussion (--no-discuss でスキップ)
Phase A: Pre-delegate（チーム初期化 + worktree 準備）
Phase B: Delegate（Worker 実装 + 必要時 Advisor + companion review レビュー）
Phase C: Post-delegate（統合検証 + Plans.md 更新 + commit）
```

## Advisor Protocol

Worker は generic な subagent を増やさない。
迷った時は構造化 JSON で相談要求だけ返し、Lead が advisor を呼ぶ。

1. Worker → `advisor-request.v1`
2. Lead → Advisor
3. Advisor → `advisor-response.v1`
4. Lead → 同じ Worker に advice を返して続行
5. Reviewer は最後の成果物だけを見る

相談条件は loop / solo とそろえる。

- 高リスク task（`needs-spike` / `security-sensitive` / `state-migration`）の初回実行前
- 同じ原因の失敗が 2 回続いた後
- plateau により `PIVOT_REQUIRED` を返す直前
- 同じ `trigger_hash` は 1 回だけ。task ごとの相談回数は最大 3 回

## Realtime Handoff / Silence Policy

Codex `0.123.0` 以降では、background agent が realtime handoff の transcript delta を受け取れる。
Breezing ではこの仕組みを「余計な通知を増やす入口」ではなく、「必要な時だけ判断を更新するための入力」として扱う。

ひとことで: Worker / Advisor / Reviewer は、状態が変わらない transcript delta には反応せず、Lead への報告は material state change に絞る。

たとえると、複数人の作業部屋で全員が独り言を実況するのではなく、担当作業が終わった時、詰まった時、判断待ちの時だけ声をかける形。

報告するもの:

- Worker の完了 JSON、blocked 理由、必要な `advisor-request.v1`
- Advisor の `PLAN` / `CORRECTION` / `STOP`
- Reviewer の `APPROVE` / `REQUEST_CHANGES`
- validation failure、contract readiness failure、plateau、drift 検知
- Lead が出す task 完了単位の progress feed

沈黙してよいもの:

- transcript delta を受け取っただけで、task status、review verdict、advisor decision が変わっていない場合
- tool stdout の細かな増分で、job log に残っていれば十分なもの
- parallel spawn 中の待機 heartbeat。待機は `wait_agent` / job status に任せる

途中報告の頻度:

- Lead の progress feed は task 完了ごとに 1 回を基本にする。
- Worker / Reviewer は「完了・差し戻し・ブロック」の結果だけを返し、delta ごとの小報告は避ける。
- user が明示的に status を求めた場合だけ、Lead がまとめて現在地を返す。

Advisor / Reviewer drift との関係:

- silence policy は Advisor / Reviewer を黙らせる免除ではない。
- `advisor-request.v1` 送信後に response が返らない、reviewer profile に必要な result がない、review loop が plateau した場合は drift として扱う。
- Advisor は方針助言、Reviewer は品質判定という役割分離を維持し、沈黙は「不要な通知を出さない」ためだけに使う。

### Phase 0: Planning Discussion（構造化 3 問チェック）

全タスク実行前に、以下の 3 問で計画の健全性を確認する。
`--no-discuss` 指定時は全スキップ。

**Q1. スコープ確認**:
> 「{{N}} 件のタスクを実行します。スコープは適切ですか？」

**Q2. 依存関係確認**（Plans.md に Depends カラムがある場合のみ）:
> 「タスク {{X}} は {{Y}} に依存しています。実行順序は合っていますか？」

**Q3. リスクフラグ**（`[needs-spike]` タスクがある場合のみ）:
> 「タスク {{Z}} は [needs-spike] です。先に spike しますか？」

### Phase A: Pre-delegate

1. Plans.md を読み込み、対象タスクを特定
2. 依存グラフを解析し、実行順序を決定
3. 各タスク用に git worktree を作成

### Phase B: Delegate（Codex Native Subagent Orchestration）

```
for task in execution_order:
    # B-0. 作業ディレクトリ分離
    worktree_path = "/tmp/worker-{task.number}-$$"
    branch_name = "worker-{task.number}-$$"
    git worktree add -b {branch_name} {worktree_path}
    TASK_BASE_REF = git rev-parse HEAD

    # B-1. sprint-contract を生成
    contract_path = bash("node \"${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js\" {task.number}")
    contract_path = bash("scripts/enrich-sprint-contract.sh {contract_path} --check \"DoD を reviewer 観点で確認\" --approve")
    bash("scripts/ensure-sprint-contract-ready.sh {contract_path}")

    # B-2. Worker spawn
    Plans.md: task.status = "cc:WIP"

    worker_id = spawn_agent({
        message: "作業ディレクトリ: {worktree_path} で作業してください。\n\nタスク: {task.内容}\nDoD: {task.DoD}\ncontract_path: {contract_path}\n\n実装してください。完了後 git commit してください。\n\n完了時、以下の JSON を返してください:\n{\"commit\": \"<hash>\", \"files_changed\": [...], \"summary\": \"...\"}",
        fork_context: true
    })
    wait_agent({ targets: [worker_id] })

    # B-3. Worker が advice request を返した時だけ、Lead が Advisor を呼ぶ
    if worker_result.type == "advisor-request.v1":
        advisor_id = spawn_agent({
            agent_type: "default",
            message: worker_result.request_json,
            fork_context: true
        })
        advisor_result = wait_agent({ targets: [advisor_id] })
        close_agent({ target: advisor_id })
        send_input({
            target: worker_id,
            message: "advisor-response.v1: {advisor_result}"
        })
        worker_result = wait_agent({ targets: [worker_id] })

    # B-4. Lead がレビュー実行（TASK_BASE_REF 起点）
    # 公式プラグイン companion review を使用（harness-work の「レビューループ」参照）:
    #   bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" review --base {TASK_BASE_REF}
    #   → verdict マッピング: approve→APPROVE, needs-attention→REQUEST_CHANGES
    VERDICT = review_task(worktree_path, TASK_BASE_REF)  # static review（harness-work 参照）
    PROFILE = jq(contract_path, ".review.reviewer_profile")
    BROWSER_MODE = jq(contract_path, ".review.browser_mode // \"scripted\"")
    REVIEW_INPUT = "review-output.json"
    if PROFILE == "runtime":
        # worktree 内で runtime checks を実行
        REVIEW_INPUT = bash("cd {worktree_path} && scripts/run-contract-review-checks.sh {contract_path}")
        RUNTIME_VERDICT = jq(REVIEW_INPUT, ".verdict")
        if RUNTIME_VERDICT == "REQUEST_CHANGES":
            VERDICT = "REQUEST_CHANGES"
        elif RUNTIME_VERDICT == "DOWNGRADE_TO_STATIC":
            REVIEW_INPUT = "review-output.json"  # static review にフォールバック
    if PROFILE == "browser":
        # browser artifact は PENDING_BROWSER scaffold。reviewer agent が後続で実行。
        BROWSER_ARTIFACT = bash("scripts/generate-browser-review-artifact.sh {contract_path}")
        # REVIEW_INPUT は static review のまま維持
    if REVIEW_INPUT != "review-output.json" and jq(REVIEW_INPUT, ".verdict") == "DOWNGRADE_TO_STATIC":
        REVIEW_INPUT = "review-output.json"
    bash("scripts/write-review-result.sh {REVIEW_INPUT} {commit_hash}")

    # B-5. 修正ループ（REQUEST_CHANGES 時、contract の max_iterations まで）
    review_count = 0
    # sprint-contract が存在するときのみ max_iterations を読む。存在しない場合は 3（後方互換）
    MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
    while VERDICT == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
        send_input({
            target: worker_id,
            message: "指摘内容: {issues}\n修正して git commit --amend してください。修正後 JSON を再出力してください。"
        })
        wait_agent({ targets: [worker_id] })
        VERDICT = review_task(worktree_path, TASK_BASE_REF)
        review_count++

    # B-6. Worker 終了
    close_agent({ target: worker_id })

    # B-7. 結果処理
    if VERDICT == "APPROVE":
        commit_hash = git("-C", worktree_path, "rev-parse", "HEAD")
        git cherry-pick --no-commit {commit_hash}
        git commit -m "{task.内容}"
        Plans.md: task.status = "cc:完了 [{short_hash}]"
    else:
        → ユーザーにエスカレーション（Plans.md は cc:WIP のまま）
        → 後続タスクも停止

    # B-8. Worktree クリーンアップ
    git worktree remove {worktree_path}
    git branch -D {branch_name}

    # B-9. Progress feed
    print("📊 Progress: Task {completed}/{total} 完了 — {task.内容}")
```

### ready task の並列 spawn（既定 max / `--max-workers N` 指定時）

Depends が満たされた ready task が複数ある場合、既定では ready task の数まで同時 spawn する。
`--max-workers N` を指定すると、同時 spawn 数を N 件までに制限する。
`--max-workers 1` は旧来の直列挙動に戻す escape hatch。

> **`wait_agent` のセマンティクス**: `wait_agent({targets: [a, b]})` は最初に完了した1つを返す（全完了待ちではない）。
> したがって、全 Worker の完了を待つにはループで個別に `wait_agent` を呼ぶ。

```
# 独立タスク A, B を並列 spawn（各自 worktree 分離済み）
worker_a = spawn_agent({ message: "作業ディレクトリ: /tmp/worker-a-$$ ...", fork_context: true })
worker_b = spawn_agent({ message: "作業ディレクトリ: /tmp/worker-b-$$ ...", fork_context: true })

# 各 Worker の完了を個別に待ち → レビュー → cherry-pick（直列）
# wait_agent は最初の1つを返すので、残りの Worker はまだ動作中
for worker_id in [worker_a, worker_b]:
    wait_agent({ targets: [worker_id] })    # この Worker の完了を待つ
    VERDICT = review_task(worktree_path, TASK_BASE_REF)  # harness-work 参照
    # 修正ループ（必要なら）...
    close_agent({ target: worker_id })
    if VERDICT == "APPROVE":
        cherry-pick → Plans.md 更新
```

> **制約**: 並列化できるのは Depends が満たされた ready task のみ。
> max は ready task 数の上限であり、無制限 spawn ではない。
> レビュー → cherry-pick は直列実行（main への書き込みが競合するため）。

### Worker の出力契約

Worker プロンプトには、完了時に以下の JSON を返すことを明示する:

```json
{
  "commit": "a1b2c3d",
  "files_changed": ["src/foo.ts", "tests/foo.test.ts"],
  "summary": "foo モジュールに bar 機能を追加"
}
```

Lead はこの JSON を解析して commit hash とファイル一覧を取得する。

### Progress Feed（Phase B 中の進捗通知）

```
📊 Progress: Task 1/5 完了 — "harness-work に失敗再チケット化を追加"
📊 Progress: Task 2/5 完了 — "harness-sync に --snapshot を追加"
```

### 完了報告（Phase C）

全タスク完了後、Lead が以下の手順でリッチ完了報告を生成:

1. `git log --oneline {session_base_ref}..HEAD` で全 cherry-pick コミットを収集
2. `git diff --stat {session_base_ref}..HEAD` で全体の変更規模を取得
3. Plans.md の残タスクを抽出
4. Breezing テンプレートに従い出力

## Claude Code 版との差分

| 項目 | Claude Code 版 | Codex ネイティブ版（本ファイル） |
|------|---------------|-------------------------------|
| Worker spawn | Claude Code Agent tool + worktree isolation | `spawn_agent({message, fork_context})` + `git worktree add` |
| 完了待ち | `Agent` の戻り値 | `wait_agent({targets: [id]})` |
| 修正指示 | Claude Code message tool | `send_input({target, message})` |
| Worker 終了 | 自動 | `close_agent({target})` |
| レビュー | Codex exec → Reviewer agent fallback | companion `review --base`（構造化出力） |
| 権限 | `bypassPermissions` + hooks | companion `task --write` / `spawn_agent`: セッション権限継承 |
| Agent Teams | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数 | Codex native（標準機能） |
| Worktree | `isolation="worktree"` 自動管理 | `git worktree add/remove` 手動管理 |
| モード昇格 | タスク4件以上で自動 | `--breezing` 明示時のみ |

## Related Skills

- `harness-work` — 単一タスクからチーム実行まで（本体）
- `harness-sync` — 進捗同期
- `harness-review` — コードレビュー
