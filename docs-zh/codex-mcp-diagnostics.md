# Codex MCP 诊断和 Plugin Loading

本文档是 Codex `0.123.0` 之后 MCP 诊断和 plugin MCP loading 的运营备忘录。
不涉及 Claude Code 端的 `claude mcp`、`.claude/mcp.json`、hook `type: "mcp_tool"`。

## 目的

Codex 的 `/mcp` 用于日常的轻量确认。
是快速查看已连接 server 概要的入口。

Codex 的 `/mcp verbose` 仅在遇到问题时使用。
是进行详细诊断（diagnostics、resources、resource templates）的入口。

这种区分使日常确认保持快速，只在 MCP server 不可见、resources 不出来、template 读不到时才深入调查。

## 使用场景

| 情况 | 使用 | 查看要点 |
|------|------|--------------|
| 仅确认 MCP server 是否已注册 | `/mcp` | server 名、连接状态、大致的有效/无效 |
| server 未显示 | `/mcp verbose` | diagnostics 的启动错误、认证错误、配置文件读取 |
| 工具可见但 resource 不可见 | `/mcp verbose` | resources 的有无、resource templates 的有无 |
| 怀疑 plugin 的 `.mcp.json` 未被读取 | `/mcp verbose` | plugin MCP loading 的目标 server 和 diagnostics |

## 诊断步骤

1. 首先在 Codex TUI 中执行 `/mcp`。
2. 仅在看不到预期的 server 或状态不明时执行 `/mcp verbose`。
3. 检查 `diagnostics` 中是否有启动失败、认证失败、配置文件 parse error。
4. 检查 `resources` 中 server 发布的 resource 是否可见。
5. 检查 `resource templates` 中 `repo://{owner}/{name}` 这样的 template 是否已发布。
6. 如果只有 plugin 来的 MCP server 不可见，确认 plugin 的 `.mcp.json` 格式。

## `.mcp.json` 的对应格式

Codex `0.123.0` 之后的 plugin MCP loading，对于 plugin 内的 `.mcp.json` 接受以下 2 种格式。

### `mcpServers` 格式

```json
{
  "mcpServers": {
    "docs": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
```

### top-level server map 格式

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

两者都可作为 plugin MCP loading 的输入。
新写时，优先使用 `mcpServers` 格式，因为与其他 AI tool 共享更容易。
如果现有 plugin 使用 top-level server map 格式，不要强行改写，利用 Codex 端的读取改进即可。

## 不要与 Claude Code 端混用

本文档的对象是 Codex 的 plugin MCP loading 和 Codex TUI 的 `/mcp` / `/mcp verbose`。

Claude Code 端的设置和诊断入口不同。

| 领域 | 入口 | 本文是否涉及 |
|------|------|------------------|
| Codex TUI 的 MCP 诊断 | `/mcp`, `/mcp verbose` | 涉及 |
| Codex plugin 的 `.mcp.json` loading | plugin 内 `.mcp.json` | 涉及 |
| Claude Code CLI 的 MCP 管理 | `claude mcp ...` | 不涉及 |
| Claude Code project MCP 设置 | `.claude/mcp.json` | 不涉及 |
| Claude Code hook 的 `type: "mcp_tool"` | `hooks.json` | 作为 53.1.2 的单独判断处理 |

## 注意事项

- `/mcp verbose` 用于详细诊断。日常确认使用 `/mcp`。
- 不要在 `.mcp.json` 中直接写 secret。所需的值应通过环境变量或受管的 credential store。
- 即使 `resources` 和 `resource templates` 为空，某些 server 也可能是正常的。只提供工具的 MCP server 也存在。
- plugin `.mcp.json` 的读取改进是 Codex 端的问题。不要作为 Claude Code 的 `.claude/mcp.json` 或 managed settings 的规格变更来处理。
