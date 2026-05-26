# Scope Review

## ひとことで

Scope Review は、やるべきことを漏らしていないか、逆に余計なことまでやっていないかを見る。

## Checkpoints

- user request と差分が一致している
- task の DoD を満たしている
- unrelated refactor が混ざっていない
- docs / tests / mirror / changelog の必要範囲が揃っている
- 新しい public surface が増えていないか確認している
- migration / release / permission 境界を勝手に変えていない

## Scope creep

scope creep は「作業範囲が必要以上に膨らむこと」。
たとえば docs 修正の task で release script を変え始めるのは危険。

scope creep を見つけたら、次のどちらかに分ける。

- 今回の DoD に必要: plan に明記して進める
- 今回の DoD に不要: 別 task に切り出す

## Verdict

| 状態 | 判定 |
|---|---|
| 要求と差分が一致 | APPROVE |
| DoD 未達または不要変更が混入 | REQUEST_CHANGES |
| scope 変更の事業判断が必要 | decision_needed |
