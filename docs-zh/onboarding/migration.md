# 现有用户迁移

Phase 73 让现有用户与新用户遵循相同的工具优先边界，但
迁移是报告优先。默认路径是检查影响、保存备份，
在存在单独明确的确认门之前避免清理。

## 第一个命令

从 Harness checkout 运行报告：

```bash
bin/harness doctor --migration-report
```

此命令是非破坏性的。它不会删除插件缓存、本地 skills、
OpenCode 文件、符号链接、项目状态或 harness-mem 数据。

## 报告检查内容

| 区域 | 影响 | 兼容性规则 | 回滚 / 备份 |
|---|---|---|---|
| Claude 插件缓存 | 过时的缓存插件版本可能使 Claude Code 停留在旧的 Harness 行为上。 | 使用 Claude Code 插件管理命令；不要将手动删除缓存条目作为报告的一部分。 | 通过插件管理器 `/plugin update` 或卸载/重新安装。 |
| Claude slash 条目 | 缺少 `harness-*` skill 条目可能使 `/harness-plan` 或 `/harness-work` 不可用。 | 缺少条目是安装漂移的证据，不是 host 不支持的证明。 | 更新或重新安装插件，然后运行 `/harness-setup`。 |
| Codex 本地 skills | 重复的 frontmatter 名称或旧别名可能使 Codex 路由到过时的 skills。 | 即使在直接插件冒烟之后，`scripts/setup-codex.sh --user` 仍然是安全的后备。 | 备份位于 `${CODEX_HOME:-$HOME/.codex}/backups/setup-codex`。 |
| Codex 符号链接 | 旧的符号链接安装可能在源 checkout 移动时或在 Windows 上损坏。 | 当前设置优先使用复制的 skill 目录。 | 重新运行 `scripts/setup-codex.sh --user`；仅在需要时恢复检查过的备份。 |
| OpenCode 文件 | 现有的 `.opencode/skills`、命令、插件和 `AGENTS.md` 可能被 setup 替换。 | OpenCode 保持 `internal-compatible`；不声称运行时对等。 | 带时间戳的备份，如 `.opencode/skills.backup.<timestamp>` 和 `.opencode/plugins/harness-bootstrap.mjs.backup.<timestamp>`。 |
| harness-mem 状态 | 内存连续性可以跨越 Claude Code 和 Codex 会话。 | `不要删除 memory DB`；报告不会读取或删除 DB 内容。 | 保留 `~/.harness-mem/` 和项目 `.harness-mem/state/`；使用 `harness mem doctor`，仅在明确确认后运行 purge。 |

## 兼容性契约

- Claude Code、Codex CLI、Cursor 和 Grok 是公开的 `supported` 路线（H8 pin）。
- OpenCode 保持 `internal-compatible`。
- Codex app、Hermes Agent 和 GitHub Copilot CLI 保持 `candidate`。
- Antigravity CLI 保持 `future/unsupported`。
- `not_observed != absent`：缺少本地证据意味着报告无法观察到该路线，
  但并不意味着该能力不可能。

## 安全迁移顺序

1. 运行 `bin/harness doctor --migration-report`。
2. 如果 Claude 插件缓存或 slash 条目过时，先通过 Claude Code
   插件命令更新。
3. 如果报告了 Codex 重复 skills 或符号链接，运行
   `scripts/setup-codex.sh --user` 并检查 `${CODEX_HOME}/backups/setup-codex`。
4. 如果报告了 OpenCode 文件，运行 `scripts/setup-opencode.sh` 并在恢复任何内容之前
   检查带时间戳的备份。
5. 如果观察到 harness-mem 状态，保留它；在适配器迁移期间不要 purge。

破坏性清理不是 Phase 73.1.9 的一部分。

对于旧的 Claude 插件 ID，请遵循 [重命名指南](../docs/onboarding/plugin-rename.md)。
更新旧 ID 不会切换其名称。
