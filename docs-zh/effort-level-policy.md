# Effort Level Policy

## 概述

定义 CC frontmatter 的 `effort` 字段与 Anthropic API 的 effort 参数的对应关系，
以及 Harness 中的采用策略。

## Opus 5 迁移笔记（2026-07-26 实测）

Opus 4.8 在 2026-07-25 的 operator 裁定（`feat(routing,breezing): retire Opus 4.8` commit `d5d1b28d`）中从 harness routing catalog 退役。brain tier 已全面迁移到 `claude-opus-5`。本文档中 Opus 4.8 特有的描述（thinking 默认 off、`xhigh` fallback 行为等）作为退役前确立的观测结果保留为历史记录。

在 `claude` CLI v2.1.220 中实测了 Opus 5 (`claude-opus-5`) 的 effort 行为（各命令仅执行 1 次，timeout 预计 120s）：

| 命令 | 实测结果 |
|---|---|
| `claude --model claude-opus-5 -p "reply exactly: OK"` | 完成约 3-4 分钟（exit 0）。标准输出仅为空行，指示的字符串 `OK` 未返回 |
| `claude --model claude-opus-5 --effort xhigh -p "reply exactly: OK"` | 完成约 10 分钟（exit 0）。标准输出不是 `OK`，而是涉及 repository 状态（skill mirror drift、`claude-opus-5` 追加任务、`bin/harness` shim 注意点）的上下文相关响应 |

两者都没有遵守指示的"仅返回 `OK`"。嵌套的 `claude` CLI 调用可能继承了用户级别的 memory / 项目上下文，但仅凭本次实测无法确定原因。`xhigh` 指定时响应时间延长约 3 倍（3-4 分钟 → 约 10 分钟）是观测到的事实，但这是否是 effort tier 本身的效果还是上下文量的差异导致的，未经实测（unknown）。关于是否存在降级等更深入的内部行为，超出本次实测范围，无法判定。

## CC Frontmatter 与 API Effort 的对应矩阵

CC v2.1.72 废弃了 `max`，v2.1.111 新增了 `xhigh`。

| CC frontmatter `effort` 值 | API effort 有效值 | Opus 4.8 中的行为 | 非 Opus 4.8 中的行为 |
|----------------------------|------------------|-------------------|---------------------|
| `low` | low | low（严格守范围、不深入挖掘） | low |
| `medium` | medium | medium | medium |
| `high` | high | high | high |
| `xhigh` | xhigh | xhigh（最高 effort tier） | `high` fallback（changelog 明记） |

**注记**：
- `xhigh` 是在 CC v2.1.111 中添加到 frontmatter 的（参见 `CLAUDE-feature-table.md`）
- `max` 已在 CC v2.1.72 中废弃。即使写在 frontmatter 中也无效
- 在 Opus 4.8 以外的模型（Sonnet 系等）中指定 `xhigh` 时，CC 会自动降级为 `high`

### Opus 4.8 的 thinking 模型（重要）

在 Opus 4.8 中 **thinking 默认 off**。仅在明确 `thinking: {type: "adaptive"}` 时 adaptive thinking 才工作，
由 effort 和 query 复杂度自动调整思考量。`budget_tokens` 方式的 extended thinking 已废弃。
CC frontmatter 的 `effort` 继续有效，在 Opus 4.8 中成为推理深度的**主要杠杆**（比过去任何 Opus 的 effort 影响都大）。

因此，Harness 在"想要深入思考"的场景中不使用 free-text marker（旧 `ultrathink`），
而是通过 `effort` tier 控制（`harness-work` 的 effort 评分也统一为 tier 选择方式）。

### 关于 xhigh 是否能通过 CC 传递给 API 的判定

**判定：采用（有证据表明接受 frontmatter 中的 xhigh）**

依据：
1. `docs/CLAUDE-feature-table.md` 的 v2.1.111 部分记录了 `xhigh effort` 为 `A: 明示追从对象`
2. 同文件的 Opus 4.7 部分也记录了 `xhigh effort` 为 `A: 明示追从对象`
3. `docs/cc-2.1.99-2.1.111-impact.md` 中记录了 v2.1.111 中 `xhigh` 的添加
4. Harness 的 `claude-5-prompt-standard.md` 中定义" `xhigh`": 调用方选择的推理强度"

在 frontmatter 中写 `xhigh` 时，CC 向 Opus 4.8 发送最高 effort tier 的请求。在非 Opus 4.8 模型（Sonnet 系等）中静默降级为 `high` 相当。不会变成 reject 或 error。

