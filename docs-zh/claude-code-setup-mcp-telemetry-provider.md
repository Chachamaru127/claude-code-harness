# Claude Code Setup：MCP、遥测、Provider 指南

最后更新：2026-05-05

Claude Code 2.1.120 及之后增加的 setup / MCP / telemetry / provider 周围的运维指南。

## 简言之

Harness 引导 Claude Code 的新功能，但不替换官方设置的含义。
MCP 的常时加载、telemetry、provider、Windows shell、deferred tools，按用途分别小额 opt-in。

## 打个比方

Claude Code 是工具箱，Harness 是作业指导书。
不是擅自改造工具箱内部，而是引导"这项工作把这个工具拿出来备用"。

## Setup 检查清单

| 项目 | Harness 指导 |
|------|------------------|
| `${CLAUDE_EFFORT}` | 仅在 skill 正文中引用当前 effort 时使用。effort 的决定留给调用方 |
| MCP `alwaysLoad` | 每 turn 必需的小型工具才设 `true`。大型 server 保持 deferred |
| `claude plugin prune` | plugin uninstall 后孤立的 dependency cleanup。先用 `--dry-run` |
| `claude project purge` | 删除 project state 的强 cleanup。先用 `--dry-run` 或 `--interactive` |
| `ANTHROPIC_BEDROCK_SERVICE_TIER` | 仅 Bedrock 用户在 provider 环境中设置。不放入 Harness default |
| `claude_code.skill_activated.invocation_trigger` | 在 telemetry 中区分 skill 启动原因 |
| PowerShell primary shell | Windows 上以 PowerShell primary 为前提引导，避免 Bash 固定的示例 |
| forked skills / subagents deferred tools | 在首次 turn 需要 deferred tools 的 workflow 中，写作方式要能明确进行 tool discovery |

## Effort 指导

`${CLAUDE_EFFORT}` 是从 skill 正文中引用当前 effort level 的变量。
这不是"skill 自己决定 effort"，而是"用于说明和分支当前以哪个 effort 被调用"。

允许的示例：

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, keep the review to confirmed blockers.
If effort is xhigh, include adversarial checks.
```

避免的示例：

- 在 skill 正文中"一定要改为 xhigh"
- 忽略 user / parent workflow 的 effort 指定
- 在 `${CLAUDE_EFFORT}` 为空时视为失败

## MCP `alwaysLoad`

MCP tool search 为了节省上下文而延迟加载 tool schema。
`alwaysLoad: true` 是将该 server 从延迟中排除、在 session 启动时始终可见 tool 的设置。

使用场景：

- 每 turn 使用的小型 core tool server
- workflow 第一手必须需要的 server
- 在 tool search 中发现较慢、影响作业质量的小型 server

避免场景：

- tool 数量多的 server
- 偶尔使用的 integration
- 有大型 schema 的 database / observability server

示例：

```json
{
  "mcpServers": {
    "core-tools": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "alwaysLoad": true
    }
  }
}
```

## Plugin cleanup

`claude plugin prune` 是删除作为 plugin dependency 自动安装但现在不再需要的 plugin 的 cleanup。
不是用于擅自删除直接安装的 plugin 的。

推荐：

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

在 Harness setup 中，作为 uninstall 后的引导发出。
不在初始 setup 或 release 步骤中无条件执行。

## Project state cleanup

`claude project purge [path]` 是删除 Claude Code 在项目中拥有的 transcripts、tasks、file history、config entry 的强 cleanup。

推荐：

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

使用场景：

- 将项目 archive
- team handoff 前删除旧的 local state
- 项目 path / owner 变更，旧状态碍事

避免场景：

- 现在进行中的作业还残留着
- 需要将 transcript 或 task queue 作为证据保留
- "总觉得想轻一点"而已，没有确认删除对象

## Provider 指导

`ANTHROPIC_BEDROCK_SERVICE_TIER` 作为 Bedrock 用户 provider 侧 tuning 相关的环境变量处理。
不作为既定值放入 Harness 的 plugin default、template、shared project settings。

理由：

- 不使用 Bedrock 的用户不需要
- team / account / region 不同正确的值也不同
- provider 设置接近 user / organization 的责任边界

Bedrock guidance 不与 Claude Code 侧的 `CLAUDE_CODE_USE_BEDROCK` / `ANTHROPIC_*` 系和
Codex 侧的 provider 设置混合。

## Telemetry 指导

`claude_code.skill_activated.invocation_trigger` 是用于查看 skill 如何启动的 telemetry attribute。

代表值：

| 值 | 含义 |
|----|------|
| `user-slash` | 用户作为 slash command 显式启动 |
| `claude-proactive` | Claude 从上下文 proactive 启动 |
| `nested-skill` | 从其他 skill / workflow 内部启动 |

在 Harness 中，防止 media / announcement 系等 `user-invocable: false` skill
变成 `claude-proactive` 前提。
期望的启动是 `user-slash` 或 `nested-skill`。

## Windows shell 指导

在 Windows 上，如果 PowerShell tool 可用，则作为 PowerShell primary shell 处理。
避免 Git Bash 固定的引导。

写法：

- 并记 `pwsh` / PowerShell 前提的示例
- 不以 POSIX shell 特有的 `export` 结束
- 注意 path separator 和 quoting 的差异

## Forked skills / subagents 和 deferred tools

`context: fork` skill 或 subagent 也可能需要 deferred tools。
在 workflow 正文中，模糊地处理首次 turn 使用的 tool，必要时明确进行 tool discovery。

示例：

- 需要 WebFetch 时，在 allowed-tools / tools 中包含
- 需要 MCP tool 时，记明 server 名和用途
- 以首次 turn 中 tool 不可见为前提，写入搜索/确认的步骤

这样可以减少在 forked context 的第一手判断中误判"应该有 tool 却没有了"的可能性。

## Sources

- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Claude Code MCP docs: https://code.claude.com/docs/en/mcp
- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
