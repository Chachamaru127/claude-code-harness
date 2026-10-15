---
name: harness-work
description: "HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel, composer, composer 2.5. Do NOT load for: planning, review, release, setup."
description-en: "HAR: Execute Plans.md tasks from single task to full parallel team run. Trigger: implement, execute, do everything, breezing, team run, parallel, composer, composer 2.5. Do NOT load for: planning, review, release, setup."
description-ja: "HAR:Plans.md タスクを1件から全並列チーム実行まで担当。実装して、実行して、全部やって、breezing、チーム実行、parallel、composer、コンポーザー、composer 2.5 で起動。プランニング・レビュー・リリース・セットアップには使わない。"
kind: workflow
purpose: "Execute Plans.md tasks end to end"
trigger: "implement, execute, do everything, breezing, team run, parallel, composer, composer 2.5, composer mode, コンポーザー"
shape: workflow
role: executor
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "Monitor"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--resume id] [--breezing] [--auto-mode] [--tdd-bypass]"
user-invocable: true
effort: high
---

# Harness Work

Harness の統合実行スキル。
以下の旧スキルを統合:

- `work` — Plans.md タスクの実装（スコープ自動判断）
- `impl` — 機能実装（タスクベース）
- `breezing` — チームフル自動実行
- `parallel-workflows` — 並列ワークフロー最適化
- `ci` — CI 失敗時の復旧

## Quick Reference

| ユーザー入力 | モード | 動作 |
|------------|--------|------|
| `/harness-work` | **auto** | タスク数で自動判定（下記参照） |
| `/harness-work all` | **auto** | 全未完了タスクを自動モードで実行 |
| `/harness-work 3` | solo | タスク3だけ即実行 |
| `/harness-work --parallel 5` | parallel | 5ワーカーで並列実行（強制） |
| `/harness-work --codex` | codex | Codex CLI に委託（明示時のみ） |
| Cursor host (adapter candidate) | cursor | Task/subagent routing via `.cursor/AGENTS.md`; not auto-selected |
| `/harness-work --breezing` | breezing | チーム実行を強制 |
| `/harness-work 3 --plan roadmap` | solo | named Plans の `roadmap` からタスク3を実行 |

## Execution Mode Auto Selection（フラグなし時の自動判定）

明示的なモードフラグ（`--parallel`, `--breezing`, `--codex`）がない場合、
対象タスク数に応じて最適なモードを自動選択する:

| 対象タスク数 | 自動選択モード | 理由 |
|-------------|---------------|------|
| **1 件** | Solo | オーバーヘッド最小。直接実装が最速 |
| **2〜3 件** | Parallel（Task tool） | Worker 分離のメリットが出始める閾値 |
| **4 件以上** | Breezing | Lead 調整 + Worker 並列 + Reviewer 独立の三者分離が効果的 |

### ルール

1. **明示フラグは常にオートモードを上書き**する（`--parallel N` / `--breezing` / `--codex` はタスク数に関係なく強制）
2. **`--codex` は明示時のみ発動**。Codex CLI が未インストールの環境があるため、自動選択しない
3. `--codex` は他モードと組み合わせ可能: `--codex --breezing` → Codex + Breezing

## Execution Backend Selection（実装バックエンド選択）

バックエンド（どのランタイムが**実装するか**）は、実行モード（トポロジー: solo / parallel / breezing）と直交する。

| backend | 実装の担い手 | 委託コマンド |
|---------|------------|------------|
| `claude`（既定） | Task subagent（`agents/worker.md`） | Agent tool で worker を spawn |
| `codex` | Codex CLI | `bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "<prompt>"` |
| `cursor` | cursor-agent（model `composer-2.5-fast`） | `bash "${HARNESS_PLUGIN_ROOT}/scripts/cursor-companion.sh" task --write --workspace <worktree> "<prompt>"` |

Codex 呼び出しのガバナンス詳細（禁止事項・verdict マッピング等）は
[references/codex-cli-only.md](${CLAUDE_SKILL_DIR}/references/codex-cli-only.md) を参照。

