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

1. **明示フラグは常にオートモードを上書き**する
   - `--parallel N` → Parallel モード（タスク数に関係なく）
   - `--breezing` → Breezing モード（タスク数に関係なく）
   - `--codex` → Codex モード（タスク数に関係なく）
2. **`--codex` は明示時のみ発動**。Codex CLI が未インストールの環境があるため、自動選択しない
3. `--codex` は他モードと組み合わせ可能: `--codex --breezing` → Codex + Breezing

## Execution Backend Selection（実装バックエンド選択）

バックエンド（どのランタイムが**実装するか**）は、実行モード（トポロジー: solo / parallel / breezing）と直交する。
実行モードが「何ワーカーで・どう分割して回すか」を決めるのに対し、バックエンドは「実装の手を誰が動かすか」を決める。

| backend | 実装の担い手 | 委託コマンド |
|---------|------------|------------|
| `claude`（既定） | Task subagent（`agents/worker.md`） | Agent tool で worker を spawn |
| `codex` | Codex CLI | `bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "<prompt>"` |
| `cursor` | cursor-agent（model `composer-2.5-fast`） | `bash "${HARNESS_PLUGIN_ROOT}/scripts/cursor-companion.sh" task --write --workspace <worktree> "<prompt>"` |

### 解決手順

run 開始時に 1 回だけ解決する:

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/resolve-impl-backend.sh"
```

precedence（高い順）: `--backend <v>` / `--cursor` / `--codex` フラグ > `HARNESS_IMPL_BACKEND` 環境変数 > プロジェクト `env.local` の同名行 > ユーザー `~/.config/claude-harness/impl-backend.env` の同名行 > 既定値 `claude`。プロジェクト設定はユーザースコープを上書きする。
明示フラグ（`--backend` / `--cursor` / `--codex`）は env / file / default を常に上書きする。

### 自然言語 backend trigger

ユーザーが `composer` / `コンポーザー` / `Composer で` / `composer 2.5` / `composer モード` と言った場合は、`cursor backend` 指定として扱う。
これは `--cursor` と同じ intent だが、backend の確定値は必ず `resolve-impl-backend.sh` で解決する。
解決時は明示 override として `--backend cursor` を渡し、env / project / user file / default より優先させる。
Lead は `composer` を Claude Worker 内の追加 agent と解釈せず、非 `claude` backend の規約どおり Worker agent を挟まずに `cursor-companion.sh` を直接呼ぶ。

### role-scoped 制約

バックエンドは **role-scoped**。解決済みバックエンドを使うのは実装（worker）ロールだけ。
Reviewer と Advisor の両ロールは常に brain（`--host claude`、Opus）に固定する。
Reviewer を cursor / codex バックエンドに routing しない（実装したバックエンドが自分の出力をレビューしてはならない）。

```bash
# 実装ロールだけ解決済み backend に従う（例: backend=cursor なら composer-2.5-fast を解決）
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host cursor --role worker --field model
# review / advisor は常に claude（Opus）固定
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host claude --role reviewer --field model
bash "${HARNESS_PLUGIN_ROOT}/scripts/model-routing.sh" --host claude --role advisor --field model
```

> モデル名の正本は `model-routing.sh` 側。本ドキュメント中の `composer-2.5-fast` は参照値であり、実際の解決は上記コマンドに従う（drift 防止）。

### 非 `claude` バックエンドのトポロジー（Worker 介在なし）

backend が `codex` または `cursor` の場合、**Lead は Worker agent (`claude-code-harness:worker`) を spawn しない**。
代わりに Lead 自身が `cursor-companion.sh` / `codex-companion.sh` を直接呼ぶ。
Worker 層の介在は backend=`claude` のときだけ。

配線:

| backend | 経路 |
|---------|------|
| `claude`（既定） | Lead → Worker (`claude-code-harness:worker` agent) → … → Lead review → cherry-pick |
| `codex` | Lead → `codex-companion.sh task --write` → Lead review → cherry-pick |
| `cursor` | Lead → `cursor-companion.sh task --write --workspace <isolated-wt>` → Lead review → cherry-pick |

非 claude backend で Worker を間に挟むと、Lead → Worker → companion → composer/codex と二段委譲になり、Worker の存在意義（agent 契約による self_review 5 件のゲート）が空回りする（非 claude では `worker-report.v1` も `self_review` も生成されないため）。Lead は Worker をスキップして companion を直接呼ぶ。

### 非 `claude` バックエンドの self_review ゲート

backend が `codex` または `cursor` の場合、`worker-report.v1` も `self_review` 配列も生成されない。
そのため Lead は self_review ゲートを**スキップ**し、Lead の diff レビューを唯一の品質ゲートとする（既存の codex path と同じ扱い）。

### cursor バックエンドの banner（委託前に必須）

backend が `cursor` のとき、Lead は委託前に次の 1 行 banner を必ず出力する:

```
⚠️ cursor backend: model=composer-2.5-fast / R01-R13 ガードレールは cursor-agent 内部に適用されない / 出力は Lead レビューまで untrusted
```

cursor の write 委託は専用 `.git` を持つ worktree 内で実行し、Lead が main へ cherry-pick する（cherry-pick 経路で R01-R13 が適用される）。
ガバナンス詳細は `.claude/rules/cursor-cli-only.md` を参照。

### Lead の cherry-pick 前ゲート（contract grep を必須）

非 claude backend (cursor / codex) の出力を main にとり込む前に、Lead は **目視 diff + contract grep の二段ゲート**を必ず通す。目視 diff だけで APPROVE しない。

| ゲート | コマンド | 検知できるもの |
|--------|----------|----------------|
| diff 目視 | `git show <sha>` | 変更が意図どおりか・他ファイル touch なしか・support tier 表記不変か |
| contract grep | `bash tests/test-support-claim-wording.sh` | 公開 support 表記の破壊 |
| contract grep | `bash scripts/ci/check-consistency.sh` | i18n / locale / mirror / capability matrix の固定文字列契約破壊 |
| contract grep | `bash tests/validate-plugin.sh` | plugin 配布契約・hook 配線 |

**全 PASS のときだけ cherry-pick**。1 件でも fail なら revert または composer に再委託（同一文字列契約を保つよう明示）。

理由: docs / README / locale / capability-matrix / spec.md には grep で監視される **固定文字列契約**がある (例: `README_ja.md` の `5動詞ワークフロー`)。composer は表面的な言語的重複を機械的に削減する傾向があり、目視 diff では「綺麗な dedup」に見えても固定句を破壊しうる。

## オプション

| オプション | 説明 | デフォルト |
|----------|------|----------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--parallel N` | 並列ワーカー数 | auto |
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

