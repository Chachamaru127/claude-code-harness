---
name: cursor-do
description: "Delegate a single write task to Cursor Composer via cursor-companion.sh inside an isolated worktree, then Lead-review the diff and cherry-pick. Use when user invokes /cursor:do, says delegate to cursor, have composer write it, refactor with cursor, hand a file edit to Composer. Do NOT load for: planning, code review only, read-only investigation, or multi-task team runs (use breezing --cursor or /cursor:ask instead)."
description-en: "Delegate a single write task to Cursor Composer via cursor-companion.sh inside an isolated worktree, then Lead-review the diff and cherry-pick. Use when user invokes /cursor:do, says delegate to cursor, have composer write it, refactor with cursor, hand a file edit to Composer. Do NOT load for: planning, code review only, read-only investigation, or multi-task team runs (use breezing --cursor or /cursor:ask instead)."
description-ja: "1 件の write タスクを Cursor Composer に委譲するスキル。専用 worktree (.claude/worktrees/cursor-do-<id>) を切って `cursor-companion.sh task --write --workspace <wt>` を直接呼び、Lead が diff レビュー → main へ cherry-pick → Plans.md `cc:done [hash]` 更新まで一気通貫する。Use when user mentions /cursor:do, cursor で実装して, composer に書かせて, カーソルにやらせて, refactor を Cursor に, ファイル編集を Composer に. Do NOT load for: 計画 (harness-plan), レビューのみ (harness-review), 読み取り調査 (/cursor:ask), 複数タスク並列 (breezing --cursor を使う)."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
argument-hint: "[task-description]"
user-invocable: true
---

# cursor-do — Single-Task Write Delegate to Cursor Composer

1 件の実装タスクを Cursor Composer (`composer-2.5-fast`) に専用 worktree 内で委譲し、Lead が diff をレビューしてから main へ cherry-pick する skill。breezing の team フローを起こさず、1 タスク 1 cherry-pick を最短経路で回す。

封じ込めは Cursor 側にはない (`.claude/rules/cursor-cli-only.md`)。**専用 `.git` を持つ worktree + Lead diff review + cherry-pick (R01-R13 経路)** の 3 点だけが実効的な境界。cursor の出力は Lead レビューまで untrusted として扱う。

## Step 0 — NARRATION RULES (UX Hard Contract)

このスキルは「起動 → 委譲開始」を 3 秒以内に進めるため、中間ナレーションを禁ずる。breezing と同じ契約。違反は UX 不合格として扱う。

- **過去経緯の振り返り禁止**: 「先ほど止まった」「前回 Worker は…」を語らない。Plans.md / git から直読する
- **事前宣言禁止**: 「使い方を確認します」「次は X を確認します」を出さない。tool call 自体が宣言
- **同じ事実の 2 回言い換え禁止**: pre-check 結果を後段で再説明しない
- **中間ステータスラベル禁止**: 「実行中」「実行済み」「次は…」を出さない
- **★ Insight ブロック禁止 (起動シーケンス中)**: Insight は最終 report で 1 回のみ可
- **最初の text は 1 行のみ**: Step 1 の `🚀 cursor / composer-2.5-fast / <branch> / <task>` を first text として 1 秒以内に出す

違反例:
```
× 「composer 2.5 で実装する流れですね、まず確認します」
× 「Cursor を呼ぶ前に branch を見ます」 → bash → 「branch を確認しました」
× ★ Insight ──── Cursor の強みは…
```

正常例:
```
🚀 cursor / composer-2.5-fast / feat/foo-bar / Add login form validation
```

## Step 1 — first text echo (1 行、1 秒以内)

引数 `$ARGUMENTS` をタスク説明として受ける。引数が空なら以下のマーカーを出力してユーザーに 1 行タスクを要求し、入力後に Step 2 へ進む:

```
CURSOR_DO_AWAITING_TASK: provide a one-line task description as $ARGUMENTS
```

引数があれば、即 1 行 echo:

```
🚀 cursor / composer-2.5-fast / <current-branch> / <task-first-60-chars>
```

`<current-branch>` は Step 2 で取得する値だが、Step 1 では未取得のため `…` でも可。Step 2 直後に確定値を 1 行で再出力する。**この echo 以外の text を Step 2 まで一切出さない。**

## Step 2 — 並列 pre-check (1 bash)

1 つの bash 呼び出しで以下を並列に取り、結果だけを 1 ブロックで受ける。個別の説明は出さない。