run 開始時に resolver で 1 回だけ解決する。`HARNESS_IMPL_BACKEND` env を直接読んで backend を決めてはならない:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/resolve-impl-backend.sh"
```

precedence（高い順）: 明示フラグ（`--backend` / `--cursor` / `--codex`） > env > project file > user file > 既定 `claude`。プロジェクト設定はユーザースコープを上書きする。

### Backend 既定（`claude` は意図された既定、警告は不正値 fallback 時のみ）

既定 backend は `claude`（Native subagent）。resolver の未設定 fallback も `claude` であり、正常に `claude` へ解決された場合に警告は**出さない**（2026-07-24 operator 裁定。フォーマットは `breezing` の Narration Rules「Backend 既定と per-run のフラット判断」と同一、cross-ref: `skills/breezing/SKILL.md`）。

- ⚠️ 警告を出すのは resolver が **不正値 fallback** の stderr 警告を出した時だけ。banner 直後に 1 行、同一 run 内で繰り返さない
- Lead は作業内容・量に応じて per-run で backend をフラットに選んでよい。選ぶ時は resolver への明示 override（`--backend <v>` / `--codex` / `--cursor`）を使う
- `composer` / `コンポーザー` / `composer 2.5` 等の自然言語表現は `--cursor` と同じ intent として扱い、resolver に `--backend cursor` を明示 override で渡す（自然言語 backend trigger）

バックエンドは **role-scoped**: 解決済みバックエンドに従うのは実装（worker）ロールのみ。Reviewer / Advisor は常に brain（`--host claude`）固定（primary reviewer を cursor/codex に routing しない）。例外は **fresh-context advisory pre-review** のみ: diff を生成した session と会話状態を共有しない cursor `review` tier が advisory findings を出すことは許可、primary verdict（`APPROVE | REQUEST_CHANGES`）は brain のみが出す。

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host cursor --role worker --field model
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host claude --role reviewer --field model
```

backend が `codex` / `cursor` の場合、Lead は Worker agent を spawn せず companion を直接呼ぶ（Worker 介在なしトポロジー）。self_review ゲートはスキップし、Lead の diff レビューが唯一の品質ゲートになる。委託前に cursor backend banner を出力し、cherry-pick 前に contract grep 二段ゲート（`test-support-claim-wording.sh` / `check-consistency.sh` / `validate-plugin.sh`）を通す。Mode 1 の Producer → Sub-Lead → Composer 階層、review→iterate ループの詳細は
[references/backend-selection.md](${CLAUDE_SKILL_DIR}/references/backend-selection.md) を参照。

## オプション

