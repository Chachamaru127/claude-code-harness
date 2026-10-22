# Claude Code 2.1.99 → 2.1.110 — Harness 影响分类

> **目的**：将 Claude Code 2.1.99 到 2.1.110 的所有主要变更点，
> 按 `.claude/rules/cc-update-policy.md` 的 3 个类别（A / B / C）分类，
> 整理成可追溯到 Phase 44.2 及之后实现任务的格式。
>
> **分类规则**（来自 cc-update-policy.md）：
> - **A: 有实现** — Harness 侧需要具体变更（新的 hook / scripts / skills / agents / docs）
> - **B: 仅写入** — 仅修改 Feature Table。**禁止**。不应出现在本表中
> - **C: CC 自动继承** — 仅 Claude Code 本体变更。Harness 无需变更。Feature Table 明确标注"CC 自动继承"
>
> **前提**：当前 Harness 为 v4.1.1，Feature Table 对应 v2.1.98（Monitor 工具）。
> 本表的 A 项目在 Phase 44.2-44.7 中实现，C 项目仅在 Phase 44.11 的 Feature Table 中追加。

---

## 1. 类别 A: 有实现（Harness 侧需要变更）

Phase 44 中包含 Harness 侧具体变更的项目。各行注明对应 Phase。

| ver | 变更点 | 影响位置 | 对应 Phase |
|-----|-------|---------|-----------|
| 2.1.101 | Settings resilience：即使混入了不明 hook event 名称，`settings.json` 整体也不会被忽略 | `.claude-plugin/settings.json` / `hooks.json` 新增 hook 时的安全性提升 | 44.2（在添加 PreCompact 时的安全装置中使用） |
| 2.1.101 | `permissions.deny` 现在会覆盖 `PreToolUse` hook `permissionDecision: "ask"` | Harness guardrails（R01-R13）的 deny 链 | **44.3**（R01-R13 重新验证） |
| 2.1.101 | Plugin 多重检测时因重复 `name:` frontmatter 导致 slash command 解析到其他 plugin 的 bug 修复 | 审计现有 `skills/**/SKILL.md` frontmatter 是否使用唯一名称 | **44.4.2**（literal 化时一并验证 name 唯一性） |
| 2.1.101 | Skill 不 honor `context: fork` 和 `agent` frontmatter 的现有 bug 修复 | 重新验证 Harness skill 中使用 `context: fork` 的 skill（canai-docs 等） | **44.7.1**（小功能集成） |
| 2.1.101 | Subagent 不继承动态注入 MCP server 的 bug 修复 | Breezing 中的动态 MCP、`harness-mem` 继承 | **44.7.1** |
| 2.1.101 | Sub-agent 无法在 isolated worktree 内对自身文件进行 Read/Edit 的 bug 修复 | `isolation: worktree` 的 Worker / Advisor | **44.7.1**（动作确认 + smoke） |
| 2.1.105 | **新 hook: `PreCompact`** — 可通过 `{"decision":"block"}` / exit 2 停止 compaction | 防止长时间 Worker 在 compaction 中意外中断 | **44.2.1**（Go 实现 + hooks.json 注册） |
| 2.1.105 | **Plugin manifest: `monitors` 新顶级 key** — session 启动 / skill 调用时 background monitor 自动 arm | Harness 的 mem 健全性 / drift 监视 / advisor 状态常驻化 | **44.2.2**（plugin.json 添加） |
| 2.1.105 | `EnterWorktree` 新增 `path` 参数，可重新进入现有 worktree | `scripts/run-worker-*.sh` 等的 worktree 重用 | **44.7.1** |
| 2.1.105 | `/proactive` 作为 `/loop` 的 alias | harness-loop 的 alias 策略 | **44.7.1**（docs 追加） |
| 2.1.108 | **`ENABLE_PROMPT_CACHING_1H` 环境变量** — 1 小时 prompt cache TTL | Breezing / harness-loop 的长时间会话成本削减 | **44.6.1**（opt-in 脚本 + docs） |
| 2.1.108 | `/recap` / `/undo` 作为 `/rewind` 的 alias | session-memory / commit safety | **44.7.1** |
| 2.1.108 | Model 可以从 Skill tool 调用 built-in slash commands（`/init`、`/review`、`/security-review`） | 确认 Harness 的 `/harness-review` 与之功能重叠 | **44.7.1** / **44.8.1** |
| 2.1.110 | `/tui` 命令 + `tui` 设置（fullscreen rendering） | 运维指南更新（docs） | **44.7.1**（仅 docs 追加，Harness 行为不变） |
| 2.1.110 | **Push notification tool**（Remote Control + "Push when Claude decides" 设置时） | 可用于 `harness-loop` 的长时间执行完成通知 | **44.7.1**（docs 追加，记录将来采用的可能性） |
| 2.1.110 | **`PermissionRequest` hooks 在返回 `updatedInput` 时，`permissions.deny` 规则会重新检查** | guardrails R01-R13 的 deny 链一致性确认 | **44.3.1**（必须重新验证） |
| 2.1.110 | `setMode:'bypassPermissions'` 遵守 `disableBypassPermissionsMode` | 维持 Harness 的 bypass 策略 | **44.3.1**（docs 追加） |
| 2.1.110 | **`PreToolUse` hook `additionalContext` 在 tool 调用失败后不会被丢弃的修复** | guardrails 的 deny 原因注入在失败后仍然保留 | **44.3.1**（回归测试追加） |
| 2.1.110 | 修复带有 `disable-model-invocation: true` 的 Skills 在 `/<skill>` 中途调用时不工作的问题 | 消除 Harness 的 `/harness-work`、`/harness-review` 等中发生的潜在 bug | **44.7.1**（smoke test） |

