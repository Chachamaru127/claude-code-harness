# Advisor Strategy

## 一句话概括

Advisor Strategy 是一种"平时执行者自行推进，遇到难题时才咨询顾问"的推进方式。

在 Harness 中作为 v1，首先从 `harness-loop` 开始引入这一理念。

## 打个比方

不是一直在旁边细致指挥的监督者，
而是在平时让现场负责人自主行动，
只在"这里判断很为难"的时候才向前辈咨询的形式。

采用这种形式，
就不必每次都请出大的判断者，
更容易在速度和安全性之间取得平衡。

## 核心内容

Harness 的角色分工有以下 4 种。

| 角色 | 做什么 |
|------|------------|
| Lead | 整理整体流程 |
| Worker / executor | 推进实现和修改 |
| Advisor | 仅提供方针建议 |
| Reviewer | 进行最终质量判定 |

重要的是，
**Advisor 不是 Reviewer 的替代者**。

Advisor 返回"接下来怎么走"。
最终是 `APPROVE` 还是 `REQUEST_CHANGES`，
和以往一样由 Reviewer 承担。

## 何时调用 advisor

v1 中，将咨询场景固定为 3 种。

1. 高风险 task 的首次执行前
2. 同一原因失败连续出现 2 次后
3. 检测到 plateau 并返回 `PIVOT_REQUIRED` 前

高风险 task 在当前 contract 中指以下任一情况：

- `needs-spike`
- `security-sensitive`
- `state-migration`

为了避免同一种咨询反复进行，
使用 `trigger_hash` 这一标识符。

这是将
**"哪个 task""什么理由""什么样的失败"**
汇总后的印记。

同一个 `trigger_hash` 只会咨询 1 次。
另外，每个 task 的咨询次数最多 3 次。

## advisor 返回的 3 种 decision

Advisor 的回答以 `advisor-response.v1` 这一 JSON 固定格式。
decision 只有以下 3 种。

| decision | 含义 | Harness 的动作 |
|----------|------|----------------|
| `PLAN` | 重新制定推进方式 | 在下次执行 prompt 的开头加入建议后重新执行 |
| `CORRECTION` | 方针正确，只需局部修改 | 作为修改指示重新执行 |
| `STOP` | 不适合继续自走 | 停止 loop，将理由留在 state 中并升级 |

## 具体例子

例如，
考虑在用 `harness-loop` 运行包含 `state-migration` 的 task 的场景。

1. loop 读取 sprint contract
2. 判断是高风险 task
3. 在开始实现前仅向 advisor 咨询 1 次
4. advisor 返回 `PLAN`
5. loop 将该建议放在下次 prompt 的开头后让执行者运行
6. 实现后的最终判定由 Reviewer 进行

也就是说，
咨询者并不接手"实现本身"，
只是为实现者消除迷茫、整理前进方向。

## 为什么先从 `harness-loop` 引入

理由有 3 个。

1. 在长时间运行时，遇到迷茫时才调用重判断的形式效果尤为显著
2. 因为有 `run.json` 和 `cycles.jsonl`，容易保留咨询历史
3. 可以在不破坏现有 Reviewer 和 checkpoint 流程的情况下引入

换句话说，
不是一下子改变所有执行路径，
而是从**效果最大、最容易观察的地方**开始引入。

## 已知限制

v1 中刻意没有加入以下内容。

- Worker 自由增加新的 subagent
- 自信估计这类基于自然语言的判定目前还不使用
- advisor 的持久化仅停留在 file-based state，不使用 SQLite
- Phase 61 的 weak-supervision cue 不是基于自然语言的自信估计，而是仅传递 `.claude/state/elicitation/events.jsonl` 中留下的证据事件的简短内容
- `breezing` 和 `harness-work` 首先从 protocol 和文档的统一开始推进

## 相关文件

- `agents/advisor.md`
- `scripts/run-advisor-consultation.sh`
- `scripts/codex-loop.sh`
- `skills/harness-loop/SKILL.md`
- `skills/harness-loop/references/flow.md`

## 为什么采取这种方式

Harness 一开始就是
"计划""实现""审查"分离以降低耦合度的设计。

引入 Advisor Strategy 时，
也在保留这一基础上进行，
**只提升执行者的自走能力**这样做更安全。

因此 v1 中，
主要内容是"追加咨询者"，
而不是"转移质量判定的责任"。
