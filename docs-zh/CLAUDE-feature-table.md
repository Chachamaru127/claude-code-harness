# Claude Code / Codex 功能表（upstream snapshot 完整版）

> **概要**: Harness 使用・追踪的 Claude Code / Codex 主要功能与 upstream snapshot 一览。
> CLAUDE.md 功能表的完整版（含详细说明）。

## 功能一览

| 功能 | 活用技能 | 用途 |
|------|-----------|------|
| **Phase 89 会话协作 (file lease + register + broadcast 复活)** | hooks, breezing, harness-work | `A: 已实现`。同一 PC・同一 repo 的多个 CC 会话中，`.go`/`.md`/`.sh` 编辑冲突通过 `continueOnBlock` 反馈给模型。`go/internal/hookhandler/session_lease.go` (`git --git-common-dir` 下以 sha256 hex 命名的 lock + `os.Link` create-only + (TTL AND active.json) stale 判定 + 24h auto-prune + worktree shared store)、`session_register.go` (SessionStart/Stop 时 active.json 记名解除 + tri-state)、`file_lease_hook.go` (PreToolUse silent acquire + PostToolUse `permissionDecision:"deny"` + `continueOnBlock:true` + 8-char holder prefix + sanitized path)、`inbox_check.go` (仅 structured fields + 4096B cap + ANSI/NUL 去除 + `userprompt-inject-policy` disclaimer)、`session_auto_broadcast.go` (`.go`/`.md`/`.sh` 扩展名匹配 via `filepath.Ext` 使 2026-02 死骸复活、`*<ext>` label 用于 debug 可视化)。`hooks/hooks.json` + `.claude-plugin/hooks.json` dual-sync 配线到 PreToolUse/PostToolUse/SessionStart/Stop。`continueOnBlock` 是 diagnostic feedback (非 R01-R13 guard rail，`hooks-2.1.139-plus.md` §3 一致)。Phase 120: `session_presence.go` 在 git-common-dir 父目录新增 `live-sessions/` presence (session-owned, 0600/0700, 24h prune)，并将 lease staleness 的存活判定修正为「共享 presence ∪ 本地 active.json」的跨 worktree union (名簿 active.json 与 broadcast/inbox 仍为 worktree 本地)。不依赖 harness-mem = 仅限同一 PC，不同 clone 之间不共享。Phase 121 (HOTL session messaging): livemsg directed message 投递路径的信赖契约 (sanitize + 非命令 disclaimer + 4096B/768B cap)、人类发送 CLI `inbox send` / 已读可视化 `inbox sent`、Claude Stop 边界配线 (`hooks/hooks.json` dual-sync，未读 0 则 silent)、生成 hook identity 的 runtime 解决 (`--from-env`、撤销 `{{TEAM}}` placeholder)、presence card `{label, task, since}` + `harness session declare/list` (task 编号→会话反向查找，liveness 仍为 filename+mtime)。 Phase 141 (会话协作管道): 修复名簿寿命，将 `unregister` 从 Stop 移动到 SessionEnd + 在 Stop 增加 `register` (Stop 是 turn 边界而非会话结束，因此以往会在第一个 turn 就抹掉自己的 presence)。refresh 只更新 mtime 并保持 `session declare` 的 task/label。`session_register_identity.go` 以 **export 形式** 向 `CLAUDE_ENV_FILE` 写入 `export HARNESS_LIVEMSG_TEAM` / `..._AGENT` (裸的 `KEY=VALUE` 无法到达子进程 env)。`deliveryidentity.Resolve()` 的优先级 (env → breezing) 不变，只增加填充 env 的一侧。`session_auto_broadcast.go` 的 broadcast 从 worktree 本地统一到 git-common-dir 父目录的共享 scope (presence 是共享的而 broadcast 却是本地，消除「看得见身影却收不到通知」的不一致)。以 `map[string]json.RawMessage` 读写 `active.json`，将自身 schema 之外的条目从 24h prune 中排除 (防止与 harness-mem 共存时的破坏)。`skills/session-send/SKILL.md` 提供 agent 主导的发送口 (`harness inbox send`)。`[livemsg] verification = "off"|"on"` (默认 off，与 `destructiveDelete` 相同的 5 段解析) 与 `templates/schemas/livemsg-gate.v1.json` + `agents/livemsg-gate.md` 将验证关卡 opt-in 化。off 期间发送路径**不调用** gate，因此验证成本为零。`hosts.toml` 增加 `[hermes]` 并仅配线 delivery (第 5 个工具)。配线验证由 `scripts/ci/check-session-pipeline-wiring.sh` (7 点) 负责。 |
| **Phase 80 Claude Code 2.1.143-2.1.152 + Codex 0.131-0.134 upstream refresh** | upstream-update, hooks, skill-editing, setup, codex, harness-plan | `A: 已实现 / C: 自动继承 / P: Plans 化 / Reject: 未确认 claim (B: 0 件)`。将 `docs/upstream-update-snapshot-2026-05-27.md` + `docs/upstream-adoption-plan-2026-05-27.md` 连接到 Plans `80.1.1`-`80.1.6`。Claude: `disallowed-tools`, `/reload-skills`, `SessionStart.reloadSkills`, `MessageDisplay` opt-in policy, `/code-review` rename, `claude agents --json`, Auto mode consent 废止 (维持 Harness default)。Codex: `--profile` primary, curl/PowerShell installer docs, MCP environment/OAuth (defer), read-only MCP parallelism (inherit). |
| **Phase 69 Claude Code 2.1.133-2.1.142 后续活用** | upstream-update, hooks, guardrails, agents, harness-plan, harness-work | `A: 已实现 / C: 自动继承 / P: Plans 化 (B: 0 件)`。将 `docs/upstream-update-snapshot-2026-05-15.md` 分解为 Tier 1 5 件 (`worktree.baseRef` template 显式 / hooks `$CLAUDE_EFFORT` rule / `autoMode.hard_deny` baseline 7 件 / hook `args` exec form + `continueOnBlock` + SessionStart command-only rules / hook `terminalSequence` opt-in 实现) + Tier 2 5 件 (CC native `/goal` 也遵循 Plans.md SSOT 的 policy / `claude agents` agent-view policy + 9 flag 使用条件 / background permission mode 保持的 Worker 期望值 / `claude plugin details` 的 CI 辅助信息化 / Phase 69 rule SSOT)。新设 `.claude/rules/hooks-2.1.139-plus.md` 与 `docs/agent-view-policy.md`，在 `templates/claude/settings.security.json.template` 中将 `worktree.baseRef: "fresh"` / `autoMode.hard_deny` 追加为 baseline (向 `.claude-plugin/settings.json` 的手动 merge 因 self-write guardrail 由 release operator 操作)、通过 `scripts/lib/terminal-notify.sh` 让 `webhook-notify.sh` 与 `notification-handler.sh` 在 `HARNESS_TERMINAL_NOTIFY` opt-in 下 emit `terminalSequence`。 |
| **Phase 67 Codex 0.130.0 stable snapshot** | upstream-update, setup, codex, harness-review | `A: 强化验证 / C: 自动继承 / P: Plans 化 (B: 0 件)`。将 `docs/upstream-update-snapshot-2026-05-10.md` 连接到 Plans `67.1.1`-`67.1.4`，对 `rust-v0.130.0` stable 的 `codex remote-control`, plugin-bundled hooks, plugin sharing metadata, app-server Thread pagination APIs, Bedrock `aws login`, selected-environment `view_image`, live threads from latest config snapshot, `apply_patch` 之后的 turn diffs, ThreadStore summaries/resume/fork, `response.processed`, Windows sandbox runtime bin cache, `cargo install --locked`, OTel trace metadata, built-in MCPs, `CODEX_HOME` environments TOML provider 做了 A/C/P 分类。 |
| **Phase 62 Claude Code 2.1.112-2.1.132 后续活用 + Opus 4.7 follow-up** | upstream-update, harness-loop, breezing, harness-review, guardrails, hooks | `A: 强化验证 / C: 自动继承 (B: 0 件)`。将 `docs/upstream-update-snapshot-2026-05-07.md` 连接到 Plans `62.1.1`-`62.3.1`。Tier 1: subagent stall 2 层防御 (CC 600s + elicitation-handler)、`ENABLE_PROMPT_CACHING_1H` 1h cache opt-in for long-running、hooks `type: "mcp_tool"` 采用判断 (= 保留)、`sandbox.network.deniedDomains` baseline 扩展 (template canonical 9 件)、R06/R11/R12 wrapper bypass test (env/sudo/watch × 3 = 9 例)。Tier 2: `PostToolUse.updatedToolOutput` opt-in handler + audit、agent permissionMode reaffirmation (Phase 59.2.3 方针 gate)、`skill_activated.invocation_trigger` privacy-first telemetry、`CLAUDE_CODE_SESSION_ID` env policy 4 经路、`skillOverrides` 3 mode governance。 |
| **Phase 61 Sandbagging-Aware Weak-Supervision Harness** | harness-review, harness-loop, harness-mem | 连接到 `docs/sandbagging-aware-weak-supervision.md` 与 `docs/weak-supervision-elicitation-snapshot-2026-05-06.md`。通过 `weak-supervision-report.v1` / `elicitation-event.v1` / `.claude/state/elicitation/events.jsonl` 记录伪装的成果・弱评分・反例，用于 Advisor cue 与 Reviewer 检测。Advisor 仍为 `PLAN/CORRECTION/STOP`，Reviewer 仍为最终判定。 |
| **Issue #105 English default + Japanese opt-in CI gate** | setup, harness-work, CI | 新的分发面默认英文，而日语 opt-in UX、双语技能元数据、setup 渲染与 mirror 一致性由 i18n 回归套件锁定。 |
| **Phase 58 Claude Code 2.1.120-2.1.126 / Codex 0.125.0-0.128.0 snapshot** | upstream-update, harness-review, setup, codex | `A: 强化验证 / P: Plans 化`。将 `docs/upstream-update-snapshot-2026-05-03.md` 与 `docs/upstream-followups-phase58-2026-05-03.md` 连接到 Plans `58.1.1`-`58.3.2`，对 Claude Code `--dangerously-skip-permissions`, `PostToolUse.updatedToolOutput`, MCP `alwaysLoad`, `claude plugin prune`, `claude project purge`, Codex permission profiles, `codex exec --json` reasoning tokens, plugin-bundled hooks, `/goal`, MultiAgentV2, and `0.129.0-alpha.2` watch status 做 A/C/P 分类后，将 runtime 实现切为 protected path taxonomy / output governance / Codex profile migration 的后续 task。 |
| **Phase 56 Claude Code 2.1.119 / Codex 0.124.0 snapshot** | upstream-update, harness-review, setup | `A: 强化验证`。将 `docs/upstream-update-snapshot-2026-04-25.md` 与 `docs/upstream-followups-phase56-2026-04-25.md` 连接到 Plans `56.1.1`-`56.2.4`，对 `--print` frontmatter parity, `PostToolUse.duration_ms`, status line effort/thinking, `prUrlTemplate`, Codex stable hooks, multi-environment app-server, and `0.125.0-alpha.2` watch status 做 A/C/P 分类后，用 tests 固定 statusline 追随与 docs-only safe default。 |
| **Task tool 指标** | parallel-workflows | 汇总子 agent 的 token/工具/时间 |
| **`/debug` 命令** | troubleshoot | 诊断复杂会话问题 |
| **PDF 页面范围** | notebookLM, harness-review | 高效处理大型文档 |
| **Git log 标志** | harness-review, CI, harness-release | 结构化提交分析 |
| **OAuth 认证** | codex-review | 非 DCR 对应 MCP 服务器的设置 |
| **68% 内存优化** | session-memory, session | 积极使用 `--resume` |
| **子 agent MCP** | task-worker | 并行执行时的 MCP 工具共享 |
| **Reduced Motion** | harness-ui | 无障碍设置 |
| **TeammateIdle/TaskCompleted Hook** | breezing | 团队监控自动化 |
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | 持久化学习 |
| **Fast mode (Opus 4.6)** | 全部技能 | 高速输出模式 |
| **自动记忆记录** | session-memory | 会话间知识的自动持久化 |
| **技能预算缩放** | 全部技能 | 自动调整到上下文窗口的 2% |
| **Task(agent_type) 限制** | agents/ | 子 agent 类型限制 |
| **Plugin settings.json** | setup | init token 削减・即时安全保护 |
| **Worktree isolation** | breezing, parallel-workflows | 同一文件并行写入安全化 |
| **Background agents** | generate-video | 异步场景生成 |
| **ConfigChange hook** | hooks | 设置变更审计 |
| **last_assistant_message** | session-memory | 会话质量评价 |
| **Sonnet 4.6 (1M context)** | 全部技能 | 大规模上下文处理 |
| **内存泄漏修复 (v2.1.50〜v2.1.63)** | breezing, work | 长时间团队会话稳定性提升 |
| **`claude agents` CLI (v2.1.50)** | troubleshoot | agent 定义诊断・确认 |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Worktree 生命周期自动 setup・cleanup（已实现） |
| **`claude remote-control` (v2.1.51)** | 已调研・将来对应 | 外部构建与本地环境服务 |
| **`/simplify` (v2.1.63)** | work | Phase 3.5 Auto-Refinement: 实现后的自动代码精炼 |
| **`/batch` (v2.1.63)** | breezing | 横向展开任务的并行迁移委派 |
| **`code-simplifier` 插件** | work | `--deep-simplify` 时的深度重构 |
| **HTTP hooks (v2.1.63)** | hooks | 提供 JSON POST 模板。`HARNESS_WEBHOOK_URL` 设置时启用 TaskCompleted 通知 |
| **Auto-memory worktree 共享 (v2.1.63)** | breezing | worktree agent 间共享内存 |
| **`/clear` 技能缓存重置 (v2.1.63)** | troubleshoot | 技能开发时的缓存问题诊断 |
| **`ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)** | setup | claude.ai MCP 服务器的禁用选项 |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | 用多要素评分对复杂任务自动注入 ultrathink |
| **Agent hooks (v2.1.68)** | hooks | 通过 type: "agent" 的 LLM agent 代码质量 guard |
| **Opus 4/4.1 删除（v2.1.68）** | — | 从 first-party API 删除。自动迁移到 Opus 4.6 |
| **`${CLAUDE_SKILL_DIR}` 变量 (v2.1.69)** | 全部技能 | 使技能内引用路径不依赖执行环境地解析 |
| **InstructionsLoaded hook (v2.1.69)** | hooks | 追踪会话前的 instructions 加载事件 |
| **`agent_id` / `agent_type` 追加 (v2.1.69)** | hooks, breezing | 稳定 teammate 的识别・角色判定 |
| **`{"continue": false}` teammate 响应 (v2.1.69)** | breezing | 实现全部任务完成时自动停止 |
| **`/reload-plugins` (v2.1.69)** | 全部技能 | 技能・hook 编辑后的即时反映 |
| **`includeGitInstructions: false` (v2.1.69)** | work, breezing | 不需要 git 指示场景的 token 削减 |
| **`git-subdir` plugin source (v2.1.69)** | setup, release | 支持子目录管理的 plugin source |
| **Auto Mode (RP Phase 1)** | breezing, work | CC native 功能。Harness 侧仅做 PermissionDenied 追踪。判断逻辑未实现。现行 default 为 `bypassPermissions` |
| **Per-agent hooks (v2.1.69+)** | agents/ | 在 agent 定义的 frontmatter 中追加 `hooks` 字段。Worker 设置 PreToolUse guard、Reviewer 设置 Stop 日志 |
| **Agent `isolation: worktree` (v2.1.50+)** | agents/worker | 在 Worker agent 定义中追加 `isolation: worktree`。并行写入时自动 worktree 分离 |
| **Compaction 图像保持 (v2.1.70)** | notebookLM, harness-review | 在摘要请求中保持图像。改善 prompt cache 复用 |
| **子 agent 最终报告简洁化 (v2.1.70)** | breezing, harness-work | 削减子 agent 完成报告的 token 消耗 |
| **`--resume` 技能列表再注入废止 (v2.1.70)** | session | 会话恢复时节省约 600 tokens |
| **Plugin hooks 修复 (v2.1.70)** | hooks | Stop/SessionEnd 在 /plugin 后触发、模板冲突消除、WorktreeCreate/Remove 正常工作 |
| **Teammate 嵌套防止追加修复 (v2.1.70)** | breezing | 在 v2.1.69 对应基础上追加嵌套防止修复 |
| **PostToolUseFailure hook (v2.1.70)** | hooks | 工具调用失败时触发的新 hook 事件 |
| **`/loop` + Cron 调度 (v2.1.71)** | breezing, harness-work | 用 `/loop 5m <prompt>` 定期执行。用于任务进度自动监控 |
| **Background Agent 输出路径修复 (v2.1.71)** | breezing, parallel-workflows | 完成通知中包含输出文件路径。压缩后也能回收结果 |
| **`--print` 团队 agent hang 修复 (v2.1.71)** | CI 连携 | 修复 `--print` 模式下团队 agent hang |
| **Plugin 安装并行执行修复 (v2.1.71)** | breezing | 多实例时插件状态稳定化 |
| **Marketplace 改善 (v2.1.71)** | setup | @ref 解析器修复、update merge conflict 修复、MCP server 去重、/plugin uninstall 使用 settings.local.json |
| **Subagent `background` 字段 (v2.1.71+)** | breezing, parallel-workflows | 在 agent 定义中追加 `background: true`。始终作为后台任务执行 |
| **Subagent `local` 内存 scope (v2.1.71+)** | agents/ | 通过 `memory: local` 保存到 `.claude/agent-memory-local/`。分离不提交到 VCS 的高机密学习 |
| **Agent Teams 实验 flag (v2.1.71+)** | breezing | 通过 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量启用 Agent Teams。已官方文档化 |
| **`/agents` 命令 (v2.1.71+)** | troubleshoot, setup | agent 的交互管理 UI。用 GUI 创建・编辑・删除・一览 |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | CC native 功能。Harness 侧无默认设置（CronCreate 工具可用） |
| **`CronCreate/CronList/CronDelete` 工具 (v2.1.71+)** | breezing, harness-work | `/loop` 的内部工具。会话内创建・管理定期任务 |
| **`CLAUDE_CODE_DISABLE_CRON` 环境变量 (v2.1.71+)** | setup | `=1` 禁用 Cron 调度器。面向以安全策略限制定期执行的环境 |
| **`--agents` CLI flag (v2.1.71+)** | breezing, CI | 用 JSON 传入会话级 agent 定义。不保存到磁盘的临时 agent 构成 |
| **`ExitWorktree` 工具 (v2.1.72)** | breezing, harness-work | 以编程方式离开 worktree 会话的工具 |
| **Effort levels 简化 (v2.1.72)** | harness-work | 废止 `max`，`low/medium/high` 3 段 + `○ ◐ ●` 符号。用 `/effort auto` 重置默认 |
| **Agent tool `model` 参数复活 (v2.1.72)** | breezing | per-invocation model override 再次可用 |
| **`/plan` description 参数 (v2.1.72)** | harness-plan | 可像 `/plan fix the auth bug` 这样带说明进入 plan 模式 |
| **并行工具调用修复 (v2.1.72)** | breezing, harness-work | Read/WebFetch/Glob 失败不再取消 sibling 调用（仅 Bash 错误级联） |
| **Worktree isolation 修复 (v2.1.72)** | breezing | Task resume 时恢复 cwd、后台通知包含 worktreePath |
| **`/clear` 后台 agent 保持 (v2.1.72)** | breezing | `/clear` 仅停止前台任务。后台 agent 继续存活 |
| **Hooks 修复群 (v2.1.72)** | hooks | transcript_path 修复、PostToolUse 双重显示修复、async hooks stdin 修复、skill hooks 双重触发修复 |
| **HTML 注释隐藏 (v2.1.72)** | 全部技能 | CLAUDE.md 的 `<!-- -->` 在自动注入时隐藏。Read 工具仍可见 |
| **Bash auto-approval 追加 (v2.1.72)** | guardrails | `lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind` 追加到许可列表 |
| **prompt cache 修复 (v2.1.72)** | 全部技能 | SDK `query()` 的 cache 无效化修复。输入 token 成本最多削减 12 倍 |
| **Output Styles (v2.1.72+)** | 全部技能 | 在 `.claude/output-styles/` 定义自定义输出样式。`harness-ops` 提供 Plan/Work/Review 的结构化输出 |
| **`permissionMode` in agent frontmatter (v2.1.72+)** | agents/ | 在 agent 定义 YAML 中显式声明 `permissionMode`。spawn 时不再需要 `mode` 指定 |
| **Agent Teams 官方最佳实践 (v2.1.72+)** | breezing | 将 5-6 tasks/teammate 指南、`teammateMode` 设置、plan approval 模式反映到 team-composition |
| **Sandboxing (`/sandbox`)** | breezing, harness-work | OS 级文件系统/网络隔离。`bypassPermissions` 的补充层 |
| **`opusplan` 模型别名** | breezing | Plan 时自动切换到 Opus、执行时切换到 Sonnet。最适合 Lead 的 Plan → Execute 流程 |
| **`CLAUDE_CODE_SUBAGENT_MODEL` 环境变量** | breezing, harness-work | 统一指定子 agent 的模型。集中控制 Worker/Reviewer 的模型 |
| **`availableModels` 设置** | setup | 可用模型的限制列表。企业运营中的模型治理 |
| **Checkpointing (`/rewind`)** | harness-work | 会话状态追踪・回退・摘要。支持安全探索与实验 |
| **Code Review (managed service)** | harness-review | 多 agent PR 审查 + `REVIEW.md`。面向 Teams/Enterprise 的 Research Preview |
| **Status Line (`/statusline`)** | 全部技能 | 用自定义 shell 脚本显示状态栏。常时监控上下文使用量・成本・git 状态 |
| **1M Context Window (`sonnet[1m]`)** | harness-review, breezing | 用 100 万 token 上下文窗口进行大规模代码库分析 |
| **Per-model Prompt Caching Control** | 全部技能 | 用 `DISABLE_PROMPT_CACHING_*` 按模型控制缓存。调试・成本优化 |
| **`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`** | harness-work | 通过禁用 Adaptive Reasoning 恢复到固定 thinking budget。可预测的成本控制 |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | 用浏览器自动化进行 UI 测试・表单输入・控制台调试。用 `/chrome` 在会话内切换 |
| **LSP 服务器集成 (`.lsp.json`)** | setup | CC native 功能。Harness 侧无 `.lsp.json` 默认设置（可用 `/setup lsp` 单独设置） |
| **`SubagentStart`/`SubagentStop` matcher (v2.1.72+)** | breezing, hooks | 在 settings.json 级别按 agent type 分别监控子 agent 生命周期。分别追踪 Worker/Reviewer/Scaffolder/Video Generator |
| **Agent Teams: Task Dependencies** | breezing | 任务间依赖的自动管理。依赖完成自动 unblock 被 block 的任务。用文件锁防止 claiming 竞争 |
| **`--teammate-mode` CLI flag (v2.1.72+)** | breezing | 按会话切换 `in-process`/`tmux` 显示模式。`claude --teammate-mode in-process` |
| **`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` (v2.1.72+)** | setup | `=1` 禁用全部后台任务功能。面向以安全策略限制后台执行的环境 |
| **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (v2.1.72+)** | breezing, harness-work | 调整子 agent 的 auto-compaction 阈值（默认 95%）。`50` 时早期压缩、提升长时间 Worker 稳定性 |
| **`cleanupPeriodDays` 设置 (v2.1.72+)** | setup | 子 agent transcript 的自动清理周期（默认 30 天） |
| **`/btw` 侧问题 (v2.1.72+)** | 全部技能 | 保持当前上下文的短问题。无工具访问、不留在历史中。子 agent 启动的轻量替代 |
| **Plugin CLI 命令群 (v2.1.72+)** | setup | `claude plugin install/uninstall/enable/disable/update` + `--scope` flag。支持脚本自动化 |
| **Remote Control 强化 (v2.1.72+)** | 已调研・将来对应 | 用 `/remote-control` (`/rc`) 从会话内启用。`--name`, `--sandbox`, `--verbose` flag。用 `/mobile` 显示二维码。支持自动重连 |
| **`skills` 字段 in agent frontmatter (v2.1.72+)** | agents/ | 向子 agent 预加载技能。向 Worker 注入 `harness-work`+`harness-review`、向 Reviewer 注入 `harness-review`、向 Scaffolder 注入 `harness-setup`+`harness-plan`（已实现） |
| **`modelOverrides` 设置 (v2.1.73)** | setup, breezing | 将模型选择器条目映射到 Bedrock ARN 等自定义 provider 模型 ID |
| **`/output-style` 弃用 (v2.1.73)** | 全部技能 | 迁移到 `/config`。输出样式选择整合到配置菜单 |
| **Bedrock/Vertex Opus 4.6 默认化 (v2.1.73)** | breezing | 云 provider 的默认 Opus 从 4.1 更新到 4.6 |
| **`autoMemoryDirectory` 设置 (v2.1.74)** | session-memory, setup | 自定义自动记忆的保存路径。支持项目固有的记忆分离 |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | 可设置 SessionEnd hook 的超时（以往固定 1.5 秒 kill） |
| **Full model ID 修复 (v2.1.74)** | agents/, breezing | `claude-opus-4-6` 等完整模型 ID 在 agent frontmatter・JSON config 中可识别 |
| **Streaming API 内存泄漏修复 (v2.1.74)** | breezing, harness-work | 修复流式响应缓冲区的无限制 RSS 增大 |
| **`--remote` / Cloud Sessions** | breezing, harness-work | 用 `--remote` 从终端启动云会话。异步任务执行 |
| **`/teleport` (`/tp`)** | session | 将云会话拉取到本地终端 |
| **`CLAUDE_CODE_REMOTE` 环境变量** | hooks, session-env-setup | 检测云 vs 本地执行。用于 hook 条件分支 |
| **`CLAUDE_ENV_FILE` SessionStart 持久化** | hooks, session-env-setup | 从 SessionStart hook 向后继 Bash 命令持久化环境变量 |
| **Slack Integration (`@Claude`)** | — | 将来对应（以 Teams/Enterprise 为前提）。Harness 侧无实现 |
| **Server-managed settings (public beta)** | setup | 通过服务器分发进行批量设置管理。面向 Teams/Enterprise |
| **Microsoft Foundry** | setup, breezing | 作为新云 provider 追加 |
| **`PreCompact` hook** | hooks | compact 前若 Plans.md 未保存则先做 pathspec 限定 auto-checkpoint 提交后继续（失败时或 `precompactAutoCommit: false` 时才 block） |
| **`Notification` hook event** | hooks | 通知触发时的自定义 handler（已实现） |
| **`/context` 命令 (v2.1.74)** | all skills | 上下文消耗可视化与优化建议 |
| **`maxTurns` agent 安全限制** | agents/ | 通过 turn 上限防止失控。Worker: 100, Reviewer: 50, Scaffolder: 75 |
| **Output token limits 64k/128k (v2.1.77)** | all skills | Opus 4.6 / Sonnet 4.6 默认 64k、上限 128k token |
| **`allowRead` sandbox 设置 (v2.1.77)** | harness-review | 在 `denyRead` 内重新允许特定路径的读取 |
| **PreToolUse `allow` 尊重 `deny` (v2.1.77)** | guardrails | hook `allow` 不覆盖 settings.json `deny` |
| **Agent `resume` → `SendMessage` (v2.1.77)** | breezing | 废止 Agent tool `resume`，迁移到 `SendMessage({to: agentId})` |
| **`/branch` (旧 `/fork`) (v2.1.77)** | session | `/fork` → `/branch` 重命名。别名存续 |
| **`claude plugin validate` 强化 (v2.1.77)** | setup | 追加 frontmatter + hooks.json 语法验证 |
| **`--resume` 45% 高速化 (v2.1.77)** | session | fork-heavy 会话恢复的高速化・内存削减 |
| **Stale worktree 竞争修复 (v2.1.77)** | breezing | 防止误删活动 worktree |
| **`StopFailure` hook event (v2.1.78)** | hooks | 捕获 API 错误时会话停止失败 |
| **`${CLAUDE_PLUGIN_DATA}` 变量 (v2.1.78)** | hooks, setup | 插件更新后仍持久化的状态目录 |
| **Agent `effort`/`maxTurns`/`disallowedTools` frontmatter (v2.1.78)** | agents/ | 插件 agent 的声明式控制 |
| **`deny: ["mcp__*"]` 修复 (v2.1.78)** | setup | 在 settings.json deny 中正确阻止 MCP 工具 |
| **`ANTHROPIC_CUSTOM_MODEL_OPTION` (v2.1.78)** | setup | 自定义模型选择器条目 |
| **`--worktree` skills/hooks 读入修复 (v2.1.78)** | breezing | worktree flag 时正常加载技能・hook |
| **Skill `effort` frontmatter (v2.1.80)** | harness-work, harness-review, harness-plan, harness-release | 让 5 动词技能本身持有思考量，提升重流程的初动质量 |
| **Agent `initialPrompt` frontmatter (v2.1.83)** | agents/ | 按角色稳定 Worker / Reviewer / Scaffolder 的最初 1 turn |
| **`sandbox.failIfUnavailable` (v2.1.83)** | setup, guardrails | sandbox 启动失败时不 silently fallback 到 unsandboxed |
| **`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` (v2.1.83)** | hooks, setup | 缩小 hook / Bash / MCP stdio subprocess 的凭证泄露面 |
| **`TaskCreated` / `CwdChanged` / `FileChanged` hooks (v2.1.83-2.1.84)** | hooks, session | 追加 reactive state tracking 与 Plans / 规则再读提醒 |
| **Rules / skills `paths:` YAML list (v2.1.84)** | setup, localize-rules | 结构化保持多个 glob，使规则适用范围更易读、更难坏 |
| **Hooks conditional `if` field (v2.1.85)** | hooks, guardrails | 将 `PermissionRequest` 限定到安全 Bash 与编辑类，减少不必要的 hook 启动与误警告 |
| **Large session truncation 修复 (v2.1.78)** | session | 修复 5MB 超会话的截断 |
| **`--console` auth flag (v2.1.79)** | setup | Anthropic Console API 计费认证 |
| **Turn duration 显示 (v2.1.79)** | all skills | 在 `/config` 中切换 turn 执行时间显示 |
| **`CLAUDE_CODE_PLUGIN_SEED_DIR` 多值支持 (v2.1.79)** | setup | 指定多个 seed 目录 |
| **SessionEnd hooks `/resume` 修复 (v2.1.79)** | hooks | 交互式会话切换时 SessionEnd 正常触发 |
| **18MB startup memory 削减 (v2.1.79)** | all skills | 削减启动时内存使用量 |
| **MCP tool description cap 2KB (v2.1.84)** | all skills | 防止 OpenAPI 来源的庞大 MCP schema 导致上下文膨胀。CC 自动继承 |
| **`TaskCreated` hook blocking (v2.1.84)** | hooks | TaskCreate 时 hook 以同步阻塞方式触发。runtime-reactive 用于 state tracking |
| **Idle-return prompt 75min (v2.1.84)** | session | 离席 75 分钟以上后建议 `/clear`。防止 stale 会话浪费 token。CC 自动继承 |
| **`X-Claude-Code-Session-Id` header (v2.1.86)** | setup | 在 API 请求中追加会话 ID header。可用于代理侧聚合。CC 自动继承 |
| **Cowork Dispatch 修复 (v2.1.87)** | breezing | Cowork Dispatch 的消息投递修复。CC 自动继承 |
| **`PermissionDenied` hook event (v2.1.89)** | hooks, breezing | auto mode classifier 拒绝时触发。用 `{retry:true}` 引导重试。实现 Breezing Worker 的拒绝追踪・Lead 通知 |
| **`"defer"` permission decision (v2.1.89)** | hooks, breezing | 从 PreToolUse 返回 `"defer"` 则暂停 headless 会话→resume 时再评估。Breezing 的安全阀 |
| **`updatedInput` + `AskUserQuestion` (v2.1.89+)** | hooks | 在 headless 环境中外部 UI / 显式 answer source 收集问题回答，仅将已知同义词归并到 canonical option label 并返回 `updatedInput.answers`。A: 已实现 (`ask-user-question-normalize`) |
| **Hook output >50K disk save (v2.1.89)** | hooks | 大输出 hook 保存到磁盘＋预览。防止上下文膨胀 |
| **Hooks `if` compound command fix (v2.1.89)** | hooks | 修复 `ls && git push` 或 `FOO=bar git push` 这类复合命令能匹配 `if` 条件。CC 自动继承 |
| **Autocompact thrash loop fix (v2.1.89)** | all skills | 连续 3 次 compact→立即再填充则输出 actionable error 并停止。CC 自动继承 |
| **Nested CLAUDE.md re-injection fix (v2.1.89)** | all skills | 修复长会话中 CLAUDE.md 被再注入数十次的 bug。CC 自动继承 |
| **Thinking summaries default off (v2.1.89)** | all skills | 停止 thinking summaries 的默认生成。用 `showThinkingSummaries:true` 恢复。CC 自动继承 |
| **PreToolUse exit 2 JSON fix (v2.1.90)** | hooks, guardrails | 修复 JSON stdout + exit 2 时的阻塞行为。pre-tool.sh 的 deny 更可靠地工作 |
| **PostToolUse format-on-save fix (v2.1.90)** | hooks | 修复 PostToolUse hook 重写文件后的 Edit/Write 失败。CC 自动继承 |
| **`--resume` prompt-cache miss fix (v2.1.90)** | session | 修复 v2.1.69 以后的回归 bug。deferred tools/MCP/agents 使用时的 resume cache miss。CC 自动继承 |
| **SSE/transcript performance (v2.1.90)** | all skills | SSE 帧 O(n²)→O(n)、transcript writes 二次函数→线性。CC 自动继承 |
| **`/powerup` interactive lessons (v2.1.90)** | — | Claude Code 功能学习的动画演示。CC 自动继承 |
| **MCP `maxResultSizeChars` 500K (v2.1.91)** | hooks, setup | 通过 `_meta["anthropic/maxResultSizeChars"]` 将 MCP 工具结果最大尺寸扩展到 500K。可用于大 harness-mem 结果等 |
| **`disableSkillShellExecution` setting (v2.1.91)** | setup, guardrails | 禁用技能内的 shell 执行。面向安全要求高的环境 |
| **Plugin `bin/` directory (v2.1.91)** | setup | 插件可在 `bin/` 目录附带编译好的二进制。未来分发形态扩展候选 |
| **Transcript chain breaks fix (v2.1.91)** | session | 修复 `--resume` 时的 transcript 中断。CC 自动继承 |
| **Subagent spawning fix (v2.1.92)** | breezing | 修复「Could not determine pane count」。提升 Breezing 稳定性。CC 自动继承 |
| **`forceRemoteSettingsRefresh` (v2.1.92)** | — | 面向 Teams/Enterprise 的 fail-closed remote settings。CC 自动继承 |
| **`/usage` usage / cost / stats view (v2.1.92, v2.1.118 refresh)** | all skills | 将 `/usage` 作为用量・成本・统计入口处理。旧 `/cost` / `/stats` 作为打开相关 tab 的 shortcut 由 CC 自动继承 |
| **Linux `apply-seccomp` helper (v2.1.92)** | setup | 强化 sandbox unix-socket 阻塞。CC 自动继承 |
| **Plugin `skills` 字段显式化 (v2.1.94)** | setup | 在 plugin.json 中显式声明 `"skills": ["./"]`。CC 2.1.94 中技能调用名以 frontmatter `name` 为基准。A: 已实现 (plugin.json 更新) |
| **Monitor 工具 (v2.1.98)** | breezing/harness-work/ci/deploy/harness-review | 长时间进程的 stdout 流式监控。以比 polling 更低的延迟・更低的 token 消耗追踪 CI/部署进度。A: 已实现 (allowed-tools + 运用指南 + Feature Table) |

## Phase 44 补充表

此补充部分将 `2.1.99-2.1.111` 与 Opus 4.7 单独汇总，便于查看。

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **无公开 changelog 的版本 (`2.1.99`, `2.1.100`, `2.1.102`, `2.1.103`, `2.1.104`, `2.1.106`)** | all skills | 无显式追随项目。仅基线确认 | `C: CC 自动继承` |
| **`/team-onboarding` 与 `2.1.101` 系稳定化** | setup, session | onboarding / resume UX 提升 | `C: CC 自动继承` |
| **`PreCompact` hook (v2.1.105)** | hooks, breezing | 作为长时间 Worker 执行中 block compaction 的设计基础 | `A: 显式追随对象` |
| **plugin `monitors` manifest (v2.1.105)** | hooks, setup, breezing | 在 session start / skill invoke 时 auto-arm monitor | `A: 显式追随对象` |
| **thinking hint 改善 (v2.1.107, v2.1.109)** | all skills | 长考中的 UI 提示改善 | `C: CC 自动继承` |
| **`ENABLE_PROMPT_CACHING_1H` (v2.1.108)** | session, work, breezing | 使 1 小时 prompt cache TTL 可 opt-in 运用 | `A: 显式追随对象` |
| **recap / built-in slash command discovery (v2.1.108)** | session, all skills | 恢复质量与 slash command 使用提升 | `C: CC 自动继承` |
| **permission deny 再评估 fix (v2.1.110)** | hooks, guardrails | 将 `updatedInput` 与 mode 更新后仍再评估 deny 的前提反映到 docs 与测试视角 | `A: 显式追随对象` |
| **`/tui`, focus, recap 周边的 UX 改善 (v2.1.110)** | session | 画面显示与 remote client 体验改善 | `C: CC 自动继承` |
| **`xhigh` effort (v2.1.111)** | harness-review, advisor, docs | 采用 `high` 与 `max` 之间的中间强度作为正式对象 | `A: 显式追随对象` |
| **`/ultrareview` (v2.1.111)** | harness-review, docs | 整理 cloud 多 agent review 与 `/harness-review` 的角色 | `A: 显式追随对象` |
| **Auto mode no longer requires `--enable-auto-mode` (v2.1.111)** | docs, guardrails | 将 Auto Mode 的前提表述从旧 enable flag 依赖更新 | `A: 显式追随对象` |
| **`/effort` slider 与 model picker 连携 (v2.1.111)** | harness-review, docs | 使 effort 更容易在会话中调整 | `A: 显式追随对象` |
| **read-only bash permission prompt 缓和 (v2.1.111)** | guardrails, docs | 更新安全 read-only 命令的 prompt 触发减少前提 | `C: CC 自动继承` |

### Opus 4.7 部分

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **literal instruction following** | agents, skills, docs | 减少歧义表达，具体化指示与停止条件 | `A: 显式追随对象` |
| **`xhigh` effort** | harness-review, advisor, docs | 仅对重 review / advisory 提升一层 thinking | `A: 显式追随对象` |
| **task budgets** | docs, future work | 先整理与现有 `max_consults` / cost 控制的竞争 | `A: 显式追随对象` |
| **tokenizer 改善** | all skills | 受益于 token 效率改善 | `C: CC 自动继承` |
| **vision 2576px** | harness-review, docs | 更新高分辨率 review 的运用上限 | `A: 显式追随对象` |
| **memory 改善** | session-memory, docs | 使长时间执行与 resume 的说明符合新前提 | `A: 显式追随对象` |
| **`/ultrareview`** | harness-review, docs | 明确与 `/harness-review` 的分工 | `A: 显式追随对象` |
| **Auto Mode 扩大** | docs, guardrails | 去掉 enable flag 前提，作为常设功能处理 | `A: 显式追随对象` |

| **`context: fork` host CLAUDE.md 继承规格与 auto-start 回避模式 (Phase 46)** | harness-review | `context: fork` 技能在 isolated context 中运行，被 host CLAUDE.md 的 session-start rules override 而停止的现象已消除。将 host CLAUDE.md 继承规格与 auto-start 回避模式明文化到 `skill-editing.md`（Issue #84）。A: 已实现（SKILL.md Step 0 硬化 + `REVIEW_AUTOSTART` marker 契约） | `A: 已实现` |

**注记**:
此补充使用 `A` / `C` / `P`，`B` 为 `0` 件。
`A` 表示「Harness 侧有显式追随责任的项目」、`C` 表示「直接继承 Claude Code / Codex 本体更新的项目」、`P` 表示「本次不直接实现而是 Plans 化的项目」。

## Phase 51 补充表

此补充部分从 Claude Code `2.1.112-2.1.114` 与 Codex `0.121.0` 的一次信息中，仅分类要装载到 Harness 的项目。

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **AskUserQuestion `updatedInput.answers` bridge** | hooks, harness-plan, harness-release | 读取 `PreToolUse` 显式传入的 answers，仅将 `solo/team` 或 `scripted/exploratory` 等已知同义词归一化到 option label 以继续 headless 对话 | `A: 已实现` (`go/internal/hookhandler/ask_user_question_normalizer.go`, `hooks/hooks.json`, `tests/test-claude-upstream-integration.sh`) |
| **Claude Code 2.1.113 permission / sandbox hardening** | settings, guardrails | 设置 `sandbox.network.deniedDomains`，在 Harness guardrail 中也检测 `find -exec` / `-delete` 与 macOS dangerous rm paths | `A: 已实现` (`.claude-plugin/settings.json`, `go/internal/guardrail/helpers.go`, `tests/test-claude-upstream-integration.sh`) |
| **Claude Code 2.1.114 permission dialog crash fix** | hooks, team execution | Agent Teams teammate 的 permission dialog crash 修复 | `C: CC 自动继承` |
| **Claude/Codex upstream update Skills gate** | skills, review | 在 upstream update 实施前强制 version-by-version 分解表，同步 PR 对象 `skills/` / `codex/.codex/skills/` 与 local-only `.agents/skills/` 的判定 | `A: 已实现` (`claude-codex-upstream-update`, `cc-update-review`) |
| **Codex 0.121.0 marketplace / MCP Apps / memory controls** | setup, future Codex workflow | 将 plugin marketplace、MCP Apps tool calls、memory reset / cleanup、sandbox metadata 保留到 Harness 的 Codex 比较轴 | `P: Plans 化`。本次优先 Claude hardening 实现并切到 Plans |
| **Codex 0.121.0 secure devcontainer / bubblewrap** | setup, guardrails | 将 secure devcontainer profile 与 macOS Unix socket allowlist 作为未来 sandbox policy 比较对象 | `C: Codex 侧已调研 / Harness 无变更` |
| **Skills mirror 总点检** | skills, setup | 盘点 `.agents/skills` 的 Claude/Codex 置换 drift、Codex native tool model、memory/session path、media generation metadata | `P: Plans 化` (`docs/skills-audit-2026-04-20.md`) |

**注记**:
Phase 51 中 `B: 只写` 也为 `0` 件。Codex 0.121.0 的大项目不作为本次直接实现而是作为「Codex 比较轴」保留到 Plans，Claude Code 侧的 `AskUserQuestion.updatedInput` 与 2.1.113 hardening 则实现到 settings / Go / tests 并作为 `A`。

## Phase 52 补充表

此补充部分从 Claude Code `2.1.116` 与 Codex `0.122.0` / `0.123.0-alpha.2` 的一次信息中，分类为应直接实现到 Harness，还是应停留在自动继承 / Plans 化。详情记录在 `docs/upstream-update-snapshot-2026-04-21.md`。

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **Claude Code 2.1.116 resume / MCP / plugin updater UX refresh** | session, setup, MCP | 将 `/resume` 高速化、MCP startup deferred loading、plugin dependency auto-install 与 Harness 的 session / setup guidance 对照 | `C/P: 自动继承 + Plans 化`。不追加 Harness wrapper，保留为 plugin dependency policy 与 MCP health watch 的后续候选 |
| **Claude Code 2.1.116 dangerous-path safety / agent hooks refresh** | guardrails, agents | 将 sandbox auto-allow dangerous-path safety 与 main-thread `--agent` hooks 触发与现有 guardrail / agent policy 对照 | `C/P: 自动继承 + Plans 化`。维持 R05 guardrail，保留为 agent frontmatter policy audit |
| **Codex 0.122.0 plugin / Plan Mode / permission model** | codex workflow, setup, sandbox | 将 `/side`、fresh-context Plan Mode、plugin workflow、deny-read glob、tool discovery default-on 分类为 Codex mirror 改善候选 | `P: Plans 化`。与 Phase 51.2 的 Codex-native skill audit 一并处理 |
| **Codex 0.123.0-alpha.2 pre-release** | future compare | 对 release body 单薄的 alpha 不推测实现，作为 stable 化后的再确认对象 | `P: Plans 化`。不从 compare 推测实现 |
| **Upstream update Skills merge hardening** | skills, review, tests | 将 `cc-update-review` diff-aware 化，让 `claude-codex-upstream-update` 支持 no-op adaptation 并追加 mirror drift test | `A: 已实现` (`skills/cc-update-review`, `skills/claude-codex-upstream-update`, `tests/test-claude-upstream-integration.sh`) |

**注记**:
Phase 52 中 `B: 只写` 也为 `0` 件。Claude / Codex 本体自然改善的 UX 作为 `C`，叠加到 Harness 会变成双重责任的项目作为 `P` 连接到后续的 Codex-native skill audit / plugin policy。直接实现只聚焦 review findings 的复发防止，并用 test 固定 skill mirror drift 与 no-op adaptation。

## Phase 53 补充表

此补充部分从 Claude Code `2.1.117-2.1.118` 与 Codex `0.123.0` 的一次信息中，分类为应直接实现到 Harness，还是应停留在自动继承 / Plans 化。详情记录在 `docs/upstream-update-snapshot-2026-04-23.md`。

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **Claude Code `type: "mcp_tool"` hooks** | hooks, MCP diagnostics, tests | 不增加 shell script，小规模验证只读 MCP health / resource 诊断 hook | `A: 已实现`。53.1.2 将 manifest 追加视为 no-op，在常设 read-only diagnostic tool 与稳定 field 规格齐备之前不放入分发 hooks 的判断记录到 snapshot。不调用写入类 MCP tool 由 `tests/test-claude-upstream-integration.sh` 固定 |
| **Claude Code `claude plugin tag`** | harness-release, plugin release | 在确认 `VERSION` 与 `.claude-plugin/plugin.json` 同步后，创建带 plugin version validation 的 tag | `A: 计划实现`。53.1.3 中追加到 release flow / dry-run / test guidance |
| **Auto Mode `"$defaults"` extension** | permissions, sandbox, settings docs | 将 guidance 更新为不替换 built-in default，而是追加 Harness 自有规则的形式 | `A: 已实现`。53.1.4 将 `"$defaults"` 记录为 additive baseline，并用 snapshot・template・upstream integration test 固定不会与 R05 / `deniedDomains` 形成双重责任的理由 |
| **Plugin themes / managed settings / dependency auto-resolve** | setup, plugin policy, enterprise docs | 面向管理环境整理 `themes/`, `DISABLE_UPDATES`, `blockedMarketplaces`, `strictKnownMarketplaces`, dependency hints | `A: 已 docs 化`。53.1.5 新设 `docs/plugin-managed-settings-policy.md`，明记不叠加 Harness 自有 resolver 的方针。theme 附带判断在 snapshot 侧作为 `P` 保留 |
| **Claude Code UX / runtime fixes** | session, agents, MCP, search, effort | 整理 `/usage` 整合、`/resume` `/add-dir` 支持、`--agent` + `mcpServers`、stale session summary、native `bfs` / `ugrep`、高 effort default | `C/P: 自动继承 + Plans 化`。53.1.6 将不追加 wrapper 的理由记录到 snapshot，`--agent` + `mcpServers` 与 external forked subagent flag 作为 agent audit 候选保留为 `P` |
| **Codex 0.123.0 provider / model metadata** | Codex setup, provider policy | 将 built-in `amazon-bedrock` provider、AWS profile support、current `gpt-5.4` default metadata 反映到 Codex setup guidance | `A: 已 docs 化`。53.2.1 新设 `docs/codex-provider-setup-policy.md`，固定「Harness 分发 config 不固定 `model` / `model_provider`，仅 Bedrock 使用者加入 user / project config」的方针 |
| **Codex 0.123.0 MCP diagnostics / plugin loading** | troubleshoot, setup, Codex plugin docs | 将 `/mcp verbose`、diagnostics / resources / resource templates、`.mcp.json` 的 `mcpServers` 形式与 top-level server map 形式反映到 setup guidance | `A: 已 docs 化`。53.2.2 新设 `docs/codex-mcp-diagnostics.md`，固定「平时用 `/mcp`，遇到困难时才用 `/mcp verbose`」的步骤与不与 Claude Code 侧 MCP guidance 混淆的方针 |
| **Codex 0.123.0 realtime handoff silence** | harness-loop, breezing, long-running | 以 background agents 接收 transcript delta、不需要时能显式沉默为前提，整理中途报告频率 | `A: 已 docs 化`。53.2.3 固定 `harness-loop` 每 1 cycle 最终报告 1 次、`breezing` 每 task 完成 progress feed 1 次为基础，advisor / reviewer drift 不在 silence 对象内 |
| **Codex 0.123.0 sandbox / exec changes** | sandbox, execution policy | 追随 `remote_sandbox_config`、`codex exec` shared flags | `A: 已 docs 化`。53.2.4 追加 `docs/codex-sandbox-execution-policy.md`，固定每个 remote environment 的 sandbox 要件比较与 wrapper flag 重复削减可否 |
| **Codex 0.123.0 automatic bug fixes** | Codex long-running UX, session shell, review privacy | 记录 `/copy` rollback、manual shell follow-up queue、Unicode / dead-key、stale proxy env、VS Code WSL keyboard、review prompt leak | `C: Codex 自动继承`。53.2.5 明记不追加 workaround 的理由 |

**注记**:
Phase 53 中 `B: 只写` 也为 `0` 件。Feature Table 停留在入口，官方 URL 与 version-by-version 判断依据集中到 `docs/upstream-update-snapshot-2026-04-23.md`。`A` 连接到 Phase 53 的具体 task，`C` 作为本体修复的自动继承，`P` 作为不推测实现的未来判断处理。

Phase 53 closeout 将 Codex mirror / path drift 的广泛盘点保留到 Phase 51.2 的 Codex-native skill audit TODO。Phase 53 只关闭 upstream `0.123.0` 差异的具体反映，不提前处理 Phase 51.2.1-51.2.4 的 tool model / memory path / mirror path / media metadata 整理。

## Phase 69 补充表 (Claude Code 2.1.133-2.1.142)

此补充部分记载 Claude Code `2.1.133-2.1.142` 的 10 个版本如何分类为 Harness 的实现/自动继承/保留。一次信息与 version-by-version 判断依据请参照 `docs/upstream-update-snapshot-2026-05-15.md`。

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **Claude Code `worktree.baseRef` (2.1.133)** | settings, breezing, worker isolation | 用 `origin/<default>` (`fresh`) or 本地 `HEAD` (`head`) 显式指定 `--worktree` / `EnterWorktree` / agent-isolation worktree 的起点 | `A: 已实现` (`templates/claude/settings.security.json.template`)。Phase 69.1.1 在 template 中显式 baseline `fresh`，想带入 unpushed commits 的团队可在 project-level opt-in `head`。Plugin 本体 `.claude-plugin/settings.json` 因 self-write deny 由 release operator 手动 merge |
| **Claude Code hook `$CLAUDE_EFFORT` env + `effort.level` JSON (2.1.133)** | hooks, observability | 可从 hook handler / Bash subprocess 观测当前 effort | `A: 已实现` (`.claude/rules/hooks-2.1.139-plus.md`)。Phase 69.1.2 明文化「仅观测可、禁止 guard rail 的 effort 缓和」 |
| **Claude Code `settings.autoMode.hard_deny` (2.1.136)** | settings, guardrails, auto mode | Auto Mode classifier 能处理「无论许可意图都一定 deny」 | `A: 已实现` (`templates/claude/settings.security.json.template`)。Phase 69.1.3 使 template baseline 7 件 (`Bash(sudo:*)` / `Bash(rm -rf:*)` / `Bash(rm -fr:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git reset --hard:*)` / `mcp__codex__*`) 与 Harness deny 一致。Plugin 本体 `.claude-plugin/settings.json` 因 self-write deny 由 release operator 手动 merge |
| **Claude Code `claude agents` agent view (2.1.139-2.1.142)** | agents, breezing, operator workflow | 能在一个画面监控全部 CC session 的 operator entrypoint。`--cwd`, `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions` 的 9 flag 构成 dispatched background session | `A: 已实现` (`docs/agent-view-policy.md`, `docs/team-composition.md`, `agents/worker.md`)。Phase 69.2.2 明文化与 teammate spawn workflow (breezing skill) 的分离与各 flag 使用条件 |
| **Claude Code native `/goal` command (2.1.139)** | harness-plan, harness-work, Codex `/goal` 补充 | 能跨 turn 保持完成条件 | `A: 已实现` (`docs/codex-plugin-workflows-policy.md`)。Phase 69.2.1 将「仅限 session continuation memo」「不夺取 Plans.md SSOT」「不把 acceptance criteria 只放在 `/goal`」3 规则与 Codex `/goal` 整合 |
| **Claude Code `claude plugin details <name>` (2.1.139)** | plugin observability, CI 辅助 | 能看到 plugin 的 component 明细与 projected per-session token cost | `A: 已实现` (`docs/agent-view-policy.md`, `docs/upstream-update-snapshot-2026-05-15.md`)。Phase 69.2.4 定位为 CI / doctor 的辅助信息，docs 化 plugin 超过 session 预算阈值时的对应步骤 |
| **Claude Code hook `args: string[]` (exec form, 2.1.139)** | hooks, security, future-proof | 能不经 shell 直接 spawn command | `A: 已实现` (`.claude/rules/hooks-2.1.139-plus.md`)。Phase 69.1.4 rules 化「仅 path placeholder 时 exec form 优先，需要 shell 控制时维持现有 `command`」 |
| **Claude Code hook `PostToolUse.continueOnBlock` (2.1.139)** | hooks, guardrails | 可将 hook 的 rejection reason 反馈给 Claude 并继续 turn | `A: 已实现` (`.claude/rules/hooks-2.1.139-plus.md`)。Phase 69.1.4 rule 化「仅 diagnostic feedback 为 true、R01-R13 / secret / protected config 必须 `false`」 |
| **Claude Code hook `terminalSequence` (2.1.141)** | hooks, local notification | 无需 controlling terminal 即可触发 desktop 通知 / window title / bell | `A: 已实现` (`scripts/lib/terminal-notify.sh`, `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh`)。Phase 69.1.5 实现 `HARNESS_TERMINAL_NOTIFY` (`0` / `bell` / `title` / `osc9` / `notify`) opt-in。与现有 `HARNESS_WEBHOOK_URL` 独立 |
| **Claude Code background permission mode 保持 (2.1.141)** | agents, breezing | 通过 `/bg` / `←←` / `claude agents` 启动的 teammate 保持启动时 mode | `A: 已实现` (`agents/worker.md`, `docs/team-composition.md`)。Phase 69.2.3 明文化「Worker 无需 permission mode 再注入、即便 `bypassPermissions` 也不覆盖 settings.json deny」的期望值 |
| **Claude Code hook config error (SessionStart/Setup/SubagentStart 为 command-only, 2.1.142)** | hooks, validation | bootstrap 阶段的 hook 会拒绝 LLM 型 hook | `A: 已实现` (`.claude/rules/hooks-2.1.139-plus.md`)。Phase 69.1.4 在同 rule 内将「SessionStart/Setup/SubagentStart 仅限 `type: "command"`」grep-able 地显式化 |
| **CC 2.1.142 fast mode Opus 4.7 default + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE`** | model defaults | fast mode 始终以 Opus 4.7 运行 | `C: CC 自动继承`。Harness 已将 Opus 4.7 作为 default 处理，无需变更 |
| **CC 2.1.139 MCP stdio receives `CLAUDE_PROJECT_DIR`** | MCP setup | MCP server 能解析 project dir | `C: CC 自动继承` |
| **CC 2.1.139 `x-claude-code-agent-id` / `parent-agent-id` headers + OTEL attrs** | OTel | 提升 subagent 可观测性 | `C: CC 自动继承` |
| **CC 2.1.141 `claude agents --cwd`** | operator UX | 可按 directory scope 过滤 session list | `A: 已实现` (`docs/agent-view-policy.md`)。Phase 69.2.2 docs 化按 project 的分离运用 |
| **CC 2.1.141 Rewind "Summarize up to here"** | session | 保持 context compression 中间状态 | `C: CC 自动继承`。与 `.claude/rules/commit-safety.md` 的 `/undo` policy 一致 |
| **CC 2.1.133/2.1.136-2.1.142 runtime bug fixes (parallel session credential race / MCP `/clear` persistence / OAuth refresh / extended thinking redaction / `--resume` underscore / WSL2 image paste / agent color palette / settings hot-reload symlink / spinner amber / 大量 plugin/MCP/UX 修复)** | runtime | safety / stability | `C: CC 自动继承`。Harness 侧不追加 wrapper |

