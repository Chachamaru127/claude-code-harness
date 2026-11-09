# Model Routing Policy

状态：已采纳
最后更新：2026-09-05

本文档定义了 Harness 工作流中 Claude Code、Codex、Cursor 与 Grok 的默认模型与推理努力路由。

## 决策

使用显式角色层级，而非提示词文本推断。

Harness 必须根据工作流角色路由模型与 effort：

- `lite`：低成本、读密集、低风险工作
- `standard`：普通实现与设置
- `worker`：Breezing 实现与重试工作
- `deep`：架构、安全、跨仓库、迁移、失败恢复
- `review`：质量门禁与对抗性检查
- `release`：程序化发布与公共面检查
- `long-context`：大仓库或长会话上下文工作

不要从 "think harder" 等自由文本标记推断 effort。
调用者仍可请求一次性的深度推理，但持久化路由应放在配置、agent frontmatter 或包装器参数中。

## 官方证据

Claude Code 支持模型别名与显式模型 ID。
旧版 `opusplan` 别名在 plan 模式下用 Opus，在执行模式下用 Sonnet；
下方的 9 月路由显式选择 Fable 5.1。
Claude Code 设置可钉定 `model`、限制 `availableModels`、并通过 `ANTHROPIC_DEFAULT_*_MODEL` 环境变量设置默认别名目标。
官方文档：https://code.claude.com/docs/en/model-config

Claude Code effort 可通过 `/effort`、`/model`、`--effort`、
`CLAUDE_CODE_EFFORT_LEVEL`、`effortLevel`、skill/subagent frontmatter 配置。
Frontmatter 覆盖会话级别，而 `CLAUDE_CODE_EFFORT_LEVEL` 两者都覆盖。
官方文档：https://code.claude.com/docs/en/model-config

在验证过的 Claude Code 2.1.261 运行时上，已保存的
`modelSettings.<canonical-model-id>.effortLevel` 优于共享的
`effortLevel`；显式会话 `--effort` 两者都胜过。
`[1m]` 后缀不创建单独的保存 effort 键。
保留现有的按模型选择，而不是把共享设置报告为有效值。

Claude subagents 可将 `model` 设为别名、完整模型 ID 或 `inherit`。
自 Claude Code 2.1.251 起，解析顺序为：每次调用的 model、
frontmatter model、`CLAUDE_CODE_SUBAGENT_MODEL`、主会话 model。
显式 `inherit` 选择父模型。自 2.1.257 起，
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 恢复全局强制覆盖。
使用角色特定模型时保持该强制标志未设置。
现有的 Sonnet 默认在验证过的 2.1.261 运行时上不会压平角色。
官方文档：https://code.claude.com/docs/en/sub-agents#choose-a-model

2026 年 9 月的 Claude 路由器对深度规划与 advisor 默认使用 Fable 5.1，
worker 用 Sonnet 5，轻量阅读用 Haiku 4.5。
独立的原生安全 reviewer 仍为 Sonnet 5。
Fable 的标准 effort 为 `high`；基准测试结果不支持提升每个角色的 effort。
官方文档：
https://code.claude.com/docs/en/model-config 与
https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1

Codex 前沿角色使用 `gpt-6-astra`。
Harness 对轻量阅读保留 `gpt-5.6-luna`（low effort），对专用实现 worker 保留 `max`。
9 月刷新保留现有的 `xhigh` effort 用于通用的 `standard`、`deep`、`review` 与 `advisor` 角色，
而非从用户提示词推断新的 effort。
中央路由器是这些 companion 角色默认值的 SSOT；
managed worker 自定义 agent 是原生 worker-route SSOT。
官方文档：https://developers.openai.com/codex/models

Codex 配置支持 `model`、`review_model`、`model_reasoning_effort`，
以及 `agents.max_threads` / `agents.max_depth` 等 agent 并发设置。
自定义 Codex agents 可设置自己的 `model` 与 `model_reasoning_effort`。
Codex 0.153.4 接受角色文件中的 `sandbox_mode`，
但不将其投射到生成 agent 的权限中；原生子进程继承父进程的权限配置。
仅角色文件不构成文件系统隔离。
Harness 的 companion review 路径提供只读执行上下文。
下方的 managed worker 契约不声明 `sandbox_mode`。
官方文档：
https://developers.openai.com/codex/config-reference 与
https://developers.openai.com/codex/subagents
实现与权限继承测试：
https://github.com/openai/codex/blob/rust-v0.153.4/codex-rs/core/src/agent/role.rs 与
https://github.com/openai/codex/blob/rust-v0.153.4/codex-rs/core/src/agent/role_tests.rs

