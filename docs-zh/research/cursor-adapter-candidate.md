# Cursor Adapter 候选证据边界

> **晋升说明 (2026-07-19):** Cursor 于 2026-07-19 晋升为 `supported`
> (2026-07-17 实时 H4 工作流冒烟测试 + H7 release-preflight fail-closed 门)。
> 下面的层级表述为历史证据；公开表面现固定为 `supported`，并附有 harness 侧 containment
> (`docs/CURSOR_INTEGRATION.md`)。

状态：internal-compatible 证据边界
检查时间：2026-05-28 JST
Phase: `Plans.md` 81.1

## 结论

Cursor 仍为 `internal-compatible`。

Harness 现已有 Cursor adapter 骨架 (`.cursor-plugin/`、`.cursor/AGENTS.md`、
`.cursor/agents/`、hooks/MCP 配置形态) 和静态冒烟测试，但尚无验证性的工作流冒烟测试
来证明仅从 Cursor 即可完成 Plan → Work → Review。已有的
`docs/CURSOR_INTEGRATION.md` PM 交接路径与 adapter 支持无关。

## 证据边界

`not_observed != absent`：缺少 Cursor 运行时冒烟测试并不能证明 Cursor
无法支持 Harness。这只能证明 Harness 尚不能声称支持。

在以下条件满足前，不要将 Cursor 晋升超过 `internal-compatible` 层级：

- 主机特定 bootstrap 冒烟测试通过，
- release preflight 消耗 adapter 路由，
- README/onboarding 措辞仍区分 handoff 集成与 adapter 支持。

## 观测到的运行时证据 (2026-05-29)

本地 Desktop 观测（operator 本地，非 CI 门控）：

| 观测项 | 证据 | 限制 |
|---|---|---|
| 真实目录安装后本地插件加载 | Cursor Plugins 日志不再显示 `loadUserLocalPlugin ... rejected: symlink target ... is outside ...` | Cursor 拒绝符号链接安装 |
| Skill 菜单可见性 | Operator 确认 `/breezing` 等工作流 skill 在 Reload Window 后出现 | 仅单会话手动证明 |
| Frontmatter 规范化 | `scripts/build-host-plugin-dist.sh` 将 `user-invocable: true` 重写为 Cursor 包的 `false` | Claude dist 中保留 Claude Code slash 契约 |

修复前的失败（指导分发阶段）：

- `~/.cursor/plugins/local/claude-code-harness` 的符号链接安装 → **被拒绝**
  (目标在 `~/.cursor/plugins/local` 之外)
- 带 `user-invocable: true` 的原始 repo skills → **被 Cursor 丢弃** (skill
  在 `/` 菜单中不可见)

已应用修复：

```bash
bash scripts/setup-cursor.sh --check   # build + validate only
bash scripts/setup-cursor.sh           # real copy to ~/.cursor/plugins/local/
```

## Harness 证据（本仓库）

| 产物 | 证明内容 | 未证明内容 |
|---|---|---|
| `docs/CURSOR_INTEGRATION.md` | Cursor PM ↔ Claude Code Harness handoff 工作流 | Cursor adapter 支持 |
| `.cursor-plugin/plugin.json` | 插件 manifest 指向核心 `skills/` | marketplace 安装或运行时 skill 加载 |
| `.cursor/AGENTS.md` | Plan/work/review 的 bootstrap 路由指导 | 自动运行时路由 |
| `.cursor/agents/*.md` | Worker/Reviewer/Advisor adapter 角色 subagent 形态 | 与 Claude Agent Teams 的团队执行 parity |
| `.cursor/hooks.json` | 可选会话 hooks 的配置形态 | 与 Claude Code 的 hook 执行 parity |
| `.cursor/mcp.json` | MCP 配置形态占位符 | MCP 信任或运行时布线 |
| `tests/test-cursor-adapter-candidate.sh` | 静态 adapter 契约 + 可选 CLI 冒烟 | 完整 Breezing 多任务证明 |
| `scripts/model-routing.sh --host cursor` | 角色层级 → Cursor 模型映射契约 | 账户特定模型可用性 |