| オプション | 説明 | デフォルト |
|----------|------|----------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--parallel N` | 並列ワーカー数（CC 側の同時実行キャップ 既定 20 が上限。詳細は下記） | auto |
| `--sequential` | 直列実行強制 | - |
| `--codex` | Codex CLI で実装委託（明示時のみ、自動選択しない） | false |
| `--backend <claude\|codex\|cursor>` | 明示バックエンド選択（worker ロールのみ適用、precedence 最上位） | claude |
| `--cursor` | cursor backend（`--codex` と同様、明示時のみ。cursor-agent 未インストール環境があるため自動選択しない） | false |
| `--plan NAME` | `plans/manifest.json` の named plan を使う | active/default |
| `--no-commit` | 自動コミット抑制 | false |
| `--resume <id\|latest>` | 前回セッション再開。長く空いた後は `/recap` 併用を推奨 | - |
| `--breezing` | Lead/Worker/Reviewer のチーム実行 | false |
| `--no-tdd` | TDD フェーズスキップ | false |
| `--tdd-bypass` | 緊急時だけ TDD 強制を bypass。`HARNESS_TDD_BYPASS_REASON` または明示理由を audit に残す | false |
| `--no-simplify` | Auto-Refinement スキップ | false |
| `--auto-mode` | Harness 側の Auto Mode rollout を明示。CC 2.1.111 で不要になった `--enable-auto-mode` とは別物 | false |

## Progressive Disclosure

実行依頼は、目的と理由、担当範囲、検証可能な DoD、選択した plan / spec、観測済み証拠、原依頼と適用される承認の参照を渡す。
以降の `{task prompt}` と companion のタスク本文にはこれらを含める。再試行でも元の範囲と条件を残し、追加の finding や advisor response だけで置き換えない。
方法は担当が選ぶ。承認済みの可逆作業を再確認で止めず、不足情報は契約と読み取り調査で回収する。軽微な仮定は明示し、重大な仕様判断や不足する権限に依存する操作だけ止める。
評価・相談だけの依頼から実装を開始しない。推定した変更範囲は保護操作の承認ではない。
独立して検証できる作業を、担当ファイルと同時実行上限を明記して委譲する。他担当の編集を戻さず、関連する follow-up は同じ担当へ返す。Lead も仕様調査や証拠照合を進める。
必須チェックと既定レビューを完了した後は、新しい変更、失敗、未解決の懸念がない限り追加テストや機能を増やさない。
完了報告は実際の差分と検証結果で支え、自己申告だけで完了を判定しない。理由と参照可能な証拠を返し、内部の思考過程は求めない。

まずこの本文で入口、自動選択、停止条件だけを確認する。詳細は必要になった時だけ読む。

| 詳細 | 参照 |
|---|---|
| Solo / Breezing の 1〜17 ステップ完全版、Phase A/B/C 完全版 | `references/execution-modes.md` |
| Backend role-scoped 制約、非 claude トポロジー、Mode 1 階層、review→iterate | `references/backend-selection.md` |
| Codex review、Reviewer fallback、verdict mapping、修正ループ | `references/review-loop.md` |
| Sprint Contract フィールド一覧、PR Closeout | `references/sprint-contract.md` |
| effort tier の多要素スコアリング詳細 | `references/effort-routing.md` |
| Solo / Breezing 完了報告の生成 | `references/completion-report.md` |
| テスト/CI 失敗時の再チケット化コマンド | `references/failure-reticketing.md` |
| 仕様正本チェックの基準 | `docs/plans/spec-ssot.md` |

### 重要停止条件

- `Plans.md` が旧フォーマットで DoD / Depends / Status を読めない時は停止する。
- 仕様が実装判断に影響するのに project spec SSOT が見つからない時は、先に仕様正本を作成/更新してから実装する。
- sprint-contract が required なのに ready でない時は実装に進まない。
- critical / major review finding が残っている時は完了にしない。
- テストを弱める、skip する、期待値を実装に合わせて緩める形では解決しない。
- helper script は host project の `scripts/` ではなく `${HARNESS_PLUGIN_ROOT}/scripts/` から呼ぶ。
- 複数 Plans.md がある場合は、1 run の中で plan を切り替えない。必要なら `--plan NAME` を明示して新しい run を開始する。

### 自主停止の禁止 (140.3、2026-08-22 の release run で 2 回発生した停止パターンの再発防止)

以下は禁止行動。literal に列挙する (AUTOSTART pattern と同じ方式):

- background 待ちで turn を終えて停止しない (turn を終えると background 子プロセスは残らない)
- 「検証を待ちます」「確認します」「完了を待機します」で turn を終えない
- 待つなら同期実行 (foreground / Monitor) で待ち切る。待てないものは保留として報告し、次のタスクへ進む

> **Token Optimization (v2.1.69+)**: git 操作を伴わない軽量タスクでは
> plugin settings の `includeGitInstructions: false` を有効にしてプロンプトトークンを削減できる。

> **Prompt Cache (CC 2.1.108+)**: 長めの実装や `--resume` を多用する作業では
> `ENABLE_PROMPT_CACHING_1H=1` を優先する。

## スコープダイアログ（引数なし時）

直前の明示依頼や選択済み plan で対象が確定していれば、その範囲を使う。以下の確認は対象範囲が未決の場合だけ行う。

```
/harness-work
どこまでやりますか?
1) 次のタスク: Plans.md の次の未完了タスク → Solo で実行
2) 全部（推奨）: 残りのタスクをすべて完了 → タスク数で自動モード選択
3) 番号指定: タスク番号を入力（例: 3, 5-7）→ 件数で自動モード選択
```

引数ありなら即実行（対話スキップ）:
- `/harness-work all` → 全タスク、自動モード選択
- `/harness-work 3-6` → 4件なので Breezing 自動選択

## モデルごとの推論量

effort は推論に使う量の指定。利用者の明示設定を優先し、未指定の担当は `scripts/model-routing.sh` の役割別設定を使う。
CCH のモデルと effort は未指定時の既定値であり、利用者の明示指定と手動変更を尊重する。AI が文言から再調整したり、親の変更を全 Worker へ配ったりしない。担当別 profile と独立 Reviewer の隔離契約は維持する。
Fable 5.1 の計画と相談は `high`。実装 worker と独立 reviewer は、それぞれの設定を使う。
複雑度スコアは見直しの判断材料であり、明示した推論量を自動変更する許可ではない。
free-text marker（旧 `ultrathink`）を spawn prompt に注入しない。

| スコア | code-risk（core/guardrails/security/architecture/migration を含む） | 見直し候補 |
|--------|-----------------------------------|-------------|
| 0-2 | 不問 | `medium`（Worker frontmatter 既定のまま） |
| ≥ 3 | なし | `high` |
| ≥ 3 | あり | `xhigh` |

breezing モードでも同じロジックを適用する（harness-work が一本化して管理）。スコアリング内訳・lever の詳細は
[references/effort-routing.md](${CLAUDE_SKILL_DIR}/references/effort-routing.md) を参照。

## 実行モード詳細

### Harness helper script root

Harness が同梱する helper script は、作業対象プロジェクトの `scripts/` ではなく、必ず plugin bundle root から呼ぶ。

```bash
HARNESS_PLUGIN_ROOT="${HARNESS_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ] && [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
  probe="$(cd "${CLAUDE_SKILL_DIR}" && pwd)"
  while [ "$probe" != "/" ] && [ ! -d "$probe/scripts" ]; do
    probe="$(cd "$probe/.." && pwd)"
  done
  [ -d "$probe/scripts" ] && HARNESS_PLUGIN_ROOT="$probe"