Cursor subagents 支持 frontmatter `model: inherit|<model-id>`、`readonly`
与后台执行。Task 工具接受显式 `model` 参数。
Cursor CLI 支持 `--model` 用于每次运行选择。
Cloud Agent API 接受 `model.id` 与 `model.params`。
官方文档：
https://cursor.com/docs/subagents 、
https://cursor.com/docs/cli/overview 、
https://cursor.com/docs/cloud-agent/api/endpoints

## 覆盖优先级（所有宿主）

1. **显式调用者覆盖** — Task/subagent `model`、CLI `--model`、或
   wrapper 文档化时的 companion `--model`。
2. **Harness 路由默认** — `scripts/model-routing.sh --host <host> --role …`
3. **会话继承** — subagent `model: inherit` 或宿主会话默认。

残留风险：team/admin/plan-unavailable 模型可能静默回退，
除非 smoke 或 operator 检查捕获它们。
不要把某账号的可用性视为对每个 Harness 用户的保证。

## Claude Code Routing

| Harness 层级 | Claude 模型 | Effort | 使用场景 |
| --- | --- | --- | --- |
| `lite` | `claude-haiku-4-5` 或 `haiku` | `low` 或 `medium` | 只读搜索、文档清理、简单摘要、廉价旁路研究 |
| `standard` | `claude-sonnet-5` | 默认 `medium`，代码风险任务用 `high` | 普通 worker 实现、设置、测试、范围限定重构 |
| `deep` | `claude-fable-5-1` | `high` | 架构、迁移、跨仓库决策、重复失败 |
| `review` | `claude-fable-5-1` | `high` | 路由的独立 review；原生安全 reviewer 仍为 Sonnet 5 |
| `advisor` | `claude-fable-5-1` | `high` | 阻塞执行后的 PLAN / CORRECTION / STOP 决策 |
| `release` | `claude-sonnet-5` | `high` | release preflight、changelog、版本/标签/GitHub Release 检查 |
| `long-context` | `sonnet[1m]` | `high` | 大仓库阅读、长会话、上下文密集型比较 |

推荐的 Claude 会话默认：

```json
{
  "model": "claude-fable-5-1",
  "availableModels": [
    "opusplan",
    "claude-opus-5",
    "claude-fable-5-1",
    "claude-sonnet-5",
    "claude-haiku-4-5",
    "sonnet[1m]"
  ],
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5"
  }
}
```

说明：

- Fable 5.1/high 是此次刷新的操作员基线。现有的会话上下文窗口与 effort 选择保持显式；此示例不是覆盖用户设置的指令。`opusplan` 仍为可选的操作员选择。
- 配置的 `CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-5` 在 Claude Code 2.1.251+ 上与角色特定模型兼容。保持单独的 `_FORCE` 标志未设置。旧版本有不同的优先级，需要验证。
- 不要在共享设置中设置 `max`。`max` 仅限会话，应仅用于显式的一次性实验。
- `ultrathink` 是旧式自由文本标记。不要用于持久化路由。
  在 Claude 5 系列上，用 `effort`（`high`/`xhigh`）控制推理深度，而非提示标记。如果硬任务上的推理看起来浅，提升 effort 而非绕过提示。
- 未设置、空值、或 `HARNESS_BRAIN_MODEL=fable` 对 `deep`/`advisor` 用 Fable 5.1/high。显式 `opus` 或 `opus5` 用 Opus 5/xhigh。未知值退出码 2。
  仅限 Claude 宿主，永不改变 `standard`/`review` 层级。

## Codex Routing