Superpowers 参考形态（外部，非 Harness 证明）：

- `.cursor-plugin/plugin.json` 可引用其他仓库的 `skills`、`agents`、`commands` 和
  `hooks`。
- 该形态启发了 Harness 骨架，但本身不提升 Harness 支持层级。

## 官方 Cursor 表面（2026-05-28 观测）

已检查来源：

- https://cursor.com/docs/context/rules — 项目规则 (`.cursor/rules`、`AGENTS.md`)
- https://cursor.com/docs/context/skills — Agent Skills 发现和调用
- https://cursor.com/docs/context/subagents — subagent frontmatter (`model`、`readonly`、background)
- https://cursor.com/docs/agent/hooks — 生命周期 hooks (session/tool 事件)
- https://cursor.com/docs/context/mcp — MCP server 配置
- https://cursor.com/docs/cloud-agent/api — Cloud Agent API (`mode`、`model.id`、`model.params`)
- https://cursor.com/docs/cli/overview — 带 `--model` 和 mode 标志的 CLI agent

观测到的 adapter 相关机制：

| 表面 | Harness 映射 | 备注 |
|---|---|---|
| Rules / `AGENTS.md` | Bootstrap 通知 + prompt 路由 | 与 Codex `AGENTS.md` 概念相同，执行不同 |
| Skills | 通过插件 `skills/` 路径的核心工作流 skills | Skill tool / `$skill` 风格调用因 host 而异 |
| Subagents | Worker / Reviewer / Advisor adapter 角色 | `model: inherit` 或显式模型 slug；`readonly` 用于 review |
| Task / background agents | 仅 Breezing 并行 worker 冒烟目标 | Core 保持 review + cherry-pick 串行 |
| Hooks | 可选 sessionStart / preflight gate | 静态冒烟中仅进行无密钥的配置形态验证 |
| MCP | 可选 harness-mem / tool bridge | 信任策略适用；冒烟中无密钥读取 |
| Cloud Agent API | 可选付费/认证证据 | 不需要本地 Desktop/CLI 静态门控 |
| CLI `--model` | 显式覆盖表面 | 调用方设置时优先于路由默认值 |

本仓库冒烟中未观测到 (2026-05-28)：

- 此 manifest 的 Cursor Desktop 插件 marketplace 安装 transcript
- 带认证的 Cloud Agent API 工作流冒烟
- 完整 Breezing cherry-pick 循环的多任务证明
- Hook 运行时块 parity 与 Claude PreToolUse
  (2026-06-12 已取代 — 见下方"Hook 运行时 deny parity — 已验证")

## 分离：PM Handoff vs Adapter 支持

| 关注点 | PM handoff (`CURSOR_INTEGRATION.md`) | Adapter 候选 (本文) |
|---|---|---|
| 主要用户 | Cursor 规划/评审，Claude 实现 | Operator 留在 Cursor 中完成 Plan → Work → Review |
| Bootstrap | 共享 `Plans.md` + Cursor 命令模板 | `.cursor-plugin/` + `.cursor/AGENTS.md` + skills/agents |
| 并行性 | 超出范围 | 映射到 subagents / background agents / multitask (冒烟目标) |
| 支持声明 | 从不暗示 Cursor adapter 支持 | 在冒烟 + preflight 通过前保持 `internal-compatible` |
| 验证 | Branch + marker sanity | `bash tests/test-cursor-adapter-candidate.sh` |

## cursor-agent CLI 事实核查（本地，无网络）

对 `~/.local/bin/cursor-agent`
(version `2026.05.28-a70ca7c`) 的 `cursor-agent` CLI 进行本地检查。从 `cursor-agent --help`
和模型路由契约确认事实；此处无内容针对 Cursor
云运行，因此模型调用行为保持 `⏳ needs-network`。