fi
```

以降の `node "${HARNESS_PLUGIN_ROOT}/scripts/..."` / `bash "${HARNESS_PLUGIN_ROOT}/scripts/..."` は、この解決済み root を前提にする。

### Backend-resolved executor path (Solo / Parallel / Breezing)

Solo / Parallel / Breezing は同じ resolver result から実装 executor を選ぶ。
`harness-work 3 --cursor` や resolver 出力が `cursor` の run（project / user file 経由の default 含む）は、1 件タスクでも local Read/Write/Edit/Bash に fall through してはいけない。

```
resolver_backend_arg = ""
if explicit_backend_value in ["claude", "codex", "cursor"]:
    resolver_backend_arg = "--backend {explicit_backend_value}"
backend = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/resolve-impl-backend.sh\" {resolver_backend_arg}")
if explicit_flag == "--cursor":
    backend = "cursor"
if explicit_flag == "--codex":
    backend = "codex"

if topology in ["solo", "parallel"] and backend in ["cursor", "codex"]:
    BASE_REF = git("rev-parse", "HEAD")
    WT_ID = "{task.number}-$(date +%Y%m%d-%H%M%S)-$$"
    worktree_path = ".claude/worktrees/{backend}-{WT_ID}"
    worktree_branch = "{backend}-work/{WT_ID}"
    bash("mkdir -p .claude/worktrees && git worktree add -b {worktree_branch} {worktree_path} {BASE_REF}")
    companion_prompt = "{task prompt}\n\nAfter making changes, create exactly one git commit in this worktree before returning."
    if backend == "cursor":
        companion_output = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/cursor-companion.sh\" task --write --workspace {worktree_path} \"{companion_prompt}\"")
    else:
        companion_state_file = "{worktree_path}/.claude/state/codex-primary-environment.json"
        companion_output = bash("CODEX_MODEL_TIER=worker HARNESS_CODEX_PRIMARY_ENV_STATE_FILE={companion_state_file} bash \"${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh\" task --write -C {worktree_path} \"{companion_prompt}\"")
    latest_commit = git("-C", worktree_path, "rev-parse", "HEAD")
    if backend == "cursor" and git("-C", worktree_path, "status", "--porcelain") != "":
        git("-C", worktree_path, "add", "-A")
        git("-C", worktree_path, "-c", "user.name=cursor-composer", "-c", "user.email=cursor-composer@local", "commit", "--no-verify", "-m", "cursor: delegated change")
        latest_commit = git("-C", worktree_path, "rev-parse", "HEAD")
    if latest_commit == BASE_REF:
        raise EscalationError("{backend} companion produced no commit")
    worker_result = {type: "companion-result.v1", baseCommit: BASE_REF, commit: latest_commit, worktreePath: worktree_path, branch: worktree_branch, files_changed: git("-C", worktree_path, "diff", "--name-only", "{BASE_REF}..HEAD"), summary: companion_output}
    enter_non_claude_companion_review_loop(worker_result)
