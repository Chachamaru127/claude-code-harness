# harness-review operating model

## ひとことで

`harness-review` は、軽い closeout から重い品質 gate までを 1 つの入口で扱う。
別の軽量 skill は作らない。

## たとえると

病院の受付を 2 つに増やすのではなく、同じ受付で「通常診察」「精密検査」「救急」を振り分ける形にする。
入口を増やすと迷いやすい。
入口を 1 つにして、中で適切な検査の重さを選ぶ。

## Why single entrypoint

| 判断 | 理由 |
|---|---|
| 別 skill を作らない | discovery noise が増える。ユーザーも agent も、どちらを呼ぶべきか迷う |
| `harness-review` を dispatcher にする | contract drift を避けられる。`APPROVE` の意味が skill ごとにズレない |
| governance を reference に逃がす | 長い SKILL.md を毎回読む負担を減らしつつ、品質 gate は残せる |
| read-only default にする | review だけで commit / push まで進むと、release/work flow の責務が壊れる |

## Mode table

| mode | 使う場面 | 重さ | 主な出力 |
|---|---|---:|---|
| `quick` | 小さな未コミット変更を閉じたい時 | 軽い | accepted/rejected findings と focused tests |
| `codex-closeout` *(archived for v1)* | Codex review を助言として使い、実コードで確認したい時 | 軽い | review command / tests / clean result |
| `code` | 普通の実装差分レビュー | 中 | `APPROVE` / `REQUEST_CHANGES` |
| `plan` | `Plans.md` の DoD / Depends / Status を見る時 | 中 | plan 修正点 |
| `scope` | やりすぎ、漏れ、不要変更を見たい時 | 中 | scope 判定 |
| `security` | 権限、入力、秘密情報などのリスクを見る時 | 重い | OWASP Top 10 観点の findings |
| `ui-rubric` | 見た目、使いやすさ、完成度を点数化する時 | 中 | design quality score |
| `full` | release 前や重要変更の最終 gate | 重い | TeamAgent Debate + governance gate |

## Adopted from external codex-review *(historical upstream context, Codex archived for v1)*

| 採用項目 | harness-review での扱い |
|---|---|
| `advisory` | Codex の指摘は助言。実コード、diff、テストで確認してから採用する |
| `accepted/rejected` | 指摘は accepted findings / rejected findings に分けて理由を書く |
| `stop-on-clean` | clean result 後に、見栄えのためだけの追加 review をしない |
| `target selection` | dirty / PR branch / branch range / single commit を最初に固定する |
| `no push just to review` | Do not push just to review。review 目的だけで push しない |
| `dirty tree handling` | untracked を含む未コミット変更を review scope に含める |

## Not adopted

| 非採用 | 理由 |
|---|---|
| review skill の default auto-commit | review と work/release の責務が混ざる |
| 軽量専用の別 skill | discovery noise と contract drift が増える |
| AI 指摘の自動採用 | 実コード確認なしでは false positive / false negative が混ざる |
| clean 後の追加 review loop | 時間を使うだけで品質が上がりにくい |

## Side-effect boundary

`harness-review` は原則 read-only。
`APPROVE` は「品質 gate を通った」という判定であり、「commit してよい」という操作命令ではない。

commit / push / release の責務:

| 操作 | 担当 |
|---|---|
| 修正 commit | `harness-work` またはユーザー明示依頼 |
| release commit / tag / publish | `harness-release` |
| review 結果の判定 | `harness-review` |
| push | ユーザー明示依頼または release flow |

## Concrete example

小さな docs 修正を見たい時:

```bash
/harness-review --quick
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
```

release 前の重い gate を通す時:

```bash
/harness-review full --team-debate --dual
```

## Why this approach

今の問題は、品質基準が弱いことではない。
入口の `SKILL.md` が重すぎて、軽い closeout でも毎回精密検査の説明書を読む形になっていること。

だから、品質基準を削らず、入口だけを薄くする。
これにより、通常時は速く、重要時は深く見られる。
