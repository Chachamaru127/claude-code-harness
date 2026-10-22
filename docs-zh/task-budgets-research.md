# Task Budgets (Public Beta) 调查备忘录

Phase 44.10.1 创建日：2026-04-18

本文档整理了添加到 Anthropic API 的 **Task Budgets (public beta)** 的规格，
分析了与 Harness 现有控制机构的冲突关系后，
**记录本 Phase 不采用（延迟采用）的判断依据和将来采用判定时机**。

---

## 1. Task Budgets 的 API 规格摘要

> **注意**：以下是 2026-04-18 时点 public beta 规格的摘要。
> 正确的字段名・schema・错误码请参照官方 Anthropic 文档。
> 字段名等不确定的地方明确记载为 `(推定)`。

### 1-1. 概要

Task Budgets 是添加到 Anthropic API 的 Messages API 或 Agents API 的参数群，
声明性指定一次 agent 调用（或 task 单位）可消费的资源上限。

通过将 token 消费・成本作为事前约束传递，
实现在 API 层防止 agent 暴走・意外高额请求的目的。

### 1-2. 输入参数（推定）

因官方文档未确定的 beta 阶段，以下基于 Anthropic 的公开信息和已知类似功能推定。

| 参数名 | 类型 | 说明 |
|------------|-----|------|
| `max_input_tokens` (推定) | integer | 1 task 可消费的输入 token 上限 |
| `max_output_tokens` (推定) | integer | 1 task 可生成的输出 token 上限 |
| `max_cost_usd` (推定) | number | USD 换算的最大成本上限 |

这些参数预计在 API 请求的 `task_budget` 对象（推定）内指定。

```json
// 構造例（推定 — 実際の field 名は Anthropic docs を参照）
{
  "model": "claude-opus-4-7",
  "messages": [...],
  "task_budget": {
    "max_input_tokens": 100000,
    "max_output_tokens": 8000,
    "max_cost_usd": 2.00
  }
}
```

### 1-3. 输出・错误格式（推定）

超过上限时，预计返回与通常流式完成不同的 `budget_exhausted` 错误。

```json
// エラーレスポンス例（推定）
{
  "type": "error",
  "error": {
    "type": "budget_exhausted",
    "message": "Task budget exceeded: max_cost_usd limit reached",
    "exhausted_budget": "max_cost_usd"
  }
}
```

agent loop 组成的情况下，loop 侧需要将该错误作为
"因预算耗尽而提前结束"处理。

### 1-4. 现行状态

- **Public beta** — 仅限部分用户/API tier 限定公开
- GA（一般提供）时期未公布（2026-04-18 时点）
- schema 后向兼容不保证（beta 常）

---

## 2. Harness 现有机构との競合関係

Task Budgets 提供的"资源上限"功能与 Harness 已经用多个独自机构实现的概念重复。
以下表中整理冲突点。

| Harness 现有机构 | 场所 | 控制对象 | 与 Task Budgets 的重复度 |
|----------------|------|---------|----------------------|
| Advisor 商量次数上限（最多 3 次） | `agents/worker.md` 的 Advisor 商量判定 | Worker 调用 Advisor 的次数 | 低（用途不同） |
| `maxTurns` | `agents/worker.md` frontmatter（Worker: 100, Reviewer: 50） | agent 的回合数上限 | 中（间接限制 token 消费） |
| `effort` frontmatter | `agents/worker.md`、各 skill frontmatter | thinking 强度（low/medium/high） | 中（影响输出 token 消费） |
| `/cost` per-model breakdown | CC 内置（v2.1.92） | 成本可视化（事后确认） | 低（事后确认，不是事前约束） |
| `scripts/detect-review-plateau.sh` | `skills/harness-loop` Step 6 | review loop 的停滞检测 | 低（品质 gate。不是成本控制） |
| harness-loop `--max-cycles N` | `skills/harness-loop` | 循环周期数上限（默认 8） | 中（间接限制整个会话的消费） |
| Advisor `STOP` 判定 | `agents/worker.md`、`skills/harness-loop` Advisor Strategy | 危险 task 的人工 escalation | 低（品质 gate。不是成本控制） |

### 2-1. 重复度最高的点

**`maxTurns` vs `max_input_tokens` / `max_output_tokens`**：

- `maxTurns: 100` 限制 Worker 的回合数，间接抑制 token 消费
- `max_input_tokens` 更直接地限制 token 数
- 不过 `maxTurns` 是"循环控制"，`max_input_tokens` 是"成本控制"，主要目的不同

**`harness-loop --max-cycles` vs `max_cost_usd`**：

- `--max-cycles N` 用周期数间接控制长时间会话的成本
- `max_cost_usd` 用美元换算直接控制
- `--max-cycles 8`（默认）在实际成本不明的情况下限制，是粗糙的方法，`max_cost_usd` 更精密

### 2-2. 非竞争领域

以下是与 Harness 固有概念，无法被 Task Budgets 替代：

- `plateau 检测` — 品质 loop 的停滞（不是成本控制，是品质 gate）
- Advisor 商量次数上限 — 方针商量的次数控制（不是成本控制，是 governance）
- `effort` 级别 — thinking 品质的调整（不是成本削减，是品质/成本的 trade-off 调整）

---

## 3. 如果采用的话"哪个 skill 中""哪个粒度"

整理将来采用 Task Budgets 时的粒度和适用箇所候选。

### 3-1. Per-task budget（1 task 的 Worker spawn 上限）