else:
    run_native_solo_or_parallel()

def enter_non_claude_companion_review_loop(worker_result):
    # companion-result.v1 has no worker_id and no worker_result.self_review.
    # Do not use the Worker-only SendMessage/self_review loop for cursor/codex.
    latest_commit = worker_result.commit
    diff_text = git("-C", worker_result.worktreePath, "diff", "{worker_result.baseCommit}..HEAD")
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
    review_count = 0
    MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
    while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
        previous_commit = latest_commit
        if backend == "cursor":
            companion_output = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/cursor-companion.sh\" task --write --workspace {worker_result.worktreePath} \"{task prompt}\n\nReview findings:\n{issues}\n\nPreserve the original DoD, owned scope and authorization references. Fix the findings and commit the result.\"")
        else:
            companion_state_file = "{worker_result.worktreePath}/.claude/state/codex-primary-environment.json"
            companion_output = bash("CODEX_MODEL_TIER=worker HARNESS_CODEX_PRIMARY_ENV_STATE_FILE={companion_state_file} bash \"${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh\" task --write -C {worker_result.worktreePath} \"{task prompt}\n\nReview findings:\n{issues}\n\nPreserve the original DoD, owned scope and authorization references. Fix the findings and commit the result.\"")
        latest_commit = git("-C", worker_result.worktreePath, "rev-parse", "HEAD")
        if backend == "cursor" and git("-C", worker_result.worktreePath, "status", "--porcelain") != "":
            git("-C", worker_result.worktreePath, "add", "-A")
            git("-C", worker_result.worktreePath, "-c", "user.name=cursor-composer", "-c", "user.email=cursor-composer@local", "commit", "--no-verify", "-m", "cursor: review fix")
            latest_commit = git("-C", worker_result.worktreePath, "rev-parse", "HEAD")
        if latest_commit == previous_commit:
            raise EscalationError("{backend} companion retry produced no new commit")
        worker_result.commit = latest_commit
        worker_result.summary = companion_output
        diff_text = git("-C", worker_result.worktreePath, "diff", "{worker_result.baseCommit}..HEAD")
        verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
        review_count++
    if verdict == "APPROVE":
        git cherry-pick --no-commit {worker_result.baseCommit}..{worker_result.commit}