**注记**:
Phase 69 中 `B: 只写` 也为 `0` 件。Feature Table 停留在入口，官方 URL 与 version-by-version 判断依据集中到 `docs/upstream-update-snapshot-2026-05-15.md`。`A` 与实际 file 变更 (settings / hooks / rules / docs / scripts) 绑定，`C` 作为本体修复的自动继承，`P` 作为不推测实现的未来判断处理。

## Phase 133.6 补充表 (subagent depth/concurrency + sandbox credential-masking claim 验证)

此部分只反映先行 research agent 报告的 2 个 cluster 的 claim 用一次信息 (raw
`CHANGELOG.md`) 个别验证后的结果。不是完整版本同步
(`2.1.153`-`2.1.216` 未确认)。验证记录・引用来源: `docs/research/133-6-cc-cli-claim-verification.md`。

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-------------------|------|----------|
| **Subagent nested-spawn depth limit + 同时执行数上限 (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` / `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, 2.1.217/2.1.219)** | breezing, harness-work, harness-review | `confirmed`。2.1.217 将嵌套 spawn 默认 OFF + 同时执行数上限默认 20 可设置化，2.1.219 将默认 depth 从 1→3 缓和 (原文 "was 1")。`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` 与 breezing 的并行 worker 数、`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` 与 sub-agent 调用 further sub-agent 的设计 (worker → 内部 delegation 等) 可能相互作用 | `A: 已采用 (docs 反映)`。133.9 反映。在 `skills/breezing/SKILL.md` 与 `skills/harness-work/SKILL.md` 中明记 `--parallel N` 是期望值、实际同时执行数由 CC 决定 (超过 20 只进入等待队列不报错)。确认 spawn 深度 3 对 Lead(0) → Worker(1) → advisor(2) 与 Mode 1 的 Producer → Sub-Lead → Composer 都成立。**env 不显式设置在 Harness 侧，遵循 CC 默认** (覆盖默认会导致无法追随 CC 侧更新) |
| **Sandbox credential-masking (`mode: "mask"`, `extract`/`onExtractNoMatch`, JWT/AWS SigV4) + `sandbox.network.strictAllowlist` (2.1.219/2.1.221/2.1.224)** | guardrails, setup | `confirmed`。与 `denyRead` 的目录单位 deny 不同，是能按值单位 mask credential 的机构。注意 macOS 的文件 masking 会 fallback 到 `deny` (raw changelog 原文) | `P: Plans 化 (待实测)`。已在 `docs/sandbox-allowlist-recipe.md` 与 `.claude/rules/defense-layer-blast-radius.md` 追加采用讨论的 PROPOSAL 部分 (无实现・live 设置变更)。133.9 时点 **`not_observed`** — raw changelog 明记 macOS 的文件 masking 会 fallback 到 `deny`，本 repo 的执行环境是 macOS (`uname -s` = Darwin)，因此无法测有效性。**不是 `absent`**: Linux/WSL 下仍可能运行。手头有 docker，但尚未建立「在 Linux 容器内启用 sandbox 运行 CC CLI」的经路。要测就从那里开始 |

