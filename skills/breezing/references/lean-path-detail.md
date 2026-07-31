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
| `claude-code-harness:worker` agent spawn | cursor backend は Worker 介在なし | 5-30s |
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

全タスク実行前に、以下の 3 問で計画の健全性を確認する。`--no-discuss` 指定時は全スキップ。合計 30 秒で完了する設計。

**Q1. スコープ確認**: 「{{N}} 件のタスクを実行します。スコープは適切ですか？」
多すぎる場合は優先度（Required > Recommended > Optional）で絞り込みを提案。

**Q2. 依存関係確認**（Plans.md に Depends カラムがある場合のみ）: 「タスク {{X}} は {{Y}} に依存しています。実行順序は合っていますか？」
Depends カラムを読み取り、依存チェーンを表示。循環依存があればエラー。

**Q3. リスクフラグ**（`[needs-spike]` タスクがある場合のみ）: 「タスク {{Z}} は [needs-spike] です。先に spike しますか？」
spike 未完了の `[needs-spike]` タスクがある場合、spike を先行実行するか確認。

3 問とも問題なければ、Phase A に進む。

## 依存グラフに基づくタスク割り当て（詳細）

Plans.md に Depends カラムがある場合（v2 フォーマット）、依存グラフに従ってタスクを実行する:

1. **Depends が `-` のタスク**を先に実行。独立タスクが複数あれば並列 spawn 可能
2. 各 Worker 完了後、Lead がレビュー→cherry-pick（`harness-work` Phase B 参照）
3. 依存元タスクが main に cherry-pick されたら、そのタスクに依存していたタスクを次に実行
4. 全タスクが完了するまで繰り返す

各タスクの「Worker 完了→レビュー→cherry-pick」は逐次処理。並列化できるのは独立タスク（Depends が `-`）の Worker spawn 部分のみ。