```

Parallel は task ごとにこの resolver path を適用する。
backend=`cursor` / `codex` の場合は native Worker spawn を使わず、task ごとに isolated companion worktree を作成して `companion-result.v1` に正規化してから non-Claude companion 専用の range review / cherry-pick loop に入る。

### Solo モード（1 件時の自動選択）

Plans.md 読み込みから `cc:完了 [hash]` までの 1〜17 ステップ完全版は
[references/execution-modes.md#solo-detailed-steps](${CLAUDE_SKILL_DIR}/references/execution-modes.md) を参照。
要点: **仕様正本 preflight** で spec SSOT の有無を確認し `spec_path` を Worker/Reviewer に渡す。plan-time 事前確認を適用し、
work 中の宣言済み事項起因 `AskUserQuestion` はゼロにする。TDD Red → sprint-contract → 実装 → レビューループ → commit → `cc:完了` の順で進める。

### Parallel モード（2〜3 件時の自動選択 / `--parallel N` で強制）

`[P]` マーク付きタスクを N ワーカーで並列実行。
`--parallel N` で明示指定した場合は、タスク数に関係なくこのモードを使用。

**N は希望値で、実際の同時実行数は CC が決める**（133.9、一次ソース確証済み）。CC は同時実行中の
subagent を既定 20 に制限し（`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`、2.1.217）、超過分は待ち行列に
入るだけでエラーにはならない。ネストした spawn は既定で深さ 3 まで
（`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`、2.1.219 で 1 → 3 に緩和）で、Lead（0）→ Worker（1）→
Worker が呼ぶ advisor（2）は収まる。これを超える階層は env で上げない限り静かに拒否される。
Harness 側はどちらの env も明示設定せず、CC の既定に従う。
同一ファイルへの書き込みが競合する場合は git worktree で分離。
各 task の実装 executor は Backend-resolved executor path に従う。
`--parallel N --cursor`、`--backend cursor`、または resolver 出力が `cursor` の場合、Parallel でも native Worker spawn ではなく task ごとの Cursor companion worktree を使う。

### Codex モード（`--codex` 明示時のみ）

公式プラグイン `codex-plugin-cc` の companion 経由で Codex CLI にタスクを委託する。

```bash
# タスク委託（書き込み可能・worktree 分離）
BASE_REF="$(git rev-parse HEAD)"
WT_ID="codex-$(date +%Y%m%d-%H%M%S)-$$"
WORKTREE_PATH=".claude/worktrees/${WT_ID}"
git worktree add -b "codex-work/${WT_ID}" "$WORKTREE_PATH" "$BASE_REF"
CODEX_MODEL_TIER=worker HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="$WORKTREE_PATH/.claude/state/codex-primary-environment.json" \
  bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write -C "$WORKTREE_PATH" \
  "タスク内容。完了前にこの worktree で exactly one git commit を作成してください。"

# stdin 経由（大きなプロンプト向け）
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# タスク内容を書き出し
cat "$CODEX_PROMPT" | CODEX_MODEL_TIER=worker HARNESS_CODEX_PRIMARY_ENV_STATE_FILE="$WORKTREE_PATH/.claude/state/codex-primary-environment.json" \
  bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write -C "$WORKTREE_PATH"
rm -f "$CODEX_PROMPT"