| 声明 | 状态 | 来源 |
|---|---|---|
| `cursor-agent` 二进制文件位于 `~/.local/bin/cursor-agent` | ✅ 已确认-本地 | `command -v cursor-agent` |
| 版本为 `2026.05.28-a70ca7c` | ✅ 已确认-本地 | `cursor-agent --version` |
| 标志 `-p/--print`、`--output-format text\|json\|stream-json`、`--model` 存在 | ✅ 已确认-本地 | `cursor-agent --help` |
| 标志 `-f/--force`、`--yolo`、`--mode plan\|ask`、`--resume`、`--continue` 存在 | ✅ 已确认-本地 | `cursor-agent --help` |
| 标志 `--list-models`、`--sandbox enabled\|disabled`、`--trust`、`--workspace`、`-w/--worktree` 存在 | ✅ 已确认-本地 | `cursor-agent --help` |
| 通过 `--api-key` / `CURSOR_API_KEY` 认证；通过 `-H/--header` 的 headers；`--approve-mcps`、`--plugin-dir` 存在 | ✅ 已确认-本地 | `cursor-agent --help` |
| macOS 无 `timeout` / `gtimeout` (探测包装器不能依赖它们) | ✅ 已确认-本地 | 本地 shell 环境 |
| 模型路由器暴露 cursor 层级 `composer-2.5-fast` 和 `composer-2-fast` 但**无裸 `composer-2.5` slug** | ✅ 已确认-本地 | `scripts/model-routing.sh --host cursor` |
| `composer-2.5` / `composer-2.5-fast` 实际可端到端调用 | ⏳ needs-network | 需要实时 `cursor-agent` 模型调用 |
| `.result` JSON schema (`--output-format json` 的形态) | ⏳ needs-network | 需要实时模型运行 |
| 是否暴露 chat-completions 风格 API | ⏳ needs-network | 见 Route B 说明 — 不可证伪的负面，未被依赖 |
| 模型调用的延迟数字 | ⏳ needs-network | 需要计时的实时运行 |
| Cursor 云出口主机名 | ⏳ needs-network | 需要观察实时运行的网络流量 |

### Route B：超出验证范围

Route B（包装 `cursor-agent` 的本地 OpenAI 兼容桥接）超出
验证范围，因为双重 agent 问题：`cursor-agent` 本身就是
一个完整的 agent，因此 host 的 tool-calling 协议无法穿透它。只有
最终的 `.result` 文本返回，这实际上会终止 host agent 循环。
因此验证 Route B 不会证明任何 Route A 尚未证明的内容。

保持 `not_observed != absent` 纪律：未观察到 chat-completions API
这一事实是不可证伪的负面，**不被**用作证明。没有声明声称"无 chat-completions API"已被证明。

此事实核查仅检查本地 CLI。它**不**将 Cursor 晋升超过 `internal-compatible` 层级，
也不添加任何支持声明；结论和证据边界部分中的 `internal-compatible` 边界不变。

## cursor-agent CLI 网络冒烟 (2026-05-29 验证)

在一次性 `mktemp -d` 目录中使用 `--mode ask`（只读）、无 `--force`/`--yolo`，
以及 cursor-agent 自己的 `--sandbox enabled` 执行的受限 Route A go/no-go 运行。
此次运行禁用了 Claude Code Bash 沙箱，因为 cursor-agent 访问 Cursor
云主机超出沙箱允许列表（沙箱下调用挂在被阻止的出口上 — 确认网络
依赖）。此次运行未改变支持层级；Cursor 保持 `internal-compatible`。

