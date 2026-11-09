# 主要命令一览

Claude Harness 开发时使用的命令和交接（handoff）一览。

## 主要命令（开发时使用）

| 命令 | 用途 |
|---------|------|
| `/plan-with-agent` | 向 Plans.md 添加改进任务 |
| `/work` | 实现任务（自动判断范围，--codex 支持） |
| `/breezing` | 使用 Agent Teams 进行团队并行运行（--codex 支持） |
| `/reload-plugins` | 技能/钩子编辑后即时生效（无需重启） |
| `/harness-review` | 审查变更内容 |
| `/validate` | 验证插件 |
| `/remember` | 记录学习事项 |

## 交接（Handoff）

| 命令 | 用途 |
|---------|------|
| `/handoff-to-cursor` | Cursor 运用时的完成报告 |

**技能（会话中自动启动）**:
- `handoff-to-impl` - "交给实现者" → PM → 对 Impl 的委托
- `handoff-to-pm` - "向 PM 报告完成" → Impl → 对 PM 的完成报告

## 相关文档

- [CLAUDE.md](../CLAUDE.md) - 项目开发指南
- [docs/CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - 技能目录
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - 新功能运用表
