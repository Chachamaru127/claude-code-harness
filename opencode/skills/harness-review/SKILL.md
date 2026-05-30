---
name: harness-review
description: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
---

# Harness Review

Harness の統合レビュースキル。
この `SKILL.md` は薄い dispatcher であり、詳細な品質基準は `references/` を読む。

if $ARGUMENTS == "":
  → 「今までの作業のレビュー」と解釈し、Review target detection を実行する
  → review target が 1 つに確定できる場合だけ自動開始する
  → review target が不明または複数候補の場合は AskUserQuestion で選択肢を出し、認識を揃えてから開始する

<!-- 上記 3 行は AUTO-START CONTRACT。skill-editing.md の「最冒頭 3 行以内」ルールに従い fence / HTML コメントで押し下げない -->

### Output Contract (P35: 「止まったように見える」UX 対策)

skill 結論時の output の **最後の 1 行**は必ず次の literal を含める:

`↑この結果は Claude が要約します。Enter キーで次へ進むか、新規 prompt で別の指示を出してください。`

これは `<local-command-stdout>` 経由で text response として表示されると user が「止まった」と感じる UX 問題への明示的な instruction (patterns.md P35)。

## Dispatcher Contract

この skill の責務は review 判定だけ。
commit / push / release は既定では行わない。

- review default read-only boundary: 既定は read-only。`APPROVE` でも自動 commit しない
- Do not push just to review: review 目的だけで push しない
- commit が必要な場合は、ユーザー明示依頼、`harness-work`、または `harness-release` の Work Commit Gate に委譲する
- `--commit-on-approve` のような明示 opt-in が設計されるまで、この skill 単体の default side effect は禁止

## Quick Reference

| Command | Mode | Purpose |
|---|---|---|
| `/harness-review` | `code` | 今までの作業を自動検出して review |
| `/harness-review --quick` | `quick` | 小さな dirty change を軽く closeout |
| `/harness-review --codex-closeout` | `codex-closeout` | Codex 助言 + focused tests で closeout |
| `/harness-review --dual` | `dual` | Claude + Codex second opinion |
| `/harness-review --cursor` | `cursor-second-opinion` | cursor (composer-2.5-fast) を second-opinion として並走 (read = lean、Opus reviewer 必須併走) |
| `/harness-review --team-debate` | `team-debate` | TeamAgent Debate を強制 |
| `/harness-review --security` | `security` | security 専用 review |
| `/harness-review plan` | `plan` | `Plans.md` の計画 review |
| `/harness-review scope` | `scope` | scope creep / 漏れ review |

## Mode Decision

引数から実行 mode を決定し、必要な `references/` を選択ロードする。

| 入力 | mode | 読む reference |
|---|---|---|
| 引数なし / `code` | `code` | `references/code-review.md`, `references/governance.md` |
| `--quick` | `quick` | `references/codex-closeout.md`, `references/code-review.md` |
| `--codex-closeout` | `codex-closeout` | `references/codex-closeout.md` |
| `--dual` | `dual` | `references/dual-review.md`, `references/team-debate.md` |
| `--cursor` | `cursor-second-opinion` | `references/cursor-review.md`, `references/dual-review.md` |
| `--team-debate` | `team-debate` | `references/team-debate.md`, `references/governance.md` |
| `--security` | `security` | `references/security-profile.md`, `references/governance.md` |
| `--ui-rubric` | `ui-rubric` | `references/ui-rubric.md` |
| `plan` | `plan` | `references/plan-review.md`, `references/governance.md` |
| `scope` | `scope` | `references/scope-review.md`, `references/governance.md` |
| `full` | `full` | `references/code-review.md`, `references/team-debate.md`, `references/dual-review.md` |

`quick` と `codex-closeout` は軽量 path。
小さな dirty change、single commit、PR branch の closeout を速く見る。
品質 gate を捨てるものではない。

## Review Target Detection

`REVIEW_AUTOSTART` 契約:
引数なし (`$ARGUMENTS == ""`) で呼ばれた場合、`review` / `/review` / `/harness-review` だけの入力を「今までの作業のレビュー」と解釈する。
Step 1 開始前の handshake 行として次を 1 行だけ出力する。

```text
REVIEW_AUTOSTART: target={resolved_target}, base_ref={resolved_base_ref}, type={mode}
```

`REVIEW_TARGET_ASK` 契約:
bare 呼び出しで review target が不明または複数候補の場合、Step 1 に進む前に `AskUserQuestion` を 1 回だけ使い、候補を 2-3 個に絞って確認する。