| 观测项 | 结果 |
| --- | --- |
| 可用模型 slug (`--list-models`) | `composer-2.5` (当前) 和 `composer-2.5-fast` (默认) 均存在 ✅ |
| Route A go/no-go (`-p --output-format json --model composer-2.5 --mode ask "Reply with PONG"`) | `is_error:false`、`result:"PONG"` ✅ |
| 成功 JSON 顶级键 | `type, subtype, is_error, duration_ms, duration_api_ms, result, session_id, request_id, usage` (最初文档化的 `{type,is_error,result,session_id,usage}` 的超集) |
| 延迟 | API `duration_ms` ≈ 9.85s；wall `real` ≈ 17.4s (含 CLI 启动)；`inputTokens` ≈ 每次调用 69k |
| **错误形态（错误模型名）** | 退出 `1`，**stdout 无 JSON** — 错误文本发往 stderr (`Cannot use this model: ...`)。Route A 包装器必须检查退出码，而不仅是解析 `.result`（裸 `jq -r .result` 在错误时打印 nothing/`null`）。 |
| 出口目的地 | `52.6.48.235:443`、`54.82.32.244:443` (AWS us-east-1 范围，无 PTR 记录)。进程所有者为 `node` (cursor-agent 是 Node 应用)。TLS SNI 主机名本地未捕获；解析允许列表主机名是 Phase 83 (分发) 的后续事项。 |

裁决：**Route A 已验证 (go)**。Route B 保持超出范围（上述双重 agent
问题）。分发给消费者超出本阶段范围，由 Phase 83 前置条件
(手动沙箱允许列表配方、cursor-agent 治理规则、支持层级晋升) 门控。

### 写能力 spike (Phase 83.3a, 2026-05-29)

"brain Opus / body composer" 执行后端的成败检查：能否
`cursor-agent --force` 在其自身沙箱保持启用的情况下写入文件 (Codex
`workspace-write` 等效)，还是需要 `--sandbox disabled`？

| cursor-agent sandbox | `--force` 在一次性 workspace 中写入 `foo.txt` | is_error | wall |
| --- | --- | --- | --- |
| `--sandbox enabled` | ✅ 写入了 `PONG` | false | ~32.6s (冷启动) |
| `--sandbox disabled` | ✅ 写入了 `PONG` | false | ~18.3s |

结果：`--sandbox enabled --force --workspace <dir>` **确实执行写入**，因此
推荐路径保持 cursor-agent 自身的 jail 启用 (Codex 等效 containment)，
不需要禁用它。只有 Claude Code 外部 Bash
沙箱需要出口路径（优先允许列表而非禁用）。含义：
推荐的 gatsuri 路径不需要每个任务的 Risk Gate ack；唯一的 ack 门控路径是裸
`--sandbox disabled` 回退。

### Containment / "能否停止？" spike (Phase 83.3a 后续, 2026-05-29)

验证 cursor-agent 是否可被**阻止**，CC 外部 Bash 沙箱
禁用（因此仅 cursor-agent 自身的控制项受测试）：

| 测试 | 设置 | 结果 |
| --- | --- | --- |
| 在 `--workspace` 外写入 | `--sandbox enabled --force --workspace W` → 写入 `W` 外的路径 | ❌ **未被阻止** — 文件被写入了。`--sandbox enabled` **不**将写入限制在 workspace 内。 |
| 在 `--workspace` 外写入 | `--sandbox disabled --force` → 相同 | 已写入（无 jail，预期）。 |
| 只读模式下写入 | `--mode ask --force` → 在 `W` 内创建文件 | ✅ **被阻止** — "无法在 Ask 模式下创建"。`--force` **不**覆盖 `--mode ask`。 |

更正结论（取代 `--sandbox enabled` 等于 Codex `workspace-write` 的假设）：

1. cursor-agent 的 `--sandbox enabled` **不是**文件系统 confinement 边界；
   `--workspace` 仅设置 cwd，不设写入 jail。
2. 可靠的硬"停止"是 `--mode ask` / `--mode plan`（只读，`--force` 无法
   覆盖）— 用于只读/plan 委托。
3. 对于**写**委托，confinement 必须来自**CC 外部 Bash 沙箱**
   (network = 允许列表 Cursor 出口，filesystem 写入 = 限制到
   worktree)，而非 cursor-agent 自身的沙箱。cursor-agent 在外部沙箱
   FS-confined 时是否能正常工作是后续验证 (Phase 83.3b)。
4. 无论 cursor-agent 自我 confinement 是否可靠，worktree (专用 `.git`) + Lead diff review + cherry-pick 仍是必需的。

