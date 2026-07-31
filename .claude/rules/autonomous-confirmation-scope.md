# Autonomous Confirmation Scope

`breezing` / `harness-work` / `harness-loop` など自律実行系スキルが実行中にユーザーへ確認 (`AskUserQuestion` 等) してよい範囲を固定する SSOT。

## なぜこのルールが必要か

背景 (why): [docs/rules/governance-rationale.md](../../docs/rules/governance-rationale.md#autonomous-confirmation-scopemd)

## 確認してよい 3 ケース（これ以外は確認しない）

1. **外部送信が絡むとき**: git push、PR 作成/merge、GitHub Release 公開、外部 API 呼び出し、メール/Slack/Discord 等への送信、デプロイ
2. **セキュリティのリスクが絡むとき**: 秘密情報露出、認証/認可/権限変更、破壊的操作（`rm -rf`、`git reset --hard`、`git push --force` 等。既存の deny/ask はそのまま有効）
3. **もともとの依頼が達成できなさそう、またはその判断を求めたいとき**: 仕様正本と実装の矛盾、`Plans.md` の DoD/Depends と矛盾、backward compatibility を残すか削るかで依頼の解釈が変わる場合

上記 3 ケースに該当する確認は、`AskUserQuestion` が使える環境では使い、使えない環境では `decision_needed.v1` を出力してから停止する。

## 確認しないこと（推測して進める）

以下は 3 ケースに該当しないため、`AskUserQuestion` を使わない。最も妥当な 1 つを選び、選んだ理由を 1 行の出力に残してからそのまま進める。ユーザーは事後に結果を見て軌道修正できる。

| 場面 | 自動選択の基準 |
|---|---|
| `harness-review` の review target が複数候補 | working tree（未コミット変更）> branch range（upstream/main..HEAD）> recent commits の優先順で先頭を選ぶ |
| `harness-release` の Review Gate（未レビューの work が見つかった） | 「レビューから開始」を自動選択し `harness-review` を起動する。dry-run/中止は明示指定があった時のみ |
| `harness-release` の Work Commit Gate の commit message | review summary / `Plans.md` task / branch name から生成した 1 案をそのまま使う |
| `harness-review` の Scope Review で軽微な範囲判断 | 依頼の解釈自体は変わらない軽微な範囲調整は進める。依頼の解釈が変わる場合はケース 3 として確認する |
| security **と** UX のトレードオフのうち、UX 側だけの好み | セキュリティ側の結論を優先し、UX は推奨案を選んで進める（セキュリティが絡む場合はケース 2 として確認してよい） |

## 例外: `harness-release` の単一 Confirmation Gate

`harness-release` の Post-Gate 直前にある単一 Confirmation Gate（version bump / CHANGELOG / PR merge / tag / GitHub Release の一括提示）は、ケース 1（外部送信）に該当するため維持する。これは release フロー全体で唯一の確認ポイントであり、道中の Review Gate / Work Commit Gate を自動化した分だけ、この 1 回に判断を集約する。

## 適用範囲

- `skills/harness-review/references/governance.md` の `decision_needed`
- `skills/harness-review/SKILL.md` の `REVIEW_TARGET_ASK` 契約
- `skills/harness-release/SKILL.md` の Review Gate / Work Commit Gate
- `agents/worker.md` / `agents/advisor.md` 経由で Lead に戻った後、Lead がユーザーに確認するかどうかの判断

適用対象外（このルールを変更しない）:

- `harness-release` の単一 Confirmation Gate（上記「例外」参照）
- `.claude/rules/commit-safety.md`、Permission Boundaries（`git push --force` 等の不可逆操作 ask/deny）
- `/breezing` を引数なしで呼んだ時のスコープ確認（タスク範囲そのものの解釈であり、ケース 3 に該当する）

## 関連

- ユーザー個人のワーキングアグリーメント（`~/.claude/CLAUDE.md` Risk Gates）のプロジェクト側 SSOT 化
- `.claude/rules/commit-safety.md` — 不可逆な git 操作の扱い
- `CLAUDE.md` Permission Boundaries — deny/ask の多層防御