## 功能详情

### Task tool 指标

可汇总子 agent 消耗的 token 数・工具调用数・执行时间。
`parallel-workflows` 技能汇总多个子 agent 的指标用于成本分析。

```
metrics: {tokens: 40000, tools: 7, duration: 67s}
```

### `/debug` 命令

会话诊断用命令。用于复杂错误或意外行为的原因调查。
`troubleshoot` 技能自动启动，系统性诊断问题。

### PDF 页面范围指定

读取大型 PDF 时可指定页面范围（例: `pages: "1-5"`）。
用于 `notebookLM` 技能的文档处理、`harness-review` 的大型规格书参照。

### Git log 标志

活用 `git log` 的结构化选项（`--format`, `--stat`, `--since` 等）。
提高发布说明生成、提交分析、变更追踪的效率。

### OAuth 认证

对非 DCR（Dynamic Client Registration）对应 MCP 服务器的 OAuth 认证设置。
用于 `codex-review` 技能的 Codex CLI 连接。

### 68% 内存优化

通过 `--resume` flag 削减会话恢复时的内存使用量。
对长时间作业会话的上下文继续有效。

### 子 agent MCP

Task tool 启动的子 agent 可共享父会话的 MCP 工具。
`task-worker` 并行实现时，各 agent 可使用相同的 MCP 工具集。