まずこの本文で入口、自動選択、停止条件だけを確認する。
詳細は必要になった時だけ読む。

| 詳細 | 参照 |
|---|---|
| Solo / Parallel / Codex / Breezing の具体手順 | `references/execution-modes.md` |
| Codex review、Reviewer fallback、AI Residuals、修正ループ | `references/review-loop.md` |
| Solo / Breezing 完了報告の生成 | `references/completion-report.md` |
| テスト/CI 失敗時の再チケット化 | `references/failure-reticketing.md` |
| 仕様正本チェックの基準 | `docs/plans/spec-ssot.md` |

### 重要停止条件

- `Plans.md` が旧フォーマットで DoD / Depends / Status を読めない時は停止する。
- 仕様が実装判断に影響するのに project spec SSOT が見つからない時は、先に仕様正本を作成/更新してから実装する。
- sprint-contract が required なのに ready でない時は実装に進まない。
- critical / major review finding が残っている時は完了にしない。
- テストを弱める、skip する、期待値を実装に合わせて緩める形では解決しない。
- helper script は host project の `scripts/` ではなく `${HARNESS_PLUGIN_ROOT}/scripts/` から呼ぶ。
- 複数 Plans.md がある場合は、1 run の中で plan を切り替えない。必要なら `--plan NAME` を明示して新しい run を開始する。

> **Token Optimization (v2.1.69+)**: git 操作を伴わない軽量タスクでは
> plugin settings の `includeGitInstructions: false` を有効にして
> プロンプトトークンを削減できる。

> **Prompt Cache (CC 2.1.108+)**: 長めの実装や `--resume` を多用する作業では
> `ENABLE_PROMPT_CACHING_1H=1` を優先する。

## スコープダイアログ（引数なし時）

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

## Effort レベル制御（Opus 4.8 / v2.1.111+）

effort はモデルの推論強度を選ぶ正式なノブ。`low(○)/medium(◐)/high(●)/xhigh` の 4 段階で、
`/effort auto` でデフォルトにリセットできる（`max` は v2.1.72 で廃止、`xhigh` が後継）。

Opus 4.8 では thinking は既定 off で、effort が推論深度の主レバー（過去のどの Opus より effort の影響が大きい）。
「浅い推論」を観測したら prompt で回避せず effort を上げる。
そのため複雑タスクの強化は **free-text marker（旧 `ultrathink`）を spawn prompt に注入する方式を廃止**し、
複雑度スコアから **Worker spawn の effort tier を選ぶ**方式に統一する。
これは `docs/model-routing-policy.md`（effort を free-text から推測しない）と
`.claude/rules/opus-4-7-prompt-audit.md` 合格条件 5（`xhigh` は呼び出し側が選ぶ）と整合する。

### 多要素スコアリング

タスク着手時に以下のスコアを合算する。

| 要素 | 条件 | スコア |
|------|------|--------|
| ファイル数 | 変更対象 4 ファイル以上 | +1 |
| ディレクトリ | core/, guardrails/, security/ を含む | +1 |
| キーワード | architecture, security, design, migration を含む | +1 |
| 失敗履歴 | agent memory に同タスクの失敗記録あり | +2 |
| 明示指定 | PM テンプレートに `effort: high` / `effort: xhigh`（旧 `ultrathink` も互換受理）記載あり | +3（自動採用） |

### effort tier の決め方（注入しない）

