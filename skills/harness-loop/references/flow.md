# harness-loop: wake-up フロー詳細

`harness-loop` の各 wake-up エントリ手順の詳細版。
SKILL.md のサマリを補完する実装リファレンス。

---

## wake-up 毎のエントリ手順（詳細）

### Step 0: plugin bundle root 解決

`harness-loop` は host project の cwd ではなく、plugin bundle root 配下の helper script を呼ぶ。
作業対象の `Plans.md` や `.claude/state/...` は host project 側に残し、工具にあたる script だけを plugin bundle から読む。

```bash
resolve_harness_plugin_root() {
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/scripts" ]; then
        (cd "${CLAUDE_PLUGIN_ROOT}" && pwd -P)
        return 0
    fi

    if [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
        for candidate in "${CLAUDE_SKILL_DIR}/../.." "${CLAUDE_SKILL_DIR}/../../.."; do
            candidate_abs="$(cd "${candidate}" 2>/dev/null && pwd -P)" || continue
            if [ -f "${candidate_abs}/.claude-plugin/plugin.json" ] && [ -d "${candidate_abs}/scripts" ]; then
                printf '%s\n' "${candidate_abs}"
                return 0
            fi
        done
    fi

    echo "ERROR: cannot resolve Claude Harness plugin root. Set CLAUDE_PLUGIN_ROOT to the installed plugin bundle root." >&2
    return 1
}

HARNESS_PLUGIN_ROOT="$(resolve_harness_plugin_root)" || exit 1
```

- `CLAUDE_PLUGIN_ROOT` が有効なら最優先で使う
- `CLAUDE_PLUGIN_ROOT` がない場合は `CLAUDE_SKILL_DIR` から配布元を逆算する
  - `skills/harness-loop` 配布なら `${CLAUDE_SKILL_DIR}/../..`
  - `.agents/skills/harness-loop` mirror 配布なら `${CLAUDE_SKILL_DIR}/../../..`
- `scripts/` と `.claude-plugin/plugin.json` がある候補だけを plugin root として扱う
- host project cwd の `scripts/` は使わない

### Step 0.1: 多重起動防止ロック（冪等性ガード (a)）

```bash
LOCK_DIR=".claude/state/locks/loop-session.lock.d"
mkdir -p ".claude/state/locks"

# アトミック作成（既存なら即失敗 — TOCTOU レース回避）
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    existing=$(cat "${LOCK_DIR}/meta.json" 2>/dev/null || echo '{}')
    echo "ERROR: harness-loop is already running (lock dir exists: ${LOCK_DIR})" >&2
    echo "Lock contents: ${existing}" >&2
    echo "To force-clear, run: rm -rf ${LOCK_DIR}" >&2
    exit 10
fi

# lock メタデータを lock ディレクトリ内に書く
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
ARGS_STR="$*"
cat > "${LOCK_DIR}/meta.json" <<EOF
{
  "pid": $$,
  "session_id": "${SESSION_ID}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "args": "${ARGS_STR}"
}
EOF

# 終了時（正常・異常問わず）lock を削除
cleanup_loop_lock() {
    rm -rf "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup_loop_lock EXIT INT TERM
```

- `LOCK_DIR` は `.claude/state/locks/loop-session.lock.d`（ディレクトリ）
- `mkdir` はアトミックなので TOCTOU レースが発生しない（2 プロセスが同時に実行しても一方だけが成功する）
- lock メタデータは `${LOCK_DIR}/meta.json` に書く: `{"pid": <pid>, "session_id": <session>, "started_at": <ISO8601>, "args": "<args>"}` の JSON
- 既存 lock がある場合は `already running` エラー（exit 10）で即停止
- `EXIT` / `INT` / `TERM` いずれでも lock を削除（正常・異常問わず cleanup）
- `rm -rf` で冪等（2 回削除しても安全）

### Step 0.5: state 整合性チェック（冪等性ガード (b)）

