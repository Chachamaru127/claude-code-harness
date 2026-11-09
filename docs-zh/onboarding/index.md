# 工具优先入门

从这里开始——选择你现在使用的工具。
Claude Code Harness 仍然以 Claude 为先，但 Phase 73 使每个 host 的入口点变得明确，
以免用户将候选路线误认为已验证的安装路径。

详细命令见 [install.md](install.md)。现有用户应在清理前运行
[migration.md](migration.md) 中的报告优先迁移路径。

## 支持层级规则

公开措辞必须保持这些层级不变：

| 工具 | Phase 73 层级 | 从这里开始 |
|---|---|---|
| Claude Code | `supported` | 使用 [install.md](install.md#claude-code-supported) 中的 Claude 插件安装路径。 |
| Codex CLI | `supported` | 使用 [install.md](install.md#codex-cli-supported) 中的 `scripts/setup-codex.sh --user`。 |
| Codex app | `candidate` | 使用 [install.md](install.md#codex-app-candidate) 中的候选冒烟检查清单；不要复用 Codex CLI 的证明。 |
| OpenCode | `internal-compatible` | 使用 [install.md](install.md#opencode-internal-compatible) 中的 `scripts/setup-opencode.sh`。 |
| Cursor | `supported` | 使用 [install.md](install.md#cursor-supported) 中的 `scripts/setup-cursor.sh`；隔离在 harness 侧——见 [docs/CURSOR_INTEGRATION.md](../docs/CURSOR_INTEGRATION.md)。 |
| Grok | `supported` | 使用 [install.md](install.md#grok-supported) 中的 `scripts/setup-grok.sh`；Claude-envelope PreToolUse floor——非完整 Claude hook 对等。 |
| Hermes Agent | `candidate` | 使用 [install.md](install.md#hermes-agent-candidate) 中的候选边界；仅手动符号链接研究。 |
| GitHub Copilot CLI | `candidate` | 使用 [install.md](install.md#github-copilot-cli-candidate) 中的候选边界。 |
| Antigravity CLI | `future/unsupported` | 使用 [install.md](install.md#antigravity-cli-futureunsupported) 中的非支持边界。 |

`not_observed != absent`：缺少本地运行时证据意味着在该 artifact 集合中未观察到该能力。
这并不能证明该能力不存在。

公开的 **正式対応** 对应英文 `supported`，适用于 Claude Code、Codex CLI、Cursor 和
Grok（H8 pin）。其余行按层级使用 兼容利用可 或 试验対応。
OpenCode、独立的 app 候选路径、Hermes Agent、GitHub Copilot CLI 和 Antigravity CLI
在自己的 H1–H8 通过之前（`docs/spec/planning-and-host-adapter.md`）不得借用该措辞。

| EN 层级 | JP 公开措辞 |
|---|---|
| `supported` | 正式対応 |
| `internal-compatible` | 互換利用可 / 制限付き対応 |
| `candidate` | 試験対応 / プレビュー |
| `future/unsupported` | 非対応 / 将来検討 |

## 选择路线

| 如果你正在使用... | 首先做这个 | 不要声称 |
|---|---|---|
| Claude Code | 安装 marketplace 插件，然后运行 `/harness-setup`。 | 在已验证的门之外声称通用多 host 支持。 |
| Codex CLI | 运行 `scripts/setup-codex.sh --user`，重启 Codex，然后调用 `$harness-plan`。 | 直接安装 Codex 插件或声称 Codex app 对等。 |
| OpenCode | 运行 `scripts/setup-opencode.sh`，启动 OpenCode，然后请求 `harness-plan`。 | 声称 Claude hook 对等或运行时自动路由对等。 |
| Codex app | 仅记录候选冒烟证据。 | App 行为由 Codex CLI 文档或帮助输出证明。 |
| Cursor | 运行 `scripts/setup-cursor.sh`，重载 Cursor，然后调用 `/breezing` 或 `/harness-plan`。 | 声称顶级 Cursor 适配器或 Claude hook 对等。 |
| Grok | 运行 `scripts/setup-grok.sh`，重启 Grok，然后调用 `/harness-plan` 或 `/breezing`。 | 公开声称 Grok 适配器为顶级；声称 Claude SessionStart/PreToolUse 对等。 |
| Hermes Agent | 将手动符号链接暴露视为仅候选研究。 | 公开声称 Hermes 支持、Claude hook 对等或运行时 workflow 对等。 |
| GitHub Copilot CLI | 将其视为仅 CLI 能力研究。 | 声称 Harness 引导支持。 |
| Antigravity CLI | 将其排除在最终用户安装流程之外。 | 声称安装支持、设置支持或适配器支持。 |

## 首次成功会话

一条路线仅在具备以下全部条件时才可用：

- 第一个 prompt
- 第一个命令
- 验证命令
- 成功 look
- 支持层级和已知不对称

对于候选和非支持的 host，success look 不是"已安装"。
而是"边界保持了诚实"：证据记录为 `candidate`、
`future/unsupported`、`manual` 或 `not observed`。