スコアから effort tier を **escalation signal** として決める（`ultrathink` 等の marker 文字列を spawn prompt に **書かない**）。
適用 lever は次の 2 つだけ:

- **session `/effort`**: 複雑タスクのバッチに入る前に host が `/effort high` / `/effort xhigh` を設定する（session 単位で効く確実な lever）。
- **worker frontmatter**: `agents/worker.md` の `effort`（既定 `medium`）が floor。CC の Agent / Task spawn API は per-spawn の effort 指定を公開しないため、worker 1 体ごとに effort を上げる機構はない。スコアは `worker-report.v1` の `task_complexity_note` に記録し、Lead が session effort 引き上げの判断材料にする。

| スコア | code-risk（core/guardrails/security/architecture/migration を含む） | effort tier |
|--------|-----------------------------------|-------------|
| 0-2 | 不問 | `medium`（Worker frontmatter 既定のまま） |
| ≥ 3 | なし | `high` |
| ≥ 3 | あり | `xhigh` |

breezing モードでも同じロジックを適用する（harness-work が一本化して管理）。
Worker は Sonnet 4.6 のため `xhigh` は実効 `high` にダウングレードされるが、tier 引き上げ自体は有効（`docs/effort-level-policy.md`）。

## 実行モード詳細

### Harness helper script root

Harness が同梱する helper script は、作業対象プロジェクトの `scripts/` ではなく、必ず plugin bundle root から呼ぶ。

```bash
HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$HARNESS_PLUGIN_ROOT" ] && [ -n "${CLAUDE_SKILL_DIR:-}" ]; then
  HARNESS_PLUGIN_ROOT="$(cd "${CLAUDE_SKILL_DIR}/../.." && pwd)"
fi
```

以降の `node "${HARNESS_PLUGIN_ROOT}/scripts/..."` / `bash "${HARNESS_PLUGIN_ROOT}/scripts/..."` は、この解決済み root を前提にする。

### Solo モード（1 件時の自動選択）

1. Plans.md を読み込み、対象タスクを特定
   - **Plans.md が存在しない場合**: `harness-plan create --ci` を自動呼び出し → Plans.md を生成して続行
   - ヘッダーに DoD / Depends カラムがない場合: `Plans.md が旧フォーマットです。harness-plan create で再生成してください。` → **停止**
   - **会話に未記載タスクがある場合**: 直前の会話コンテキストから要件を抽出し、Plans.md に `cc:TODO` で自動追記
     - 抽出ロジック: ユーザー発言からアクション動詞（「〜を追加」「〜を修正」「〜を実装」）を検出
     - 追記時は v2 フォーマット（Task / 内容 / DoD / Depends / Status）に準拠
     - 追記後、ユーザーに「Plans.md に以下を追記しました」と表示（5 秒タイムアウト付きプロンプト、デフォルト: 続行）
1.5. **タスク背景確認**（30 秒）:
   - タスクの「内容」と「DoD」から **目的**（このタスクが解く課題）を 1 行で推論表示
   - `git grep` / `Glob` で **影響範囲**（変更が及ぶファイル/モジュール）を推論表示
   - 推論に自信がある場合: そのまま実装に進む（フロー遅延なし）
   - 推論に自信がない場合: ユーザーに 1 問だけ確認（「この理解で合っていますか？」）
1.6. **仕様正本 preflight**:
   - 既存の project spec SSOT を探す（例: `docs/spec/00-project-spec.md`, `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `docs/oem/PROJECT_COMPASS.md`, `docs/specs/`）
   - task が product behavior / API / data model / permission / billing / integration / tenant boundary を変える場合、spec がなければ `docs/spec/00-project-spec.md` を作る
   - spec が古い、または task と矛盾する場合は、実装前に spec を更新する
   - typo / format / dependency bump / docs-only / 動作変更なし refactor は skip 理由を残して続行する
   - Worker / Reviewer へ渡す context には `spec_path` または `spec_skip_reason` を含める
2. タスクを `cc:WIP` に更新
3. **TDD フェーズ**（`[skip:tdd]` なし & テストFW存在時）:
   a. テストファイルを先に作成（Red）
   b. 失敗を確認
   c. `bash "${HARNESS_PLUGIN_ROOT}/scripts/log-tdd-red.sh"` で `.claude/state/tdd-red-log/<task-id>.jsonl` に FAIL 証跡を残す。script が利用できない環境では、literal な failing test output を worker-report の `self_review` evidence に添付する
   d. `--tdd-bypass` を使う場合は、`HARNESS_TDD_BYPASS=1` と `HARNESS_TDD_BYPASS_REASON="<理由>"` を明示し、TDD を省略した理由を sprint-contract / worker-report に残す
4. `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" <task-id>` で `sprint-contract.json` を生成
5. Reviewer 観点の追記を `bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh"` で加え、`bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh"` で approved を確認
6. **Advisor consult（必要時のみ）**:
   - 高リスク task（`needs-spike` / `security-sensitive` / `state-migration`）は、初回実行前に 1 回だけ相談する
   - 同じ原因の失敗が 2 回続いたら、3 回目に入る前に相談する
   - plateau（行き詰まり検知）が `PIVOT_REQUIRED` を返した時は、ユーザーへ止めて投げる前に 1 回だけ相談する
   - 相談結果は `advisor-response.v1` で受け取り、`PLAN` は進め方の組み替え、`CORRECTION` は局所修正、`STOP` は即エスカレーションとして扱う
   - 同じ `trigger_hash` では 1 回しか相談しない。task ごとの相談回数は最大 3 回
