# harness-review operating model

## 一句话概括

`harness-review` 通过一个入口处理从轻量 closeout 到重量级品质 gate 的全部工作。
不创建另一个轻量级 skill。

## 打比方

就像医院不增设两个挂号窗口，而是让同一个窗口分流「普通门诊」「精密检查」「急救」。
增设入口会让用户迷茫。
将入口统一为一个，在内部选择合适的检查重量级。

## Why single entrypoint

| 判断 | 理由 |
|---|---|
| 不创建独立 skill | discovery noise 增加。用户和 agent 都容易困惑该调用哪个 |
| 让 `harness-review` 担任 dispatcher | 可以避免 contract drift。`APPROVE` 的含义不会因 skill 不同而产生偏差 |
| 将 governance 放到 reference 中 | 减少每次阅读冗长 SKILL.md 的负担，同时保留品质 gate |
| 设为 read-only default | 如果 review 本身直接推进到 commit / push，release/work flow 的职责会混乱 |

## Mode table

| mode | 使用场景 | 重量级 | 主要输出 |
|---|---|---:|---|
| `quick` | 想关闭小的未提交变更时 | 轻 | accepted/rejected findings 和 focused tests |
| `codex-closeout` | 将 Codex review 作为建议使用，想在实代码中确认时 | 轻 | review command / tests / clean result |
| `code` | 普通实现差异 review | 中 | `APPROVE` / `REQUEST_CHANGES` |
| `plan` | 查看 Plans.md 的 DoD / Depends / Status 时 | 中 | plan 修改点 |
| `scope` | 想看过度、遗漏、不必要变更时 | 中 | scope 判定 |
| `security` | 查看权限、输入、秘密信息等风险时 | 重 | OWASP Top 10 视角的 findings |
| `ui-rubric` | 对外观、可用性、完成度打分时 | 中 | design quality score |
| `full` | release 前或重要变更的最终 gate | 重 | TeamAgent Debate + governance gate |

## Adopted from external codex-review

| 采用项 | harness-review 中的处理 |
|---|---|
| `advisory` | Codex 的指出是建议。需在实代码、diff、测试中确认后再采纳 |
| `accepted/rejected` | 将指出分为 accepted findings / rejected findings 并写明理由 |
| `stop-on-clean` | clean result 后不做为美观而进行的额外 review |
| `target selection` | 最初固定 dirty / PR branch / branch range / single commit |
| `no push just to review` | Do not push just to review。不要仅为 review 而 push |
| `dirty tree handling` | 将包含 untracked 的未提交变更纳入 review scope |

## Not adopted

| 未采用 | 理由 |
|---|---|
| review skill 的 default auto-commit | review 和 work/release 的职责会混淆 |
| 轻量专用的独立 skill | 增加 discovery noise 和 contract drift |
| AI 指出的自动采纳 | 没有实代码确认会有 false positive / false negative 混入 |
| clean 后的额外 review loop | 浪费时间却难以提升品质 |

## Side-effect boundary

`harness-review` 原则上是 read-only。
`APPROVE` 是「通过了品质 gate」的判定，不是「可以 commit」的操作指令。

commit / push / release 的职责:

| 操作 | 负责 |
|---|---|
| 修正 commit | `harness-work` 或用户明确委托 |
| release commit / tag / publish | `harness-release` |
| review 结果的判定 | `harness-review` |
| push | 用户明确委托或 release flow |

## Concrete example

想 review 小的 docs 修正时:

```bash
/harness-review --quick
bash scripts/harness-review-closeout.sh --dry-run --uncommitted
```

release 前通过重量级 gate 时:

```bash
/harness-review full --team-debate --dual
```

## Why this approach

现在的问题不是品质标准太弱。
而是入口的 `SKILL.md` 太重，即使轻量 closeout 也要每次阅读精密检查说明书的形态。

所以，不削减品质标准，只把入口做薄。
这样通常时快速，重要时深入。
