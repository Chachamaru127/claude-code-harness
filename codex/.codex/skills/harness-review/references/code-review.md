# Code Review Flow

## ひとことで

差分を集め、実装・仕様・Plans・デグレ・テストを見て、止めるべき問題だけを止める。

## Step 1: collect diff

確認するもの:

```bash
git status --short
git diff --stat "${BASE_REF:-HEAD}"
git diff "${BASE_REF:-HEAD}"
git ls-files --others --exclude-standard
```

untracked files は `git diff` に出ない。
必ず scope に含める。

## Step 2: static scans

AI Residuals:

```bash
bash scripts/review-ai-residuals.sh --base "${BASE_REF:-HEAD}"
bash scripts/review-weak-supervision-report.sh
```

候補:

- `mockData`
- `dummy`
- `fake`
- `localhost`
- `TODO`
- `FIXME`
- `it.skip`
- `describe.skip`
- `test.skip`
- `expect(true).toBe(true)`

候補が見つかっただけで major にしない。
diff 文脈で「出荷事故や誤設定に直結するか」で severity を判定する。
ただし minor と判定したものも黙って捨てず観察として記録する（下の Finding coverage 参照）。

## Step 3: eight review lenses

| 観点 | 見るもの |
|---|---|
| Security | SQL injection, cross-site scripting, secret leak, permission bypass |
| Performance | N+1, needless heavy IO, blocking work |
| Quality | duplicate logic, unclear boundary, fragile parsing |
| Accessibility | labels, focus, contrast, keyboard path |
| AI Residuals | fake success, skipped tests, mock-only implementation |
| Spec Alignment | root `spec.md` product contract と sub-spec (`spec_path`) との矛盾 |
| Plans Alignment | `Plans.md` の task / DoD / Depends / `[lane:*]` / stage gate との一致 |
| Regression Safety | 既存挙動・mirror・CLI/skill UX のデグレ |

## TDD compliance

`[tdd:required]` task では `tdd_red_log`、literal failing test output、または明示 `skip_tdd_reason` を確認する。
docs-only や refactor-only のように TDD が過剰な場合は、`[tdd:skip:<reason>]` を記録すればよい。
証跡なしで `APPROVE` しない。

## Unknown data contract

`not_observed != absent` — 未観測データを「存在しない」「問題なし」と断定しない。
file / API / CI / memory / fixture が見えない場合は `unknown` / `not observed` と報告する。

## Evidence pack

`APPROVE` 前に evidence pack を確認する: accepted findings、rejected findings、focused tests、`release-preflight` warnings の処理方針、residual risk。

## Finding coverage（Opus 4.8）

finding 段階と verdict 段階を分ける。

- finding 段階は **網羅優先**。確信が低い指摘や minor も含め、見つけた issue は全て severity と確信度つきで記録する（`review-result.v1` の `observations[]` / `recommendations[]` に残す）。
- gate するのは verdict 段階だけ（critical / major で `REQUEST_CHANGES`、minor のみ `APPROVE`）。
- 「出荷事故や誤設定に直結するか」は **severity の判定**であって、**記録するかの判定ではない**。minor と判断しても黙って捨てない。

Opus 4.8 は「low-severity は報告するな」を忠実に守り、調査はしても報告を絞って recall を落とす癖がある。
finding を絞るのは verdict 段階の責務であり、調査段階で findings を捨てない。

## 確定前の再調査（1 回限定）

verdict を確定する前に、より良い案がないか徹底的に再調査する。
findings で見えている系統だけでなく、圏外の別系統案（未検討の別アプローチ）も最低 1 つ検討する。
より良い案が見つからなければ、ここまでの findings / verdict 方針をそのまま維持する。

この再調査は 1 回限定。同じ review 内で繰り返さない（ループ化禁止）。
Severity 表 / 下記 Verdict の閾値ロジックはこの step で変更しない。

## Verdict

1. critical / major がある → `REQUEST_CHANGES`
2. root `spec.md` / `Plans.md` lane-stage / デグレ gate が fail → `REQUEST_CHANGES`
3. TDD evidence 欠落、unknown data を断定、evidence pack 空 → `REQUEST_CHANGES`
4. 意思決定が必要 → `decision_needed`
5. minor / recommendation のみ → `APPROVE`
6. 証拠が足りない → `REQUEST_CHANGES` または `decision_needed`

## 修正後再レビュー

`REQUEST_CHANGES` の後は、修正後再レビューを必ず行う。
同じ issue を 2 回連続で落とした場合は TeamAgent Debate を強制する。