7. コードを実装（Green）（Read/Write/Edit/Bash）
8. `/simplify` で Auto-Refinement（`--no-simplify` で省略可）
9. **自動レビューステージ**（「レビューループ」参照）:
   - Codex exec 優先でレビュー実行 → フォールバックで内部 Reviewer agent
   - `sprint-contract.json` の `reviewer_profile` が `runtime` の場合は `bash "${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh"` を実行
   - REQUEST_CHANGES の場合: 指摘を元に修正→再レビュー（`MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`）
   - APPROVE で次ステップへ。self-check だけでは完了を確定しない
10. `bash "${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh"` で review artifact を正規化して保存（browser profile は `--browser-result` を渡し、`browser_verdict == PENDING_BROWSER` の時は static verdict を採用）
11. `git commit` で自動コミット（`--no-commit` で省略可）
12. タスクを `cc:完了` に更新（commit hash 付与）
   - `git log --oneline -1` で直近の commit hash（短縮形 7 文字）を取得
   - Plans.md の Status を `cc:完了 [a1b2c3d]` 形式で更新
   - commit がない場合（`--no-commit` 時）は hash なしで `cc:完了` のみ
13. **リッチ完了報告**（「完了報告フォーマット」参照）
14. **失敗時の自動再計画**（テスト/CI 失敗時のみ）:
    - テスト実行結果を確認
    - 失敗した場合: 修正タスク案を state に保存し、承認コマンド経由で Plans.md に追加（「失敗タスクの自動再チケット化」参照）
    - 成功した場合: 次タスクへ進む

### Parallel モード（2〜3 件時の自動選択 / `--parallel N` で強制）

`[P]` マーク付きタスクを N ワーカーで並列実行。
`--parallel N` で明示指定した場合は、タスク数に関係なくこのモードを使用。
同一ファイルへの書き込みが競合する場合は git worktree で分離。

### Codex モード（`--codex` 明示時のみ）

公式プラグイン `codex-plugin-cc` の companion 経由で Codex CLI にタスクを委託する。

```bash
# タスク委託（書き込み可能）
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "タスク内容"

# stdin 経由（大きなプロンプト向け）
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# タスク内容を書き出し
cat "$CODEX_PROMPT" | bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write
rm -f "$CODEX_PROMPT"

# 前回スレッドの続行
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --resume-last --write "続きをやって"
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

Model routing:

```bash
bash scripts/model-routing.sh --host cursor --role worker --format json
```

Explicit Task/subagent `model` が routed default より優先。

検証:

```bash
bash tests/test-cursor-adapter-candidate.sh
```

### Breezing モード（4 件以上で自動選択 / `--breezing` で強制）

Lead / Worker / Advisor / Reviewer の役割分離でチーム実行する。
Codex では `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`
を使った native subagent orchestration を前提にし、
古い TeamCreate / TaskCreate ベースの説明を採らない。
Cursor では Task/subagent/background agents へ mapping するが、
review/cherry-pick の直列責務は core 側に残す（adapter smoke target）。

**権限ポリシー**:
- 現行の shipped default は `bypassPermissions`
- `--auto-mode` は互換な親セッション向けの opt-in rollout フラグとして扱う
- `permissions.defaultMode` や agent frontmatter の `permissionMode` には未文書化の `autoMode` 値を書かない

> **CC v2.1.69+**: nested teammates はプラットフォーム側で禁止されるため、
> Worker/Reviewer プロンプトには冗長な nested 防止文言を追加しない。

```
Lead (this agent)
├── Worker (task-worker agent) — 実装担当
├── Advisor (claude-code-harness:advisor) — 方針助言
└── Reviewer (code-reviewer agent) — レビュー担当
```

**Phase A: Pre-delegate（準備）**:
1. Plans.md を読み込み、対象タスクを特定
2. 依存グラフを解析し、実行順序を決定（Depends カラム）
3. 各タスクの effort スコアリング（effort tier 判定 — high/xhigh）
4. `node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js"` で `sprint-contract.json` を生成
5. `bash "${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh"` で Reviewer 観点を加え、`bash "${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh"` で未承認なら停止

**Phase B: Delegate（Worker spawn → 必要時 Advisor → レビュー → cherry-pick）**:

各タスクについて以下を**逐次**実行する（依存順）:

> **API 注記**: 以下は Claude Code の API 構文で記述。
> Codex 環境では `Agent(...)` → `spawn_agent(...)`, `SendMessage(...)` → `send_input(...)` に読み替え。
> 詳細は `team-composition.md` の API マッピング表を参照。