**A 项目数**：**19 项**
**实现分配**：44.2 (2)、44.3 (3)、44.4.2 (1)、44.6.1 (1)、44.7.1 (10)、44.8.1 (1) + 44.3.1 内 3 项汇总

---

## 2. 类别 C: CC 自动继承（Harness 无需变更）

仅追加到 Feature Table。Harness 的实现无需变更，但需更新用户指南和期望值。

| ver | 变更点 | Harness 侧获得的效果 |
|-----|-------|-------|
| 2.1.101 | 内存泄漏修复——长会话中 virtual scroller 保持数十个 historical message-list 的 bug | 长时间 Breezing 的 RSS 稳定化 |
| 2.1.101 | `--resume` / `--continue` 因 dead-end branch 锚点导致大会话 context loss 的修复 | harness-loop wake-up 时 resume 信赖性提升 |
| 2.1.101 | 5 分钟硬编码 timeout 遵循 `API_TIMEOUT_MS` 的修复（本地 LLM / extended thinking） | Opus 4.7 xhigh 时 thinking 更长的安全性 |
| 2.1.101 | Bedrock SigV4 认证失败修复 | 对使用 Bedrock 的用户透明改善 |
| 2.1.101 | Grep tool ENOENT → 系统 `rg` fallback | 所有 skill 的 Grep 信赖性 |
| 2.1.101 | `/btw` 每次对整个会话写入磁盘的 bug 修复 | 上下文成本削减 |
| 2.1.101 | `/plugin update` ENAMETOOLONG 修复 | `/harness-setup` 时 plugin 更新稳定化 |
| 2.1.101 | Directory-source plugins 的 stale cache 修复 | Harness dev 的重新加载稳定化 |
| 2.1.101 | Custom keybindings 在 Bedrock / Vertex 中不读取的修复 | 多 provider 环境的 keybindings |
| 2.1.101 | 命令注入漏洞修复：POSIX `which` fallback（LSP binary detection） | 安全自动继承 |
| 2.1.105 | 图像在队列消息中 drop 的 bug 修复 | 多模态投入的稳定化 |
| 2.1.105 | 前导空白 trim 破坏 ASCII art / indented diagram 的 bug 修复 | 设计图、表输出的信赖性 |
| 2.1.105 | `alt+enter` / `Ctrl+J` 换行插入修复 | 编辑体验 |
| 2.1.105 | One-shot scheduled task 再次触发的修复（file watcher 后处理遗漏） | scheduled 运维的信赖性 |
| 2.1.105 | Team/Enterprise inbound channel notification 消失的修复 | CC 的多人功能 |
| 2.1.105 | `/skills` 菜单滚动修复 | UI |
| 2.1.107 | Extended-thinking indicator 显示改善（更早显示 hint） | Opus 4.7 xhigh 时 UX |
| 2.1.108 | `/compact` 在大会话中因 "context exceeded" 失败的修复 | 长时间会话的信赖性 |
| 2.1.108 | DISABLE_TELEMETRY 用户无法接受 1h cache 的修复 | 作为 44.6.1 opt-in 的前提必需 |
| 2.1.108 | Agent tool auto mode 中 safety classifier transcript overflow 时 permission prompt 的修复 | Auto Mode 采用时的信赖性 |
| 2.1.108 | Bash tool 在 `CLAUDE_ENV_FILE` 存在尾随 `#` 注释行时不输出的 bug 修复 | Bash 执行稳定化 |
| 2.1.108 | `claude --resume <session-id>` 中 `/rename` 的自定义名称/颜色丢失的 bug 修复 | 会话管理 |
| 2.1.108 | Policy-managed plugins 在首次安装和从其他 project 执行时 not auto-update 的 bug 修复 | Enterprise/Teams 分发 |
| 2.1.108 | 设置 `language` 时 diacritical marks（重音等）被丢弃的 bug 修复 | i18n |
| 2.1.109 | Extended-thinking indicator rotating progress hint | UX |
| 2.1.110 | MCP tool calls 在 SSE/HTTP server 连接 drop 期间无限 hang 的 bug 修复 | MCP 相关的信赖性（harness-mem 等） |
| 2.1.110 | Non-streaming fallback retries 的数分钟 hang 修复 | 长时间任务 UX |
| 2.1.110 | Session cleanup 现在包含 subagent transcripts 的完全删除 | 磁盘节约 |
| 2.1.110 | `/skills` 菜单滚动修复（fullscreen） | UI |
| 2.1.110 | Remote Control session re-login prompt 修复（stale session） | Remote Control UX |

