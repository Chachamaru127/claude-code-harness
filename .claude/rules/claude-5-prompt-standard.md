---
description: Claude 5 世代の agent prompt 監査基準（opus-4-7-prompt-audit.md の後継）
paths: "agents/worker.md, agents/reviewer.md, agents/advisor.md, agents/test-wiring-auditor.md, docs/team-composition.md"
---

# Claude 5 Prompt Standard

operator 承認: 2026-07-26（breezing 起動時の一括承認）。`.claude/rules/opus-4-7-prompt-audit.md`（Phase 44 / Opus 4.7 世代）の後継。

Claude 5 ガイダンス（2026-07）の要点は「例文の大量提示は探索空間を狭める」「ルールで縛るより判断に任せる」。旧基準の一部と衝突するため、契約（interface）条項だけ残し、書き方を縛る条項を撤廃した。

## 維持する規律（契約 = interface）

agent 間・agent-tool 間の**境界**を定義する条項は変えない。判断力の向上は「何を返すか」の契約を緩めない。

1. **出力 schema 名と列挙値は固定**: `worker-report.v1` / `advisor-request.v1` / `advisor-response.v1` / `review-result.v1` / `PLAN | CORRECTION | STOP` / `APPROVE | REQUEST_CHANGES` / `self_review[].rule`（既定 6: `dry-violation-none | plans-cc-markers-untouched | all-declared-symbols-called | dod-items-verified-with-evidence | no-existing-test-regression | tdd-red-evidence-attached`）/ `memory_updates[].scope`（`universal | task-specific`）
2. **回数上限は数字で書く**: 例「最大 3 回」「同じ原因の失敗が 2 回続いたら」。並列 worker 数の判定（1/2/3グループ）も同様
3. **Codex / Cursor 連携は wrapper command 経由のみ**: `bash scripts/codex-companion.sh task --write "..."` / `bash scripts/cursor-companion.sh task --write "..."`。raw `codex exec` / raw `cursor-agent` を標準手段にしない
4. **権限と責務境界は 1 行で判定できるようにする**: Lead だけが teammate を spawn する / Worker は `advisor-request.v1` を返し Advisor を直接 spawn しない / Reviewer は品質判定だけを行い実装しない
5. **effort は tier 指定、free-text marker 禁止**: `xhigh` は呼び出し側が選ぶ推論強度で、agent prompt が `ultrathink` 等から推測しない。`/ultrareview` は呼び出し側の entrypoint、agent 側の契約は `review-result.v1` のまま。`--auto-mode` は opt-in、既定値にしない

## 撤廃する規律(Claude 5 の判断に任せる)

1. **曖昧語 blanket 禁止の撤廃**: 「必要に応じて」「適宜」等 8 語を使うたび直後に条件補足を義務化する運用をやめる。文脈から妥当な範囲を判断できる
2. **行動指示ごとの逐語必須化の撤廃**: 「コマンド名 / パス / schema 名 / 数値閾値 / 真偽判定条件のいずれかを必ず含む」という全指示への一律適用をやめる。上記「維持する規律」に触れない判断は任せる
3. **例文の大量提示義務の撤廃**: before/after 例を多数記録・列挙する運用をやめる。例示は最小限(1 例)に留め、探索空間を狭めない

## 維持 / 撤廃 対比表

| 旧基準の項目 | 扱い |
|---|---|
| 出力 schema 名 + 列挙値の固定 | 維持 |
| 回数制御は数字で書く | 維持 |
| Codex wrapper command の完全一致 | 維持(Cursor も同列) |
| 2.1.111 運用ノブ(xhigh / `/ultrareview` / `--auto-mode`)分離 | 維持 |
| 権限と責務境界の 1 行判定 | 維持 |
| 並列 worker 数の数値条件 | 維持 |
| 行動指示への逐語要素(コマンド名等)の一律必須化 | 撤廃 |
| 曖昧語 8 語の使用時補足義務 | 撤廃 |
| before/after 例の大量記録義務 | 撤廃 |
| Phase 44 限定スコープ除外 | 撤廃(historical) |

## 関連

- `.claude/rules/workflow-test-wiring.md` — auditor 列挙値(`PASS | ADD_REQUIRED | APPEAL_REJECTED`)も「維持する規律 1」の対象
- `docs/effort-level-policy.md` / `docs/agent-view-policy.md` / `docs/ultrareview-policy.md` — 各運用ノブの詳細