### 官方安全模型 (cursor.com/docs/agent/security，2026-05-29 观测)

Cursor 自身的安全文档确认并完善了 spike 发现：

- **"无传统沙箱。"** 文件写入自动批准，**"无项目文件夹 confinement"** — 与 83.3a 后续结果完全匹配。
  cursor-agent 的 `--sandbox` 限制 shell **命令**，而非 file-edit tool。
- **命令控制在 `~/.cursor/permissions.json`** 中，有三个级别：
  `Ask Every Time`（默认）、`Allowlist` / **`Allowlist (with Sandbox)`**
  (预批准命令自动运行，沙箱化) 和 `Run Everything`
  (Cursor 文档说**"永不使用"** — 这等同于 `--force`/`--yolo`)。
- **`.cursorignore`** 阻止 agent *读取*列出的文件（如密钥） —
  需要添加到治理规则中的渗透控制。
- **网络默认**：agent 不能发出任意请求；仅允许 GitHub、直接
  链接检索和 web-search providers，无文档化的扩展允许列表。
- **Workspace trust**：`"security.workspace.trust.enabled": true` 为不受信任的仓库启用受限模式。

设计后果（取代 `--force` 建议）：

1. **不要**用 `--force` / Run Everything 驱动 cursor-agent (Cursor 说
   永不)。优先使用 `~/.cursor/permissions.json` `Allowlist (with Sandbox)`，
   以便仅预批准的命令自动运行；`--mode ask` 用于只读委托。
2. 写入 confinement 不能来自 Cursor；它来自专用-`.git`
   worktree + CC 外部沙箱 / OS + Lead review (Phase 83.3b)。
3. 添加推荐的 `.cursorignore`（密钥、`.env`、keys、`.git`），
   以便网络启用的 agent 无法读取密钥进行渗透。

#### `~/.cursor/permissions.json` schema (cursor.com/docs/reference/permissions)

两个可选顶级数组。全局每用户（无每项目覆盖），JSONC，
热重载：

```jsonc
{
  // terminal commands that auto-run without approval (prefix match, case-sensitive)
  "terminalAllowlist": ["git status", "git diff", "go test", "npm:test*"],
  // MCP tools that auto-run without approval ("server:tool", wildcards ok)
  "mcpAllowlist": ["harness:*"]
}
```

- `terminalAllowlist`：命令前缀字符串。`"git"` 匹配每个 `git ...`；
  `"npm:install*"` = 基本命令 `npm` + 参数 glob。
- 优先级：团队管理员 (dashboard) > `permissions.json` > IDE 设置 UI。已定义键**完全替换**
  该类型的应用内允许列表（无合并）。
- **关键 (Cursor 原话)："允许列表是尽力而为的便利。
  它们不是安全保证。"** 因此 `permissions.json` 仅减少
  无人值守自动运行的批准摩擦；它**不是** containment 边界，可被绕过。
  真正的边界仍然是：专用-`.git` worktree + Lead diff review + 通过 R01-R13 的 cherry-pick，
  并将 cursor 输出视为不受信任。这就是为什么写入 containment 完全不能委托给 Cursor。

### 出口 + 内存发现 (2026-05-29)

- **Cursor 出口主机**（来自 `~/.cursor/cli-config.json`）：`api2.cursor.sh` 和
  `agentn.global.api5.cursor.sh`。CC 沙箱 `network.allowedDomains` 条目
  `*.cursor.sh` 覆盖两者，让 cursor-agent 无需
  每次运行 `dangerouslyDisableSandbox` 即可到达云（符合人体工程学的优势；沙箱的其他 guard 保持开启）。
  (TLS SAN 捕获通过裸 IP 失败 — ALB 需要 SNI — 因此主机名
  来自 CLI 配置，非证书探测。)