```
for task in execution_order:
    # B-1. sprint-contract を生成
    contract_path = bash("node \"${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js\" {task.number}")
    contract_path = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/enrich-sprint-contract.sh\" {contract_path} --check \"DoD を reviewer 観点で確認\" --approve")
    bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/ensure-sprint-contract-ready.sh\" {contract_path}")

    # B-2. Worker spawn（フォアグラウンド、worktree 分離）
    # Agent tool の戻り値に agentId が含まれる — 修正ループで SendMessage に使用
    Plans.md: task.status = "cc:WIP"  # 着手時に更新（未着手タスクは cc:TODO のまま）

    # 逐次 /harness-work を連打している時も universal violations を伝播させる
    # （初回実行時は universal_violations = [] で初期化済み想定）
    briefing_header = ""
    if universal_violations:
        briefing_header = (
            "🚨 同一セッションで既に検出された universal 違反（再発禁止）:\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )

    worker_result = Agent(
        subagent_type="claude-code-harness:worker",
        prompt=briefing_header + "タスク: {task.内容}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing",
        isolation="worktree",
        run_in_background=false  # フォアグラウンドで実行 → Worker 完了まで待機
    )
    worker_id = worker_result.agentId  # SendMessage 用に保持
    # worker_result には {commit, worktreePath, files_changed, summary} が含まれる

    # B-3. Worker が advice request を返した時だけ、Lead が Advisor を呼ぶ
    if worker_result.type == "advisor-request.v1":
        advisor_result = Advisor(
            prompt=worker_result.request_json
        )
        worker_result = SendMessage(
            to=worker_id,
            message="advisor-response.v1: {advisor_result}"
        )

    # B-3.5. self_review ゲート（Reviewer spawn 前、Lead が機械的に検証）
    # Worker の worker-report.v1 に active self_review rules がそろい、全 verified=true かつ evidence 非空であること
    # tdd.enforce.enabled=true かつ tdd_required=true の時は `tdd-red-evidence-attached` も active rule として必須
    # verified=false または evidence=="" が 1 件でもあれば Reviewer を spawn せず Worker に差し戻す
    self_review_failures = 0
    MAX_SELF_REVIEW_RETRIES = 2  # 3 回目 (retries=2) で Lead が escalate
    while True:
        unverified = [
            r for r in worker_result.self_review
            if (not r.get("verified")) or (not r.get("evidence"))
        ]
        if not unverified:
            break  # 全 rule verified → B-4 (実レビュー) へ進む
        self_review_failures += 1
        if self_review_failures > MAX_SELF_REVIEW_RETRIES:
            # 3 回目でも未確認項目あり → Lead に escalate
            Plans.md: task.status = "cc:TODO"  # 着手前に戻す
            raise EscalationError(f"self_review が 3 回の差し戻しでも未確認 (rules: {[u['rule'] for u in unverified]})")
        # Worker に差し戻し (Reviewer spawn せず)
        SendMessage(
            to=worker_id,
            message=f"self_review に未確認 rule があります: {[u['rule'] for u in unverified]}。各 rule の evidence を実コマンド出力または literal テスト結果で埋め、TDD 必須時は .claude/state/tdd-red-log/<task-id>.jsonl または literal failing test output を添えて verified=true にしてから amend してください"
        )
        worker_result = wait_for_response(worker_id)

    # B-4. Lead がレビュー実行（Codex exec 優先）
    diff_text = git("-C", worker_result.worktreePath, "show", worker_result.commit)
    verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
    profile = jq(contract_path, ".review.reviewer_profile")
    review_input = "review-output.json"
    if profile == "runtime":
        review_input = bash("cd {worker_result.worktreePath} && bash \"${HARNESS_PLUGIN_ROOT}/scripts/run-contract-review-checks.sh\" {contract_path}")
        runtime_verdict = jq(review_input, ".verdict")
        if runtime_verdict == "REQUEST_CHANGES":
            verdict = "REQUEST_CHANGES"
        elif runtime_verdict == "DOWNGRADE_TO_STATIC":
            pass  # runtime 検証コマンドなし → static verdict をそのまま使う
    browser_result = ""
    if profile == "browser":
        # browser artifact から route / browser_mode / execution_instructions を再利用して browser runner を起動する。
        browser_artifact = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/generate-browser-review-artifact.sh\" {contract_path}")
        browser_result = bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/browser-review-runner.sh\" {browser_artifact}")
        browser_verdict = jq(browser_result, ".browser_verdict")
        if browser_verdict == "REQUEST_CHANGES":
            verdict = "REQUEST_CHANGES"
        elif browser_verdict == "APPROVE" and verdict != "REQUEST_CHANGES":
            verdict = "APPROVE"
        # browser_verdict == PENDING_BROWSER のときは static verdict を維持する
    # review_input が DOWNGRADE_TO_STATIC の場合は static review 結果を使う
    if review_input != "review-output.json" and jq(review_input, ".verdict") == "DOWNGRADE_TO_STATIC":
        review_input = "review-output.json"  # static review の結果にフォールバック
    bash("bash \"${HARNESS_PLUGIN_ROOT}/scripts/write-review-result.sh\" {review_input} {latest_commit} --browser-result {browser_result}")

    # B-5. 修正ループ（REQUEST_CHANGES 時、contract の max_iterations まで）
    # Worker はフォアグラウンドで完了済みだが、SendMessage で再開可能
    # （CC: SendMessage(to: agentId) / Codex: resume_agent(agent_id) + send_input）
    review_count = 0
    # sprint-contract が存在するときのみ max_iterations を読む。存在しない場合は 3（後方互換）
    MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3
    latest_commit = worker_result.commit
    while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
        SendMessage(to=worker_id, message="指摘内容: {issues}\n修正して amend してください")
        # Worker が修正 → amend → 更新された commit hash を返す
        updated_result = wait_for_response(worker_id)
        latest_commit = updated_result.commit
        diff_text = git("-C", worker_result.worktreePath, "show", latest_commit)
        verdict = codex_exec_review(diff_text) or reviewer_agent_review(diff_text)
        review_count++

    # B-6. APPROVE → trunk に cherry-pick（feature ブランチ経由）
    # Worker の Branch Guard により trunk HEAD は動かず、commit は feature ブランチ上にある想定
    if verdict == "APPROVE":
        TRUNK=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main")
        git checkout "$TRUNK"  # safety: 既に trunk なら no-op
        # feature ブランチの commit が既に trunk にある（Branch Guard 失敗時のフォールバック）か確認
        if git("merge-base", "--is-ancestor", latest_commit, "HEAD"):
            pass  # 既に trunk 上 — cherry-pick 不要（再入防止）
        else:
            git cherry-pick --no-commit {latest_commit}  # feature branch → trunk
            git commit -m "{task.内容}"
        # Worker の worktree を remove してから feature ブランチを削除
        if worker_result.worktreePath:
            git worktree remove {worker_result.worktreePath} --force
        if worker_result.branch and worker_result.branch not in ["main", "master"] and worker_result.branch != TRUNK:
            git branch -D {worker_result.branch}
        Plans.md: task.status = "cc:完了 [{hash}]"
        # auto-checkpoint 記録（冪等性ガード (c)）
        # Plans.md 書き換え直後に呼ぶ。失敗しても fail-open（|| true）でループを止めない
        HASH=$(git rev-parse --short HEAD)
        REVIEW_RESULT_PATH=".claude/state/review-results/${task.number}.review-result.json"
        bash "${HARNESS_PLUGIN_ROOT}/scripts/auto-checkpoint.sh" \
            "${task.number}" "${HASH}" "${contract_path}" "${REVIEW_RESULT_PATH}" \
            || true  # fail-open: harness-mem 未起動環境でも継続
    else:
        → ユーザーにエスカレーション

    # B-7. Progress feed
    print("📊 Progress: Task {completed}/{total} 完了 — {task.内容}")
```