### Reduced Motion

无障碍设置。削减运动/动画的选项。
`harness-ui` 技能在 UI 生成时考虑。

### TeammateIdle/TaskCompleted Hook

Breezing 团队成员进入空闲状态时，或任务完成时触发的 hook。
由 `scripts/hook-handlers/teammate-idle.sh` 与 `task-completed.sh` 处理。

```json
"TeammateIdle": [{"hooks": [{"type": "command", "command": "...teammate-idle", "timeout": 10}]}],
"TaskCompleted": [{"hooks": [{"type": "command", "command": "...task-completed", "timeout": 10}]}]
```

### Agent Memory (memory frontmatter)

通过 agent 定义 YAML 的 `memory: project` 字段启用持久化记忆。
`task-worker`, `code-reviewer` 跨会话学习过去的实现模式・失败与解决方案。

### Fast mode (Opus 4.6)

用 `/fast` 命令切换的高速输出模式。使用相同的 Opus 4.6 模型。
全部技能可用。对缩短长实现任务的等待时间有效。

### 自动记忆记录

会话结束时自动将学习内容持久化到记忆文件。
`session-memory` 技能管理。下一会话自动恢复上次上下文。

### 技能预算缩放

SKILL.md 的字数预算自动调整到上下文窗口的 2%。
推荐 500 行是参考值。实际上限取决于模型的上下文窗口大小。

### Task(agent_type) 限制

Task tool 调用时指定 `subagent_type`，限制子 agent 的类型。
与 `agents/` 定义组合，保证只启动意图内的 agent。

### Plugin settings.json

用插件的 `settings.json` 预定义初始化时的设置。
削减 init token 消耗，从会话开始后立即应用安全策略。

### Worktree isolation

用 `git worktree` 安全化对同一文件的并行写入。
防止 `breezing` 与 `parallel-workflows` 中多 agent 并行实现时的冲突。

### Background agents

异步启动后台 agent。无需等待完成即可继续其他处理。
用于 `generate-video` 技能的多场景并行生成。

### ConfigChange hook

设置文件（`settings.json` 等）变更时触发的 hook。
由 `scripts/hook-handlers/config-change.sh` 记录・审计变更。

### last_assistant_message

可参照会话结束时的最后一条 assistant message 的功能。
`session-memory` 技能用于会话质量的自我评价。

### Sonnet 4.6 (1M context)

拥有最大 1M token 上下文窗口的 Sonnet 4.6 模型。
支持大规模代码库分析、长文档处理。全部技能可用。

> 补充: 2.1.69 系中以旧 Sonnet 4.5 参照自动迁移到 Sonnet 4.6 为前提运用。

### 内存泄漏修复 (v2.1.50〜v2.1.63)

CC 2.1.50 修复了 LSP 诊断数据、大型工具输出、文件历史、shell 执行相关的内存泄漏。
实现了完成任务垃圾回收，大幅改善 `/breezing` 等长时间团队会话的稳定性。
v2.1.63 进一步追加修复了 MCP 重连时的泄漏、git root 缓存、JSON 解析缓存、Teammate 消息保持、shell 命令前缀缓存的泄漏。
Harness 侧已通过 JSONL 轮换（500→400 行）和原子更新实施自有对策。

### `claude agents` CLI (v2.1.50)

用 `claude agents list` 显示已注册 agent 一览。
`troubleshoot` 技能用于 agent spawn 失败时的诊断。

```bash
claude agents list   # 登録済みエージェントの一覧
```

### WorktreeCreate/WorktreeRemove hook (v2.1.50)

Worktree 创建・删除时触发的生命周期 hook。
用于 `/breezing` 并行工作流的自动 setup・cleanup。
已由 `scripts/hook-handlers/worktree-create.sh` 与 `worktree-remove.sh` 实现。

### `claude remote-control` (v2.1.51)

使外部构建系统与本地环境服务成为可能的子命令。
未来有用于 Breezing 跨会话控制或 CI 连携的空间。

### `/simplify` (v2.1.63)

CC 2.1.63 追加的实现后自动代码精炼命令。
作为 `/work` 的 Phase 3.5 Auto-Refinement 整合，实现完成后自动简洁化・整理代码。
与 `code-simplifier` 插件组合，可用 `--deep-simplify` 选项进行深度重构。

### `/batch` (v2.1.63)

将横向展开任务（对多个文件应用相同变更的迁移等）并行委派的命令。
与 `/breezing` 组合，用于让 Breezing 团队并行执行批量迁移。
对重复作业的效率和减少人为失误有效。

### `code-simplifier` 插件

承担 `/simplify` 深度重构模式的外部插件。
`--deep-simplify` 指定时启动，自动执行复杂逻辑分解・去除不必要抽象・改善命名。
普通 `/simplify` 是轻量的，`--deep-simplify` 进行更深的重构。

### HTTP hooks (v2.1.63)

CC 2.1.63 追加的新 hook 形式。在现有 `command` / `prompt` 类型之外，`http` 类型可用。
向指定 URL POST JSON，可与外部服务（Slack、dashboard、指标收集等）连携。
详情参照 [.claude/rules/hooks-editing.md](../.claude/rules/hooks-editing.md) 的「http Type」部分。

### Auto-memory worktree 共享 (v2.1.63)

CC 2.1.63 中，`isolation: "worktree"` 使用时 Agent Memory 可在 worktree 间共享。
`/breezing` 的并行 Implementer 各自在 worktree 分离下作业，同时可参照・更新同一 MEMORY.md。
防止 Implementer 间的知识共享与对同一 bug 的重复对应。

### `/clear` 技能缓存重置 (v2.1.63)

CC 2.1.63 追加的技能缓存重置命令。
编辑技能文件后用旧缓存运行的问题（技能开发时频发）可用 `/clear` 消除。
已纳入 `troubleshoot` 技能的缓存问题诊断步骤。

### `ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)

CC 2.1.63 追加的环境变量。设置 `false` 可禁用 claude.ai 提供的 MCP 服务器。
设想用于安全策略上想限制外部 MCP 服务器连接的环境。
已追加到 `setup` 技能的环境初始化检查清单。

### Agent hooks (v2.1.68)

CC 2.1.68 追加的 `type: "agent"` hook。由 LLM agent 进行 hook 判断，可动态判断难以用正则表达式检测的代码质量问题。
Harness 限用于 3 处，为成本管理用 `model: "haiku"` 与 `matcher` 缩小对象:

- **PreToolUse Write|Edit**: secret 嵌入・TODO stub・安全漏洞的 guard
- **PreCompact**: dirty Plans.md 先做 pathspec 限定 auto-checkpoint（`chore(plans): auto-checkpoint before compaction`）后继续 compact。仅 commit 失败或 `precompactAutoCommit: false` 时 block（harness-loop 所有会话另行 block）
- **PostToolUse Write|Edit**: 代码审查（质量・命名・单一责任）

效果不足时可回退到 `command` 型的设计。

这 3 件是 Claude 专用。Codex manifest 用 inline 的空 hook object
停止 plugin-root fallback，防止 Codex / Orca 跳过未对应 agent hook 的警告。
Codex 的 command hook 作为 `harness gen hooks` 的 project-local 生成物
通过别的经路配线。

### Effort levels + ultrathink (v2.1.68)

CC 2.1.68 中 Opus 4.6 将 **medium effort** 改为默认。用 `ultrathink` 关键字可仅对 1 turn 启用 high effort（extended thinking）。
`harness-work` 技能用多要素评分（变更文件数・对象目录・关键字・失败历史・PM 显式指定）算出分数，阈值 3 以上时在 Worker spawn prompt 开头自动注入 `ultrathink`。
详情参照 `skills/harness-work/SKILL.md` 的「Effort 级别控制」部分。

### Opus 4/4.1 删除（v2.1.68）

CC 2.1.68 中 Opus 4 与 Opus 4.1 从 first-party API 删除。Harness 在对象 agent 中指定 `model: opus` 相当值时，自动迁移到 Opus 4.6。
Worker/Reviewer agent 因是 `model: sonnet` 不受影响。只有 Lead（Opus 使用时）受到 medium effort 成为默认的变更。

### `${CLAUDE_SKILL_DIR}` 变量 (v2.1.69)

CC 2.1.69 引入技能执行时的基准路径变量 `${CLAUDE_SKILL_DIR}`。
Harness 将 `SKILL.md` 中参照 `references/*.md` 的链接统一为 `${CLAUDE_SKILL_DIR}/references/...`，在 mirror 构成（codex/opencode）中也保持相同参照。

### InstructionsLoaded hook (v2.1.69)

CC 2.1.69 追加 `InstructionsLoaded` 事件。Harness 新设
`scripts/hook-handlers/instructions-loaded.sh`，用于 instructions 加载完成时的轻量追踪与事前验证。

### `agent_id` / `agent_type` 追加 (v2.1.69)

Teammate 系事件追加 `agent_id` / `agent_type`。
Harness 的 guardrail 从 `session_id` 前提扩展到 `agent_id` 优先（fallback: `session_id`），稳定了 role guard。

### `{"continue": false}` teammate 响应 (v2.1.69)

`TeammateIdle` / `TaskCompleted` 可返回 `{"continue": false, "stopReason": "..."}`。
Harness 在 stop 请求接收时与全部任务完成时返回相同响应，显式化 breezing 的停止判定。

### `/reload-plugins` (v2.1.69)

为在技能・hook 编辑后无需会话重启即可反映，在开发流程中追加 `/reload-plugins`。
编辑 → `/reload-plugins` → 再执行，作为标准步骤。

