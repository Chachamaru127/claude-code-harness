# Dual Review (--dual)

Claude Reviewer と Codex Reviewer を並行実行し、異なるモデル視点でレビュー品質を向上させる。
`--dual` は単なる二重チェックではなく、必要時に TeamAgent Debate を組み合わせて、
仕様正本・Plans.md・デグレの合格ラインを複数視点で潰し込む。

## 前提条件

- Codex CLI がインストール済み（`scripts/codex-companion.sh setup --json` で確認）
- Codex が利用不可の場合、Claude 単独レビューにフォールバック

## 実行フロー

1. Codex の利用可否を確認する

   ```bash
   CODEX_AVAILABLE="$(bash scripts/codex-companion.sh setup --json 2>/dev/null | jq -r '.ready // false')"
   ```

2. Claude Reviewer を Task ツールで起動（通常の review フロー）

3. Codex が利用可能であれば `scripts/codex-companion.sh review` を並行起動

   ```bash
   # BASE_REF が渡されている場合は --base を指定。--json で構造化出力を取得
   bash scripts/codex-companion.sh review --base "${BASE_REF:-HEAD~1}" --json
   ```

4. 両方の結果を待ち合わせ

5. 以下のいずれかに当たる場合は TeamAgent Debate を実行する
   - Claude と Codex の verdict が割れた
   - 仕様正本、Plans.md、デグレのいずれかで不一致または未確認がある
   - `critical` / `major` 候補が 1 件以上ある
   - `--team-debate` が指定されている

6. 合格ラインを固定してから verdict をマージする

## TeamAgent Debate

TeamAgent Debate は、異なる見解をあえて衝突させる read-only review pass として扱う。

| Agent | 主な問い |
|-------|----------|
| Spec Agent | 仕様正本と実装は矛盾していないか |
| Plans Agent | `Plans.md` の task / DoD / Depends と証跡は一致しているか |
| Regression Agent | 既存挙動、既存テスト、配布 mirror、CLI/skill UX にデグレはないか |
| Skeptic Agent | 合格させたい前提で見落としている major risk はないか |

Claude Code では Task tool を使う。
Codex 環境では native TeamAgent が使えないことがあるため、
Codex reviewer subagent、`codex-companion.sh review`、または明示的に分けた manual-pass で同じ観点を再現し、
`team_agent_mode` に記録する。

## 合格ライン

最終 `APPROVE` の条件は次のすべて。

- `critical` / `major` が 0 件
- 仕様正本または `spec_skip_reason` と矛盾しない
- `Plans.md` の task / DoD / Depends と矛盾しない
- 既存挙動・既存テスト・配布 mirror・CLI/skill UX のデグレ証拠がない
- Claude / Codex / TeamAgent の disagreement が解消済み、または `minor` / `recommendation` として理由付きで格下げ済み

## Verdict マージルール

以下の順に評価する:

   - 両方 APPROVE → `APPROVE`
   - どちらかが REQUEST_CHANGES → `REQUEST_CHANGES`（厳しい方を採用）
   - TeamAgent Debate が `critical` / `major` 相当の disagreement を残した → `REQUEST_CHANGES`
   - 仕様正本 / Plans.md / デグレ gate が fail → `REQUEST_CHANGES`
   - `critical_issues` は両方のリストを統合（重複排除なし）
   - `major_issues` は両方のリストを統合（重複排除なし）
   - `recommendations` は重複排除して統合

## 出力形式

通常の `review-result.v1` スキーマに `dual_review` フィールドを追加する:

```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "dual_review": {
    "claude_verdict": "APPROVE | REQUEST_CHANGES",
    "codex_verdict": "APPROVE | REQUEST_CHANGES | unavailable | timeout",
    "merged_verdict": "APPROVE | REQUEST_CHANGES",
    "divergence_notes": "判定が分かれた場合の理由。例: Claude は Performance で major 検出、Codex は問題なし"
  },
  "acceptance_bar": {
    "critical_major_zero": true,
    "spec_alignment": "pass | fail | not_applicable",
    "plans_alignment": "pass | fail | not_applicable",
    "regression_safety": "pass | fail | not_applicable",
    "verification_evidence": "pass | fail | not_applicable"
  },
  "team_debate": {
    "required": true,
    "mode": "native | codex-companion | manual-pass | unavailable",
    "agents": ["Spec Agent", "Plans Agent", "Regression Agent"],
    "disagreements": []
  },
  "critical_issues": [],
  "major_issues": [],
  "observations": [],
  "recommendations": []
}
```

### `codex_verdict` の特殊値

| 値 | 意味 |
|----|------|
| `"unavailable"` | Codex CLI がインストールされていないか利用不可 |
| `"timeout"` | Codex レビューがタイムアウト（120 秒以内に応答なし） |

## フォールバック

- **Codex が利用不可**: Claude 単独で実行し、`codex_verdict: "unavailable"` を記録する
- **Codex がタイムアウト**: Claude の verdict をそのまま採用し、`codex_verdict: "timeout"` を記録する
- **Codex のレビュー出力が不正**: パース失敗として扱い、`codex_verdict: "unavailable"` を記録する
- **TeamAgent が利用不可**: `team_debate.mode: "unavailable"` と理由を記録し、最低でも Spec / Plans / Regression の manual-pass を行う

Codex unavailable / timeout の場合でも、仕様正本・Plans.md・デグレの合格ラインは省略しない。
TeamAgent unavailable のまま manual-pass もできない場合は `REQUEST_CHANGES` ではなく `decision_needed` として止める。

## Divergence Notes の書き方

判定が一致した場合（`claude_verdict == codex_verdict`）は `divergence_notes` を空文字列にする。

判定が分かれた場合は以下の形式で記録する:

```
Claude: REQUEST_CHANGES（Security - SQLインジェクションのリスク）
Codex: APPROVE（同箇所を問題なしと判定）
採用: REQUEST_CHANGES（厳しい方を優先）
```
