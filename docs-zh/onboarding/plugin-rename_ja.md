# 将插件从 Claude 切换到 Harness

由于 Claude Code 以旧名作为保留名拒绝，插件 ID 从 `claude-code-harness` 更改为 `harness`。
GitHub 仓库 `Chachamaru127/claude-code-harness` 和 marketplace 名称 `claude-code-harness-marketplace` 保持不变。

[English](../docs/onboarding/plugin-rename.md)

## 切换前

这里的是终端命令。
不要在 AI 对话栏中输入。
结束使用旧插件的 Harness 作业，关闭使用旧插件的 Claude 会话。
使用 `claude plugin disable --help` 和 `claude plugin install --help` 确认可使用此处指定的 scope 的版本。
此指定在 Claude Code 2.1.296 中确认。

使用 `claude plugin list` 检查旧插件启用的所有 scope。
scope 是应用的范围。
`user` 是自己的账户，`project` 是项目的共享设置，`local` 是仅限一个项目的个人设置。
对 project 和 local 的操作在相应项目目录下进行。
更改共享设置会影响其他用户，因此请协调切换时间。

## 在当前 Claude Code 中遵循重命名信息

从 Claude Code 2.1.193 开始，遵循 marketplace 的 `renames` 映射（旧 ID 到新 ID 的对应表）。
重写 user、project、local 的启用设置和插件设置密钥。
组织的管理设置需要管理员更新。
这是基于[官方重命名规范](https://code.claude.com/docs/en/plugins/host-marketplace#migrate-users-with-a-renames-map)的路径。

在重命名版本发布后，在终端执行。

```bash
claude plugin marketplace update claude-code-harness-marketplace
claude plugin install harness@claude-code-harness-marketplace --scope user
claude plugin list
```

根据应用到的 scope 调整 `user` 为 `project` 或 `local`。
结束后检查所有 scope。
保持原本禁用的设置为禁用状态，仅在需要时为新插件启用。
对于通过 Git 和 URL 添加的 marketplace，引入新 ID 一次以同步缓存。
开始新的 Claude 会话。
对应功能可以通过 `/reload-plugins` 重新加载，但重启可以明确会话边界。

使用 `/plugin` 确认所需的新 ID 有效，旧版未同时启用。
执行 `/harness-setup`，向 `/harness-plan` 发送一个小请求。
查看提议的项目变更后再接受。
如果名称冲突，可以使用 `/harness:harness-plan`。

## 使用旧版本或手动恢复

先完成正在进行的作业。
对于每个残留旧 ID 的 scope，保留数据并移除旧版本，在同一 scope 安装新版本。

```bash
claude plugin uninstall claude-code-harness@claude-code-harness-marketplace --scope user --keep-data
claude plugin install harness@claude-code-harness-marketplace --scope user
claude plugin list
```

根据实际 scope 调整 `user`。
在无法使用 `--keep-data` 的版本中放弃，不要执行会删除数据的卸载。
准备好已验证的备份，并使用该版本对应的插件管理路径。
作为安装失败的对策，不要同时启用两个 ID。

## 数据和其他执行目标

项目的 `Plans.md`、`.claude/state/`、`.claude-code-harness.config.yaml`、harness-mem 的保存位置保持不变。
插件专用目录根据 ID 而变化。
如果存在 `CLAUDE_PLUGIN_DATA`，Harness 使用其中的 `state.db` 和 `livemsg.db`。
即使保留旧数据，新 ID 的专用状态也可能全新开始。
重命名映射移动的是设置密钥，而不是此数据库。
不保证数据库的自动传输。
在切换前结束会话，并确认待处理的工作和审批。
不要复制正在运行的数据库，也不要无条件地恢复过去的审批。

由于共享相同的 marketplace ID，Codex、Cursor、Grok 的分发 manifest 也统一为 `harness`。
安装方法和对应范围不变。
在引入新的分发物之前，使用执行目标提供的管理方法禁用或删除旧插件。
确认只有一份有效副本。
Cursor 和 Grok 的副本安装目标末尾为 `harness`，组装用保存位置和项目设置保持原有名称。
如果使用 `setup-codex.sh --user` 复制 skills，则 skills 名称和保存位置不变。

不要手动删除缓存、认证信息和记忆以进行切换。
不保证新的 Claude Code 可以恢复到旧名称。
本地候选检查成功不意味着重命名版本已发布。
