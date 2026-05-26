# Quick / Codex Closeout

## ひとことで

小さな変更は、対象を固定し、Codex の助言を実コードで確認し、clean ならそこで止める。

## target selection decision tree

1. working tree が dirty
   - 推奨: 未コミット変更のみ
   - base: `HEAD`
   - untracked を含める
2. PR branch / feature branch に commits がある
   - 推奨: `upstream..HEAD` または `origin/main..HEAD`
   - working tree も dirty なら AskUserQuestion で「未コミット変更のみ / 全部 / commit のみ」を選ぶ
3. clean tree で branch 差分がない
   - 推奨: 直近 1 commit
   - 必要なら直近 5 commits
4. user が `--base` / `--commit` を指定
   - 明示指定を優先

## Advisory rule

Codex の指摘は advisory。
つまり「参考意見」であり、事実そのものではない。

必ず次を行う。

- 指摘箇所を実コードで読む
- diff とテストで再現性を確認する
- accepted findings / rejected findings に分ける
- rejected には「なぜ採用しないか」を書く

## Stop-on-clean

stop-on-clean:
clean result が出た後に、見栄えのためだけの追加 review をしない。

例:

- Codex review: no major issues
- focused tests: pass
- manual spot check: pass

この状態なら止める。
追加の重い review は、release 前、security-sensitive、仕様正本変更、またはユーザー明示時だけ行う。

## Helper contract

`scripts/harness-review-closeout.sh` は lightweight closeout の実行計画を固定する helper。

対応する入力:

- `--dry-run`
- `--parallel-tests`
- `--base REF`
- `--commit REF`
- `--uncommitted`
- `--test CMD`
- `--json`

例:

```bash
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
bash scripts/harness-review-closeout.sh --base origin/main --parallel-tests --test "bash tests/test-harness-review-governance.sh"
bash scripts/harness-review-closeout.sh --commit HEAD --json
```

Codex が利用できない場合:

- full manual pass に fallback
- failure を success と扱わない
- final report に `codex_available:false` を残す

## Final report

必須項目:

- review command
- tests
- accepted findings
- rejected findings
- clean result
- fallback reason

JSON では最低限こう残す。

```json
{
  "schema_version": "harness-review-closeout.v1",
  "target": "working_tree | branch_range | commit",
  "base_ref": "HEAD",
  "review_command": "bash scripts/codex-companion.sh review --base HEAD --json",
  "tests": [],
  "accepted_findings": [],
  "rejected_findings": [],
  "clean_result": true,
  "codex_available": true,
  "fallback": ""
}
```