### `includeGitInstructions: false` (v2.1.69)

对无需常时嵌入 git 指示的任务应用 `includeGitInstructions: false`，可抑制 token 消耗。
Harness 推荐用于 breezing/work 的轻量任务（文档更新等）。

### `git-subdir` plugin source (v2.1.69)

支持以 `git-subdir` 方式在 monorepo 子目录管理 plugin source。
Harness 当前不强制 `.claude-plugin/plugin.json` 追加字段，发布时显式 `plugin source` 运用（兼容性优先）。

### Compaction 图像保持 (v2.1.70)

CC 2.1.70 中上下文压缩（Compaction）时摘要请求保持图像。
因此，包含截图或图表会话在 Compaction 后仍维持图像上下文。
prompt cache 再利用率也改善，处理图像的技能整体效率提升。

### 子 agent 最终报告简洁化 (v2.1.70)

子 agent 完成时的最终报告被简洁化，token 消耗削减。
`breezing` 或 `harness-work` 启动大量子 agent 时，累积 token 节省效果很大。

### `--resume` 技能列表再注入废止 (v2.1.70)

用 `--resume` 恢复会话时，废止技能列表的再注入。
节省约 600 tokens，`session` 技能的恢复流程轻量化。

### Plugin hooks 修复 (v2.1.70)

v2.1.70 修复了多个 Plugin hooks 相关 bug:
- `Stop` / `SessionEnd` hook 在 `/plugin` 命令执行后也正常触发
- 消除持有相同模板的 hook 间冲突
- 确认 `WorktreeCreate` / `WorktreeRemove` hook 正常动作

### Teammate 嵌套防止追加修复 (v2.1.70)

对 v2.1.69 已对应的 Teammate 嵌套防止追加修复。
强化了 agent 无限 spawn 别的 agent 的级联问题防止。

### PostToolUseFailure hook (v2.1.70)

CC 2.1.70 追加 `PostToolUseFailure` 事件。工具调用失败时触发的新的 hook 事件。
Harness 用 `hooks` 技能与 `error-recovery` 活用，用于连续失败时的自动升级（连续 3 次失败停止）。

```json
"PostToolUseFailure": [{
  "hooks": [{
    "type": "command",
    "command": "...post-tool-failure.sh",
    "timeout": 10
  }]
}]
```

### `/loop` + Cron 调度 (v2.1.71)

CC 2.1.71 追加 `/loop` 命令。像 `/loop 5m <prompt>` 这样指定间隔与提示词，可进行定期执行命令的 Cron 式调度。
`breezing` 中用 `/loop 5m /sync-status` 进行任务进度的定期检查。
与现有 `TeammateIdle`（被动・事件驱动）不同，可主动定期监控。

### Background Agent 输出路径修复 (v2.1.71)

CC 2.1.71 中 Background Agent 的完成通知包含输出文件路径。
因此压缩后也能安全回收后台 agent 的结果。
`breezing` 或 `parallel-workflows` 中的 `run_in_background: true` 变得实用。

### `--print` 团队 agent hang 修复 (v2.1.71)

修复 `--print` 模式下团队 agent hang 的问题。
CI 管道中 `claude --print` 执行时团队 agent 稳定性提升。

### Plugin 安装并行执行修复 (v2.1.71)

修复多个 Claude Code 实例同时安装插件时的状态竞争。
`breezing` 中多个 Teammate 同时启动时插件加载稳定性提升。

### Marketplace 改善 (v2.1.71)

CC 2.1.71 中 Marketplace 周边有多个改善:
- `@ref` 解析器修复: `owner/repo@vX.X.X` 形式参照解析准确
- update 时 merge conflict 修复: 插件更新更稳定
- MCP server 去重: 防止同一 MCP server 多重注册
- `/plugin uninstall` 使用 `settings.local.json`: 准确反映到用户本地设置

### Per-agent hooks (v2.1.69+)

CC 2.1.69 中 agent 定义的 frontmatter 追加 `hooks` 字段。
可在全局 hooks.json 之外定义 agent 固有 hook。

Harness 的活用:
- **Worker**: 用 `PreToolUse` 在 Write/Edit 时应用 `pre-tool.sh` guardrail
- **Reviewer**: 用 `Stop` 输出审查会话完成日志

agent 定义内 hook 仅在该 agent 生命周期内有效，结束时自动清理。

### Agent `isolation: worktree` (v2.1.50+)

在 agent 定义的 frontmatter 追加 `isolation: worktree`，
该 agent 启动时自动创建 git worktree，在独立的仓库副本中作业。
无变更时 worktree 自动清理。

Harness 在 Worker agent 中追加 `isolation: worktree`。
与 `memory: project` 组合，worktree 间共享 Agent Memory（MEMORY.md），
并行 Worker 可参照・更新同一学习内容。

### Auto Mode rollout 政策

Auto Mode 作为使 Claude Code 的 team execution 更向安全侧靠拢的迁移候选整理。
但 shipped default 仍是 `bypassPermissions`，project template 或 frontmatter 只保留官方 docs 记载的 permission mode。

| 层 | 采用值 | 理由 |
|---------|--------|------|
| project template (`permissions.defaultMode`) | `bypassPermissions` | 因为 documented permission modes 不含 `autoMode` |
| agent frontmatter (`permissionMode`) | `bypassPermissions` | 声明式设置只使用 documented 值 |
| teammate 执行经路 | `bypassPermissions`（现行） | 使 shipped default 与实际 permission 继承一致 |
| `--auto-mode` | opt-in marker | 仅当父会话是兼容 permission mode 时尝试 rollout |

默认命令例:

```bash
/breezing all
/execute --breezing all
```

### Subagent `background` 字段

在 agent 定义的 frontmatter 追加 `background: true`，该 agent 始终作为后台任务执行。
即使不显式指定 `run_in_background: true`，每次通过 Agent tool 启动都会后台执行。

```yaml
---
name: long-running-analyzer
background: true
---
```

Harness 在 `breezing` 的 Worker spawn 时可考虑，但现状是 Lead 显式控制 `run_in_background`，追加应用在 Phase 2 以后讨论。

### Subagent `local` 内存 scope

`memory: local` 保存到 `.claude/agent-memory-local/<name>/`，是应追加到 `.gitignore` 的路径。
与 `project` 的区别:

| scope | 路径 | VCS 提交 | 用例 |
|---------|------|-------------|------------|
| `user` | `~/.claude/agent-memory/<name>/` | 对象外 | 全项目共通学习 |
| `project` | `.claude/agent-memory/<name>/` | 可共享 | 团队共享的项目知识 |
| `local` | `.claude/agent-memory-local/<name>/` | 不推荐 | 个人固有・高机密学习 |

Harness 中 Worker/Reviewer 都使用 `memory: project`。`local` 适合记录个人调试模式，但为优先团队共享维持现行设置。

### Agent Teams 实验 flag

Agent Teams 作为实验功能用 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 环境变量启用。
也可通过 settings.json 设置:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Harness 的 `breezing` 技能以 Agent Teams 功能为前提，
追加了确认 setup 时已设置该环境变量的验证步骤。

### Desktop Scheduled Tasks

Desktop 应用的 Scheduled Tasks 保存到 `~/.claude/scheduled-tasks/<task-name>/SKILL.md`。
用 YAML frontmatter 定义 `name` 与 `description`，正文写提示词。

调度设置（频率・时刻・文件夹）从 Desktop 应用的 UI 管理。
可用于定期执行 `/harness-work` 或 `/harness-review`。

### `/agents` 命令

agent 的交互管理界面。可进行以下操作:
- 显示全部可用 agent 一览（built-in, user, project, plugin）
- 引导式或 Claude 生成式 agent 创建
- 编辑现有 agent 的设置・工具访问
- 删除自定义 agent

CLI 非交互一览显示: `claude agents`

### `--agents` CLI flag

会话启动时用 JSON 传入 agent 定义。不保存到磁盘的临时构成:

```bash
claude --agents '{
  "quick-reviewer": {
    "description": "Quick code review",
    "prompt": "Review for critical issues only",
    "tools": ["Read", "Grep", "Glob"],
    "model": "haiku"
  }
}'
```

用于 CI/CD 管道中的临时 agent 注入。

### `ExitWorktree` 工具 (v2.1.72)

CC 2.1.72 追加 `ExitWorktree` 工具。可从 `EnterWorktree` 创建的 worktree 会话以编程方式离开。
以往只能在 worktree 会话结束时的提示中手动选择，现在 agent 可在实现完成后自动离开 worktree。

Harness 的活用:
- `breezing` 的 Worker 在 `isolation: worktree` 作业完成后，用 `ExitWorktree` 显式关闭 worktree
- 提升 worktree 清理的确定性（可与无变更时自动删除的现有动作组合）

### Effort levels 简化 (v2.1.72)

CC 2.1.72 中 effort 级别简化为 `low/medium/high` 3 段。废止 `max` 级别，显示符号统一为 `○ ◐ ●`。可用 `/effort auto` 重置为默认（medium）。

对 Harness 的影响:
- 用 `ultrathink` 关键字注入 high effort 依然有效（无变更）
- harness-work 的评分逻辑无需变更（维持 ultrathink → high effort 的对应）
- 将文档中对 `max` 的提及统一为 `high`

### Agent tool `model` 参数复活 (v2.1.72)

CC 2.1.72 中 Agent tool 的 `model` 参数复活。可按 per-invocation 指定模型启动子 agent。
与 agent 定义的 `model` 字段不同，spawn 时可临时指定模型。

Harness 的活用空间:
- 轻量任务（文档更新、格式修正等）用 `model: "haiku"` spawn 削减成本
- 安全审查或架构变更用 `model: "opus"` spawn 最大化质量
- 现状 Worker/Reviewer 都用 `model: sonnet` 固定。Lead 根据任务特性动态切换模型的实现在 Phase 2 以后讨论

### `/plan` description 参数 (v2.1.72)

CC 2.1.72 中 `/plan` 命令接受可选的 description 参数。
可像 `/plan fix the auth bug` 这样带说明立即进入 plan 模式。

Harness 的活用:
- 可与 `harness-plan` 技能的 `create` 子命令互补使用
- 作为用户想简易进入 plan 模式时的 shortcut 引导

### 并行工具调用修复 (v2.1.72)

CC 2.1.72 修复了并行工具调用时的重要 bug。
以前 Read, WebFetch, Glob 任一失败时，并行执行中的 sibling 调用也被取消。
修复后仅 Bash 错误级联，其他工具失败独立处理。

对 Harness 的影响:
- `breezing` 或 `harness-work` 中并行执行文件读取与 Web 搜索时稳定性提升
- 消除不存在文件的 Read 取消其他正常 Read 的问题
- Worker agent 探索阶段的可靠性改善

### Worktree isolation 修复 (v2.1.72)

CC 2.1.72 修复了 worktree isolation 相关的 2 个 bug:

1. **Task resume 的 cwd 恢复**: 用 `resume` 参数恢复的任务正确恢复 worktree 的工作目录
2. **Background 通知的 worktreePath**: 后台任务完成通知包含 `worktreePath` 字段

对 Harness 的影响:
- `breezing` 的 Worker 在 `isolation: worktree` 作业、Lead 回收结果时可靠性提升
- 可从 `run_in_background: true` spawn 的 Worker 完成通知获取 worktree 路径

### `/clear` 后台 agent 保持 (v2.1.72)

CC 2.1.72 中 `/clear` 动作变更。仅停止前台任务，后台执行中的 agent 或 Bash 任务不受影响。

对 Harness 的影响:
- `breezing` 团队执行中用户 `/clear` 后台 Worker 也存续
- Lead 用 `/clear` 整理上下文也不会中断执行中的任务，安全性提升

### Hooks 修复群 (v2.1.72)

CC 2.1.72 修复了多个 hook 相关 bug:

1. **transcript_path**: `--resume` / `--fork` 会话中 `transcript_path` 正确设置
2. **PostToolUse 阻塞理由双重显示**: 修复 PostToolUse hook 阻塞时理由消息显示 2 次的问题
3. **async hooks 的 stdin**: 异步 hook 正确接收 stdin
4. **skill hooks 双重触发**: 修复技能 hook 每事件触发 2 次的问题

对 Harness 的影响:
- `pre-tool.sh` / `post-tool.sh` guardrail hook 触发精确为 1 次，日志可靠性提升
- `session-memory` 的 transcript 参照在 `--resume` 会话中也正常动作

### HTML 注释隐藏 (v2.1.72)

CC 2.1.72 中 CLAUDE.md 文件内的 HTML 注释（`<!-- ... -->`）在自动注入时隐藏。
用 Read 工具直接读文件时仍可见。

对 Harness 的影响:
- **无实害**: 贯彻不在 HTML 注释内写重要指示或设置的运用

### Bash auto-approval 追加 (v2.1.72)

CC 2.1.72 中以下命令追加到 Bash auto-approval 许可列表:
`lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind`

对 Harness 的影响:
- Worker 可无权限提示执行进程确认（`pgrep`）或文件搜索（`fd`）
- guardrails 的 `pre-tool.sh` 继续放行这些命令（非阻塞对象）

### prompt cache 修复 (v2.1.72)

CC 2.1.72 修复了 SDK `query()` 调用时 prompt cache 无效化 bug。
输入 token 成本最多削减 12 倍。

对 Harness 的影响:
- `breezing` 或 `harness-work` 中大量子 agent spawn 时成本大幅削减
- 尤其在同一会话内反复 API 调用模式效果大

### Output Styles (v2.1.72+)

CC 的 Output Styles 功能可自定义系统提示词本身。
与 CLAUDE.md（作为用户消息追加）或 Skills（特定任务用）不同的层。

Harness 提供 `.claude/output-styles/harness-ops.md`:
- `keep-coding-instructions: true` — 维持编码指示同时优化运用流程
- 结构化进度报告格式（实施/当前位置/下一步动作）
- Quality Gate 的表格式输出
- Review 判定的结构化格式
- 升级（3 次规则）的标准输出形式

```bash
# 有効化
/output-style harness-ops
```

### `permissionMode` in agent frontmatter (v2.1.72+)

官方文档将 `permissionMode` 文档化为 agent frontmatter 的正式字段。

对 Harness 的反映:
- 对 Worker/Reviewer/Scaffolder 3 个 agent 全部追加 `permissionMode: bypassPermissions`
- 实现不依赖 spawn 时 `mode` 指定的声明式权限管理
- Auto Mode 作为 rollout 候选整理，现行 shipped default 维持 `bypassPermissions`

```yaml
# agents/worker.md frontmatter
permissionMode: bypassPermissions  # 追加
```

### Agent Teams 官方最佳实践 (v2.1.72+)

Claude Code 官方将 `agent-teams.md` 作为独立文档整理。
反映到 Harness 的 `docs/team-composition.md`:

1. **任务粒度指南**: 5-6 tasks/teammate 的推荐值
2. **`teammateMode` 设置**: `"auto"` / `"in-process"` / `"tmux"` 的官方支持
3. **Plan Approval 模式**: 要求 Worker 使用 plan mode 的官方模式
4. **Quality Gate Hooks**: `TeammateIdle`/`TaskCompleted` 的 exit 2 反馈模式
5. **团队规模**: 3-5 teammates 的推荐值（与 Harness 的 Worker 1-3 + Reviewer 1 一致）

### Sandboxing (`/sandbox`)

原生集成到 Claude Code 的 OS 级沙盒功能。macOS 用 Seatbelt、Linux 用 bubblewrap，限制 Bash 命令的文件系统/网络访问。

**2 个模式**:
- **Auto-allow mode**: 沙盒内命令自动批准。约束外访问回退到通常权限流程
- **Regular permissions mode**: 沙盒内也全部命令需要批准

**Harness 的活用策略**:
- 定位为 `bypassPermissions` 的 **补充层**（非替换）
- 为 Worker agent 的 Bash 命令追加 OS 级安全边界
- 用 `sandbox.filesystem.allowWrite` 显式限制 Worker 可写范围
- 用 `sandbox.network` 将外部访问限制到可信域（防止 exfiltration）

**分阶段引入计划**:

| 阶段 | Worker 权限 | Sandbox |
|---------|-----------|---------|
| 现行 | `bypassPermissions` + hooks guard | 未应用 |
| 验证阶段 | `bypassPermissions` + hooks + sandbox auto-allow | 应用于 Worker 的 Bash |
| 稳定后 | 仅 sandbox auto-allow（讨论废止 `bypassPermissions`） | 应用于全部 Bash |

```json
// settings.json (検証フェーズ用)
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.claude", "//tmp"]
    }
  }
}
```

> `@anthropic-ai/sandbox-runtime` 已作为 OSS 公开，也可用于 MCP 服务器的沙盒化。

### `opusplan` 模型别名

Plan mode 用 Opus、执行模式用 Sonnet 自动切换的混合别名。

**Harness 的活用**:
- 最适合 Breezing 的 Lead 会话: Plan 阶段（任务分解・架构决定）活用 Opus 的推理力，Worker spawn 后的执行协调用 Sonnet 提高成本效率
- 用 `claude --model opusplan` 或 `/model opusplan` 启用

**用环境变量控制**:
```bash
# opusplan の内部マッピングをカスタマイズ
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6    # Plan 時
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5    # 実行時
```

### `CLAUDE_CODE_SUBAGENT_MODEL` 环境变量

统一指定子 agent（Worker/Reviewer）模型的环境变量。

**Harness 的活用**:
- 现状: Worker/Reviewer 在 agent 定义中固定 `model: sonnet`
- 用本环境变量可不变更 agent 定义切换模型
- 用于 CI 环境成本控制（`CLAUDE_CODE_SUBAGENT_MODEL=haiku` 测试执行）