```bash
bash -c '
  set +e
  echo "==BRANCH=="; git branch --show-current
  echo "==VERSION=="; cat VERSION 2>/dev/null
  echo "==PLANS_TAIL=="; tail -n 12 Plans.md 2>/dev/null
  echo "==CURSOR_AGENT=="; cursor-agent --version 2>/dev/null || echo "NOT_INSTALLED"
'
```

判定:
- `CURSOR_AGENT=NOT_INSTALLED` → `ERROR: cursor-agent not found (exit 3 expected from companion). Install via setup-cursor.sh.` を出し終了。
- `BRANCH` が `main` / `master` → `WARN: on protected branch — cherry-pick target is HEAD of this branch. Confirm intent or switch.` を出し継続。

## Step 3 — backend + model resolve (1 bash)

```bash
bash -c '
  BACKEND=$(bash "${HARNESS_PLUGIN_ROOT:-.}/scripts/resolve-impl-backend.sh" --backend cursor --role worker)
  MODEL=$(bash "${HARNESS_PLUGIN_ROOT:-.}/scripts/model-routing.sh" --host cursor --role worker --field model)
  echo "BACKEND=$BACKEND"
  echo "MODEL=$MODEL"
'
```

`BACKEND` は必ず `cursor`、`MODEL` は通常 `composer-2.5-fast`。どちらかが空なら `ERROR: backend/model resolution failed` を 1 行で出して終了。

## Step 4 — 専用 worktree 作成

衝突しない id を作って worktree を切る。**main tree や `$HOME` を指してはならない** (companion 側 guard で exit 2 になる)。

```bash
bash -c '
  set -euo pipefail
  ID="$(date +%Y%m%d-%H%M%S)-$$"
  WT_DIR=".claude/worktrees/cursor-do-${ID}"
  BASE_REF="$(git rev-parse HEAD)"
  BASE_BRANCH="$(git branch --show-current)"
  WT_BRANCH="cursor-do/${ID}"
  mkdir -p .claude/worktrees
  git worktree add -b "${WT_BRANCH}" "${WT_DIR}" "${BASE_REF}"
  echo "WT_DIR=${WT_DIR}"
  echo "WT_BRANCH=${WT_BRANCH}"
  echo "BASE_REF=${BASE_REF}"
  echo "BASE_BRANCH=${BASE_BRANCH}"
'
```

返却された `WT_DIR` / `WT_BRANCH` / `BASE_REF` / `BASE_BRANCH` を以降の Step で使う。失敗時 (branch 名衝突等) は `ID` を作り直して 1 回だけ retry。2 回連続失敗で `ERROR: worktree creation failed` を出し終了。

## Step 5 — cursor-companion.sh task --write で委譲

Lead が直接 companion を呼ぶ (`.claude/rules/cursor-cli-only.md` Topology 節 — 非 claude backend では Worker 介在なし)。プロンプトは引数の task そのまま + 必要な追補のみ。冗長な前置きは付けない。

```bash
bash -c '
  set -euo pipefail
  PROMPT="<task-description>

Constraints:
- Modify only files relevant to the task.
- Keep existing tests green. Add tests when the task is verifiable.
- Match existing code style and naming.
- Do not touch .claude-plugin/settings*, .claude/settings*, .eslintrc*, biome.json, tsconfig*.json."
  bash "${HARNESS_PLUGIN_ROOT:-.}/scripts/cursor-companion.sh" task \
    --write \
    --workspace "${WT_DIR}" \
    "${PROMPT}"
' 2>&1
```

判定:
- exit 0 + result text → Step 6 へ
- exit 1 (result-error) → companion stderr を 1 行要約して `ERROR: cursor returned is_error/empty result` を出し終了。worktree は Step 8 のクリーンアップで削除
- exit 2 (bad-guard) → 設定不備。原因 (workspace 指定誤り等) を 1 行で示し終了
- exit 3 (not-found) → Step 2 で検出済みのはずだが、再度遭遇したら同様に終了

## Step 6 — Lead diff review

worktree 内で Composer が作成した commit を読み、目視レビュー + contract grep の二段ゲートを通す (`harness-work` 「Lead の cherry-pick 前ゲート」と同じ契約)。

```bash
bash -c '
  set -euo pipefail
  cd "${WT_DIR}"
  echo "==LOG=="
  git log --oneline "${BASE_REF}..HEAD"
  echo "==STAT=="
  git diff --stat "${BASE_REF}..HEAD"
  echo "==DIFF=="
  git diff "${BASE_REF}..HEAD"
'
```

Lead は diff 全文を Read し、以下を確認する:

- 変更が依頼タスクの範囲内か (関係ないファイルを触っていないか)
- protected path (`.claude-plugin/settings*`, `.eslintrc*`, etc.) を変更していないか
- secret / `.env` / 認証情報を含まないか
- 公開 support tier 表記を破壊していないか:
  ```bash
  bash tests/test-support-claim-wording.sh 2>/dev/null || true
  bash scripts/ci/check-consistency.sh 2>/dev/null || true
  bash tests/validate-plugin.sh 2>/dev/null || true
  ```

判定:
- 問題なし → Step 7 へ
- 範囲外変更あり → 該当 commit を `git reset` で巻き戻すか、Cursor に再委譲 (Step 5 を 1 回だけ retry)。2 回失敗で `REQUEST_CHANGES: <理由>` を出し、worktree を残したまま終了
- protected path / secret 検出 → 即 abort。`ABORT: protected path violation` を出し worktree 削除

## Step 7 — cherry-pick + Plans.md cc:done 更新

worktree から main tree に cherry-pick する。**SHA 直接指定** (branch 名経由ではない) で reviewer state drift を避ける (MEMORY: reviewer_state_drift)。

```bash
bash -c '
  set -euo pipefail
  COMMITS=$(cd "${WT_DIR}" && git log --reverse --format=%H "${BASE_REF}..HEAD")
  if [ -z "${COMMITS}" ]; then
    echo "ERROR: no commits to cherry-pick"
    exit 1
  fi
  for SHA in ${COMMITS}; do
    git cherry-pick "${SHA}"
  done
  echo "==CHERRY_PICKED=="
  git log --oneline -n $(echo "${COMMITS}" | wc -l)
'
```

cherry-pick で conflict が出たら `git cherry-pick --abort` し、`CHERRY_PICK_CONFLICT: <files>` を 1 行で示して終了 (worktree は残す、ユーザー判断)。

cherry-pick 後、Plans.md に対応行があれば該当タスクのマーカーを更新する:

```
| <task> | ... | cc:done [<merged-sha>] |
```

該当行の特定: 引数 task 文字列の先頭 40 文字で grep し、ヒットした最初の `cc:TODO` / `cc:WIP` / `cc:todo` 行を `cc:done [<sha>]` に置換する。ヒットなしなら更新スキップ (Plans.md 外のタスクとして扱う)。

## Step 8 — worktree cleanup + 完了報告 (1 ブロック)

cherry-pick 成功後、worktree を delete する。失敗 path では呼ばれない（worktree を残してユーザー判断）。

```bash
bash -c '
  set -euo pipefail
  git worktree remove --force "${WT_DIR}"
  git branch -D "${WT_BRANCH}" 2>/dev/null || true
  echo "==CLEANUP=="
  git worktree list | grep -v "cursor-do-" || true
'
```

完了報告は **1 ブロック** で出す。中間ナレーションなし:

```
✅ cursor-do completed
   task: <task-first-60-chars>
   commits: <count>
   base: <BASE_REF> → cherry-picked into <BASE_BRANCH>
   plans: <updated|skipped (no match)>
   files: <changed-file-count> changed, +<inserts> -<deletes>
```

## Full Containment (write mode 必須)

| 層 | 役割 | skip 可否 |
|---|---|---|
| 専用 `.git` worktree | cursor の書込を main tree から隔離 | 不可（必須） |
| Lead diff review | untrusted cursor 出力の品質ゲート | 不可（必須） |
| contract-grep ゲート | docs / locale / matrix 固定文字列の保護 | 不可（必須） |
| cherry-pick → main | R01-R13 guard rail を通す唯一の経路 | 不可（必須） |
| Plans.md cc:done 更新 | 台帳との sync | 該当行なければ skip 可 |

## Prohibited

- `--force` / `--yolo` を companion に渡す（Cursor 公式 "Never use"）
- cursor 出力を Lead レビュー前に main へ直接 commit する
- protected path (`.claude-plugin/settings*`, `.eslintrc*`, `tsconfig*.json`, etc.) を Step 5 の prompt で許可する
- `$HOME` / `/` / main tree を `--workspace` に指定する
- Plans.md の `cc:*` マーカーを task と無関係に書き換える

## Related Skills / Rules

- `cursor-ask` — 読取専用の質問・調査・敵対的視点 (worktree 不要)
- `breezing --cursor` — 複数タスクを team フローで cursor 委譲する場合
- `harness-work` — claude backend の default フロー (Worker agent 経由)
- `.claude/rules/cursor-cli-only.md` — Cursor backend governance + Topology