```bash
# wake-up 冒頭で --quick モードの軽量整合性チェックを実行
# 失敗した場合はループを即停止する（Plans.md 破損・未初期化環境への保護）
if bash "${HARNESS_PLUGIN_ROOT}/tests/validate-plugin.sh" --quick; then
    : # OK — 続行
else
    echo "harness-loop: state 整合性チェック失敗 — ループを停止します" >&2
    echo "詳細: bash \"${HARNESS_PLUGIN_ROOT}/tests/validate-plugin.sh\" --quick を実行して確認してください" >&2
    exit 1
fi
```

- `${HARNESS_PLUGIN_ROOT}/tests/validate-plugin.sh --quick` は軽量で数秒以内に完了する
- チェック内容: `.claude/state/` の存在 / Plans.md の存在+v2フォーマット / sprint-contract の形式
- フル validate（39 検証項目）は走らせない
- Plans.md を意図的に破損した状態でこのチェックが失敗すれば、ループは即停止する

### Step 1: Plans.md を先に読む

```bash
# cc:WIP / cc:TODO タスクを抽出し、先頭タスクの task_id を特定
grep -E "cc:(WIP|TODO)" Plans.md | head -1
```

- `cc:WIP` タスクが残っている場合: 前サイクルで中断された可能性あり → task_id を取得して継続
- `cc:TODO` タスクがある場合: 次のターゲットタスクとして task_id を取得
- どちらもない場合: **全タスク完了** → ループ正常終了

> **41.1.2 前提**: `plans-watcher.sh` が flock で Plans.md を保護している場合、
> Plans.md 読み取りはその flock スコープ内で実行すること。
> 41.1.2 リリース前は flock なしで直接読み取り可。

### Step 2: sprint-contract 存在確認 & 生成

```bash
CONTRACT_PATH=".claude/state/contracts/${task_id}.sprint-contract.json"

if [ ! -f "${CONTRACT_PATH}" ]; then
    # contract 未生成 → 生成する
    node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" "${task_id}"

    # Step 2.5: draft → approved に昇格（初回生成時のみ）
    # generate-sprint-contract.js は review.status == "draft" で初期化するため、
    # ensure-sprint-contract-ready.sh（approved 要求）の前に必ず昇格させる
    bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh" "${CONTRACT_PATH}" \
      --check "wake-up 自動承認（harness-loop のため DoD を reviewer 観点で確認）" \
      --approve
fi
```

- `.claude/state/contracts/${task_id}.sprint-contract.json` の有無を確認
- 存在しない場合は `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" ${task_id}` で生成
  （※ 41.5.1 で .sh→.js リネーム予定だが、現時点は既存名を node 経由で呼ぶ）
- **生成直後（初回のみ）**: `enrich-sprint-contract.sh --approve` で `draft` → `approved` に昇格
  - `generate-sprint-contract.js` は `review.status == "draft"` で初期化する
  - `ensure-sprint-contract-ready.sh`（次の Step 3）は `approved` しか受け付けない
  - `if [ ! -f ... ]` ブロック内に入れることで、既存 contract（前サイクルで approved 済み）には適用しない
- 生成後は `${CONTRACT_PATH}` を以降のステップで使い回す

### Step 3: contract readiness チェック

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh" "${CONTRACT_PATH}"
```

- sprint-contract の `review.status == "approved"` を確認
- 未承認 contract が残っている場合はエラーで停止

### Step 4: Resume pack 再読込

```
Step 4. harness-mem resume-pack 再読込:
  mcp__harness__harness_mem_resume_pack ツールを呼ぶ。
  必須引数:
    - project: 現在のプロジェクト名（既存 session-init スキルの実装例に倣う。
              例: リポジトリ root を `basename $(git rev-parse --show-toplevel)` で取得して渡す）
  optional: session_id（前セッションから再開する場合）

  例（擬似コード）:
    resume_pack = mcp__harness__harness_mem_resume_pack(
      project="claude-code-harness",
      session_id=<前回 checkpoint の session_id>
    )
