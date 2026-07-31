# Effort Routing Detail

`harness-work` の effort tier 判定ロジックのフル仕様（本体 SKILL.md には決定表のみを残す）。

## 背景

Opus 4.8 では thinking は既定 off で、effort が推論深度の主レバー（過去のどの Opus より effort の影響が大きい）。
「浅い推論」を観測したら prompt で回避せず effort を上げる。
複雑タスクの強化は free-text marker（旧 `ultrathink`）を spawn prompt に注入する方式を廃止し、複雑度スコアから Worker spawn の effort tier を選ぶ方式に統一する。
これは `docs/model-routing-policy.md`（effort を free-text から推測しない）と `.claude/rules/claude-5-prompt-standard.md`「維持する規律 5」（`xhigh` は呼び出し側が選ぶ）と整合する。

## 多要素スコアリング

タスク着手時に以下のスコアを合算する。

| 要素 | 条件 | スコア |
|------|------|--------|
| ファイル数 | 変更対象 4 ファイル以上 | +1 |
| ディレクトリ | core/, guardrails/, security/ を含む | +1 |
| キーワード | architecture, security, design, migration を含む | +1 |
| 失敗履歴 | agent memory に同タスクの失敗記録あり | +2 |
| 明示指定 | PM テンプレートに `effort: high` / `effort: xhigh`（旧 `ultrathink` も互換受理）記載あり | +3（自動採用） |

## effort tier の決め方（注入しない）

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