- **harness-mem 已全局布线**：在 `~/.cursor/mcp.json` 中存在
  `harness-mem` server 条目。cursor-agent (CLI) 加载全局 `~/.cursor/mcp.json`，
  因此 body (composer) 已与 brain (Opus) 共享内存。repo 级别的 `.cursor/mcp.json`
  为空，对该用户**冗余** — Phase 83.6 简化为"确认 cursor-agent 在运行时加载全局 mcp + 记录"；
  无需 repo 布线。
- **83.3b 现实**：CC 沙箱 filesystem-write 规则是**全局设置**；
  将写入限制到单个 worktree 也会阻止正常的本地开发，因此
  外部沙箱写入-confinement 不是干净的每次运行控制。建议：
  做 `*.cursor.sh` 网络允许列表（保持沙箱开启），但将写入模式
  containment 保持为 worktree + Lead review + 每次会话同意（与 Codex 相同的姿态）。
  通过沙箱的严格写入-confinement 是可选的全局强化，非阻塞项。

## Cursor ACP — 未采用 (2026-05-29)

Cursor 的 Agent Client Protocol (ACP) 在此记录为**未采用**于
harness 执行后端；Cursor 保持 `internal-compatible`，支持层级不变。

### ACP 是什么

- 用于"自定义客户端和集成"的 stdio 上的双向 JSON-RPC，
  通过 `agent acp` 激活。
- 通过 `session/update` 通知进行流式传输（实时 token / 事件源）。
- 通过 `session/request_permission` 进行权限门控（每个操作批准）。
- 阻止方法如 `cursor/ask_question` 和 `cursor/create_plan`，以及
  用于多轮连续性的持久 `sessionId`。
- 编辑器（Cursor desktop 除外）嵌入 composer 的 IDE 集成路径。
- 无单独 server，无特殊层级；认证重用 `agent login` /
  `--api-key` / `--auth-token`。
- cursor.com/docs/ja/cli/acp 的官方指导："ACP 旨在
  构建自定义客户端或集成。对于正常终端工作流，使用
  带 `agent` 的交互式 CLI。"

### 为什么不现在采用

- Harness 委托模式是整个任务：发送任务、等待、接收最终
  `.result`。ACP 的优势（流式传输、权限门控、阻止对话框、
  sessionId 连续性）未被使用。
- 实现 ACP 需要在 harness 侧有流式消费者、权限门控
  处理程序和 JSON-RPC 管道，而不增加 wrapper 尚未提供的功能。
- `cursor-agent -p --output-format json --trust`（当前 wrapper）
  已通过 wrapper 的退出码优先检查 (Phase 82 证据) 确定性地返回最终 `.result`。

### 在满足以下任一条件时重新评估 ACP

- 需要流式 UX（Lead 内实时进度源，而非仅
  任务完成事件）。
- Cursor desktop 以外的 IDE 必须将 composer 嵌入为 worker 后端。
- 每个操作权限门控（而非每会话）成为 harness 契约。

支持层级不变 (cursor=`internal-compatible`)；本文未添加任何消费者分发声明。

## Hook 运行时 deny parity — 已验证 (2026-06-12, Phase 83.7)

"CCH guardrails 在 Cursor 内部执行"的成败检查：Cursor
hooks 能否执行 PreToolUse 等效的**deny**（受保护路径写入块）？
**可以 — 已实时验证。** 这取代了 2026-05-28 的"未观测到"条目。

### 官方文档 (cursor.com/docs/agent/hooks，2026-06-12 获取)

- hooks.json 层级：Enterprise / Team / **Project (`.cursor/hooks.json`)** /
  User (`~/.cursor/hooks.json`)；schema `{"version":1,"hooks":{event:[{command,timeout}]}}`。
- 具备权限的事件：`preToolUse` (allow|deny)、`beforeShellExecution` /
  `beforeMCPExecution` (allow|deny|ask)、`beforeReadFile` (allow|deny)、
  `subagentStart` (allow|deny)。Deny 响应：`{"permission":"deny",
  "user_message":...,"agent_message":...}`。**退出码 2 == deny**；其他
  非零退出码 fail open。
