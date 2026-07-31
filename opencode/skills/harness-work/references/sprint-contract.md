# Sprint Contract & PR Closeout

## Sprint Contract

`sprint-contract` は「このタスクを何で合格にするか」を機械でも人でも同じ意味で読める形にする小さな契約ファイル。既定の保存先は `.claude/state/contracts/<task-id>.sprint-contract.json`。

```bash
node "${HARNESS_PLUGIN_ROOT}/scripts/generate-sprint-contract.js" 32.1.1
```

生成物には次を含める。

- `checks`: DoD を分解した確認項目
- `non_goals`: 今回やらないこと
- `runtime_validation`: test, lint, typecheck などの検証コマンド
  - 同じ symbol を同一セッションで 2 回 grep したら `harness_ast_search` に切り替える。
  - 複数モジュールに相同実装があるバグ修正では、編集前に `harness_ast_search` で全実装を洗い出す。
  - 変更ファイルが `.ts`/`.tsx` を含む時だけ `harness_lsp_diagnostics` の新規エラー 0 件を DoD にする。harness MCP 未接続や対象外ファイル型なら not-configured 扱いで non-blocking。
- `browser_validation`: browser reviewer が残すべき UI フロー検証項目
- `browser_mode`: `scripted` または `exploratory`
- `route`: browser reviewer が `playwright` / `agent-browser` / `chrome-devtools` のどれを使うか
- `risk_flags`: `needs-spike`, `security-sensitive`, `ux-regression` など
- `reviewer_profile`: `static`, `runtime`, `browser`

**必須メタデータ（lane / stage / evidence）** — Worker / Scaffolder / Reviewer へ渡す sprint contract input:

| フィールド | 意味 | 例 |
|-----------|------|-----|
| `spec_path` | root `spec.md`（または最寄 sub-spec）のパス | `spec.md`, `docs/spec/00-project-spec.md` |
| `lane` | タスクの lane taxonomy | `fast`, `gate`, `release` |
| `stage` | 5-stage gate の現在段階 | `research`, `plan`, `impl`, `review`, `closeout` |
| `research_evidence` | research 結果の link / commit / file | `docs/research/phase-72-evidence.md`, commit hash |
| `tdd_red_log` | `[tdd:required]` タスクの RED 証跡（commit hash または log path） | `.claude/state/tdd-red-log/72.1.3.jsonl`, `abc1234` |
| `review_artifact` | review verdict と findings | `{ verdict: "APPROVE", findings: [...] }` |
| `pr_closeout` | closeout artifact（base/head refs + evidence pack） | `{ base_ref, head_ref, evidence_pack }` |

`generate-sprint-contract.js` 実行時、Lead は `spec_path` / `lane` / `stage` を Plans metadata から contract に載せ、research 完了後は `research_evidence` を追記する。TDD Red 後は `tdd_red_log` を載せ、review 後は `review_artifact`、PR closeout 後は `pr_closeout` を載せる。

**TDD 完了ゲート**: `[tdd:required]` タスクでは sprint contract に `tdd_red_log` または明示 `skip_tdd_reason` が無い限り完了扱いにしない（`cc:完了` 更新・cherry-pick・PR closeout すべて対象）。

## PR Closeout（review APPROVE 後）

review APPROVE 後の PR title/body は `bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh"` で evidence pack から組み立てる。**default は `dry-run` preview**（`git push` / `gh pr create` は `push` サブコマンド + 確認または `--yes` のみ）。

```bash
bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh" build \
  --base origin/main --head "$(git branch --show-current)" \
  --evidence .claude/state/evidence-pack.json \
  --out .claude/state/pr-payload.json
bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh" dry-run --payload .claude/state/pr-payload.json
# 明示 push のみ（確認必須、--yes で skip 可）:
bash "${HARNESS_PLUGIN_ROOT}/scripts/harness-pr-closeout.sh" push --payload .claude/state/pr-payload.json
```

`harness-review` 経路からの自動 push / PR / merge は禁止（read-only boundary）。detached HEAD では `push` 前に branch 作成が必要。

**Fast lane の軽量化境界**: `lane: fast` は full review を省略できるが、`not_observed != absent` の unknown data contract と focused checks（`runtime_validation` / `checks` の DoD 分解）は省かない。
