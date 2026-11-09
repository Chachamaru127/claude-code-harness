# Review Calibration

抑制审查 drift 的保存格式和运用规则。

## 保存位置

- `.claude/state/review-result.json`
- `.claude/state/review-calibration.jsonl`
- `.claude/state/review-few-shot-bank.json`

## 记录规则

`review-result.json` 中附有 `calibration` 时，`record-review-calibration.sh`
会向 `review-calibration.jsonl` 追加 1 行。

`calibration.label` 仅限于以下之一。

- `false_positive`
- `false_negative`
- `missed_bug`
- `overstrict_rule`

Phase 61 的 weak-supervision observations 不混入 `review-calibration.jsonl`。
`weak_label`、`judge_verdict`、`eval_result`、`counterexample` 作为
`.claude/state/elicitation/events.jsonl` 中的 `elicitation-event.v1` 分隔记录。
审查 calibration 用于 Reviewer 判定 drift 修正，elicitation ledger 作为下次 Advisor/Reviewer 的证据 cue 的角色分工。

## few-shot 更新

`build-review-few-shot-bank.sh` 从 calibration log 中提取最新样本，
重新生成 few-shot 用的 JSON bank。

## 质量姿态

- 仅将重大缺陷设为 `REQUEST_CHANGES`
- 没有证据的违和感保留为 `minor` 或 `recommendation`
- 指出内容要写得简短具体，以便日后用于 few-shot