```

fresh context での wake-up 直後は前サイクルのメモリが失われている。
`harness-mem resume-pack` 相当の操作で以下を再注入する:

- `decisions.md` — アーキテクチャ決定事項
- `patterns.md` — 再利用パターン
- `session-state` — 前回の作業状態
- 直前サイクルの `checkpoint` — 何を完了したか

> **注意**: resume pack 再読込は Step 3（contract readiness チェック）の後に実行すること。
> スキップすると前サイクルの成果物を重複実装するリスクがある。

### Step 4.5: Advisor consult（必要時のみ）

loop は executor 主導で進め、advisor は必要な時だけ呼ぶ。
相談するタイミングは次の 3 つに固定する。

1. 高リスク task の初回実行前
2. 同じ原因の失敗が 2 回続いた後
3. `PIVOT_REQUIRED` による停止直前

```bash
TRIGGER_HASH="${task_id}:${reason_code}:$(normalize_error_signature "${summary_or_risk}")"

if ! advisor_trigger_seen "${TRIGGER_HASH}"; then
    RESPONSE_FILE=$(
        bash "${HARNESS_PLUGIN_ROOT}/scripts/run-advisor-consultation.sh" \
          --request-file ".claude/state/codex-loop/${task_id}.${reason_code}.advisor-request.json" \
          --response-file ".claude/state/codex-loop/${task_id}.${reason_code}.advisor-response.json"
    )
    DECISION=$(jq -r '.decision' "${RESPONSE_FILE}")
fi
```

- `PLAN` / `CORRECTION` は次の executor prompt 先頭に advice を入れて再実行
- `STOP` は loop を止め、`run.json` の `last_decision`, `last_trigger`, `last_model` に記録
- 同じ `trigger_hash` は 1 回だけ相談する
- task ごとの相談回数は最大 3 回

### Step 5: 1 タスクサイクル実行

Agent tool 経由で `claude-code-harness:worker` を spawn する:

> **重要**: `subagent_type` には `"harness-work"` ではなく `"claude-code-harness:worker"` を指定すること。
> `harness-work` はスキルであり agent ではない。実在する agent は `worker` / `reviewer`。
> `"harness-work"` を指定すると Agent spawn が失敗し、ループが初回 Worker 起動で停止する。

```python
worker_result = Agent(
    subagent_type="claude-code-harness:worker",  # ← worker エージェント（スキルではない）
    prompt="""
    タスク: ${task_id}
    DoD: <Plans.md から抽出>
    contract_path: ${CONTRACT_PATH}
    mode: breezing
    完了後: commit hash・branch・変更サマリを返却してください。
    """,
    isolation="worktree",
    run_in_background=false  # フォアグラウンド実行（完了まで待機）
)
# worker_result: { commit, branch, worktreePath, files_changed, summary }
```

Worker は `mode: breezing` で動作するため:
- feature branch 上に commit するだけで main には触らない
- `worktreePath` に変更内容が格納される
- Lead（harness-loop）が Step 5.5/5.6 でレビュー → cherry-pick を担当する

> **Codex loop 実装差分**: Codex 版は `${HARNESS_PLUGIN_ROOT}/scripts/codex-loop.sh` が background task を起動し、
> advisor が返した guidance を次回 prompt に prepend して同じ task を再実行する。

> **実装上の注意**: `Bash("harness-work --breezing")` でも代替可能だが、
> Agent tool 経由の方がコンテキスト分離が明確でデバッグしやすい。

### Step 5.5: Lead レビュー実行

Worker が返却した commit に対して Lead がレビューを実行する:

```bash
# diff 取得（worktree 内の commit を対象）
diff_text=$(git -C "${worker_result.worktreePath}" show "${worker_result.commit}")

# ── (a) Codex companion review: Worker の worktree ディレクトリで実行 ──────────────
# Lead が main repo dir にいると diff が空になる（無条件 APPROVE の危険）。
# Worker の worktreePath に cd してから review を呼ぶことで正しい差分を渡す。
#
# worktreePath が空 or main repo と同一（worktree isolation が効かない環境）の場合は
# Lead dir で実行（既存挙動と同等のフォールバック）。