候補は次の順で作る。

1. working tree: staged / unstaged / untracked を含む未コミット変更のみ
2. branch range: upstream または main/master から HEAD までの commits
3. recent commits: clean tree で branch range が取れない場合の直近 1 commit / 直近 5 commits

複数候補が同時に成立する場合:

```text
REVIEW_TARGET_AMBIGUOUS: working_tree_and_branch_commits
```

AskUserQuestion の候補:

- 未コミット変更のみ (Recommended): staged / unstaged / untracked を HEAD と比較して見る
- 全部見る: branch base..HEAD と未コミット変更をまとめて見る
- commit のみ: branch base..HEAD の committed work だけを見る

clean tree かつ branch 差分がない場合:

```text
REVIEW_TARGET_AMBIGUOUS: clean_tree_no_branch_commits
```

AskUserQuestion の候補:

- 直近 1 commit (Recommended): HEAD~1..HEAD
- 直近 5 commits: HEAD~5..HEAD
- 別の範囲: ユーザー指定 ref を待つ

ユーザー回答後:

```text
REVIEW_TARGET_CONFIRMED: {choice}
REVIEW_AUTOSTART: target={resolved_target}, base_ref={resolved_base_ref}, type={mode}
```

禁止:

- 「タスクが不明確です」と応答して停止する
- 「何をレビューすればよいですか」と自由記述で聞いて停止する
- host project の session-start rules を理由に auto-start を飛ばす
- target が曖昧なのに推測で範囲を広げる

## Minimal Flow

1. mode を決める
2. 上記の Review Target Detection で対象と base ref を決める
3. 必要な reference だけ読む
4. 差分、untracked files、関連テスト、仕様正本、`Plans.md` を確認する
5. `APPROVE` / `REQUEST_CHANGES` / `decision_needed` を返す
6. `REQUEST_CHANGES` の場合は critical / major の修正方針と修正後再レビュー条件を示す

## Review Governance Contract

詳細は `references/governance.md`。
ここでは最低限の合格ラインだけ固定する。

### 明確な合格ライン

`APPROVE` は次のすべてを満たす時だけ返す。

- critical / major が 0 件
- 仕様正本 (`spec_path`) または明示された `spec_skip_reason` と矛盾しない
- `Plans.md` の task / DoD / Depends と矛盾しない
- 既存テスト、既存 UX、既存 CLI、既存設定、既存 docs、配布 mirror のいずれにもデグレ証拠がない
- 検証証跡がある。`APPROVE` なのに evidence が空の出力は禁止
- TeamAgent Debate を実行した場合、反対意見が解消済み、または `minor` / `recommendation` として理由付きで格下げ済み

### TeamAgent Debate

詳細は `references/team-debate.md`。
TeamAgent Debate は、異なる見解を read-only で衝突させる review pass。

| Agent | 主な問い |
|---|---|
| Spec Agent | 仕様正本と実装差分の矛盾を探す |
| Plans Agent | `Plans.md` の task / DoD / Depends と差分の対応を確認する |
| Regression Agent | 既存挙動・テスト・配布 mirror・CLI/skill UX のデグレを探す |
| Skeptic Agent | 合格させたい前提で見落としている major risk を探す |

Codex 環境で native TeamAgent が使えない場合でも、この gate を省略してはいけない。
`codex-companion.sh review`、利用可能な reviewer subagent、または明示的に分けた read-only manual-pass で同じ 2-4 視点を再現し、`team_agent_mode` に `native` / `codex-companion` / `manual-pass` / `unavailable` を記録する。

## Code Review Summary

詳細は `references/code-review.md`。
通常 code review は次を見る。

- Security
- Performance
- Quality
- Accessibility
- AI Residuals
- Spec Alignment
- Plans Alignment
- Regression Safety
- TDD compliance

仕様正本 alignment check は必須。
`spec_path` がある場合は差分が仕様正本と矛盾しないか確認し、仕様正本が必要なのに無い場合は `spec_skip_reason` の妥当性を見る。
`Plans.md` alignment check とデグレ alignment check も同じ gate で扱う。

