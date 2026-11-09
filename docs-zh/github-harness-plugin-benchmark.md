# GitHub Harness Plugin Benchmark

最终更新: 2026-03-06

本文档以 **引入后标准运营如何改变** 为视角，对 GitHub 上受欢迎的 **Claude Code 用 harness / workflow plugin** 进行了比较，是一份日期标注的快照。

- 这不是**人气投票**，而是 **harness 比较**
- GitHub stars 仅作为「比较对象的选择理由」
- 首先列出「引入后什么成为标准」，然后解释差异的含义
- 通用 AI coding agent（Aider, OpenHands 等）和 curated list 因**不是单一 harness** 而不在比较表范围内

## Compared Repositories

截至 2026-03-06，以在 GitHub 上公开且主张「Claude Code 用多段 workflow / plugin / harness」的 repo 中，具有足够公开信息进行比较的为对象。

| Repo | GitHub stars | 入选原因 |
|------|--------------|----------|
| [obra/superpowers](https://github.com/obra/superpowers) | 71,993 | 人气最高的 workflow / skills 系 plugin。不可或缺比较对象 |
| [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd) | 2,770 | 正面强调需求驱动开发流程的热门 Claude Code 系 harness |
| [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) | 232 | 本 repo |

## 用户可见比较表

凡例:

- `✅` 从引入起即可作为标准流程使用
- `△` 努力可以做，但不是主线路
- `—` 不是主要诉求

| 用户关心的事项 | Claude Harness | Superpowers | cc-sdd |
|------------------------|----------------|-------------|--------|
| 计划不会在对话中消失，而是留在 repository | ✅ | ✅ | ✅ |
| 实现后易于按同一流程推进 | ✅ | ✅ | △ |
| 审查进入完成前的标准流程 | ✅ | ✅ | △ |
| 用运行时 guard 阻止危险操作 | ✅ | △ | — |
| 验证可以后来用相同步骤重新执行 | ✅ | △ | ✅ |
| 审批后可以一口气走到最后 | ✅ | △ | — |

## 此差异的含义

### Claude Harness

- 最强的是 **标准流程的固化** 和 **运行时 guard** 和 **可重新执行的验证**
- Plan → Work → Review 作为独立线路齐备，甚至有 `/harness-work all` 这个一键执行的捷径
- 适合「不要每次都差不多就行，而是要每次都以相同形态稳定推进」的人

### Superpowers

- 最强的是 **workflow 的广度** 和 **引入故事的易理解性**
- 策划、实现、审查、debug 的流程清晰可见，自动触发也很强
- 但是，运行时规则阻止危险操作的机制，以及可重新执行的证据，作为标准流程没有 Harness 那么突出

### cc-sdd

- 最强的是 **规格驱动的纪律**
- `Requirements -> Design -> Tasks -> Implementation` 的流程清晰，有 dry-run 和 validate-gap / validate-design
- 但是，从公开面看，独立的审查流程和一键执行的线路，没有 Harness 作为标准流程那么强

## README 中的呈现方式

在 README 和 LP 中，以下说法比较自然：

> 想扩展 workflow 的选项就用 Superpowers。
> 想加强需求 → 设计 → 任务的纪律就用 cc-sdd。
> 想将计划・实现・审查・验证变为不易崩塌的标准流程就用 Claude Harness。

## 判定备忘录

- `计划不会在对话中消失，而是留在 repository`
  - Harness: `Plans.md` / `/harness-plan`
  - Superpowers: brainstorming / writing-plans workflow
  - cc-sdd: requirements / design / tasks workflow
- `实现后易于按同一流程推进`
  - Harness: `/harness-work --parallel`、Breezing、worker/reviewer flows 接入标准流程
  - Superpowers: parallel agent execution / subagent workflows 在公开面容易理解
  - cc-sdd: Claude agent variant 中可确认多个 subagent，但并非在所有用法中都作为核心功能推出
- `审查进入完成前的标准流程`
  - Harness: `/harness-review` 和 `/harness-work all`
  - Superpowers: code review workflow is explicit
  - cc-sdd: validate 命令有说明，但将代码审查作为独立流程推出的程度较弱
- `用运行时 guard 阻止危险操作`
  - Harness: TypeScript guardrail engine + deny / warn rules
  - Superpowers: workflow discipline and hooks are visible, but compiled deny / warn runtime engine is not front-and-center
  - cc-sdd: 在公开 README 中难以确认明确的运行时 safety engine
- `验证可以后来用相同步骤重新执行`
  - Harness: validate scripts + consistency checks + evidence pack
  - Superpowers: 有 verify-oriented workflows，但 artifact pack 没有突出呈现
  - cc-sdd: 有 dry-run / validate-gap / validate-design
- `审批后可以一口气走到最后`
  - Harness: `/harness-work all`
  - Superpowers: 有 auto-triggered workflow，但同等意义上的 published single command 没有突出呈现
  - cc-sdd: 有 spec-based command set，但在 approval 之后把 full loop 统合起来的单一线路没有突出呈现

## 注意事项

- stars 每天都在变化，因此此表是 **日期标注的快照**
- 本比较侧重于「用户可见的 harness 功能差异」，而非「市场人气」
- 也存在 `Superpowers > Claude Harness` 的维度。尤其是 ecosystem / adoption / workflow story 的优势很明显
- 也存在 `cc-sdd > Claude Harness` 的维度。尤其是需求驱动纪律的清晰度是优势
- 在 README 中呈现时，比起断言胜负，**写明适合重视什么的人**更为自然

## Evidence Used

### Local evidence

- [README.md](../README.md)
- [docs/claims-audit.md](claims-audit.md)
- [docs/distribution-scope.md](distribution-scope.md)
- [docs/evidence/work-all.md](evidence/work-all.md)

### Public GitHub sources

- [obra/superpowers](https://github.com/obra/superpowers)
- [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)
- [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)