# Lead review 後に承認されたら range を取り込む
git -C "$WORKTREE_PATH" diff "$BASE_REF..HEAD"
WORKTREE_HEAD="$(git -C "$WORKTREE_PATH" rev-parse HEAD)"
git cherry-pick --no-commit "$BASE_REF..$WORKTREE_HEAD"
```

companion は App Server Protocol 経由で Codex と通信し、
Job 管理・thread resume・構造化出力を提供する。
結果を検証し、品質基準を満たさない場合は自力で修正。

### Cursor モード（adapter candidate、自動選択しない）

Cursor host では `.cursor/AGENTS.md` と `.cursor-plugin/plugin.json` が
bootstrap route。Cursor は `candidate` のまま — supported claim は禁止。

- **Solo / Parallel**: Task tool または `.cursor/agents/worker.md` subagent
- **Breezing**: Worker 並列は non-overlapping file groups のみ;
  Reviewer / cherry-pick / Advisor は core どおり直列
- **Multitask / background agents**: smoke target のみ。Claude Agent Teams parity
  を主張しない

```bash
bash scripts/model-routing.sh --host cursor --role worker --format json
bash tests/test-cursor-adapter-candidate.sh
```

Explicit Task/subagent `model` が routed default より優先。

### Breezing モード（4 件以上で自動選択 / `--breezing` で強制）

Lead / Worker / Advisor / Reviewer の役割分離でチーム実行する。
Codex では `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`
を使った native subagent orchestration を前提にする。
Cursor では Task/subagent/background agents へ mapping するが、
review/cherry-pick の直列責務は core 側に残す（adapter smoke target）。

**権限ポリシー**: 現行の shipped default は `bypassPermissions`。`--auto-mode` は互換な親セッション向けの opt-in rollout フラグ。
`permissions.defaultMode` や agent frontmatter の `permissionMode` には未文書化の `autoMode` 値を書かない。

```
Lead (this agent)
├── Worker (task-worker agent) — 実装担当
├── Advisor (harness:advisor) — 方針助言
└── Reviewer (code-reviewer agent) — レビュー担当
```

Phase A（準備: Plans.md 読み込み・依存解決・plan-preapproval 適用・effort スコアリング・sprint-contract 生成）→
Phase B（各タスク: Worker spawn → 必要時 Advisor → self_review ゲート → レビューループ → APPROVE で trunk へ cherry-pick）→
Phase C（統合: commit log 集計・リッチ完了報告・Plans.md 最終確認）の 3 段構成。
完全版の pseudocode（B-1〜B-7 の逐次手順含む）は
[references/execution-modes.md#breezing-phase-detail](${CLAUDE_SKILL_DIR}/references/execution-modes.md) を参照。

### Active task scope

各タスクの preapproval preflight より前に、対象 worktree の
`.claude/state/active-task.json` へ `{"phase":"<phase>","task":"<task>"}` を
原子的に書く。Go guardrail はこのファイルを現在スコープの正本として読む。
タスク終了時は成功、失敗、停止のどの経路でも削除する。環境変数
`HARNESS_ACTIVE_PHASE` / `HARNESS_ACTIVE_TASK` は、state ファイルが存在しない
host の fallback に限る。

Parallel / Breezing ではタスクごとの worktree に書く。同じ worktree の
`active-task.json` を複数タスクで共有しない。

### Work Mode Lifecycle (`bin/harness work-mode`)

R04（project root 外への書き込み）/ R05（危険な rm）の確認 skip は
`ctx.WorkMode` に依存するが、これを立てる経路は 2 つとも実効しない状態だった:
`HARNESS_WORK_MODE` / `ULTRAWORK_MODE` env は skill / hook から設定する手段がなく、
`state.SetWorkState`（SQLite `work_states` 行）も呼び出し元が皆無だった。
`bin/harness work-mode <on|off|status>` がこの SQLite 経路を書く唯一の入口になる。

- Lead は **run 開始時**（Phase A 開始前、solo 実行では最初の実装アクション前）に
  `bin/harness work-mode on` を実行する。`--codex` run では
  `bin/harness work-mode on --codex`（R07 = Lead の直接 Write/Edit 禁止が同時に立つ）
- Lead は **run 終了時**、成功・失敗・中断の全経路で `bin/harness work-mode off` を実行する。
  `active-task.json` と同じ「終了時はどの経路でも後始末する」規律を適用する
- run 単位（Phase A〜C を通じて 1 回）であり、`active-task.json` のようなタスクごとの
  書き込みではない。子 worktree で個別に on/off しない
- session ID の解決順は `--session-id` フラグ → `HARNESS_SESSION_ID` env
  （SessionStart hook が CLAUDE_ENV_FILE 経由で export する実 session_id）→
  `.claude/state/last-session-id.json`（鮮度 2 時間以内）。旧
  `.claude/state/session.json` の内部 ID は guardrail が受け取る ID と一致しない
  ため**受理されない**。解決できない場合 `work-mode` は非ゼロ終了し理由を
  stderr に出す（無言で成功しない）

### Advisor Protocol（全モード共通）

Advisor は「実装者」でも「レビュー担当」でもない。迷った時だけ、実行役が次の一歩を決めるための相談役として入る。

1. Worker は generic な subagent を増やさず、必要時だけ `advisor-request.v1` を返す
2. Lead が advisor を 1 回だけ呼ぶ
3. Advisor は `PLAN` / `CORRECTION` / `STOP` のどれかを返す
4. Lead はその advice（`advisor-response.v1`）を同じ Worker に返して続行させる
5. Reviewer は最後の成果物だけを見る。advisor の返答に APPROVE / REQUEST_CHANGES を出さない

solo 実行では親セッション自身が Lead を兼ねる（自分で実装し、自分で advisor に相談し、最後は独立レビューに回す）。
相談条件・budget は breezing と同じで、task ごとの相談回数は最大 3 回。`STOP` はその場で止まり、ユーザー判断へ上げる。review artifact のゲートは飛ばさない。

### Sprint Contract と PR Closeout

`sprint-contract` は「このタスクを何で合格にするか」を機械可読にする契約ファイル（既定: `.claude/state/contracts/<task-id>.sprint-contract.json`、`generate-sprint-contract.js` で生成）。
`runtime_validation` の LSP/AST ワークフロー方針:

- If you grep the same symbol twice in the same session, switch to harness_ast_search.
- For a bugfix where homologous implementations appear across multiple modules, run harness_ast_search to find all implementations before editing.
- Only when changed files include .ts or .tsx, the DoD requires zero new harness_lsp_diagnostics errors; if the harness MCP is not connected or the changed file types are not eligible, treat diagnostics as not-configured and non-blocking.

`spec_path` / `lane` / `stage` / `research_evidence` / `tdd_red_log` / `review_artifact` / `pr_closeout` のフィールド仕様と、
review APPROVE 後の PR title/body 組み立て（`harness-pr-closeout.sh`、既定 `dry-run`）の詳細は
[references/sprint-contract.md](${CLAUDE_SKILL_DIR}/references/sprint-contract.md) を参照。

## CI 失敗時の対応

CI が失敗した場合:

1. ログを確認してエラーを特定
2. 修正を実施
3. 同一原因で 3 回失敗したら自動修正ループを停止
4. 失敗ログ・試みた修正・残る論点をまとめてエスカレーション

## 失敗タスクの自動再チケット化

タスク完了後にテスト/CI が失敗した場合、修正タスク案を自動生成し、承認後に Plans.md へ反映する。
トリガー条件・生成フォーマット・承認コマンド（`approve fix <task_id>` / `reject fix <task_id>`）の詳細は
[references/failure-reticketing.md](${CLAUDE_SKILL_DIR}/references/failure-reticketing.md) を参照。

## レビューループ

実装完了後に自動実行される品質検証ステージ。**全モード共通**（Solo / Parallel / Breezing）で統一的に適用される。
優先順位（Codex exec → 内部 Reviewer agent フォールバック）、APPROVE / REQUEST_CHANGES 判定基準（critical/major のみが verdict に影響）、
verdict マッピング、修正ループ（`MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`）の完全版は
[references/review-loop.md](${CLAUDE_SKILL_DIR}/references/review-loop.md) を参照。

## Completion Report Output Contract

<!-- harness-work-completion-output-contract:start -->
Before rendering a Solo, forced single-task Parallel, or Breezing completion
report:

1. Resolve the active locale with the shared `get_harness_locale` function from
   `${HARNESS_PLUGIN_ROOT}/scripts/config-utils.sh`. Pass an explicit session or
   user language as its optional argument; otherwise keep the resolver priority
   of project `i18n.language`, `CLAUDE_CODE_HARNESS_LANG`, then default `en`.
2. Unset, invalid, and resolved `en` render the English template.
3. Only resolved `ja` renders the Japanese template.
4. Japanese input alone does not select the Japanese template.
5. Read `references/completion-report.md` and render exactly one template for
   the selected mode and locale.
6. Keep machine-readable status and review values in English, and never mix
   English and Japanese labels in one report.
<!-- harness-work-completion-output-contract:end -->

## 進捗の可視化（非エンジニア向け）

タスク実行中は `harness-progress` が進捗の件数と drift alert を 1 枚の HTML にまとめる。
PostToolUse hook で自動再生成されるため、発注者は呼び方を覚えずに最新の進捗ボードを見られる
（`posttool-progress-regen.sh` が最大 1 分に 1 回再生成）。

## 関連スキル

- `harness-plan` — 実行するタスクを計画する
- `harness-sync` — 実装と Plans.md を同期する
- `harness-review` — 実装のレビュー
- `harness-release` — バージョンバンプ・リリース
- `harness-progress` — 進捗ボード HTML（非エンジニア向け、実行中に自動再生成）
