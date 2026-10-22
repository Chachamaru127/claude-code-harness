# Project Spec And Plans SSOT Workflow

Plans.md 是任务台账。`spec.md` 是产品契约。

这个区分之所以重要，是因为一个任务可能写得很完善，但项目含义
仍然模糊。如果产品行为、领域术语、数据归属、API 契约、安
全边界或 non-goal 没有写在任何稳定的地方，即使
Plans.md 的所有任务都完成了，实现仍可能 drift。

因此 `/harness-plan`
为两个契约产出共同必需的规划结果：

- `spec.md` 产品契约：必须保持为真的东西。
- `Plans.md` 任务契约：做什么、如何证明它、以及当前状态。

优先级保持不变：`spec.md` > sub-spec>
 `Plans.md`。 「共同必需的产出」意
味着规划结果必须同时包含 spec 结果和任务结果。它
并不意味着让 Plans.md 等同于或高于产品契约。

agent 应基于 repo 证据、记忆、测试和用
户请求起草 spec delta。不要让这个工作流
看起来像用户必须从零手写 spec 才能开始规划。

对于非平凡的规划，起草稿在成为实现工作之前必须经过团队验证。非平凡
是指请求跨越多个任务、文件或 session，或改变产品行为、
API、数据模型、权限、计费、外部集成、分发或安全态势。 在可用时使
用 TeamAgent 或 sub-agent 视角。如果不可用，
请写 `サブエージェント未使用` 并在分开的章节中手动执行相同的检
查。 同时写 `team_validation_mode`：
`not_required_lightweight`、`native`、
`subagent`、`manual-pass` 或
`unavailable`。 轻量工作可以使用 `not_required_lightweight`。
 非平凡工作必须使用 `native`、
`subagent` 或 `manual-pass`；
`unavailable` 不能变成 Required。 Product、
Architecture、Security、QA 和 Skeptic
是验证视角，不是必需的运行时 `agent_type` 名称。

## Default Location

优先使用根目录的 `spec.md`。

对于本 repo，以及任何拥有根目录 `spec.md`
的消费方 repo，该根文件就是产品契约：

- `spec.md`

只有当消费方 repo 没有根目录 `spec.md`
时，才回退到已经存在的项目级规格（如果已有的话）：

- `docs/spec/00-project-spec.md`
- `docs/ARCHITECTURE.md`
- `docs/HANDOFF.md`
- `docs/oem/PROJECT_COMPASS.md`
- `docs/specs/` 下名称明确的产品或领域 spec

如果消费项目中既没有根目录 `spec.md`，
也没有更强的本地约定，则创建：

```text
docs/spec/00-project-spec.md
```

对于本 repo，`spec.md` 是根产品契约。诸如
`docs/architecture/hokage-core.md` 和
`go/SPEC.md` 这样的范围限定文档是 sub-spec，不替代根契约。

## Harness-Plan Output Contract

每个 `create` 输出和每个影响产品的
`add` 输出都必须包含 spec 结果和任务结果。

必需的组合：

- `Spec delta`：当产品行为、API、
  数据模型、权限、计费、集成、租户边界、
  支持主张或其他产品契约发生变化时包含此项。
- `Spec skip reason`：当现有产品契约
  已覆盖该请求，或任务仅涉及文档／机械性操作时包含此项。
- `Plans.md`：包含带 DoD、依赖关系、status
  marker 和 evidence 预期的任务行或任务契约文本。

由 Harness 生成 `Spec delta` 和 `Spec skip reason`；
消费方负责审批或编辑它们。 不要求消费方从零编写 spec。

`create` 和影响产品的 `add` 每次都必须读取根目录
`spec.md`，并在生成任务之前产出 spec 结果。搜索结果缺
失、记忆查找失败或文件未被观察到，都不是「不存在 spec」的证据：

```text
not_observed != absent
```

如果任务仅涉及文档或机械性操作，仍应在任务上下文或 sprint contract 中
保留 `Spec skip reason`，以便后续 worker 知道跳过是有意为之。

非平凡的产出还必须保留以下规划 gate：

- `spec.md` / sub-spec / `Plans.md` 的一致性，
- 项目范围内的 harness-mem / harness-recall / repo-memory wheel 检查，
- 与主要工作流的适配性，
- 针对权限、secret、外部发送、供应链、
  分支保护和发布 gate 的安全适配性，
- 通过测试、smoke、CI、review 以及 release
  或 closeout evidence 证明其切实可用。

安全适配性不应要求读取 secret。如果需要检查 `.env`、
token、私钥或客户数据，请在 Risk Gate 处停止，
改用非 secret 的 evidence surface。

## When To Create Or Update It

在实现之前，当满足以下任一条件时，创建或更新 spec SSOT：

- 任务引入或改变用户可见的产品行为。
- 任务改变 API、数据模型、权
  限、计费、租户边界或集成契约。
- 存在多个合理的实现选择，
  且会产生不同的产品行为。
- reviewer、worker 或用户已
  经看到因需求不清导致的实现 drift。
- 任务跨越多个模块，需要共享术语或不变量。
- Plans.md 写了做什么，但没有写对本项目而言「正确」意味着什么。

## When To Skip

对纯机械性工作不要新建 spec：

- 修正错别字
- 格式化
- 无行为变化的依赖升级
- 没有产品决策的本地 CI/测试修复
- 仅涉及 README/CHANGELOG 的更新
- 保持既有行为且有明确测试的窄范围重构

如果跳过可能会让后续实现者感到意外，请在任务上下文
或 sprint contract 中写明跳过理由。

## Minimum Content

保持最初的 spec 简短。它只需要足够的结构来防止 drift。

```markdown
# Project Spec

## Purpose
What this project is for, in one paragraph.

## Users And Workflows
Who uses it, and the main workflows they expect.

## Core Rules
The product rules that implementation must not violate.

## Data And Contracts
Important data shapes, API contracts, integrations, and ownership boundaries.

## Non-Goals
Things the project intentionally does not do.

## Open Decisions
Unknowns that must be resolved before implementation can rely on them.

## Links
- Plans.md task or phase:
- Related briefs:
- Related decisions:
```

## Relationship To Plans.md

当任务依赖项目级行为时，Plans.md 应链接到 spec。

示例：

```markdown
| 4.2 | Add tenant invite flow (spec: docs/spec/00-project-spec.md#tenant-rules) | invite API rejects cross-tenant roles in tests | 4.1 | cc:TODO |
```

spec 不替代 DoD。DoD 仍然说明任务如何被
判定为完成。 spec 说明实现必须保持一致的对象。

## Review Rule

reviewer 应把与 spec SSOT 的直接矛
盾视为重大问题。 如果 spec 缺失而任务又确实需
要它，那是规划缺口，而不是在实现过程中臆造行为的理由。