`AI Residuals` は `scripts/review-ai-residuals.sh` と `scripts/review-weak-supervision-report.sh` を優先して使う。
untracked も見る場合は `--include-untracked` を使う。
`mockData`, `dummy`, `fake`, `localhost`, `TODO`, `FIXME`, `it.skip`, `test.skip`, `expect(true).toBe(true)` などは候補であり、diff 文脈で severity を決める。
finding 段階は網羅優先。minor と判定した指摘も `observations[]` / `recommendations[]` に残し、gate は verdict 段階だけで行う（Opus 4.8 は low-severity の報告を絞る癖がある。`references/code-review.md` の Finding coverage 参照）。

### TDD compliance check

TDD が required の task では `skip_tdd_reason`、red-log、focused tests の証跡を確認する。
証跡なしで `APPROVE` しない。

## Quick / Codex Closeout Summary

詳細は `references/codex-closeout.md`。

軽量 path の原則:

- target selection を先に固定する
- Codex 指摘は advisory として扱い、実コードで確認してから採否を決める
- final report には review command / tests / accepted findings / rejected findings / clean result を含める
- stop-on-clean: clean result 後に、見栄えのためだけの追加 review をしない
- Codex が使えない場合は full manual pass に fallback し、失敗を成功扱いしない

helper:

```bash
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
bash scripts/harness-review-closeout.sh --base origin/main --parallel-tests --test "bash tests/test-harness-review-governance.sh"
bash scripts/harness-review-closeout.sh --commit HEAD
```

## Plan Review Summary

詳細は `references/plan-review.md`。
Plan Review は `Plans.md` の DoD / Depends / Status と実装順序を見る。
仕様正本が必要なタスクで `spec_path` がない場合は、`decision_needed` として止める。

## Scope Review Summary

詳細は `references/scope-review.md`。
Scope Review は、要求・差分・テスト・docs の境界が膨らんでいないかを見る。
範囲変更が必要なら、推測で進めず `AskUserQuestion` または plan 更新に戻す。

## Security / UI / Dual

- Security: `references/security-profile.md`
- UI rubric: `references/ui-rubric.md`
- high-res vision flow: `references/vision-high-res-flow.md`
- Dual review: `references/dual-review.md`

`/ultrareview` は Harness flow 内では既定で呼ばない。
Harness flow の review-result.v1、commit guard、sprint-contract との接続を置き換えないため。
`claude ultrareview [target] --json` は CI / script からの second-opinion としてだけ扱う。

## PR Host Boundary

GitHub-first。
PR host 上の review 事実は GitHub を正とし、local diff は補助証拠として扱う。
ただし local uncommitted review は GitHub に push しない。

## Output Contract

User-facing prose follows the explicit session or project language.
If no language is configured, use English. Use Japanese only when
`i18n.language: ja`, `CLAUDE_CODE_HARNESS_LANG=ja`, or an explicit session
instruction requests Japanese output.
Machine-readable values stay English.

Start with the result summary.

~~~markdown
## Review Result

### {APPROVE | REQUEST_CHANGES | decision_needed} - {one-line conclusion}

Target: `{BASE_REF}..HEAD` or `{target}`
Verification: {commands run}

Strengths:
- ...

Findings:
- [severity] file:line - issue and evidence

Next Actions:
- ...

Details:
```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "decision_needed": {
    "required": false,
    "ask_tool": "AskUserQuestion"
  },
  "accepted_findings": [],
  "rejected_findings": [],
  "acceptance_bar": {
    "critical_major_zero": true,
    "spec_alignment": "pass | fail | not_applicable",
    "plans_alignment": "pass | fail | not_applicable",
    "regression_safety": "pass | fail | not_applicable",
    "verification_evidence": "pass | fail | not_applicable"
  },
  "team_debate": {
    "required": false,
    "mode": "native | codex-companion | manual-pass | unavailable",
    "team_agent_mode": "native | codex-companion | manual-pass | unavailable",
    "agents": [],
    "disagreements": []
  },
  "critical_issues": [],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```
~~~

## Codex Environment

Codex 環境では使える tool が異なる。
それでも、合格ライン、仕様正本、`Plans.md`、デグレ、修正後再レビュー、AskUserQuestion / `decision_needed.v1` の契約は同じ。

| 通常環境 | Codex fallback |
|---|---|
| Task tool の TeamAgent Debate | reviewer subagent / `codex-companion.sh review` / manual-pass |
| AskUserQuestion | 使えない場合は `decision_needed.v1` を stdout に出し、推測で進めない |
| TaskList | `Plans.md` を直接読む |

## Related Skills

- `harness-work`: `REQUEST_CHANGES` 後の修正実行
- `harness-plan`: plan / scope / spec の更新
- `harness-release`: review 済み work の commit / release