| Harness 层级 | Codex 模型 | 推理 effort | 使用场景 |
| --- | --- | --- | --- |
| `lite` | `gpt-5.6-luna` | `low` | explorer subagents、简单文档、小清理、廉价并行扇出 |
| `standard` | `gpt-6-astra` | `xhigh` | 通用实现与设置 |
| `worker` | `gpt-5.6-luna` | `max` | Breezing 实现、重试、聚焦重构 |
| `deep` | `gpt-6-astra` | `xhigh` | 跨文件架构、安全、迁移、失败循环恢复 |
| `review` | 通过 `review_model` 用 `gpt-6-astra` | `xhigh` | `/review`、companion review、对抗性 diff review |
| `advisor` | `gpt-6-astra` | `xhigh` | 阻塞循环的 PLAN / CORRECTION / STOP 决策 |
| `release` | `gpt-6-astra` | `high` | release-preflight 与 PR 收尾证据 |
| `spark` | `gpt-5.3-codex-spark` | `low` | 可选 Pro 实时 UI 微迭代；从不强制 |

新配置会话的 Codex 基线示例：

```toml
model = "gpt-6-astra"
model_reasoning_effort = "medium"
review_model = "gpt-6-astra"

[agents]
max_threads = 8
max_depth = 1
```

保留现有的有效交互式 effort；此示例不是改变 low、high、ultra 的迁移。
此基线不是原生 Breezing worker 定义。
`breezing --codex` 使用来自 `scripts/model-routing.sh` 的单独显式 `worker` 路由，而非继承会话基线。

操作员可在工作进行中更改模型或 effort。保留该实时选择，而非恢复审计快照。CCH 的角色表是其自有调度路径的默认值，不是对交互式设置或显式 `--model`/`--effort` 请求的锁定。仅更改父会话不会重新调整所有单独配置的子角色。自动化环境更新仅修改其声明的 CCH 键并保留无关的当前值；受控键上的冲突必须报告而非覆盖。

推荐的项目级 Codex 自定义 agents：

下方示例展示配置字段。对于 CCH-managed worker 与 reviewer 角色，安装由 `hosts.toml` 生成的完整档案；它们的 task、evidence、authority 指令是角色契约的一部分。Prompt 校准与交付面见 [prompt-calibration.md](prompt-calibration.md)。

```toml
# .codex/agents/explorer.toml
name = "explorer"
description = "Read-only codebase exploration and evidence gathering."
model = "gpt-5.6-luna"
model_reasoning_effort = "low"
sandbox_mode = "read-only"
developer_instructions = "Inspect files and return concise evidence with paths. Do not edit files."
```

```toml
# .codex/agents/worker.toml
name = "worker"
description = "Scoped implementation worker for a single task."
model = "gpt-5.6-luna"
model_reasoning_effort = "max"
developer_instructions = "Complete the assigned outcome within owned files and approval. Read the contract, recover missing context, honor required checks, and report changed files, observed results, and remaining gaps."
```

Codex-native Breezing 通过 `agent_type: worker` 选择此 managed custom agent。
上述必需的 custom-agent 字段拥有 worker 的模型、推理 effort 与指令；sandbox 与权限仍由执行路径拥有。原生 Breezing 不通过 `spawn_agent` 直接传递模型或推理字段。有界的 `fork_turns: "3"` fork 可保留为执行限制。不要配置 `[agents].default_subagent_*`：那些全局默认会重新调谐每个原生 subagent，包括 reviewer 与 advisor 角色。

此 custom agent 仅在 setup 将其复制到用户 `$CODEX_HOME/agents/worker.toml` 或项目 `.codex/agents/worker.toml` 路径后激活。
Codex 0.148 插件清单无法注册原生 agent 角色；插件安装、缓存、或分发包含本身不激活此 agent。
官方 Subagents 配置：
https://developers.openai.com/codex/subagents

```toml
# .codex/agents/reviewer.toml
name = "reviewer"
description = "Read-only reviewer for diffs, risk, and missing tests."
model = "gpt-6-astra"
model_reasoning_effort = "xhigh"
sandbox_mode = "read-only"
developer_instructions = "Review the actual artifact against the contract in a fresh context. Report actionable findings with file and line references and observed evidence using the requested schema. Do not edit files or invent requirements."
```

说明：

- 内联的 `[agents.reviewer]` 声明优先于同一配置层中自动发现的 `agents/reviewer.toml`。Setup 通过 `config_file = "agents/reviewer.toml"` 绑定 managed 文件；显式 custom 绑定仍归操作员所有。原生 loader 回读必须显示预期的角色模型与 effort，而不仅仅是 TOML 文件的存在。见
  https://github.com/openai/codex/blob/rust-v0.153.4/codex-rs/agent-roles/src/loader.rs