```bash
# 全サブエージェントを haiku で実行（CI コスト削減）
export CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

### `availableModels` 设置

限制用户可选择模型的设置。在 managed/policy settings 中设置时，`/model`、`--model`、`ANTHROPIC_MODEL` 任一路径都应用限制。

**Harness 的活用**:
- 企业环境的模型治理: 防止 Worker/Reviewer 使用意外模型
- 用 `availableModels` + `model` 组合统制全用户模型体验

```json
// managed settings
{
  "model": "sonnet",
  "availableModels": ["sonnet", "haiku", "opusplan"]
}
```

### Checkpointing (`/rewind`)

自动追踪会话中的文件编辑，可回退到任意时点的功能。
每个用户提示词自动创建 checkpoint。

**操作方法**:
- 用 `Esc + Esc` 或 `/rewind` 打开 rewind 菜单
- 选项: 代码恢复 / 对话恢复 / 两者恢复 / 从这里摘要

**Harness 的活用**:
- `harness-work` 的自我审查阶段发现问题时，回退到实现前状态
- 用「从这里摘要」回收冗长调试会话的上下文窗口
- 与 `/compact` 的区别: checkpoint 可选择性地指定压缩范围

**限制事项**:
- 不追踪 Bash 命令的文件变更（`rm`, `mv`, `cp` 等）
- 不追踪外部手动变更
- 不是 Git 的替代，而是会话级的「本地 Undo」

### Code Review (managed service)

在 Anthropic 基础设施上运行的多 agent PR 审查服务。面向 Teams/Enterprise 的 Research Preview。

**动作概要**:
1. PR 创建/更新时自动启动
2. 多个专业 agent 并行分析差异与代码库
3. 验证步骤过滤假阳性
4. 去重・重要度排序后作为 inline 评论投稿

**重要度级别**:
| 标记 | 级别 | 含义 |
|---------|--------|------|
| 🔴 | Normal | 合并前应修复的 bug |
| 🟡 | Nit | 轻微问题（非阻塞） |
| 🟣 | Pre-existing | 此 PR 之前就存在的 bug |

**`REVIEW.md`**: 放置在仓库根目录的审查专用 guidance 文件。与 `CLAUDE.md` 不同，定义仅审查时适用的规则。

**Harness 的活用**:
- 作为 `harness-review` 技能的 Code Review 对应，讨论生成 `REVIEW.md` 模板
- Harness 的 Worker 自我审查与 managed Code Review 互补（本地 + 远程双重检查）
- 平均成本 $15-25/审查。`on-push` 触发器按 push 次数产生成本，注意

### Status Line (`/statusline`)

显示在 Claude Code 终端下部的可定制状态栏。将 JSON 会话数据传给 shell 脚本，显示输出文本。

**可用数据**:
- `model.id`, `model.display_name` — 当前模型
- `context_window.used_percentage` — 上下文使用率
- `cost.total_cost_usd` — 会话成本
- `cost.total_duration_ms` — 经过时间
- `worktree.*` — worktree 信息
- `agent.name` — agent 名
- `output_style.name` — 输出样式名

**Harness 的活用**:
- 用 `scripts/statusline-harness.sh` 提供 Harness 专用状态栏
- 常时显示模型名・上下文使用率・会话成本・git 分支・Harness 版本
- 用 ANSI 颜色显示上下文使用率阈值（70% 黄色、90% 红色）

### 1M Context Window (`sonnet[1m]`)

Opus 4.6 与 Sonnet 4.6 可用的 100 万 token 上下文窗口。超过 200K token 时应用 long-context pricing。

**Harness 的活用**:
- 用于 `harness-review` 的大规模代码库分析
- `breezing` 中同时处理大量文件的会话
- 用 `/model sonnet[1m]` 启用。可用 `CLAUDE_CODE_DISABLE_1M_CONTEXT=1` 禁用

### Per-model Prompt Caching Control

按模型控制 prompt cache 的环境变量群。

| 环境变量 | 用途 |
|---------|------|
| `DISABLE_PROMPT_CACHING` | 全模型 cache 无效化 |
| `DISABLE_PROMPT_CACHING_HAIKU` | 仅 Haiku 无效化 |
| `DISABLE_PROMPT_CACHING_SONNET` | 仅 Sonnet 无效化 |
| `DISABLE_PROMPT_CACHING_OPUS` | 仅 Opus 无效化 |

**Harness 的活用**:
- 调试时无效化特定模型 cache 确认行为
- 云 provider（Bedrock/Vertex）cache 实现不同时的选择性控制

### `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

无效化 Opus 4.6 / Sonnet 4.6 的 Adaptive Reasoning，恢复到由 `MAX_THINKING_TOKENS` 控制的固定 thinking budget 的环境变量。

**Harness 的活用**:
- 用于需要 token 成本可预测性的 CI 环境
- 与 `harness-work` 的 effort 评分不互斥（两者都可用，但通常保持 adaptive thinking 有效并用 ultrathink 控制更有效）

### Chrome Integration (`--chrome`)

与 Claude Code 的 Chrome 扩展连携，从终端执行浏览器自动化的 beta 功能。
用 `--chrome` flag 启动会话，或用 `/chrome` 从会话内启用。

**主要功能**:
- 实时调试: 读取控制台错误，立即修正原因代码
- UI 测试: 表单验证、视觉回归确认、用户流程验证
- 数据提取: 从网页提取结构化数据并本地保存
- GIF 记录: 将浏览器操作序列记录为 GIF

**Harness 的活用**:
- `harness-work` 中 UI 组件实现后的自动验证
- `harness-review` 中 Web 应用的视觉审查
- 用 `/chrome` 启用使 Worker 可执行浏览器测试

**约束**: 仅 Google Chrome / Microsoft Edge。不支持 Brave, Arc 等。不支持 WSL。

### LSP 服务器集成 (`.lsp.json`)

通过 Plugin 集成 Language Server Protocol 服务器，提供实时代码诊断。

**可用 LSP 插件**:
| 插件 | Language Server | 安装 |
|-----------|----------------|------------|
| `pyright-lsp` | Pyright (Python) | `pip install pyright` |
| `typescript-lsp` | TypeScript Language Server | `npm install -g typescript-language-server typescript` |
| `rust-lsp` | rust-analyzer | 参照 rust-analyzer 官方指南 |

**提供的功能**:
- 即时诊断: 编辑后立即显示错误/警告
- 代码导航: 定义跳转、引用搜索、悬停信息
- 类型信息: 符号类型与文档显示

**设置例** (`.lsp.json`):
```json
{
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".ts": "typescript",
      ".tsx": "typescriptreact"
    }
  }
}
```

### `SubagentStart`/`SubagentStop` matcher

在 settings.json 级别按 agent type 分别监控子 agent 生命周期的 hook。
官方文档记录了在 matcher 中指定 agent 名的模式。

**Harness 的实现**:
- `SubagentStart`: 分别追踪 Worker/Reviewer/Scaffolder/Video Generator 的启动
- `SubagentStop`: 分别记录各 agent 的完成
- 在现有 `subagent-tracker` Node.js 脚本中追加 matcher

```json
"SubagentStart": [
  { "matcher": "worker", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] },
  { "matcher": "reviewer", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] }
]
```

### Agent Teams: Task Dependencies

可给 Agent Teams 的任务设置依赖关系。依赖任务完成自动 unblock 被 block 的任务。

**动作**:
- 任务有 `pending`, `in_progress`, `completed` 3 状态
- 有未解决依赖的 pending 任务不可 claimed
- 依赖完成时自动 unblock（无需手动干预）
- 用文件锁防止多个 teammate 同时 claim

**Harness 的活用**:
- Breezing 的 Lead 在任务分解时显式指定依赖关系
- 例: 保证「API 端点实现」→「测试创建」→「文档更新」的顺序

### `--teammate-mode` CLI flag

按会话指定 Agent Teams 显示模式的 flag。

```bash
claude --teammate-mode in-process  # 全 teammate を同一ターミナル
claude --teammate-mode tmux        # 各 teammate に個別ペイン
```

覆盖 settings.json 的 `teammateMode` 设置。VS Code 集成终端推荐 `in-process`。

### `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`

`=1` 禁用全部后台任务功能的环境变量。

**Harness 的活用**:
- 面向以安全策略限制后台执行的环境
- 也会禁用 Breezing 的后台 Worker spawn，使用时要注意

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

调整子 agent auto-compaction 阈值的环境变量（默认 95%）。

**Harness 的活用**:
- 设置为 `50` 启用早期压缩。提升长时间 Worker 稳定性
- 防止 Breezing 的 Worker 读取大量文件时上下文溢出

### `cleanupPeriodDays` 设置

控制子 agent transcript 自动清理周期的设置（默认 30 天）。
transcript 保存到 `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`。

### `/btw` 侧问题

保持当前上下文进行短问题的命令。
回答后不留在主对话历史中，不消耗上下文窗口。

**与子 agent 的区分**:
- `/btw`: 当前上下文可即时回答的问题（无工具访问）
- 子 agent: 独立调查・实现任务（有工具访问）

### Plugin CLI 命令群

插件的非交互管理命令。支持脚本自动化。

```bash
claude plugin install <plugin> [--scope user|project|local]
claude plugin uninstall <plugin> [--scope user|project|local]
claude plugin enable <plugin> [--scope user|project|local]
claude plugin disable <plugin> [--scope user|project|local]
claude plugin update <plugin> [--scope user|project|local|managed]
```

### Remote Control 强化

用 `/remote-control` (`/rc`) 可从会话内启用 Remote Control。

**新功能**:
- `--name "My Project"`: 指定会话名
- `--sandbox` / `--no-sandbox`: 启用/禁用沙盒
- `--verbose`: 详细日志显示
- `/mobile`: 显示二维码快速连接到 iOS/Android 应用
- 自动重连: 网络中断自动恢复（10 分钟内）
- `/config` → "Enable Remote Control for all sessions" 常时启用

### `skills` 字段 in agent frontmatter

在子 agent 的 frontmatter 追加 `skills` 字段，启动时预加载技能全部内容。
父对话的技能不被继承，需要显式列出。

**Harness 的实现状况**:
- Worker: `skills: [harness-work, harness-review]` — 预加载实现与自我审查技能
- Reviewer: `skills: [harness-review]` — 预加载审查技能
- Scaffolder: `skills: [harness-setup, harness-plan]` — 预加载 setup 与计划技能

> `skills` in skill (`context: fork`) 的逆模式。不是 skill 控制 agent，而是 agent 加载 skill。

### `modelOverrides` 设置 (v2.1.73)

CC 2.1.73 追加的设置。可将模型选择器（`/model` 菜单）的条目映射到自定义 provider 的模型 ID。
可指定 Bedrock ARN 或 Vertex AI 的模型 ID 等 provider 固有标识符。

**Harness 的活用**:
- 企业环境经 Bedrock/Vertex 使用 Anthropic 模型时，用 `modelOverrides` 将模型选择器显示名与实际 provider 模型 ID 对应
- Worker/Reviewer 的 `model: sonnet` 自动解析为 provider 固有 ARN
- 与 `availableModels` 组合，统制团队整体模型体验

```json
// settings.json
{
  "modelOverrides": {
    "sonnet": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-5",
    "opus": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-opus-4-6-20250610-v1:0"
  }
}
```

### `/output-style` 弃用 (v2.1.73)

CC 2.1.73 中 `/output-style` 命令弃用，输出样式选择整合到 `/config` 菜单。
现有 `/output-style harness-ops` 等继续工作，但官方推荐经 `/config` 选择。

**对 Harness 的影响**:
- 推荐将文档中对 `/output-style harness-ops` 的提及更新为经 `/config`
- `.claude/output-styles/harness-ops.md` 本身继续有效（设置文件放置位置无变更）
- 技能内有执行 `/output-style` 的地方则讨论切换到 `/config`

### Bedrock/Vertex Opus 4.6 默认化 (v2.1.73)

CC 2.1.73 中云 provider（Amazon Bedrock / Google Vertex AI）上的默认 Opus 模型从 4.1 更新到 4.6。
first-party API 在 v2.1.68 时点 Opus 4.6 已是默认，云 provider 经路也统一。

**对 Harness 的影响**:
- Bedrock/Vertex 环境中 Lead（Opus 使用时）也以 medium effort 默认动作
- `opusplan` 别名在 Bedrock/Vertex 环境也参照 Opus 4.6
- 用 `ANTHROPIC_DEFAULT_OPUS_MODEL` 环境变量覆盖依然有效

### `autoMemoryDirectory` 设置 (v2.1.74)

CC 2.1.74 追加的设置。可自定义自动记忆（auto-memory）的保存目录。
可从默认 `~/.claude/` 下变更到项目固有路径。

**Harness 的活用**:
- 多项目使用 Harness 时，按项目分离自动记忆
- CI 环境将记忆保存到临时目录，会话结束时清理
- 与 Agent Memory（`memory: project`）不同的层（自动记忆是用户级学习）

```json
// settings.json (プロジェクトレベル)
{
  "autoMemoryDirectory": ".claude/auto-memory"
}
```

### `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)

CC 2.1.74 追加的环境变量。可以毫秒为单位指定 `SessionEnd` hook 的超时。
以往固定 1.5 秒 kill，存在重清理处理在完成前被中断的问题。

**Harness 的活用**:
- `SessionEnd` hook 执行 `harness-mem` 的会话记录或 JSONL 轮换时，确保足够超时
- 推荐值: `5000`（5 秒）。需要复杂清理时最多 `10000`（10 秒）

```bash
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000
```

### Full model ID 修复 (v2.1.74)

CC 2.1.74 中 `claude-opus-4-6`、`claude-sonnet-4-6` 等完整模型 ID（连字符分隔形式）在 agent frontmatter 及 JSON config 中可正确识别。
以往只有别名（`opus`, `sonnet`）稳定工作。

**对 Harness 的影响**:
- 可在 agent 定义的 `model` 字段指定完整模型 ID（例: `model: claude-sonnet-4-6`）
- `--agents` CLI flag 的 JSON 内也可用完整模型 ID
- 现状 Harness 使用别名（`sonnet`, `opus`）无即时影响。Bedrock/Vertex 环境需要完整 ID 指定时有用

```yaml
# agents/worker.md frontmatter（完全モデル ID 使用例）
model: claude-sonnet-4-6
```

### Streaming API 内存泄漏修复 (v2.1.74)

CC 2.1.74 修复了流式 API 响应缓冲区的无限制 RSS（Resident Set Size）增大。
消除长时间流式会话中 Node.js 进程内存使用量无限增加的问题。

**对 Harness 的影响**:
- `breezing` 长时间团队会话稳定性提升
- `harness-work` 中大量文件读写的长时间 Worker 会话内存消耗稳定化
- 继 v2.1.50〜v2.1.63 的内存泄漏修复系列（LSP 诊断、工具输出、文件历史等）之后的追加修复
- 与 Harness 侧 JSONL 轮换对策（自有内存管理）组合，双重确保稳定性

### `--remote` / Cloud Sessions

用 CC 的 `--remote` flag 可从终端启动云会话。任务在 Anthropic 管理的隔离 VM 上执行，完成后可创建 PR。

**Harness 的活用**:
- 将 `breezing` 的大规模任务委派到云端，节省本地资源
- 用 `--remote` 并行启动多个任务（各任务是独立云会话）
- 用 `/teleport` 将云端成果拉取到本地，连接到后续 `/harness-review`

```bash
# クラウドでタスク実行
claude --remote "Fix the authentication bug in src/auth/login.ts"

# 完了後にローカルに取り込み
/teleport
```

### `/teleport` (`/tp`)

将云会话拉取到本地终端的命令。用 `/teleport` 或 `/tp` 交互选择会话，也可用 `claude --teleport <session-id>` 直接指定。

**前提条件**:
- 本地 git working directory 干净
- 从同一仓库执行
- 以同一 Claude.ai 账号认证

### `CLAUDE_CODE_REMOTE` 环境变量

云会话内设置 `CLAUDE_CODE_REMOTE=true`。Harness 的 `session-env-setup.sh` 将此值持久化为 `HARNESS_IS_REMOTE`，供其他 hook handler 用于判定跳过本地专用处理。

```bash
# フックスクリプト内でのクラウド検出例
if [ "$HARNESS_IS_REMOTE" = "true" ]; then
  # クラウド環境ではローカル専用処理をスキップ
  exit 0
fi
```

### `CLAUDE_ENV_FILE` SessionStart 持久化

CC 的 `SessionStart` hook 通过向 `CLAUDE_ENV_FILE` 环境变量指向的文件写入 `KEY=VALUE`，可将环境变量持久化给后续 Bash 命令。

Harness 的 `session-env-setup.sh` 活用此机构，使 `HARNESS_VERSION`、`HARNESS_AGENT_TYPE`、`HARNESS_IS_REMOTE` 等在会话整体可用。

### Slack Integration (`@Claude`)

在 Slack 频道向 `@Claude` 提及编码任务时，自动创建云会话。以与 GitHub 仓库连携为前提。

**与 Harness 的关系**:
- 将 Harness 的 HTTP hooks（`type: "http"`）设置到 Slack Webhook URL，可实现任务完成时的 Slack 通知
- 云会话内 `.claude/settings.json` 的 hook 也工作，因此 Harness 的 guardrail 也适用于经 Slack 的任务

### Server-managed settings (public beta)

从 Claude.ai 管理画面向团队整体服务器分发 Claude Code 设置的功能。面向 Teams/Enterprise。

**Harness 的活用**:
- 批量管理团队整体的 `permissions.deny` 规则
- 经服务器分发 Harness 的 hook 设置（但 hook 设置会显示安全确认对话框）
- 用 `availableModels` + `model` 组合统制团队模型体验

### Microsoft Foundry

Azure 基盘的新云 provider。作为继 Bedrock / Vertex 之后的第 3 个第三方 provider 追加。
可用 `modelOverrides` 设置映射 Foundry 的模型 ID。

