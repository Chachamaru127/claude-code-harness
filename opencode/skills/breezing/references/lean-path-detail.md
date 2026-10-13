# Lean Path & Phase Detail

Supplementary detail for `breezing`'s free-text brief composer, the Cursor lean
path savings breakdown, Phase 0 planning discussion, and dependency-graph task
assignment. The main `SKILL.md` keeps only the operational summary; read this
file when you need the full rationale.

## Brief Composer v0

`/breezing` の argument-hint（`all|N-M|--codex|--cursor|--reviewer-only|--parallel N|--no-commit|--no-discuss|--auto-mode`）の**どれにも一致しない自由文入力**向けの分解・確認フロー。

1. **分類** — Lead は `bash scripts/breezing-brief.sh classify "<args>"` を実行する。
   - 出力 `structured` → 既存の structured 引数経路（Quick Reference）へそのまま進む。
   - 出力 `free-text` → 次ステップへ。
2. **分解** — Lead の LLM が自由文を **3〜7 個の subtasks** に分解し、`brief-card.v1` JSON カードを組み立てる（schema: `templates/schemas/brief-card.v1.json`）。v0 では `breezing-brief.sh` は LLM を呼ばない。
3. **提示** — カード（goal / subtasks[id,title,dod] / scope_files / risk_notes / confidence）をユーザーに提示する。`confidence` は `high` | `medium` | `low` のいずれか。
4. **確定** — ユーザー Yes/No の後、`bash scripts/breezing-brief.sh confirm <yes|no> <card.json>` を実行する。
   - `yes` → `DISPATCH: <subtask 数>` を出力し、既存 team 経路（worktree-per-task）へ渡す。
   - `no` → `DISPATCH: 0`（実行 0 件の dry 契約）。

検証のみ必要な場合: `bash scripts/breezing-brief.sh validate <card.json>`（exit 0 = valid）。

## Cursor Fast Path — 削除される step（claude backend と比べて節約）

| Step | 削除理由 | 節約秒数 |
|---|---|---|
| `harness:worker` agent spawn | cursor backend は Worker 介在なし | 5-30s |
| self_review 5 件ゲート | `worker-report.v1` が cursor では生成されないため不要 | 10-60s × retry |
| sprint-contract 3 段チェーン (generate→enrich→ensure) | Worker 契約不要なら contract 不要 | 2-5s × N |
| Phase 0 Q1-Q3 interactive | `--no-discuss all` 既定 (Plans/Depends は Lead が直読み) | 15-30s |
| Effort スコアリング | cursor backend では ultrathink 注入不要 | 0.5-1s × N |
| Plans.md re-parse (per task) | session 内 cache (mtime+hash で短絡) | 3-8s |

合計 baseline `15-35s` → target `3-7s` で 1 タスク目の cursor 委譲開始までを短縮。

## Reviewer-only mode の用途

- Anthropic 側 server rate limit で Reviewer が止まった時に advisory findings を先に集めておく前倒し（brain verdict の代替にはならない — verdict は brain 復帰後に確定）
- Worker 完了済みで Reviewer だけ別系統に分散
- Codex review が auth 失敗した時の manual fallback

## Phase 0: Planning Discussion（構造化 3 問チェック・詳細）

全タスク実行前に、Lead が元の依頼と Plans.md から次の3点を確認する。承認済みの内容を毎回質問し直さない。`--no-discuss` は対話を省略する指定であり、依存関係や承認境界の確認は省かない。

**Q1. スコープ確認**: 選択済みのタスク集合、目的、DoD、承認元を照合する。
優先度（Required > Recommended > Optional）から実行順を組み、依頼済み範囲を変える判断が必要な場合だけ、具体的な推奨案と根拠を提示する。

**Q2. 依存関係確認**（Plans.md に Depends カラムがある場合のみ）: Depends と実装を照合し、順序を決める。
循環依存があれば該当タスクを止める。通常の順序調整は Lead が行い、独立した承認済みタスクは続ける。

**Q3. リスクフラグ**（`[needs-spike]` タスクがある場合のみ）: 既存の spike 計画、結果、許可範囲を読む。
承認済みの spike が未完了なら先行させる。未承認の操作や重要な仕様分岐だけ、実行前に必要な判断を求める。

不足情報は supplied contract と読み取り可能な資料から回収する。残る軽微な仮定は明示して Phase A に進む。brief-card の `confirm yes/no` 契約はこの確認で代替しない。

## 依存グラフに基づくタスク割り当て（詳細）

Plans.md に Depends カラムがある場合（v2 フォーマット）、依存グラフに従ってタスクを実行する:

1. **Depends が `-` のタスク**を先に実行。独立して検証できる成果と担当範囲を割り当て、設定済みの同時実行上限内で並列 spawn 可能
2. 各 Worker 完了後、Lead がレビュー→cherry-pick（`harness-work` Phase B 参照）
3. 依存元タスクが main に cherry-pick されたら、そのタスクに依存していたタスクを次に実行
4. 全タスクが完了するまで繰り返す

各タスクの「Worker 完了→レビュー→cherry-pick」は逐次処理。並列化できるのは独立タスク（Depends が `-`）の Worker spawn 部分のみ。
Lead は Worker 実行中に統合準備や根拠確認を進める。関連修正は同じ Worker に返し、独立 Reviewer は新しい文脈で起動する。
