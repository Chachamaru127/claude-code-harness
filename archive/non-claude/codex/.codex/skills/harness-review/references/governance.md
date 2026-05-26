# Review Governance

## ひとことで

`APPROVE` は「重大な問題がない」と証拠つきで言える時だけ返す。

## 明確な合格ライン

`APPROVE` の条件:

- critical / major が 0 件
- 仕様正本 (`spec_path`) または `spec_skip_reason` と矛盾しない
- `Plans.md` の task / DoD / Depends と矛盾しない
- 既存挙動、既存テスト、既存 UX、既存 CLI、既存設定、既存 docs、配布 mirror にデグレ証拠がない
- 検証コマンド、diff、file:line、テスト結果などの evidence がある
- TeamAgent Debate の未解消 disagreement がない

## Severity

| severity | 意味 | verdict |
|---|---|---|
| critical | 秘密情報露出、データ破壊、権限破壊、release 事故に直結する | REQUEST_CHANGES |
| major | DoD 未達、仕様正本違反、明確なデグレ、テスト未実行で危険 | REQUEST_CHANGES |
| minor | 品質は上がるが出荷停止ほどではない | APPROVE 可 |
| recommendation | 任意改善 | APPROVE 可 |

minor / recommendation だけなら、必ずしも止めない。
止めるなら、なぜ major なのかを具体的に説明する。

## AskUserQuestion / decision_needed

推測で決めると壊れる判断は、`REQUEST_CHANGES` ではなく `decision_needed` とする。

`decision_needed` の例:

- 仕様正本を変える必要がある
- `Plans.md` の DoD / Depends を変える必要がある
- security と UX の優先順位をユーザーが選ぶ必要がある
- backward compatibility を残すか削るかの事業判断が必要

AskUserQuestion が使える場合は使う。
Codex 環境などで使えない場合は `decision_needed.v1` を stdout に出し、推測で進めない。

## Side effects

review default read-only boundary:

- `APPROVE` でも自動 commit しない
- Do not push just to review
- commit / push / release は `harness-work` / `harness-release` / ユーザー明示依頼の責務

## Output evidence

必須:

- 対象範囲
- 実行した review command
- 実行した tests
- accepted findings
- rejected findings
- clean result または残課題
- 仕様正本 / Plans.md / デグレの合格ライン

`APPROVE` なのに evidence が空なら、その `APPROVE` は無効。