- Hooks 在 IDE **和 CLI (`cursor-agent`)** 中运行；云 agents 支持命令 hook 子集。

### 实时 spike (cursor-agent `2026.06.12`，一次性 `mktemp -d` workspace)

项目级 `.cursor/hooks.json`，带有 `preToolUse` hook，deny 任何输入包含
`protected.txt` 的工具操作，加上 logging hooks。

| 测试 | 结果 |
| --- | --- |
| Agent 被要求创建 `protected.txt` | ✅ **写入前被阻止** — 运行后文件不存在；agent 显示"blocked: protected path"并停止 |
| `preToolUse` 触发范围 | 为**每个**工具调用触发 (Shell / Read / Grep / Write)；stdin 携带 `{conversation_id, generation_id, model, tool_name, tool_input, ...}` |
| 对照：创建 `allowed.txt` (hook 允许) | ✅ 已写入 — 无误报 |
| Repo 布线往返 (`bin/harness hook pre-tool --host cursor`) | deny 路径已发出 Cursor schema `{"permission":"deny","agent_message":...}` + 退出码 2 (`hookcodec.DenyOutput`，Phase 91.4) |
| **发现的差距并已修复** | 实时 CLI 将 shell 工具命名为 `"Shell"`（非 `"Bash"`）；未映射的名称溜过了 R06/R11 (fail-open)。修复：`hookcodec.Normalize` 现在映射 `Shell`→`Bash`，并有实时形态测试 (`TestNormalize_Cursor_ShellToolNameMapsToBash`，冒烟用例 `cursor-live-shell`) |

### 后果

1. `.cursor/hooks.json` `preToolUse` → `bin/harness hook pre-tool --host cursor`
   (hostgen，Phase 91.3) 是 cursor workers 的**真实运行时 deny 层**，
   而非仅配置形态。
2. 纵深防御不变：专用-`.git` worktree + 指纹 gate +
   Lead diff review + cherry-pick 仍然是必需的。Hooks 是 workspace-config
   作用域 — 在 workspace 外启动的进程不加载它们 — 因此它们强化，
   而非替换 Harness 侧 containment。
3. 支持层级不变：Cursor 保持 `internal-compatible`；本文未添加公共
   支持声明。

验证：`go test ./internal/hookcodec/ ./cmd/harness/` (实时形态用例)
加上上述 spike transcript 事实。

## 晋升条件

Cursor 仅在以下所有条件在同一
声明路径上满足后才能超越 `candidate`：

1. 已捕获带可提取证据的当前官方文档（本文 + 测试）。
2. Harness 特定 Cursor bootstrap 路由已被 setup 或 release preflight 消耗。
3. 工作流冒烟证明至少一个 `harness-plan`、`harness-work` 或
   `harness-review` 从 Cursor 路由，附带 transcript 或 CI 产物。
4. Breezing Cursor 映射记录为冒烟目标，非公共 parity 声明。
5. `tests/test-support-claim-wording.sh` 仍通过（无超过 `candidate` 的公共 Cursor 层级
   声明）。
6. 可选 Cloud Agent API 冒烟单独记录；失败不阻止
   本地 Desktop/CLI candidate 证据（如果层级措辞保持诚实）。

Phase 81 后的残余风险：

- 显式 subagent `model` 覆盖获胜；团队/管理员/计划中不可用的模型
  会静默回退，除非冒烟捕获它们。
- Multitask / background agent 行为可能与 Claude Agent Teams 不同。
- MCP 和 hooks 可能影响外部发送；配置形态测试不证明运行时
  策略执行。

## 验证命令

```bash
bash tests/test-cursor-adapter-candidate.sh
bash tests/test-bootstrap-routing-contract.sh
bash tests/test-tool-capability-matrix.sh
bash tests/test-model-routing.sh
bash tests/test-support-claim-wording.sh
```

Cursor CLI 已安装时的可选运行时冒烟：

```bash
HARNESS_CURSOR_ADAPTER_SMOKE_REQUIRED=1 bash tests/test-cursor-adapter-candidate.sh
```