- reviewer 文件的 `sandbox_mode` 声明在 Codex 0.153.4 中不强制单独的只读文件系统边界。当 review 契约要求该边界时，使用 companion review 执行路径。
- Codex CLI `codex exec` 用 `--model` / `-m` 做每次运行的模型选择，
  用 `-c model_reasoning_effort="<level>"` 做每次运行的 effort 覆盖。
- 官方 Codex companion 1.0.6 拒绝 `--effort max` 与 `--effort ultra`。对于单独的 `breezing --codex` companion 路径，Harness 解析中央 `worker` 路由并将 `max` 或 `ultra` 规范化为 Codex 运行时配置（`-c model_reasoning_effort="max"`），同时保留路由的模型与写入/sandbox 意图。其他显式 effort 请求可停留在 companion 路径上。
- 任何直接 `codex exec` 路径必须将 Harness 级 `--effort` 转译为 `-c model_reasoning_effort=...`，而非静默丢弃。
- `agents.max_depth` 保持 `1`。递归扇出增加 token 使用并使结果更不可预测。
- `agents.max_threads = 8` 对 Harness breezing 可接受，因为 lite 路由将廉价探索发给 `gpt-5.6-luna`（low effort）；若所有子进程都用 `gpt-6-astra xhigh`，先降低并发。
- 不要把 Codex fast mode 设为默认。它是延迟/积分的权衡，不是智能层级。

### 显式设置与长运行会话

对于路由任务，显式 model/effort 参数胜出。支持的 `-c model=...` 与 `-c model_reasoning_effort=...` 形式会与对应标记归一化。显式 `CODEX_EFFORT` 胜过角色默认。无效或歧义的配置覆盖在调度前被拒绝。除模型与 effort 外，仅支持 task `model_verbosity=low|medium|high`；provider、MCP、权限、批准及其他配置键不由此 adapter 转发。基于提示的复杂度不能替代已解析的角色 effort。旧版计算器仅在显式禁用模型路由时相关。

Task 参数归一化也修正了主环境防卫与执行所用的工作目录与写入意图。等效写入标记规范化；歧义的重复工作目录或 sandbox 选项被拒绝。相对提示文件相对于选定的工作目录解析，`--` 之后的参数为提示文本。运行时选项使用 Codex 执行而不被重新解释为 companion 提示文本。未知运行时选项与新的 provider/profile/rule-override 入口点在调度前被拒绝。`--add-dir` 仅接受只读任务。将其与写入意图结合会被拒绝，因为防卫只检查一个目标工作目录，不授权额外的可写根目录。

原生 `codex-loop` 本地驱动继承交互式 Codex 配置。companion 驱动使用 task 角色。它们是刻意分离的策略：配置为 Astra/low 或 Astra/ultra 的会话，不是每个 Breezing worker 都使用该组合的证据。检查选定的驱动与角色。

Advisor 选择保留显式项目配置。每次运行的 `CODEX_ADVISOR_MODEL=gpt-6-astra` 可在不重写受保护项目设置的情况下选择 Astra；咨询命令上的 `--model` 优先。缺失项目选择回退到中央 advisor 路由。

通用的 `task` 路径以前允许提示评分降低已配置的角色 effort。遵守现有的 `standard/xhigh` 路由因此可能增加那些调用的有效 effort，包括 companion loop 驱动。这是角色传播的修正，不是对交互式用户设置的编辑。当预期的权衡是有界任务的较低显式 effort 时，选择它。

Codex 0.153.4 在验证过的宿主上宣传 Astra `ultra` 为自动委托的最大推理。其公开模型 API 文档仅通过 `max` 记录 effort；绝不向该 API 发送 Codex 特有值。官方 companion 无法用扩展 effort 表达每个有状态模式；拒绝不支持的 background/resume/fresh 组合，而非静默改变 effort。

可选的 `features.context_management.experimental_mode` 设置在受支持的 Codex 会话中启用实验性历史/笔记管理。本地 CLI 接受嵌套设置；此次刷新不启用实验特性或推断账号的 plan 资格。它补充而非替代 Harness task ledger 与跨会话记忆。

### Routed review transport (D70)

Codex `review` 与 `adversarial-review` 路由使用每次运行全新的本地 `scripts/codex-review-app-server-proxy.mjs`。proxy 启动 `codex app-server --stdio` 并为该运行注入有效的 `model`、`review_model` 与 `model_reasoning_effort` 值。官方 Codex companion 仍为协议端点：Harness 通过 `CODEX_COMPANION_APP_SERVER_ENDPOINT` 传递 proxy 端点，并保留官方 companion 的请求/结果信封，而非发明第二个 review 协议。