### `PreCompact` hook

上下文压缩执行前触发的 hook 事件。Harness 已用以下 3 层实现:

1. **`pre-compact-save.js`**: 持久化会话状态（进度、指标）
2. **`bin/harness pre-compact` (Go)**: 对 dirty Plans.md 做 pathspec 限定 auto-checkpoint 提交并用 `{"continue":true,...}` 继续 compact。仅 commit 失败或 `precompactAutoCommit: false` 时 block
3. **agent hook**: 检查是否残留 `cc:WIP` 任务，注入警告消息

```json
"PreCompact": [
  { "hooks": [
    { "type": "command", "command": "...pre-compact-save.js" },
    { "type": "agent", "prompt": "Check Plans.md for WIP tasks...", "model": "haiku" }
  ]}
]
```

### `Notification` hook event

Claude Code 发出通知时触发的 hook 事件。记载于插件参考。
可用于向外部监控工具或 dashboard 转发通知。

### `--plugin-dir` 规格变更 (v2.1.76, breaking)

**变更内容**: `--plugin-dir` 变更为只接受 1 个路径。多个目录重复指定。

```bash
# 旧（非対応に）
claude --plugin-dir path1,path2

# 新
claude --plugin-dir path1 --plugin-dir path2
```

**对 Harness 的影响**: 只用 Harness 插件的通常构成无影响。
仅同时使用多个插件时需要语法变更。

---

## Claude Code 2.1.76 新功能

### MCP Elicitation 支持

**动作概要**: MCP 服务器可在任务执行中向用户要求结构化输入的协议。通过表单字段或浏览器 URL 显示交互对话框。

**Harness 的活用**:
- Breezing 的后台 Worker/Reviewer 无法 UI 对话，用 `Elicitation` hook 实现自动跳过
- 通常会话直接通过（用户对话响应）
- Go hookhandler 除旧兼容日志 `.claude/state/elicitation-events.jsonl` 外，将 `elicitation-event.v1` append-only 记录到 `.claude/state/elicitation/events.jsonl`
- 仅 harness-mem healthy 时以 `event_type: "elicitation_event"` best-effort 转发到 `/v1/events/record`，不达时 silent fallback 到 local ledger

**约束事项**:
- 后台 agent 无法响应 elicitation（必须 hook 自动处理）
- MCP 服务器侧需要支持 elicitation
- Claude-harness 不直接读 harness-mem DB

### `Elicitation`/`ElicitationResult` hook

**动作概要**: 可在 MCP Elicitation 前后拦截的 2 个新 hook 事件。`Elicitation` 在响应返回 MCP 服务器前、`ElicitationResult` 在返回后触发。

**Harness 的活用**:
- `Elicitation`: Breezing 会话中的自动跳过判定 + 日志记录 + `capability_probe` event 记录
- `ElicitationResult`: 结果日志记录（`.claude/state/elicitation-events.jsonl`）+ `eval_result` event 记录
- 在 hooks.json 注册两事件的 handler

**约束事项**:
- `Elicitation` hook 中 block（deny）则 MCP 服务器收不到输入
- 推荐 timeout: Elicitation 10s / ElicitationResult 5s

### `PostCompact` hook

**动作概要**: 上下文 compaction 完成后触发的新 hook 事件。与 `PreCompact` hook（现有）成对。

**Harness 的活用**:
- compaction 后的上下文再注入（WIP 任务状态恢复）
- 记录事件到 `.claude/state/compaction-events.jsonl`
- 提升长时间会话状态连续性
- PreCompact（状态保存）→ PostCompact（状态恢复）的对称结构

**约束事项**:
- 推荐 timeout: 15s
- compaction 失败时（circuit breaker 触发时）PostCompact 可能不触发

### `-n`/`--name` CLI flag

**动作概要**: 会话启动时设置显示名的 CLI flag。像 `claude -n "auth-refactor"` 这样使用，用于会话一览识别。

**Harness 的活用**:
- 对 Breezing 会话自动设置 `breezing-{timestamp}` 形式的名称
- 用于会话一览的过滤・追踪
- 便于日志分析时的会话定位

**代码例**:
```bash
claude -n "breezing-$(date +%Y%m%d-%H%M%S)"
```

### `worktree.sparsePaths` 设置

**动作概要**: 大规模 monorepo 使用 `claude --worktree` 时，通过 git sparse-checkout 仅 checkout 必要目录的设置。大幅改善 worktree 创建性能。

**Harness 的活用**:
- 缩短 Breezing 的并行 Worker 启动时间（大规模仓库）
- 在 `.claude/settings.json` 设置:
```json
{
  "worktree": {
    "sparsePaths": ["src/", "tests/", "package.json"]
  }
}
```

**约束事项**:
- 未 sparse-checkout 路径的文件 Worker 不可访问
- 有依赖关系的目录需全部包含在 sparsePaths

### `/effort` 斜杠命令

**动作概要**: 会话中切换 effort 级别（low/medium/high）的斜杠命令。用 `/effort auto` 重置默认。

**Harness 的活用**:
- 与 harness-work 的多要素评分连携，可按任务复杂度控制 effort
- 复杂任务可手动设置 `/effort high`（ultrathink 启用）
- 简易任务用 `/effort low` 抑制 token 消耗

### `--worktree` 启动高速化

**动作概要**: 通过直接读取 git refs 与远程分支可用时跳过冗长 `git fetch`，缩短 `--worktree` 启动时间。

**Harness 的活用**:
- Breezing 的 Worker 启动开销自动削减
- 尤其同时启动大量 Worker 时收益大

### 后台 agent 部分结果保持

**动作概要**: 后台 agent 被 kill 时，部分结果也保存到对话上下文。

**Harness 的活用**:
- Breezing 的 Worker 因超时或手动停止中断时，部分作业传达给 Lead
- 可利用 Worker 的中途成果再分配
- 减少「重做」浪费

### stale worktree 自动清理

**动作概要**: 中断的并行执行残留的 stale worktree 自动清理。

**Harness 的活用**:
- 补充 `worktree-remove.sh` 的手动清理
- Breezing 会话崩溃后也自动恢复
- 防止磁盘容量浪费

### 自动 compaction circuit breaker

**动作概要**: 自动 compaction 连续失败时，3 次停止的 circuit breaker 引入。防止无限重试浪费 token。

**Harness 的活用**:
- 与 Harness 的「3 次规则」（CI 失败时 3 次限制）一致的设计思想
- 防止长时间 Breezing 会话意外成本增加
- circuit breaker 触发时与 PostToolUseFailure hook 连携升级

### Deferred Tools schema 修复

**动作概要**: 修复 `ToolSearch` 加载的工具在 compaction 后丢失输入 schema，数组・数值参数因类型错误被拒绝的问题。

**Harness 的活用**:
- 长时间会话中 ToolSearch 经路工具稳定性提升
- Breezing 的 compaction 后 MCP 工具也正常动作

### `/context` 命令 (v2.1.74)

**动作概要**: 分析上下文窗口消耗状况，定位压迫上下文的工具或记忆。显示可行动的优化建议（切断不必要 MCP 服务器、整理膨胀记忆等）。

**Harness 的活用**:
- 长时间 Breezing 会话中定位「为何频繁 compaction」的原因
- 连接大量 hooks 或 MCP 服务器环境中的上下文优化
- 会话中仅执行 `/context` 即可即时获得分析结果

**约束事项**:
- 仅会话中可用（批处理模式不支持）
- 子 agent 内不可用

### `maxTurns` agent 安全限制

**动作概要**: 限制子 agent 最大 turn 数的 frontmatter 字段。达到设置 turn 数时，agent 自动停止返回结果。CC 官方文档推荐的安全机构。

**Harness 的活用**:
- Worker: `maxTurns: 100` — 面向复杂实现任务。保持足够余裕同时防止失控
- Reviewer: `maxTurns: 50` — 专精 Read-only 分析。50 turn 不完成则有问题
- Scaffolder: `maxTurns: 75` — 脚手架构建与状态更新的中间复杂度

**设计判断**:
- 达到上限时，Lead 可回收中途结果判断
- 与 `bypassPermissions` 组合，作为失控时安全阀功能

### `Notification` hook 实现

**动作概要**: Claude Code 发出通知时触发的 hook 事件。拦截 `permission_prompt`（权限确认）、`idle_prompt`（空闲通知）、`auth_success`（认证成功）等事件。

**Harness 的活用**:
- 用 `notification-handler.sh` 将全部通知事件日志记录到 `.claude/state/notification-events.jsonl`
- 追踪 Breezing 后台 Worker 发生的 `permission_prompt`（用于事后分析）
- hooks-editing.md 中从 v3.10.3 已文档化，本次完成 hooks.json 实现

**日志格式**:
```json
{"event":"notification","notification_type":"permission_prompt","session_id":"...","agent_type":"worker","timestamp":"2026-03-15T..."}
```

### Output token limits 64k/128k (v2.1.77)

CC 2.1.77 中 Opus 4.6 与 Sonnet 4.6 的默认最大输出 token 提升到 64k，上限扩展到 128k token。

**对 Harness 的影响**:
- 长实现代码或大规模重构的输出更难被截断
- Worker agent 一次输出大量文件变更时可靠性提升
- 128k 输出导致成本增大，需注意成本管理

### `allowRead` sandbox 设置 (v2.1.77)

在 `sandbox.filesystem.denyRead` 广泛阻塞的同时，用 `allowRead` 重新允许特定路径读取。

**Harness 的活用**:
- Reviewer agent 的沙盒对 `/etc/` denyRead，同时仅对特定设置文件 allowRead
- 安全审查时提供机密目录的受限读取访问

### PreToolUse `allow` 尊重 `deny` (v2.1.77)

CC 2.1.77 中即使 PreToolUse hook 返回 `"allow"`，settings.json 的 `deny` 权限规则也继续适用。以前 hook 的 `allow` 覆盖全局 `deny`。

**对 Harness 的影响**:
- guardrails 的安全模型强化
- 在 settings.json 设置 `deny: ["mcp__codex__*"]` 则无论 PreToolUse hook 判断都确定阻塞
- 除 `.claude/rules/codex-cli-only.md` 的 hook 基盘 MCP 阻塞外，settings.json deny 成为推荐模式

### Agent `resume` → `SendMessage` (v2.1.77)

CC 2.1.77 中 Agent tool 的 `resume` 参数废止。恢复停止中的 agent 用 `SendMessage({to: agentId})`。`SendMessage` 自动后台恢复停止中的 agent。

**对 Harness 的影响**:
- `breezing` 技能的 Lead 与 Worker/Reviewer 通信时使用 `SendMessage`
- `team-composition.md` 的 Lead Phase B 记载 `SendMessage` 作为正式通信手段

### `/branch` (旧 `/fork`) (v2.1.77)

CC 2.1.77 中 `/fork` 命令重命名为 `/branch`。`/fork` 作为别名继续功能。

### `claude plugin validate` 强化 (v2.1.77)

CC 2.1.77 中 `claude plugin validate` 验证技能・agent・命令的 YAML frontmatter 与 hooks.json 语法。

**Harness 的活用**:
- 在 CI 管道追加 `claude plugin validate`，早期检测 frontmatter 错误
- 可作为 `tests/validate-plugin.sh` 的补充活用

### `StopFailure` hook event (v2.1.78)

CC 2.1.78 追加 `StopFailure` 事件。API 错误（速率限制 429、认证失败 401 等）导致会话停止失败时触发。

**Harness 的活用**:
- 用 `stop-failure.sh` handler 将错误信息日志记录到 `.claude/state/stop-failures.jsonl`
- 用于 Breezing 的 Worker 因速率限制停止失败时的事后分析
- 作为 10 秒超时的轻量 handler 实现（无需恢复处理）

### Hooks conditional `if` field (v2.1.85)

CC 2.1.85 中，hooks 定义可附加 `if` 条件，精细限定「什么输入时才运行 hook」。使用 Permission rule syntax，可像 `Bash(git status*)` 这样一并指定工具名与输入模式。

**Harness 的活用**:
- 将 `PermissionRequest` 分割为 2 系统，`Edit|Write|MultiEdit` 常时评估，`Bash` 仅对安全命令候选用 `if` 事前过滤
- 保留 `hooks/permission.sh` 自身的安全判定，同时减少不必要的 Bash permission hook 启动数
- 将 `MultiEdit` 也纳入 matcher，消除 core guardrail 已对应的自动批准遗漏

**用户体验改善**:
- 以前: Bash 权限确认广泛运行 hook，最终被放过的案例也产生启动成本
- 今后: 仅 safe-read / test 类 Bash 运行 hook，减少响应噪声与无谓评估，同时维持自动批准精度

### `${CLAUDE_PLUGIN_DATA}` 变量 (v2.1.78)

CC 2.1.78 追加 `${CLAUDE_PLUGIN_DATA}` 目录变量。可作为插件更新后仍持久化的状态存储使用。

**Harness 的活用空间**:
- 当前使用 `${CLAUDE_PLUGIN_ROOT}/.claude/state/`，插件更新可能消失
- 长期讨论将指标・通知日志等持久数据迁移到 `${CLAUDE_PLUGIN_DATA}`
- 迁移模式: `STATE_DIR="${CLAUDE_PLUGIN_DATA:-${CLAUDE_PLUGIN_ROOT}/.claude/state}"`

### Agent frontmatter: `effort`/`maxTurns`/`disallowedTools` (v2.1.78)

CC 2.1.78 中插件 agent 定义的 frontmatter 官方支持 `effort`, `maxTurns`, `disallowedTools`。

**Harness 的现状**:
- `maxTurns`: v3.10.4 已实现（Worker: 100, Reviewer: 50, Scaffolder: 75）
- `disallowedTools`: Worker 是 `[Agent]`、Reviewer 是 `[Write, Edit, Bash, Agent]` 已实现
- `effort`: 未使用。在 Worker/Reviewer 定义追加 `effort` 字段，可声明式控制默认 thinking 级别

### `deny: ["mcp__*"]` 修复 (v2.1.78)

CC 2.1.78 中 settings.json 的 `deny` 权限规则对 MCP 服务器工具正确功能。

**Harness 的活用**:
- 可将 `.claude/rules/codex-cli-only.md` 推荐的 Codex MCP 阻塞从 hook 基盘迁移到 settings.json `deny`
- `"permissions": { "deny": ["mcp__codex__*"] }` 是干净模式

### `--console` auth flag (v2.1.79)

CC 2.1.79 追加 `claude auth login --console` flag，支持 Anthropic Console API 计费认证。

### SessionEnd hooks `/resume` 修复 (v2.1.79)

CC 2.1.79 中交互式 `/resume` 会话切换时 `SessionEnd` hook 正常触发。以前会话切换时 SessionEnd 不触发，存在 cleanup 处理不执行的案例。

### `PermissionDenied` hook event (v2.1.89)

CC 2.1.89 中 auto mode classifier 拒绝命令时触发 `PermissionDenied` hook。返回 `{retry: true}` 可告知模型可重试。被拒绝的命令也显示在 `/permissions` → Recent 标签。

**Harness 的活用**:
- 新实现 `permission-denied-handler.sh`，将拒绝事件 telemetry 记录到 `permission-denied.jsonl`
- Breezing Worker 被拒绝时，用 `systemMessage` 通知 Lead 并促使其讨论替代方法
- 活用 `agent_id` / `agent_type` 字段追踪哪个 agent 被拒绝什么

**用户体验改善**:
- 以前: auto mode 的拒绝仅通知不留记录，容易重复相同拒绝
- 今后: 拒绝模式累积，Breezing 中 Lead 可即时认知应对

### `"defer"` permission decision (v2.1.89)

CC 2.1.89 中可从 PreToolUse hook 返回 `"defer"` permission decision。headless 会话（`-p` 模式）中 hook 返回 defer 则会话暂停，用 `claude -p --resume` 恢复时 hook 再评估。

**Harness 的活用空间**:
- Breezing Worker 遇到写入生产环境或外部服务请求等难判断操作时的安全阀
- 在 `pre-tool.sh` 的 guardrail 追加「defer 条件」，特定模式暂停 Worker→Lead 判断
- 现时点仅功能文档化。具体 defer 规则在运用模式累积后设计

### Hook output >50K disk save (v2.1.89)

CC 2.1.89 中 hook 输出超过 50K 字符时，不直接注入上下文而保存到磁盘，作为文件路径＋预览参照。

**对 Harness 的影响**:
- 可能返回大量输出的 hook（quality-pack, ci-status-checker 等）以此行为为前提设计
- 现状 Harness hook 输出轻量，直接影响小，但作为未来扩展时的设计约束文档化

### PreToolUse exit 2 JSON fix (v2.1.90)

CC 2.1.90 修复 PreToolUse hook 向 stdout 输出 JSON 并以 exit code 2 结束时阻塞动作。以前此模式阻塞不正确的 bug 存在。

**对 Harness 的影响**:
- `pre-tool.sh` deny 时使用 JSON + exit 2 模式，v2.1.90 以后 guardrail 的 deny 更可靠动作
- 现有 guardrail 存在「出了 deny 但工具被执行」案例时，可能是此 bug 原因

### 从 Skill tool 调用 Built-in slash commands 的 Harness 影响 (v2.1.108)

CC 2.1.108 以后，模型可通过 `Skill` tool 调用 `/init`、`/review`、`/security-review` 等
built-in slash commands。这使 Harness 技能可从内部调用 CC 内置功能的构成成为可能，但需注意与 Harness 自有 `/harness-review` 的角色重复。
具体而言，经 `Skill` tool 调用 `/review` 时，会执行不适用 Harness guardrails（R01-R13）的
CC 原生审查。Harness 的审查流程经 `/harness-review` 或 `codex-companion.sh review`
可维持 guardrails 保护与向 `review-result.v1` 形式的归一化。built-in slash command 的 Skill tool 调用
限定于轻量 inline 审查或初始化处理，不用于需要质量门禁的审查。