## Harness 的采用策略

| 流程 | 采用 effort | 理由 |
|--------|------------|------|
| Plan | `high` | 速度和整理力的平衡好 |
| Work（Worker agent） | `high` | 实现中长考不如反复确认重要 |
| Review（Reviewer agent、harness-review） | `xhigh` | 比较、反证、遗漏检测中 thinking 增加分效果显著 |
| Advisor | `xhigh` | 优先 PLAN / CORRECTION / STOP 的判断精度 |
| Release / Setup | `high` | 步骤遵守为中心，常时 `xhigh` 过度 |

### frontmatter 更新对象

| 文件 | 变更前 | 变更后 | 理由 |
|--------|--------|--------|------|
| `agents/reviewer.md` | `effort: medium` | `effort: xhigh` | Review 采用 xhigh |
| `agents/advisor.md` | `effort: high` | `effort: xhigh` | Advisor 采用 xhigh |
| `skills/harness-review/SKILL.md` | `effort: high` | 不变 | skill 的 effort 由调用方覆盖，因此维持 high |

## 运维规则

1. **review 和 advisory 优先作为 `xhigh` 的对象**
   理由：bug 检测和反证中，thinking 增加分的效果比实现本身更显著。

2. **work 维持默认 `high`**
   理由：实现中 token 消耗不如短周期验证有效。

3. **在 docs 中明确记载"Opus 4.8 以外为 `high` fallback"**
   理由：用户容易误解"写了 `xhigh` 却没效果"。

4. **不将所有 skill / 所有 agent 一律设为 `xhigh`**
   理由：成本和延迟无端增加。按角色区分使用。

5. **`${CLAUDE_EFFORT}` 仅作引用用**
   理由：Claude Code 2.1.120 及之后可从 skill 正文中引用当前 effort level。
   但这是调用方选择的 effort，供 skill 读取用的信息，不是 skill 侧擅自覆盖 effort 的机制。

### `${CLAUDE_EFFORT}` 指导

`CLAUDE_EFFORT` 是用于从 skill 正文中引用当前 session / invocation 中有效 effort level 的变量。

允许的示例：

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, report only confirmed blockers.
If effort is xhigh, include adversarial checks and edge cases.
```

避免的示例：

- 在 skill 正文中"一定要改为 xhigh"
- 将 `CLAUDE_EFFORT` 为空的环境视为失败
- 忽略 user / parent workflow 的 effort 指定

Harness 的策略：

- effort 的选择权留给调用方。
- skill 将 `CLAUDE_EFFORT` 仅用于说明、分支、输出粒度调整。
- 在 media / announcement 系等内部启动的 skill 中，优先明确化 effort 而非启动契约（`user-invocable` / `disable-model-invocation`）。

## 见外 rationale（不采用的项目）

以下不采用。记载不见外的理由。

| 项目 | 不采用理由 |
|------|-----------|
| 将 Worker agent 设为 `xhigh` | 实现循环中长考不如快速迭代重要。xhigh 的成本增量得不到相应的质量提升 |
| 将 Setup / Release skill 设为 `xhigh` | 以步骤遵守为中心，judgment 比 recall 重要的场景少 |
| `max` 的复活 | 已在 CC v2.1.72 中废弃。`xhigh` 是其后继 |

## 注意事项

- `xhigh` 不是"变聪明的魔法"，而是更深入思考的余地
- 在模糊的指示下，即使深入思考也会在错误方向上精密化
- 在 Opus 4.8 以外的模型中即使指定 `xhigh` 也会 fallback 为 `high`，可能达不到预期效果
- `claude-5-prompt-standard.md`"维持的纪律 5"：`xhigh` 是"调用方选择的推理强度"，不是 agent prompt 从 free-text marker 推测的东西

## 相关文件

- `docs/CLAUDE-feature-table.md` — v2.1.111 / Opus 4.7 的功能一览
- `docs/cc-2.1.99-2.1.111-impact.md` — xhigh 添加的详情
- `docs/claude-code-setup-mcp-telemetry-provider.md` — `${CLAUDE_EFFORT}` 和 setup 指导
- `.claude/rules/claude-5-prompt-standard.md` — xhigh 的运维 knob 定义
- `agents/reviewer.md` — Reviewer effort 设置
- `agents/advisor.md` — Advisor effort 设置
