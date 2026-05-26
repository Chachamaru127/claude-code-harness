---
name: harness-progress
description: "Generate a Progress Tracker HTML for non-engineer vibecoders to glance at session progress (cc:WIP / cc:TODO / cc:完了 counts, percentage, elapsed/estimated minutes, cost so far/estimate, drift alerts). Uses Plans.md as source of truth, renders a single-file HTML with auto-regeneration support. Use when user asks for progress overview, session status snapshot, dashboard, or says: progress tracker, 進捗確認, 進捗ボード, dashboard. Do NOT load for: actual implementation, code review, release work."
description-en: "Generate a Progress Tracker HTML for non-engineer vibecoders to glance at session progress (cc:WIP / cc:TODO / cc:完了 counts, percentage, elapsed/estimated minutes, cost so far/estimate, drift alerts). Uses Plans.md as source of truth, renders a single-file HTML with auto-regeneration support. Use when user asks for progress overview, session status snapshot, dashboard, or says: progress tracker, 進捗確認, 進捗ボード, dashboard. Do NOT load for: actual implementation, code review, release work."
description-ja: "進捗 Tracker HTML を生成する。Plans.md を SoT として cc:WIP / cc:TODO / cc:完了 件数・%、経過分数・コスト・drift alert を 1 枚 HTML で表示。PostToolUse hook で 60 秒に 1 回自動再生成。Use when: 進捗確認, 進捗ボード, dashboard。Do NOT load for: 実装作業, code review, release。"
allowed-tools: ["Read", "Write", "Bash"]
argument-hint: "[--out <path>] [--no-open]"
---

# Harness Progress Tracker

Phase 65.4 (Progress Tracker) — 3rd surface of the cognitive-load HTML triplet.
Plan Brief / Acceptance Demo に続く 3 つ目の HTML surface で、**進行中セッションの全体像を 1 枚の紙で把握** できるようにする。

## Quick Reference

| 入力 | 動作 |
|---|---|
| `/harness-progress` | 現プロジェクトの進捗 snapshot HTML を生成し開く |
| `/harness-progress --no-open` | 生成のみ (browser 開かない、PostToolUse hook 用) |
| `/harness-progress --out <path>` | 出力先指定 (default: `out/progress-snapshot.html`) |

## Mission

> "今のセッションは何件のタスクをどこまで終わらせて、いつ終わる見込みで、いくら使ったか" を、
> エンジニアじゃない vibecoder が **3 秒でブラウザで把握** できる HTML 1 枚を生成する。

**やる**:
- Plans.md の cc:TODO / cc:WIP / cc:完了 件数を集計
- progress_pct (完了率) を計算 (cc:完了 ÷ 総タスク × 100)
- 経過分数 / 推定総分数 / コスト so-far / コスト estimate を表示
- drift alert を表示 (Phase 65.4.3 以降で populate)

**やらない** (本 cycle):
- WebSocket / SSE による live update (静的 HTML、再生成で更新)
- 過去 session の history 比較 (Phase 65.4.4 で別軸)
- 他 project の cross-project view (Phase 65.3 と独立)

## Schema: progress-snapshot.v1

詳細仕様: [schemas/progress-snapshot.v1.schema.json](${CLAUDE_SKILL_DIR}/schemas/progress-snapshot.v1.schema.json)

```yaml
schema:        progress-snapshot.v1
project:       <basename of git repo>
current_task:  <cc:WIP の最初の項目 1 行サマリ、なければ空文字>
progress_pct:  <0-100 の整数、cc:完了 ÷ 総タスク × 100 の四捨五入>
todo_tasks:    [{number, title}]    ← cc:TODO のみ
wip_tasks:     [{number, title}]    ← cc:WIP のみ
done_tasks:    [{number, title, commit}]   ← cc:完了 [hash] のみ、hash は 7 chars
elapsed_minutes:          <int, state file から>
estimated_total_minutes:  <int, state file から>
cost_so_far_usd:          <float, state file から>
cost_estimate_usd:        <float, state file から>
alerts:                    []   ← Phase 65.4.3 以降で populate
generated_at:             <ISO8601 UTC>
```

## Execution Flow

### Step 0: PROJECT_NAME を取得

```bash
PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "current")"
```

### Step 1: snapshot を組み立て

```bash
SNAPSHOT_JSON="$(mktemp /tmp/progress-snapshot-XXXX.json)"
bash scripts/progress-snapshot.sh \
  --plans Plans.md \
  --project "$PROJECT_NAME" \
  > "$SNAPSHOT_JSON"
```

`scripts/progress-snapshot.sh` (Phase 65.4.1 で実装) は Plans.md を parse し
`progress-snapshot.v1` schema 準拠の JSON を出力する。

### Step 2: HTML をレンダリング

```bash
OUT_PATH="${OUT_PATH:-out/progress-snapshot.html}"
mkdir -p "$(dirname "$OUT_PATH")"

bash scripts/render-html.sh \
  --template progress \
  --data "$SNAPSHOT_JSON" \
  --out "$OUT_PATH"
```

### Step 3: ブラウザで開く

`--no-open` flag が**ない**場合のみ実行 (PostToolUse hook からの背景再生成では skip):

```bash
bash scripts/plan-brief-open.sh --path "$OUT_PATH"
```

## Cross-project search (default OFF)

Phase 65.4.4 で `--cross-project-group <name>` flag が追加される。本 cycle (65.4.1) では default OFF、現プロジェクトのみ集計する。

## Failure modes

| 状態 | 動作 |
|---|---|
| Plans.md が無い | `progress-snapshot.sh` が exit 1 (clear error message) |
| Plans.md にタスクが 1 件もない | `progress_pct: 0`, 空配列 で snapshot 生成 (HTML は「タスクなし」表示) |
| state file (経過分数等) が無い | `elapsed_minutes: 0`, `cost_so_far_usd: 0` で fallback (warning なし) |
| `git` 不在 / git repo 外 | `project: "current"` で fallback |

## Related

- `harness-plan-brief` (Phase 65.1.x) — 1st surface (実装前の説明会)
- `harness-accept` (Phase 65.2.x) — 2nd surface (検収判断)
- `harness-progress` (本 skill, Phase 65.4.x) — 3rd surface (進捗ダッシュボード)
- 65.4.2 (PostToolUse auto-regen)、65.4.3 (drift alert 5 種)、65.4.4 (過去判断 lookup) で機能拡張