Review `--commit` 在 provider 调度前被拒绝，因为官方 companion 的 `--base` 选项不是语义化的 commit 目标。路由的 review 仅在 companion 与 proxy 都成功完成后写入编排 ledger；被拒调用与失败传输不计为成功委托。收到 `TERM` 或 `INT` 时，wrapper 并发向 companion 与 app-server proxy 转发信号，最多等待一秒，再向幸存者发送 `KILL` 并回收。proxy 对其 `codex app-server` 子进程应用相同的 fail-closed 子进程生命周期。

POSIX 路径使用 Unix socket。Windows 命名管道路径仅在本仓库的 fixture/静态检查中覆盖；未观测到实时 Windows provider 或 app-server 运行。

## Cursor Routing (adapter candidate)

| Harness 层级 | Cursor 模型（路由器默认） | Effort 标签 | 使用场景 |
| --- | --- | --- | --- |
| `lite` | `composer-2-fast` | `low` | 只读探索、廉价扇出 |
| `standard` | `composer-2.5-fast` | `medium` | 普通 worker 实现 |
| `deep` | `claude-fable-5` | `xhigh` | 架构、安全、恢复 |
| `review` | `composer-2.5-fast` | `xhigh` | harness-review / reviewer subagent |
| `advisor` | `claude-fable-5` | `xhigh` | advisor-request 决策 |
| `release` | `composer-2.5-fast` | `high` | release preflight 措辞检查 |
| `long-context` | `gemini-3.1-pro` | `high` | 有可用时的大仓库读取 |

Adapter 面：

- `.cursor/agents/*.md` frontmatter `model`
- Task tool 显式 `model`
- Cursor CLI `--model`
- Cloud Agent API `model.id` / `model.params`（可选证据）

说明：

- Cursor 仍为 `candidate`；路由默认值是契约固定值，非支持声称。
- Breezing 多任务/后台 agents 可能扇出 Workers；Reviewer 与 cherry-pick 在核心保持串行。
- 当 Task/subagent 调用上设置显式 `model` 时，路由默认值不得覆盖（`tests/test-model-routing.sh` 覆盖 Codex 显式路径；Cursor 用相同优先级规则）。
- `review` 层级（`composer-2.5-fast`、`xhigh`）是全新上下文的 pre-review 面：
  一个不与生产 worker 共享会话状态的 reviewer session 可在脑主 review 前 pre-review 一个 diff。生产 diff 的 session 永不 review 自己的输出，主裁决留在脑（spec.md Execution Backend Contract）。

## Grok Routing (adapter candidate)

| Harness 层级 | Grok 模型（路由器默认） | Effort 标签 | 使用场景 |
| --- | --- | --- | --- |
| `lite` | `grok-4.5` | `low` | 只读探索、廉价扇出 |
| `standard` | `grok-4.5` | `medium` | 普通 worker 实现 |
| `deep` | `grok-4.6` | `xhigh` | 架构、安全、恢复（`xhigh` 是 grok-4.6 的默认 effort） |
| `review` | `grok-4.6` | `xhigh` | harness-review / reviewer 路径 |
| `advisor` | `grok-4.6` | `xhigh` | advisor-request 决策 |
| `release` | `grok-4.6` | `high` | release preflight 措辞检查 |
| `long-context` | `grok-4.6` | `high` | 大仓库读取（500k ctx） |

Adapter 面：

- Grok CLI `--model`
- `scripts/model-routing.sh --host grok --format json|args|env`
- Skill frontmatter `model`（当 skill 钉定模型时；优先路由默认）

说明：

