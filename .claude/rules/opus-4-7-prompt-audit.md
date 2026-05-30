---
description: Phase 44 / 2.1.111 の agent prompt 監査ルール
globs:
  - "agents/worker.md"
  - "agents/reviewer.md"
  - "agents/advisor.md"
  - "docs/team-composition.md"
---

# Opus 4.7 Prompt Audit Rule

Phase 44 / 2.1.111 で agent prompt と team composition を更新する時の監査基準。

## 合格条件

1. 行動指示には、次のどれかを必ず入れる。
   - 実行コマンド名
   - ファイルパス
   - JSON schema 名
   - 数値の閾値
   - 真偽が判定できる条件
2. 回数制御を書く時は上限を数字で書く。
   - 例: `最大 3 回`
   - 例: `同じ原因の失敗が 2 回続いたら`
3. 出力形式を書く時は schema 名と列挙値を固定する。
   - `advisor-request.v1`
   - `advisor-response.v1`
   - `review-result.v1`
   - `worker-report.v1`
   - `PLAN | CORRECTION | STOP`
   - `APPROVE | REQUEST_CHANGES`
   - `self_review[].rule` 列挙値 (default 6): `dry-violation-none | plans-cc-markers-untouched | all-declared-symbols-called | dod-items-verified-with-evidence | no-existing-test-regression | tdd-red-evidence-attached`
   - `memory_updates[].scope` 列挙値: `universal | task-specific`（文字列配列は後方互換で `task-specific` 扱い）
4. Codex 連携を書く時は wrapper command を使う。
   - 許可: `bash scripts/codex-companion.sh task --write "..."`
   - 許可: `bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"`
   - 禁止: raw `codex exec` を agent 手順の標準手段として書く
5. 2.1.111 の運用ノブは、agent 契約と operator entrypoint を分けて書く。
   - `xhigh`: 呼び出し側が選ぶ推論強度。agent prompt が free-text marker から推測しない
   - `/ultrareview`: 呼び出し側の review entrypoint。agent 定義側では `review-result.v1` を契約にする
   - `--auto-mode`: opt-in rollout。既定値として書かない
6. 権限と責務の境界は agent ごとに 1 行で判定できるようにする。
   - Lead だけが teammate を spawn する
   - Worker は `advisor-request.v1` を返し、Advisor を直接 spawn しない
   - Reviewer は品質判定だけを行い、実装しない
7. `team-composition.md` では、並列 worker 数の条件を数字で書く。
   - `1`: 変更対象が 1 グループ、または書き込みファイルが重なる
   - `2`: 独立した書き込みグループが 2 つ
   - `3`: 独立した書き込みグループが 3 つ以上
8. このフェーズでは `skills/`, `docs/`, `mirror` を更新対象に含めない。

## 曖昧語の扱い

次の語を使う場合は、直後の同じ文か次の箇条書きで条件を補う。

- `必要に応じて`
- `適宜`
- `適切に`
- `十分に`
- `柔軟に`
- `しっかり`
- `可能なら`
- `場合によって`
- `独立タスク`
- `高リスク`

補足がない場合は不合格とする。

## Checklist

- [ ] frontmatter に undocumented なキーを追加していない
- [ ] `initialPrompt` の最初の 3 手以内に読むファイルか確認項目がある
- [ ] retry / escalation / review loop の回数上限が数字で書かれている
- [ ] output JSON の schema 名と列挙値が固定されている
- [ ] `codex-companion.sh` を使う箇所で command 名が完全一致している
- [ ] `ultrathink` のような旧 free-text marker を agent 契約に残していない
- [ ] `xhigh` と `/ultrareview` を operator 側の指定として書いている
- [ ] `--auto-mode` を既定値として書いていない
- [ ] reviewer の verdict 条件が `critical | major | minor` と整合している
- [ ] advisor の `STOP` 条件に `stop_reason` がある
- [ ] team composition の spawn 権限が Lead に限定されている
- [ ] 広く適用すべき指示に scope（全件 / 各ファイル等）が明示されている
- [ ] 深い推論の要求が effort tier で書かれ、free-text marker（`ultrathink` 等）を使っていない

## 推奨確認コマンド

```bash
rg -n "必要に応じて|適宜|適切に|十分に|柔軟に|しっかり|可能なら|場合によって" \
  agents/worker.md agents/reviewer.md agents/advisor.md docs/team-composition.md

rg -n "codex exec|ultrathink|xhigh|/ultrareview|auto-mode|advisor-request.v1|advisor-response.v1|review-result.v1|worker-report.v1|REQUEST_CHANGES|PLAN|CORRECTION|STOP" \
  .claude/rules/opus-4-7-prompt-audit.md agents/worker.md agents/reviewer.md agents/advisor.md docs/team-composition.md
```
