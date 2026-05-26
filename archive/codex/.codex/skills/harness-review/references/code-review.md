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
diff 文脈で「出荷事故や誤設定に直結するか」を判定する。

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

## Verdict

1. critical / major がある → `REQUEST_CHANGES`
2. 仕様正本 / `Plans.md` / デグレ gate が fail → `REQUEST_CHANGES`
3. 意思決定が必要 → `decision_needed`
4. minor / recommendation のみ → `APPROVE`
5. 証拠が足りない → `REQUEST_CHANGES` または `decision_needed`

## 修正後再レビュー

`REQUEST_CHANGES` の後は、修正後再レビューを必ず行う。
同じ issue を 2 回連続で落とした場合は TeamAgent Debate を強制する。