| 项目 | 内容 |
|------|------|
| 适用箇所 | `agents/worker.md` 的 Agent 调用时 / `scripts/codex-companion.sh` 途经的 Codex spawn 时 |
| 粒度 | 在 sprint-contract 追加 `task_budget` 部分，按 task 指定上限 |
| 优点 | 可以防止单个重 task 吃尽预算 |
| 课题 | 需要 task 的适当 budget 估算。过小估算会导致中途切断 |
| 实现要点 | 在 `scripts/generate-sprint-contract.js` 追加 `task_budget` 部分生成逻辑 |

### 3-2. Per-session budget（1 breezing session 整体上限）

| 项目 | 内容 |
|------|------|
| 适用箇所 | `skills/harness-loop/SKILL.md` 的 loop 开始时，或 `skills/harness-work` 的 breezing 模式 |
| 粒度 | 给整个 session 设置 `max_cost_usd`，超过时停止 loop 并报告 |
| 优点 | 可以明确限定长时间会话的成本上限。比 `--max-cycles` 更精密 |
| 课题 | 需要在 session 途中 budget 耗尽时 graceful 处理逻辑 |
| 实现要点 | 在 `[Step 9] 下次 wake-up 预约` 之前追加检查残余 budget 的步骤 |

### 3-3. Per-day budget（用户单位的一天上限）

| 项目 | 内容 |
|------|------|
| 适用箇所 | 比 Harness 层更上位（Anthropic 仪表板的 API usage limits 或用户侧外部控制） |
| 粒度 | 一天累计成本超过阈值就 alert / 自动停止 |
| 优点 | 可以确实防止意外高额请求 |
| 课题 | Harness 侧实现困难（需要跨 session 的状态管理）。需要与 harness-mem 协作 |
| 实现要点 | 可以考虑利用 `harness_mem_record_checkpoint` 的日累计成本记录，和 `harness-loop` 启动时的检查 |

---

## 4. 本 Phase 不采用的决定 + rationale

**判断：Phase 44 中 Task Budgets 的实现延期。**

### 理由 1: Public beta 因此 API 稳定性不确定

Task Budgets 在 2026-04-18 时点是 public beta。
schema 后向兼容不保证，字段名和动作在 GA 前可能变更。
将 beta API 编入 Harness 的核心控制（sprint-contract 生成・harness-loop），
Anthropic 侧变更会直接导致 Harness 的破坏性变更。

### 理由 2: 现有的 `maxTurns` + `--max-cycles` + Advisor STOP 已覆盖 80%

| 想保护的风险 | 现有对应 |
|----------------|-----------|
| 单个 Worker 的暴走 | `maxTurns: 100` 切断 |
| 长时间会话的过度消费 | `--max-cycles 8`（默认）停止 |
| 品质 loop 的停滞 | `detect-review-plateau.sh` + `PIVOT_REQUIRED` |
| 高风险 task 的过度商量 | Advisor 商量上限最多 3 次 |

Task Budgets 提供的"美元换算直接控制"便利，
但与现有控制机构组合可以防止实质性的成本暴走。

### 理由 3: Phase 44 的优先级分配

Phase 44 的 scope 以以下为中心：

- Plugin agent exposure 的解消
- Phase 45 sync.go 修正
- PreCompact hook 实现
- Task Budgets 是**仅调查・文档整顿**（本任务）是 Phase 44 的目标

将 Phase 44 的剩余资源投入 Task Budgets 实现，
比完成上述确定 scope 优先级更低。

### 理由 4: harness-mem との統合设计未定

Per-day budget 这样的日累计管理与 `harness-mem` 的 checkpoint 功能协作是必要的。
不整理好集成设计就实现会成为技术负债。
要正确进行设计需要另外的调查任务，不包含在 Phase 44 scope 中。

---

## 5. 下次循环的采用判定时机

满足以下触发条件任一时重新评估。

| 触发器 | 详情 | 评估 Phase |
|---------|------|------------|
| Task Budgets 升级 GA | Anthropic 官方 announcement 时重新确认 schema，采用与否判断 | Phase 45 以降，GA 确认后 |
| 发生了无法防御的实际成本超支 | Harness 运营中在 `maxTurns` 上限到达前发生高额收费时 | 发生同时，紧急对应任务立 |
| harness-mem 的累计记录设计确定 | harness-mem 的日累计功能实现・稳定化时，per-day budget 的实现着手 | Phase 45 以降 |
| Anthropic 公开了 Harness 推荐的实现模式 | 官方文档或博客中公开了 Task Budgets + agent framework 的集成例时 | 确认后 1 Phase 以内 |

### 重新评估时的确认事项

重新评估时确认以下：

1. 字段名与本文档的推定一致吗（`max_input_tokens` 等）
2. `budget_exhausted` 错误的 graceful handling 能编入 sprint-contract loop 吗
3. 决定从 per-task / per-session / per-day 的 3 个粒度中哪个着手
4. `scripts/generate-sprint-contract.js` 追加 `task_budget` 部分在技术上可能吗

---

## 参照文件

- `agents/worker.md` — Advisor 商量上限・`maxTurns`・`effort` frontmatter
- `docs/CLAUDE-feature-table.md` — `task budgets` entry（行 210 附近，`A: 明示追从对象`）
- `skills/harness-loop/SKILL.md` — `--max-cycles`・plateau 检测・Advisor Strategy
- `.claude/rules/opus-4-7-prompt-audit.md` — 2.1.111 运用 knob 的定义