**C 项目数**：**30 项**

---

## 3. 类别 B: 仅写入（禁止）

**空**。本文档的所有项目已分类为 A 或 C。遵循 `cc-update-policy.md` 的"检测到类别 B 时阻止 PR"规则，B 完全不包含。

---

## 4. Phase 44 实现追溯表

使 Phase 44.2 及之后的任务能够反向查找本分类表对应哪个 A 项目。

| Phase | A 项目（见上表） |
|-------|---|
| 44.2.1（PreCompact hook） | 2.1.105：`PreCompact` hook |
| 44.2.2（monitors manifest） | 2.1.105：`monitors` manifest key |
| 44.3.1（guardrails R01-R13 重新验证） | 2.1.101：`permissions.deny` 覆盖 PreToolUse ask / 2.1.110：`updatedInput` 重新检查 / 2.1.110：`additionalContext` persist / 2.1.110：`setMode:'bypassPermissions'` + `disableBypassPermissionsMode` |
| 44.4.2（skill literal 化） | 2.1.101：duplicate `name:` frontmatter bug 的波及确认 |
| 44.6.1（1 小时 prompt cache opt-in） | 2.1.108：`ENABLE_PROMPT_CACHING_1H` |
| 44.7.1（小功能集成） | 2.1.101：`context: fork` + agent / subagent MCP 继承 / worktree Read/Edit / 2.1.105：`EnterWorktree path` / `/proactive` / 2.1.108：`/recap` / `/undo` / built-in slash via Skill tool / 2.1.110：`/tui` / Push notification / `disable-model-invocation` mid-message fix |
| 44.8.1（/ultrareview 联动） | 2.1.108：作为 built-in slash 调用的一环検討从 Skill tool 调用 `/ultrareview` |
| 44.11.1（Feature Table 更新） | 上述 A 19 项 + C 30 项全部 |

---

## 5. 备注：安全相关的自动继承（特别记录）

2.1.97 → 2.1.98 封堵了所有 Bash 权限 bypass（反斜杠转义标志 / 复合命令 / 环境变量前缀 / `/dev/tcp` 重定向），2.1.101 修复了 POSIX `which` fallback 的命令注入。这些都是 C 继承，但由于 Harness 的 guardrails R01-R13（Bash 系 deny）的前提条件有所改善，在 44.3.1 中"确认前提是否未变"是有价值的。