- Grok 仍为 `candidate`；路由默认值是契约固定值，非公开支持声称。
- 验证过的目录（2026-08-13，实际安装的 `grok 0.2.118` 取得的账号目录）：**仅有 `grok-4.6`**（默认/frontier/500k ctx/effort `xhigh`\|`high`\|`medium`\|`low`）与 **`grok-4.5`**（500k ctx/effort `high`\|`medium`\|`low`） **两个**。
- **订正 (2026-08-13)**：2026-08-12 记录的 `grok-4.3` / `grok-4.20-*` / `grok-3-mini` 是 **同名的另一产品** `grok-cli`（TypeScript）的目录。与更早的 `grok-composer-2.5-fast` 一样，它们是实 CLI 不存在的 ID，调用时必然失败。具有讽刺意味的是，再之前的 `grok-4.5` 的确存在 — 当时注释 "observed on CLI 0.2.93" = 实二进制观测。**capability 与目录都要用实际跑得动的 binary 验证**（CLAUDE.md FACT-4）。
- 账号目录可能不同；把缺失模型视为残留风险，而非路由器的静默回退。
- `HARNESS_BRAIN_MODEL` 仅限 claude-host，从不改变 Grok 目录。

## Harness Role Defaults

| Harness 面 | Claude 默认 | Codex 默认 | Cursor 默认 | Grok 默认 | 理由 |
| --- | --- | --- | --- | --- | --- |
| 交互式操作员会话 | Fable 5.1；保留用户保存的 effort | `gpt-6-astra`；保留用户保存的 effort | `composer-2.5-fast`、`medium` | `grok-4.5`、`low` | 宿主会话设置独立于委托角色默认 |
| `/harness-plan` deep 角色 | Fable 5.1、`high` | `gpt-6-astra`、`xhigh` | `claude-fable-5`、`xhigh` | `grok-4.6`、`xhigh` | 规划质量影响所有下游工作 |
| `worker` | Sonnet 5、`medium` 到 `high` | `gpt-5.6-luna`、`max` | `composer-2.5-fast`、`medium` | `grok-4.5`、`medium` | 实现受益于迭代与测试 |
| `explorer` / 只读扇出 | Haiku 4.5、`low` | `gpt-5.6-luna`、`low` | `composer-2-fast`、`low` | `grok-4.5`、`low` | 廉价上下文隔离 |
| `reviewer` 路由 | Fable 5.1、`high`；隔离的原生 `agents/reviewer.md` 仍为 Sonnet 5 | `gpt-6-astra`、`xhigh` | `composer-2.5-fast`、`xhigh`（仅全新上下文 pre-review；主裁决在脑） | `grok-4.6`、`xhigh` | 将路由 review 角色与安全隔离例外分离 |
| `advisor` | Fable 5.1、`high`；显式 `HARNESS_BRAIN_MODEL=opus` 仍为 Opus 5/xhigh | `gpt-6-astra`、`xhigh` | `claude-fable-5`、`xhigh` | `grok-4.6`、`xhigh` | 阻塞循环决策需要独立证据 |
| `release` | Sonnet 5、`high` | `gpt-6-astra`、`high` | `composer-2.5-fast`、`high` | `grok-4.6`、`high` | 程序化但面向公众 |

## Non-Goals

- 不自动更新全局用户配置。
- 不强制每个 subagent 用最贵的模型。
- 不用模糊提示词路由。
- 不用模型路由绕过 sandbox、批准或 review 门禁。
- 不把某账号类型的模型可用性视为对每个 Harness 用户的保证。

## Implementation Surface

Harness 通过 `scripts/model-routing.sh` 实现路由契约。路由器映射：

```text
tier -> claude model/effort
tier -> codex --model / -c model_reasoning_effort
tier -> cursor model (+ effort label for docs/tests)
role -> tier
```

Codex-native Breezing 选择带 `agent_type: worker` 的 managed `.codex/agents/worker.toml`；模型与推理来自该 custom agent，而非 skill 直接传递。有界的 `fork_turns: "3"` fork 可保留。保持 `[agents].default_subagent_*` 未设置，使 reviewer 与 advisor 路由不被全局重新调谐。单独的 `breezing --codex` companion 路径解析中央 `worker` 路由并通过原始 `codex exec` 配置规范化 `max`。skill 不得成为第二个模型目录；companion-route ID 留在此策略与 `scripts/model-routing.sh`，而原生 worker model/effort 故意留在 managed `.codex/agents/worker.toml`。

路由器应独立于当前用户级 `~/.codex/config.toml` 或 `~/.claude/settings.json` 测试，因为那些文件是操作员偏好，不是仓库真理。

`scripts/codex-companion.sh` 对 `task` 调用使用 Codex 路由，并在使用结构化 `codex exec` 模式时将 companion 级 `--effort` 转译为 Codex CLI `-c model_reasoning_effort=...`。