### Advisor Protocol（全モード共通）

Advisor は「実装者」でも「レビュー担当」でもない。
迷った時だけ、実行役が次の一歩を決めるための相談役として入る。

1. Worker は generic な subagent を増やさず、必要時だけ `advisor-request.v1` を返す
2. Lead が advisor を 1 回だけ呼ぶ
3. Advisor は `PLAN` / `CORRECTION` / `STOP` のどれかを返す
4. Lead はその advice を同じ Worker に返して続行させる
5. Reviewer は最後の成果物だけを見る。advisor の返答に APPROVE / REQUEST_CHANGES を出さない

### Solo モードでの Advisor

solo 実行では親セッション自身が Lead を兼ねる。
つまり「自分で実装し、自分で advisor に相談し、最後は独立レビューに回す」形になる。

- 相談条件は loop / breezing と同じ
- 相談 budget も task ごとに最大 3 回で同じ
- `STOP` はその場で止まり、ユーザー判断へ上げる
- review artifact の gate は飛ばさない

### Sprint Contract

`sprint-contract` は「このタスクを何で合格にするか」を機械でも人でも同じ意味で読める形にする小さな契約ファイルです。
既定の保存先は `.claude/state/contracts/<task-id>.sprint-contract.json` です。

```bash
node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" 32.1.1
```

生成物には次を含めます。

- `checks`: DoD を分解した確認項目
- `non_goals`: 今回やらないこと
- `runtime_validation`: test, lint, typecheck などの検証コマンド
- `browser_validation`: browser reviewer が残すべき UI フロー検証項目
- `browser_mode`: `scripted` または `exploratory`
- `route`: browser reviewer が `playwright` / `agent-browser` / `chrome-devtools` のどれを使うか
- `risk_flags`: `needs-spike`, `security-sensitive`, `ux-regression` など
- `reviewer_profile`: `static`, `runtime`, `browser`

**Phase C: Post-delegate（統合・報告）**:
1. 全タスクの commit log を集計
2. **リッチ完了報告**（「完了報告フォーマット」の Breezing テンプレート）を出力
3. Plans.md の最終確認（全タスク cc:完了 になっているか）

