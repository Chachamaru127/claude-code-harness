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
| Spec Alignment | 仕様正本との矛盾 |
| Plans Alignment | `Plans.md` の task / DoD / Depends との一致 |
| Regression Safety | 既存挙動・mirror・CLI/skill UX のデグレ |

## TDD compliance

TDD が要求されている task では、失敗するテストを先に確認した証跡を見る。
ただし docs-only や refactor-only のように TDD が過剰な場合は、skip 理由を記録すればよい。

## Finding coverage（Opus 4.8）

finding 段階と verdict 段階を分ける。

- finding 段階は **網羅優先**。確信が低い指摘や minor も含め、見つけた issue は全て severity と確信度つきで記録する（`review-result.v1` の `observations[]` / `recommendations[]` に残す）。
- gate するのは verdict 段階だけ（critical / major で `REQUEST_CHANGES`、minor のみ `APPROVE`）。
- 「出荷事故や誤設定に直結するか」は **severity の判定**であって、**記録するかの判定ではない**。minor と判断しても黙って捨てない。

Opus 4.8 は「low-severity は報告するな」を忠実に守り、調査はしても報告を絞って recall を落とす癖がある。
finding を絞るのは verdict 段階の責務であり、調査段階で findings を捨てない。

## Verdict

1. critical / major がある → `REQUEST_CHANGES`
2. 仕様正本 / `Plans.md` / デグレ gate が fail → `REQUEST_CHANGES`
3. 意思決定が必要 → `decision_needed`
4. minor / recommendation のみ → `APPROVE`
5. 証拠が足りない → `REQUEST_CHANGES` または `decision_needed`

## 修正後再レビュー

`REQUEST_CHANGES` の後は、修正後再レビューを必ず行う。
同じ issue を 2 回連続で落とした場合は TeamAgent Debate を強制する。