## v2.1.99-v2.1.110 + Opus 4.7 详情部分（Phase 44.11.1）

> 此部分遵循 `.claude/rules/cc-update-policy.md` 的 3 分类（A/B/C）。
> B 分类 **0 件**。A = 已实现，C = CC 自动继承。

### PreCompact hook 3-way decision API (v2.1.99)

**附加价值**: `A: 已实现`（hooks/hooks.json PreCompact 条目，Phase 44.13 确认）

CC 2.1.99 中 PreCompact hook 支持 `"block"` / `"allow"` / `"defer"` 的 3-way decision API。
此前只有 `block` / `allow` 2 选，无「稍后判断」选项。

**Harness 的活用**:
- Breezing Worker 处于 cc:WIP 状态时 `"block"` compaction，WIP 完成后 `"allow"` 的模式可安全实现
- `hooks/hooks.json` 的 PreCompact handler 经 `bin/harness pre-compact` 对 dirty Plans.md 做 pathspec 限定 auto-checkpoint，通常继续 compact（仅 commit 失败或 `precompactAutoCommit: false` 时 block）
- `"defer"` 计划用于 headless 环境的条件式延期（当前使用 block/allow 的 2-way）

**用户体验改善**:
- 以前: 防止 WIP 中 compaction 只有 `block`，长时间 Worker 存在不必要 compaction 抑制持续的问题
- 今后: 可用 `defer` 指示「现在不行但 resume 后再评估」，Worker 完成同时 compaction 适当运行

### ENABLE_PROMPT_CACHING_1H opt-in (v2.1.108)

**附加价值**: `A: 已实现`（`scripts/enable-1h-cache.sh`，Phase 44.6.1 实现）

CC 2.1.108 追加 `ENABLE_PROMPT_CACHING_1H=1` 环境变量的 1 小时 prompt cache TTL。
默认 5 分钟 TTL 中超过 30 分钟的会话 cache miss 频发，成本增大。

**Harness 的活用**:
- 执行 `scripts/enable-1h-cache.sh` 则 idempotent 追加 `ENABLE_PROMPT_CACHING_1H=1` 到 `env.local`
- 作为 `skills/breezing/SKILL.md` 与 `skills/harness-loop/SKILL.md` 的开始前推荐记载
- 在 `docs/long-running-harness.md` 追加选择基准表（会话超 30 分钟则 1h cache）

**用户体验改善**:
- 以前: 长时间 Breezing 会话 cache miss 增加，相同 CLAUDE.md 或 hooks.json 反复计费
- 今后: 1h TTL 大幅提升 cache 命中率。削减长时间任务成本

### /undo (rewind alias) (v2.1.108)

**附加价值**: `A: 已实现`（`.claude/rules/commit-safety.md`，Phase 44.7.1 实现）

CC 2.1.108 追加 `/rewind` 的别名 `/undo`。取消会话内的上一个工具调用。

**Harness 的活用**:
- 在 `.claude/rules/commit-safety.md` 明记 `/undo` 的动作定义・使用约束・禁止模式
- 文档化 Worker / Reviewer 禁止自主执行 `/undo` 的条件（git commit 后取消用 `git revert`）
- 防止误用 `/undo` 删除已 commit 变更的风险

**用户体验改善**:
- 以前: `/rewind` 与 `/undo` 的区分暧昧，agent 有误用风险
- 今后: Harness 规则明确分离「`/undo` = 会话内文件变更取消」「commit 后用 `git revert`」

### PermissionRequest updatedInput / additionalContext (v2.1.110)

**附加价值**: `A: 已实现`（`go/internal/guardrail/cc2110_regression_test.go`，Phase 44.3.1 实现）

CC 2.1.110 中 PermissionRequest hook 追加・整备 `updatedInput` 与 `additionalContext` 字段。
用 `updatedInput` 传入 CC 再评估的输入，用 `setMode: dontAsk` 使 mode 变更后也再应用 deny 规则。

**Harness 的活用**:
- 在 `go/internal/guardrail/cc2110_regression_test.go` 追加 3 组回归测试
  - 验证 `updatedInput` + `setMode` → deny 规则（R01, R02, R06）再评估后也应用
  - 确认 `additionalContext` 在 JSON round-trip 中保持（R09 警告路径）
  - 强化 Bash bypass 向量（`;`, `&&`, `||`, 子 shell 等）检测
- 使 `helpers.go` 的 `hasSudo()` 支持含 shell 元字符的上下文

**用户体验改善**:
- 以前: CC 更新输入后，理论上存在 guardrail 的 deny 不再评估的漏洞
- 今后: `updatedInput` 后也再应用 R01-R13 全部规则，保证 guardrail 完整性

### /recap 与 built-in slash command discovery (v2.1.108)

**附加价值**: `C: CC 自动继承`（Harness 侧无需变更）

CC 2.1.108 追加 `/recap` 命令，可在 resume 前摘要确认会话内容。
built-in slash command 经 Skill tool 调用也在同版本实现。

**Harness 的活用**:
- `/recap` 作为长时间 `--resume` 时确认会话记忆的步骤记载到 `skills/session-memory/SKILL.md`
- 作为 CC 本体功能自动可用。Harness 侧无需实现变更

### EnterWorktree path 参数 / stale worktree 自动清理 (v2.1.105)

**附加价值**: `A: 已实现`（`scripts/reenter-worktree.sh`，Phase 44.7.1 实现）

CC 2.1.105 中 `EnterWorktree` hook 将 worktree 路径作为参数传入。
此前需在脚本内自行定位 worktree 路径。

**Harness 的活用**:
- 用 `scripts/reenter-worktree.sh` 实现活用 EnterWorktree path 参数的 worktree 再入 helper
- 包含 worktree 注册确认与 `worktree-info.json` 对照的安全再入流程
- 保证 Breezing 的 Worker 暂停后能再入正确 worktree

**用户体验改善**:
- 以前: Worker 的 worktree 再入需要环境依赖的 worktree 路径定位，不稳定
- 今后: 直接从 hook 接收路径，与 worktree-info.json 对照确保再入正确上下文

---

## Opus 4.7 详情部分（Phase 44.11.1）

> 此部分详述 Opus 4.7 固有功能的 Harness 整合状况。
> 附加价值分类: A = 已实现，C = CC 自动继承。B 分类 0 件。

### 1. Literal Instruction Following

**附加价值**: `A: 已实现`（`.claude/rules/opus-4-7-prompt-audit.md`，Phase 44.4.1 + 44.4.2 实现）

Opus 4.7 的「按字面执行指示」能力大幅提升。不是补全歧义表达推测意图，而是只执行指示的内容。

**Harness 的活用**:
- 新设 `.claude/rules/opus-4-7-prompt-audit.md`。定义 agent 提示词的质量基准
  - 行为指示必须含执行命令名 / 文件路径 / JSON schema 名 / 数值阈值任一
  - 次数控制用 `最大 3 回` 这样数字描述
  - `必要に応じて` / `適宜` 等歧义词后必须补充条件
- 使 `agents/worker.md`, `agents/reviewer.md`, `agents/advisor.md` 的提示词符合审计基准

**用户体验改善**:
- 以前: agent 提示词的歧义表达招致模型误解，发生意外动作
- 今后: 通过审计基准的提示词被模型按字面解释，保证一致动作

### 2. xhigh Effort

**附加价值**: `A: 已实现`（`agents/reviewer.md`, `agents/advisor.md`, `docs/effort-level-policy.md`，Phase 44.5.1 实现）

Opus 4.7 追加 `xhigh` effort 级别（可作为 CC v2.1.111 frontmatter 接受）。
thinking 强度高于 `high`，适合复杂审查或设计判断。

**Harness 的活用**:
- `agents/reviewer.md`: `effort: medium` → `effort: xhigh` 变更（审查深度提升）
- `agents/advisor.md`: `effort: high` → `effort: xhigh` 变更（判断准确性提升）
- `docs/effort-level-policy.md`: 整备 CC frontmatter effort 与 Anthropic API effort 的对应矩阵
- 维持 `harness-work` 技能多要素评分向 Worker 注入 `ultrathink` 的机制

**用户体验改善**:
- 以前: Reviewer 以 medium effort 动作，复杂架构变更审查变浅的案例存在
- 今后: xhigh effort 提升 Reviewer 的 thinking 质量，critical/major 指摘检出率上升

### 3. Task Budgets（采用搁置）

**附加价值**: `C: 采用搁置`（`docs/task-budgets-research.md`，Phase 44.10.1 调研）

Anthropic Task Budgets (public beta) 是按任务限制 token・工具调用数的功能。

**Harness 的活用**:
- 在 `docs/task-budgets-research.md` 记录规格摘要・与 Harness 现有机构的竞争关系分析
- 与现有 `maxTurns` (Worker: 100, Reviewer: 50) 及 `MAX_REVIEWS` 功能重复，本 Phase 采用搁置
- 明记 GA 升级时的再评估触发条件（Harness 自有控制整合设计确定时点）

**采用搁置理由**:
- Harness 已用 `maxTurns` 与 `MAX_REVIEWS` 管理 Worker 执行限制
- 与 Task Budgets 双重管理有增加设置复杂性风险
- 比 Public beta 阶段采用，等待 GA 后稳定 API 的判断

### 4. Tokenizer 改善

**附加价值**: `C: CC 自动继承`（Harness 侧无需变更）

Opus 4.7 的新 tokenizer 削减同一提示词的 token 数。尤其日文・代码混在内容效果大。

**对 Harness 的影响**:
- CLAUDE.md、技能文件、agent 提示词的 token 消耗自动削减
- 技能预算（上下文窗口 2%）的实际字符数增加
- Harness 侧无需变更。随模型更新自动受益

### 5. Vision 2576px 支持

**附加价值**: `A: 已实现`（`docs/opus-4-7-vision-usage.md`, `skills/harness-review/references/vision-high-res-flow.md`，Phase 44.9.1 实现）

Opus 4.7 中图像短边上限扩展到 2576px。PDF・设计图・UI 截图的审查品质提升。

**Harness 的活用**:
- `docs/opus-4-7-vision-usage.md`: 新设高分辨率审查运用指南（3 种场景: PDF 审查 / 设计图解析 / UI 截图）
- `skills/harness-review/references/vision-high-res-flow.md`: 整备 2576px 上限的运用流程（resize 判定・多页 PDF 分割策略）
- 在 `/harness-review` 纳入图像附加时自动上限检查

**用户体验改善**:
- 以前: 高分辨率截图自动 resize 品质下降，遗漏细节 UI 问题的案例存在
- 今后: 可原尺寸审查到 2576px。可检测 UI 像素级问题或设计图细微标签

### 6. Memory 功能扩展

**附加价值**: `C: CC 自动继承`（auto-memory 系统已存在。Harness 侧无需变更）

Opus 4.7 的 Memory 功能扩展（自动记忆记录精度提升・长期记忆压缩品质改善）自动与 Harness 的现有 Agent Memory 基盘整合。

**Harness 的活用**:
- 经 `memory: project` frontmatter 的 agent 固有记忆继续功能
- CC 自动记忆精度提升，Worker / Reviewer / Scaffolder 的学习品质自动提升
- 维持与 `.claude/agent-memory/` 现有条目的兼容性

### 7. /ultrareview（并立维持方针）

**附加价值**: `A: 已实现`（`docs/ultrareview-policy.md`, `skills/harness-review/SKILL.md`，Phase 44.8.1 实现）

CC v2.1.111 追加 `/ultrareview` 作为 built-in operator entrypoint。执行 cloud 多 agent 审查。

**Harness 的活用（方针 B: 并立维持）**:
- `docs/ultrareview-policy.md`: 确立 `/ultrareview` 限定 ad-hoc 审查、不纳入 Harness automation flow 的方针
- Harness 的 review automation 维持 `review-result.v1` 契约基盘的 `codex-companion.sh review`（优先）+ reviewer agent（fallback）
- 在 `skills/harness-review/SKILL.md` 追加分工部分

**用户体验改善**:
- 以前: `/ultrareview` 出现使与 Harness 的 `/harness-review` 角色暧昧
- 今后: 明确分离 `/ultrareview` = 面向人类 ad-hoc 审查 / `/harness-review` = 面向自动化流程

### 8. Auto Mode 扩大

**附加价值**: `C: opt-in 处理`（`skills/breezing/SKILL.md` 的 `--auto-mode` flag 说明）

CC v2.1.111 中 Auto Mode 无需 `--enable-auto-mode` flag 也可使用。

**Harness 的活用**:
- `skills/breezing/SKILL.md` 的 `--auto-mode` 选项维持作为「显式 Harness 侧 Auto Mode rollout」的 opt-in flag 说明
- CC 本体的 Auto Mode 扩大自动继承，但注意不与 Harness 的 `bypassPermissions` 基盘实现混在
- 维持 operator entrypoint 的 `--auto-mode` 由调用侧选择的设计。agent 定义侧不写 `autoMode` 值

**用户体验改善**:
- 以前: Auto Mode 需要 `--enable-auto-mode` flag，与 Breezing 组合复杂
- 今后: CC 本体 Auto Mode 常设化，但 Harness 继续将 `--auto-mode` 作为显式 opt-in 处理以维持可预测行为

## Phase 65 (cognitive-load 3 surface) — 2026-05-09 〜 2026-05-10

| Feature | Skill / Component | Purpose | 附加价值 |
|---------|-------------------|---------|---------|
| Plan Brief HTML (1st surface) | `harness-plan-brief` | 用 1 张 HTML 向发包方确认开工前的 Claude 理解・选项・风险・接受条件・确信度 | A: 已实现 (Phase 65.1) |
| Acceptance Demo HTML (2nd surface) | `harness-accept` | 交付时 ship/wait/reject 判定 + 接受条件验证 + 过去问题模式显示 | A: 已实现 (Phase 65.2) |
| Progress Tracker HTML (3rd surface) | `harness-progress` | 进度 % + WIP/TODO/完成一览 + 5 种 drift alert + PostToolUse 自动再生成 (60s rate limit) | A: 已实现 (Phase 65.4) |
| 3-Layer Redaction | `redact-by-{dictionary,ner}.sh` + `final-scan-redaction.py` + `render-html.sh --with-redaction` | 用 Layer 2a 字典 + 2b NER (fugashi) + 3 final scan 3 层防御固有名词泄漏 | A: 已实现 (Phase 65.3) |
| Cross-Project Group | `cross-project-groups.yaml` + `load-cross-project-groups.sh` | 横断搜索的 opt-in 组定义 (default OFF) | A: 已实现 (Phase 65.3.1) |
| Cross-Project Audit Log | `cross-project-audit-log.sh` | 每次横断搜索 1 行 JSON Lines (privacy: 仅 query_hash) | A: 已实现 (Phase 65.3.6) |
| Audit-trail UI | 3 HTML templates 共通追加 | 各 surface 末尾「🔍 此 artifact 的根据」部分 (搜索范围 / 参照 ID / redact 件数 / log link) | A: 已实现 (Phase 65.5.2) |
| user_request_hash join | `personal-preference.v1` + `acceptance-decision.v1` 的 sha256 fields | 用同 hash 使 Plan Brief ↔ Acceptance 可 graph join | A: 已实现 (Phase 65.1.4 / 65.2.3) |

**用户体验改善**:
- 以前: 不读 Plans.md (200 行) + git log 就看不到进度・判断根据。非工程师发包方完全是黑箱
- 今后: 浏览器打开 1 张 HTML 3 秒即可判断「计划做什么 (Plan Brief) / 现在在哪 (Progress) / 能否接收 (Acceptance)」
- 即便启用横断搜索，3 层 redaction 也不泄漏其他项目的固有名词 (fail-safe)
- 详情: [cognitive-load-surfaces.md](./cognitive-load-surfaces.md) / [cross-project-safety.md](./cross-project-safety.md)

### Orchestration Visibility (Phase 90)

| 功能 | 活用技能 / 领域 | 用途 | 附加价值 |
|------|-----------------|------|---------|
| Delegation Ledger | `orchestration-ledger.sh` + `codex/cursor-companion.sh` | 每次委派将 backend / counts 等 8 项目记录到 `orchestration-ledger.jsonl`（无 prompt/秘密，status 不计入） | A: 已实现 (Phase 90.1.1) |
| Lifetime Accumulator | `orchestration-rollup.sh` + `go/internal/orchestration` | 完成时 + SessionEnd 2 经路幂等 roll up 到累计（`orchestration-totals.json`、record-only） | A: 已实现 (Phase 90.1.2) |
| Scorecard Aggregator | `orchestration-scorecard.sh` | 合并 session mix + lifetime 并以 tri-state (used/available/not-configured) 汇总。claude=host | A: 已实现 (Phase 90.1.3) |
| HTML Scorecard | `templates/html/orchestration.html.template` + `render-html.sh` | 累计主角的可共享 1 张 HTML（无需 JS standalone） | A: 已实现 (Phase 90.1.4) |
| Completion Summary + Skill | `harness-orchestration` + `task_completed.go` | 全部完成时 1 次终端摘要（Go all-done）+ on-demand HTML 技能 | A: 已实现 (Phase 90.1.5) |

**用户体验改善**:
- 以前: 委派在运行时不可见，「真的用了 Codex/Cursor 吗，还是全部落到 Claude」不知道
- 今后: 记录 → 累计 → scorecard 展示「此会话/项目活用多少 orchestration」（累计是主角数字）

## 相关文档

- [CLAUDE.md](../CLAUDE.md) - 开发指南（Feature Table 摘要版）
- [CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - 技能目录
- [CLAUDE-commands.md](./CLAUDE-commands.md) - 命令参考
- [ARCHITECTURE.md](./ARCHITECTURE.md) - 架构概要