## CI 失敗時の対応

CI が失敗した場合:

1. ログを確認してエラーを特定
2. 修正を実施
3. 同一原因で 3 回失敗したら自動修正ループを停止
4. 失敗ログ・試みた修正・残る論点をまとめてエスカレーション

## 失敗タスクの自動再チケット化

タスク完了後にテスト/CI が失敗した場合、修正タスク案を自動生成し、承認後に Plans.md へ反映する:

### トリガー条件

| 条件 | アクション |
|------|----------|
| `cc:完了` 後にテスト失敗 | 修正タスク案を state に保存し、承認を待つ |
| CI 失敗（3回未満） | 修正を実施し、失敗カウントをインクリメント |
| CI 失敗（3回目） | 修正タスク案を提示 + エスカレーション |

### 修正タスクの自動生成

1. 失敗原因を分類（syntax_error / import_error / type_error / assertion_error / timeout / runtime_error）
2. `.claude/state/pending-fix-proposals.jsonl` に修正タスク案を保存:
   - 番号: 元タスク番号 + `.fix` サフィックス（例: `26.1.fix`）
   - 内容: `fix: [元タスク名] - [失敗原因カテゴリ]`
   - DoD: テスト/CI が通ること
   - Depends: 元タスク番号
3. ユーザーが `approve fix <task_id>` を送ると Plans.md に `cc:TODO` で追加
4. `reject fix <task_id>` で提案を破棄。pending が1件だけのときは `yes` / `no` でも応答可能

## レビューループ

実装完了後（ステップ 5 の後）に自動実行される品質検証ステージ。
**全モード共通**（Solo / Parallel / Breezing）で統一的に適用される。
Parallel モードでは各 Worker が step 10（外部レビュー受付）として同じループを実行する。

### レビュー実行の優先順位

```
1. Codex exec（優先）
   ↓ codex コマンドが存在しない or タイムアウト（120s）
2. 内部 Reviewer agent（フォールバック）
```

### APPROVE / REQUEST_CHANGES の判定基準

レビュアーには以下の閾値基準を渡し、**この基準のみ**で verdict を判定させる。
基準外の改善提案は `recommendations` として返すが、verdict には影響しない。

| 重要度 | 定義 | verdict への影響 |
|--------|------|-----------------|
| **critical** | セキュリティ脆弱性、データ損失リスク、本番障害の可能性 | 1 件でも → REQUEST_CHANGES |
| **major** | 既存機能の破壊、仕様との明確な矛盾、テスト不通過 | 1 件でも → REQUEST_CHANGES |
| **minor** | 命名改善、コメント不足、スタイル不統一 | verdict に影響しない |
| **recommendation** | ベストプラクティス提案、将来の改善案 | verdict に影響しない |

> **重要**: minor / recommendation のみの場合は **必ず APPROVE** を返すこと。
> 「あったほうが良い改善」は REQUEST_CHANGES の理由にならない。

### Codex exec レビュー（公式プラグイン経由）

タスク開始時の HEAD を `BASE_REF` として保持し、その ref との差分をレビュー対象にする。
公式プラグイン `codex-plugin-cc` の companion review を使用する。

```bash
# タスク開始時に base ref を記録（Step 2 の cc:WIP 更新前に実行）
BASE_REF=$(git rev-parse HEAD)

# ... 実装完了後 ...

# 公式プラグインの構造化レビューを実行
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" review --base "${BASE_REF}"
REVIEW_EXIT=$?
```

**verdict マッピング**（公式プラグイン → Harness 形式）:

公式プラグインは `review-output.schema.json` 準拠の構造化出力を返す。
Harness の verdict 形式への変換ルール:

| 公式 plugin | Harness | verdict 影響 |
|---|---|---|
| `approve` | `APPROVE` | - |
| `needs-attention` | `REQUEST_CHANGES` | - |
| `findings[].severity: critical` | `critical_issues[]` | 1件でも → REQUEST_CHANGES |
| `findings[].severity: high` | `major_issues[]` | 1件でも → REQUEST_CHANGES |
| `findings[].severity: medium/low` | `recommendations[]` | verdict に影響しない |

AI Residuals スキャンは引き続き `bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh"` で実行し、
companion review の結果と合わせて最終 verdict を判定する。

```bash
# AI Residuals スキャン（companion review と並行実行可能）
AI_RESIDUALS_JSON="$(bash "${HARNESS_PLUGIN_ROOT}/scripts/review-ai-residuals.sh" --base-ref "${BASE_REF}" --include-untracked 2>/dev/null || echo '{"tool":"review-ai-residuals","scan_mode":"diff","base_ref":null,"include_untracked":true,"files_scanned":[],"untracked_files_scanned":[],"summary":{"verdict":"APPROVE","major":0,"minor":0,"recommendation":0,"total":0},"observations":[]}')"
```

### 内部 Reviewer agent フォールバック

Codex exec が使えない場合（`command -v codex` が失敗、または exit code ≠ 0）:

```
Agent tool: subagent_type="reviewer"
prompt: "以下の変更をレビューしてください。判定基準: critical/major → REQUEST_CHANGES、minor/recommendation のみ → APPROVE。diff: {git diff ${BASE_REF}}"
```

Reviewer agent は Read-only（Write/Edit/Bash 無効）で安全にレビューを実行する。

### 修正ループ（REQUEST_CHANGES 時）

```
review_count = 0
# sprint-contract が存在するときのみ max_iterations を読む。存在しない場合は 3（後方互換）
contract_path = get_sprint_contract_path()  # 例: .claude/state/contracts/<task-id>.sprint-contract.json
MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3

while verdict == "REQUEST_CHANGES" and review_count < MAX_REVIEWS:
    1. レビュー指摘を解析（critical / major のみ対象）
    2. 各指摘に対して修正を実装
    3. 再度レビューを実行（同じ判定基準・同じ優先順位）
    review_count++

if review_count >= MAX_REVIEWS and verdict != "APPROVE":
    → ユーザーにエスカレーション
    → 「MAX_REVIEWS 回修正しましたが以下の critical/major 指摘が残っています」+ 指摘一覧を表示
    → ユーザー判断を待つ（続行 / 中断）
```

### Breezing モードでの適用

Breezing モードでは **Lead** がレビューループを実行する（上記 Phase B 参照）:

1. Worker が worktree 内で実装・commit → Lead に結果返却
2. Lead が Codex exec でレビュー（優先）/ Reviewer agent（フォールバック）
3. REQUEST_CHANGES → Lead が SendMessage で Worker に修正指示 → Worker が amend
4. 修正後、再レビュー（`MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3` 回まで）
5. APPROVE → Lead が trunk（デフォルトブランチ）に cherry-pick → Plans.md を `cc:完了 [{hash}]` に更新

## 完了報告フォーマット

タスク完了時（`cc:完了` + commit 後）に自動出力される視覚的サマリ。
非専門家にも変更内容と影響が伝わることを目的とする。

### テンプレート

```
┌─────────────────────────────────────────────┐
│  ✓ Task {N} 完了: {タスク名}                    │
├─────────────────────────────────────────────┤
│                                              │
│  ■ 何をしたか                                 │
│    • {変更内容 1}                              │
│    • {変更内容 2}                              │
│                                              │
│  ■ 何が変わるか                                │
│    Before: {旧動作}                            │
│    After:  {新動作}                            │
│                                              │
│  ■ 変更ファイル ({N} files)                    │
│    {ファイルパス 1}                             │
│    {ファイルパス 2}                             │
│                                              │
│  ■ 残りの課題                                  │
│    • Task {X} ({status}): {内容}  ← Plans.md  │
│    • Task {Y} ({status}): {内容}  ← Plans.md  │
│    （Plans.md に {M} 件の未完了タスクあり）       │
│                                              │
│  commit: {hash} | review: {APPROVE}           │
└─────────────────────────────────────────────┘
```

### 生成ルール

1. **何をしたか**: `git diff --stat HEAD~1` と commit message から自動抽出。技術用語は最小限にし、動詞で始める
2. **何が変わるか**: タスクの「内容」と「DoD」から Before/After を推論。ユーザー体験の変化を重視
3. **変更ファイル**: `git diff --name-only HEAD~1` から取得。5 ファイル超は省略して件数表示
4. **残りの課題**: Plans.md の `cc:TODO` / `cc:WIP` タスクを一覧表示。Plans.md に記載済みかどうかを明示
5. **review**: レビュー結果（APPROVE / REQUEST_CHANGES → APPROVE）を表示

### Parallel モードでの報告

- **1 タスク**（`--parallel` 強制時）: Solo テンプレートを使用
- **複数タスク**: Breezing 集約テンプレートを使用（下記参照）

### Breezing モードでの報告

全タスク完了後にまとめて出力。各タスクは簡略版（何をしたか + commit hash のみ）で一覧し、
最後に全体サマリ（合計変更ファイル数 + 残り課題）を出力する:

```
┌─────────────────────────────────────────────┐
│  ✓ Breezing 完了: {N}/{M} タスク             │
├─────────────────────────────────────────────┤
│                                              │
│  1. ✓ {タスク名 1}            [{hash1}]      │
│  2. ✓ {タスク名 2}            [{hash2}]      │
│  3. ✓ {タスク名 3}            [{hash3}]      │
│                                              │
│  ■ 全体の変更                                 │
│    {N} files changed, {A} insertions(+),     │
│    {D} deletions(-)                          │
│                                              │
│  ■ 残りの課題                                  │
│    Plans.md に {K} 件の未完了タスクあり         │
│    • Task {X}: {内容}                         │
│                                              │
└─────────────────────────────────────────────┘
```

## 関連スキル

- `harness-plan` — 実行するタスクを計画する
- `harness-sync` — 実装と Plans.md を同期する
- `harness-review` — 実装のレビュー
- `harness-release` — バージョンバンプ・リリース
