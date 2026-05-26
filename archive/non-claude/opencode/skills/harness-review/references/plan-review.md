# Plan Review

## ひとことで

Plan Review は、`Plans.md` が実装できる粒度と順序になっているかを見る。

## Checkpoints

- task が 1 つの完了単位になっている
- DoD が検証可能
- Depends が循環していない
- Status が現実と合っている
- 仕様正本が必要な task で `spec_path` または作成タスクがある
- 実装順が risk の高い部分を後回しにしていない
- review / release / mirror / docs の closeout が漏れていない

## Verdict

| 状態 | 判定 |
|---|---|
| DoD が測れる、Depends が妥当、scope が明確 | APPROVE |
| DoD が曖昧、依存が壊れている、仕様正本が必要なのにない | REQUEST_CHANGES |
| ユーザー判断なしに scope を変える必要がある | decision_needed |

## Output

Plan Review では file:line を優先する。
`Plans.md` の該当行、docs、仕様正本を根拠にする。