MAIN_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
WORKER_PATH="${worker_result.worktreePath:-}"

if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
    # Worker の worktree 内で review を実行 → Worker feature branch の実際の差分を見る
    ( cd "${WORKER_PATH}" && bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" review --base "${BASE_REF}" )
    REVIEW_EXIT=$?
    # review-output.json は Worker worktree dir に作られるので絶対パスで管理する
    REVIEW_OUTPUT_PATH="${WORKER_PATH}/review-output.json"
else
    # フォールバック: Lead dir で実行（worktree isolation が効かない環境）
    bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" review --base "${BASE_REF}"
    REVIEW_EXIT=$?
    REVIEW_OUTPUT_PATH="$(pwd)/review-output.json"
fi
# → REVIEW_OUTPUT_PATH が示すファイルに verdict が書き込まれる
# 後続はすべて $REVIEW_OUTPUT_PATH を使用すること（相対パス "review-output.json" を直接参照しない）

# ── (b) reviewer_profile 分岐（sprint-contract の review.reviewer_profile を確認）──
# CONTRACT_PATH は Step 2/3 で決定済みの値をそのまま使う（ここで上書きしない）
if command -v jq >/dev/null 2>&1; then
    REVIEWER_PROFILE=$(jq -r '.review.reviewer_profile // "static"' "${CONTRACT_PATH}" 2>/dev/null || echo "static")
else
    REVIEWER_PROFILE="static"
fi

case "${REVIEWER_PROFILE}" in
    runtime)
        # runtime 検証コマンドを実行し、verdict を上書きする可能性がある
        # run-contract-review-checks.sh は Worker の worktree 内で実行する（テスト環境が worktree 内にあるため）
        # 重要: run-contract-review-checks.sh の stdout は artifact の「ファイルパス」（JSON payload ではない）
        if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
            RUNTIME_ARTIFACT_PATH=$(
                cd "${WORKER_PATH}" && bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh" "${CONTRACT_PATH}" 2>/dev/null
            ) || RUNTIME_ARTIFACT_PATH=""
        else
            RUNTIME_ARTIFACT_PATH=$(
                bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh" "${CONTRACT_PATH}" 2>/dev/null
            ) || RUNTIME_ARTIFACT_PATH=""
        fi

        # 空（スクリプト失敗）の場合は DOWNGRADE_TO_STATIC 扱い
        if [ -z "${RUNTIME_ARTIFACT_PATH}" ]; then
            RUNTIME_ARTIFACT_PATH=""
            RUNTIME_VERDICT="DOWNGRADE_TO_STATIC"
        else
            # 相対パスの場合は WORKER_PATH（または Lead dir）を基点に絶対パス化する
            if [[ "${RUNTIME_ARTIFACT_PATH}" != /* ]]; then
                if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
                    RUNTIME_ARTIFACT_PATH="${WORKER_PATH}/${RUNTIME_ARTIFACT_PATH}"
                else
                    RUNTIME_ARTIFACT_PATH="$(pwd)/${RUNTIME_ARTIFACT_PATH}"
                fi
            fi

            # artifact ファイルから verdict を読む
            if command -v jq >/dev/null 2>&1; then
                RUNTIME_VERDICT=$(jq -r '.verdict // "DOWNGRADE_TO_STATIC"' "${RUNTIME_ARTIFACT_PATH}" 2>/dev/null || echo "DOWNGRADE_TO_STATIC")
            else
                RUNTIME_VERDICT=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('verdict','DOWNGRADE_TO_STATIC'))" "${RUNTIME_ARTIFACT_PATH}" 2>/dev/null || echo "DOWNGRADE_TO_STATIC")
            fi
        fi

        if [ "${RUNTIME_VERDICT}" = "REQUEST_CHANGES" ]; then
            # runtime 検証が失敗 → verdict を REQUEST_CHANGES に上書き
            # write-review-result.sh には runtime artifact を渡す（static review-output.json を使わない）
            EFFECTIVE_VERDICT="REQUEST_CHANGES"
            REVIEW_RESULT_INPUT="${RUNTIME_ARTIFACT_PATH}"
        elif [ "${RUNTIME_VERDICT}" = "DOWNGRADE_TO_STATIC" ]; then
            # runtime 検証コマンドなし → static verdict をそのまま使う
            EFFECTIVE_VERDICT=""  # → REVIEW_OUTPUT_PATH から読む
            REVIEW_RESULT_INPUT="${REVIEW_OUTPUT_PATH}"
        else
            EFFECTIVE_VERDICT="${RUNTIME_VERDICT}"
            REVIEW_RESULT_INPUT="${RUNTIME_ARTIFACT_PATH}"
        fi
        ;;
    browser)
        # browser reviewer が後続で使う artifact を生成
        # browser artifact は PENDING_BROWSER scaffold。実際の browser 実行は reviewer agent が担当。
        # review-result の verdict は static のまま（PENDING_BROWSER ではない）。
        bash "${HARNESS_PLUGIN_ROOT}/scripts/generate-browser-review-artifact.sh" "${CONTRACT_PATH}" 2>/dev/null || true
        EFFECTIVE_VERDICT=""  # → REVIEW_OUTPUT_PATH から読む（static verdict を使用）
        REVIEW_RESULT_INPUT="${REVIEW_OUTPUT_PATH}"
        ;;
    *)
        # static（デフォルト）: Codex companion review の verdict をそのまま使う
        EFFECTIVE_VERDICT=""
        REVIEW_RESULT_INPUT="${REVIEW_OUTPUT_PATH}"
        ;;
esac

# EFFECTIVE_VERDICT が設定されていない場合は REVIEW_OUTPUT_PATH（絶対パス）から読む
if [ -z "${EFFECTIVE_VERDICT}" ]; then
    if command -v jq >/dev/null 2>&1; then
        EFFECTIVE_VERDICT=$(jq -r '.verdict // "REQUEST_CHANGES"' "${REVIEW_OUTPUT_PATH}" 2>/dev/null || echo "REQUEST_CHANGES")
    else
        EFFECTIVE_VERDICT=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('verdict','REQUEST_CHANGES'))" "${REVIEW_OUTPUT_PATH}" 2>/dev/null || echo "REQUEST_CHANGES")
    fi
fi

# review-result を正規化して保存
# REVIEW_RESULT_INPUT は runtime REQUEST_CHANGES 時は runtime artifact パス、それ以外は REVIEW_OUTPUT_PATH
# これにより runtime REQUEST_CHANGES が pretooluse-guard まで正しく伝わる（指摘 4 対応）
bash "${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh" "${REVIEW_RESULT_INPUT}" "${worker_result.commit}"
```

**verdict 判定**:

| verdict | アクション |
|---------|----------|
| `APPROVE` | Step 5.6 へ（cherry-pick） |
| `REQUEST_CHANGES` | 修正ループへ（最大 3 回） |

**修正ループ（REQUEST_CHANGES 時）**:

```python
review_count = 0
latest_commit = worker_result.commit
worker_id = worker_result.agentId
# sprint-contract が存在するときのみ max_iterations を読む。存在しない場合は 3（後方互換）
MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    # Worker に修正を指示（SendMessage で再開）
    SendMessage(to=worker_id, message=f"指摘内容: {issues}\n修正して amend してください")
    updated_result = wait_for_response(worker_id)
    latest_commit = updated_result.commit
    diff_text = git("-C", worker_result.worktreePath, "show", latest_commit)
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
    review_count += 1

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    # エスカレーション
    raise PivotRequired(f"{MAX_REVIEWS} 回修正後も REQUEST_CHANGES: {issues}")
```

### Step 5.6: APPROVE → main に cherry-pick

```bash
# trunk ブランチに戻る（Worker は feature branch で作業）
TRUNK=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
git checkout "${TRUNK}"

# feature branch の commit が trunk に未マージかを確認（再入防止）
if ! git merge-base --is-ancestor "${latest_commit}" HEAD; then
    git cherry-pick --no-commit "${latest_commit}"
    git commit -m "${task_title}"
fi

# ── (c) cleanup 順序: worktree remove → branch -D ────────────────────────────────
# feature branch が worktree に checkout されている状態では
# `git branch -D` が "branch is checked out at <path>" エラーになる。
# worktree remove を先に実行することで branch -D が安全に動作する。
#
# 順序:
#   1. cherry-pick → main に取り込み（上記 git commit 済み）
#   2. worktree remove（feature branch が checked out されていた worktree を削除）
#   3. branch -D（worktree が remove されたので削除可能になる）

MAIN_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
WORKER_PATH="${worker_result.worktreePath:-}"

# Step 2: worktree remove
if [ -n "${WORKER_PATH}" ] && [ "${WORKER_PATH}" != "${MAIN_REPO_ROOT}" ]; then
    git worktree remove "${WORKER_PATH}" --force 2>/dev/null || true
fi

# Step 3: branch -D（worktree remove 後なので安全）
if [ -n "${worker_result.branch}" ] && \
   [ "${worker_result.branch}" != "main" ] && \
   [ "${worker_result.branch}" != "master" ] && \
   [ "${worker_result.branch}" != "${TRUNK}" ]; then
    git branch -D "${worker_result.branch}" 2>/dev/null || true
fi
```

Plans.md を更新:

```bash
# cc:WIP → cc:完了 [{hash}] に更新
HASH=$(git rev-parse --short HEAD)
# Plans.md の該当タスク行を更新
```

### Step 6: plateau 判定

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/detect-review-plateau.sh" ${current_task_id}
PLATEAU_EXIT=$?
# ※ current_task_id は Step 1 で特定した task_id
```

| exit code | 意味 | アクション |
|-----------|------|----------|
| `0` | `PIVOT_NOT_REQUIRED` | 続行 |
| `1` | `INSUFFICIENT_DATA` | 続行（データ不足） |
| `2` | `PIVOT_REQUIRED` | advisor を 1 回だけ挟む。`STOP` か相談枠切れのときだけ **ループ停止** + エスカレーション |

**PIVOT_REQUIRED 時のエスカレーションメッセージ**:

```
harness-loop: plateau 検知により停止（サイクル {N}/{max}）

検知された問題:
  {plateau の詳細: detect-review-plateau.sh の出力}

対応案:
  1. 手動でタスク内容を見直す
  2. `--pacing plateau` で間隔を延ばして再実行
  3. 問題タスクをスキップして `/harness-loop` を再起動

現在の Plans.md 状態を確認してください。
```

### Step 7: サイクル数チェック

```
cycles_completed += 1
if cycles_completed >= max_cycles:
    ループ停止
    print(f"harness-loop: {max_cycles} サイクル完了で停止")
    return
```

- default `max_cycles = 8`
- `--max-cycles N` 指定時は N サイクルで停止

**サイクルカウントの永続化**:
- `ScheduleWakeup` の `prompt` 引数にカウントを埋め込む:
  ```
  /harness-loop all --max-cycles 8 --cycles-done {N} --pacing worker
  ```
- wake-up 時に `--cycles-done N` を読み取り、カウントを復元する

### Step 8: checkpoint 記録

```json
{
  "session_id": "<現在のセッション ID>",
  "title": "harness-loop cycle {N}/{max}: {task_completed}",
  "content": "cycle {N} 完了。commit: {commit}。変更: {files_changed}。次: {next_task}"
}
```

`harness_mem_record_checkpoint` ツールでメモリに記録する。
次の wake-up の resume pack に自動的に含まれる。

### Step 9: 次 wake-up 予約

```
ScheduleWakeup(
    delaySeconds=<pacing に対応する値>,
    prompt="/harness-loop <同じ引数> --cycles-done {N}",
    reason="サイクル {N}/{max} 完了: {task_completed}"
)
```

**pacing に対応する delaySeconds**:

| pacing | delaySeconds | 選定理由 |
|--------|-------------|---------|
| `worker` | 270 | Worker 完了直後の再入（5 min cache warm 以内） |
| `ci` | 270 | CI ジョブの最短完了を想定した待機 |
| `plateau` | 1200 | 20 min 冷却期間（plateau 回避） |
| `night` | 3600 | 深夜バッチ（最大 clamp 値） |

> **clamp 制約**: `ScheduleWakeup` は `delaySeconds` を `[60, 3600]` にランタイムで clamp する。
> 60 未満を指定すると 60 に切り上げ、3600 超を指定すると 3600 に切り下げられる。
> 設計値は全て範囲内だが、将来的な変更時は要注意。

---

## サイクル停止条件マトリクス

| 条件 | サイクル数 | exit | 停止理由 | ユーザー通知 |
|------|-----------|------|---------|------------|
| `cycles >= max_cycles` | N (上限) | 0 | 正常上限 | 「{N} サイクル完了で停止」 |
| `PIVOT_REQUIRED` | 任意 | 2 | plateau 検知 | エスカレーション詳細 |
| 未完了タスクなし | 任意 | 0 | 全タスク完了 | 完了報告 |
| ユーザーキャンセル | 任意 | - | 手動中断 | - |

---

## pacing 選択ガイド

### どの pacing を使うべきか

```
タスクの性質は？
│
├── Worker 完了直後に再入したい
│     → worker（270s）
│
├── CI / テストの完了を待つ必要がある
│     → ci（270s）
│     ※ CI が 270s 以上かかる場合は手動で --pacing を調整
│
├── plateau を検知して間隔を空けたい
│     → plateau（1200s）
│
└── 深夜に放置して翌朝確認したい
      → night（3600s）
```

### pacing 変更のタイミング

- **初回起動時**: 通常は `worker`（デフォルト）で良い
- **CI 待ちが多い場合**: `--pacing ci` に切り替え
- **plateau 検知後**: `--pacing plateau` で自動切り替えを検討（Step 5 参照）
- **夜間放置**: `--pacing night` で起動してそのまま就寝

---

## ScheduleWakeup の制約詳細

### delaySeconds のランタイム制約

```
ScheduleWakeup(delaySeconds=X)
  → X < 60  → clamp to 60
  → X > 3600 → clamp to 3600
  → 60 <= X <= 3600 → そのまま使用
```

### cache TTL との関係

ScheduleWakeup の cache TTL は **5 min（300s）**。

- `worker` / `ci` の 270s は 5 min 以内 → cache warm な状態で wake-up
- `plateau` の 1200s、`night` の 3600s は cache 失効後に wake-up
  → Step 2（resume pack 再読込）が特に重要

### prompt の引数引き継ぎ

サイクルカウントを次の wake-up に引き継ぐ方法:

```bash
# 現在の cycle count を prompt に埋め込む
NEXT_PROMPT="/harness-loop ${SCOPE} --max-cycles ${MAX_CYCLES} --cycles-done ${CYCLES_DONE} --pacing ${PACING}"

ScheduleWakeup(
    delaySeconds=${DELAY},
    prompt="${NEXT_PROMPT}",
    reason="cycle ${CYCLES_DONE}/${MAX_CYCLES} 完了"
)
```

---

## 参考: spike 41.0.0 の検証結果

この設計は spike 41.0.0 の実証結果に基づく:

- `ScheduleWakeup`: 内部ツールとして存在確認済み。delay [60, 3600] clamp、cache 5min TTL
- `/loop`: CC dynamic mode として存在確認済み。sentinel `<<autonomous-loop-dynamic>>`
- `harness_mem_record_checkpoint`: 存在確認済み（schema: session_id / title / content 必須）

これらの前提が変わった場合は本ファイルを更新すること。
