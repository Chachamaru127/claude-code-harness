# TeamAgent Debate

## ひとことで

TeamAgent Debate は、別々の視点で同じ変更を読み、見落としを減らす read-only review pass。

## When required

次のいずれかなら実行する。

- 変更が複数モジュールにまたがる
- security / auth / release / distribution / mirror に触る
- 仕様正本や `Plans.md` との対応が曖昧
- regression risk が高い
- Claude と Codex の verdict が割れた
- reviewer の中で観点別評価が割れた
- 同じ issue を修正後再レビューで 2 回連続で落とした

## Agents

| Agent | 主な問い |
|---|---|
| Spec Agent | 仕様正本と実装差分の矛盾を探す |
| Plans Agent | `Plans.md` の task / DoD / Depends と差分の対応を確認する |
| Regression Agent | 既存挙動・テスト・配布 mirror・CLI/skill UX のデグレを探す |
| Skeptic Agent | 合格させたい前提で見落としている major risk を探す |

最低 2 視点、必要時 4 視点まで。
全員 read-only。

## Codex fallback

Codex 環境で native TeamAgent が使えない場合も、省略しない。

使える fallback:

- `codex-companion.sh review`
- reviewer subagent
- 明示的に分けた manual-pass

`team_agent_mode` には次のどれかを記録する。

- `native`
- `codex-companion`
- `manual-pass`
- `unavailable`

`unavailable` のまま manual-pass もできない場合は、`decision_needed` として止める。

## Output

```json
{
  "team_debate": {
    "required": true,
    "mode": "manual-pass",
    "team_agent_mode": "manual-pass",
    "agents": ["Spec Agent", "Plans Agent", "Regression Agent"],
    "disagreements": [],
    "acceptance_bar": {
      "spec_alignment": "pass",
      "plans_alignment": "pass",
      "regression_safety": "pass"
    }
  }
}
```

## 合格ライン

TeamAgent Debate の disagreement が critical / major 相当なら `REQUEST_CHANGES`。
minor / recommendation に格下げする場合は、理由を evidence 付きで書く。
