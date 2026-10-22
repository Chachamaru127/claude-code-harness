# CLAUDE.md - Claude Harness 开发指南

本文件为 Claude Code 在本仓库中工作提供指引。

## 项目概览

**Claude harness** 是一个插件，用于以「Plan → Work → Review」工作流自主运营 Claude Code。

**特别说明**：本项目是自指的 — 它用 harness 自身来改进 harness。

## Claude Code 功能运用

<!-- Feature Table は docs/CLAUDE-feature-table.md に集約。ここに行を追加しない -->
运用 CC v2.1.111+ 的集成功能。详情：[docs/CLAUDE-feature-table.md](docs-zh/CLAUDE-feature-table.md)
Fable 5.1 / astra 的分角色模型与显式指定：[docs/model-routing-policy.md](docs-zh/model-routing-policy.md)
向负责人传递目的、完成条件、证据：[docs/prompt-calibration.md](docs-zh/prompt-calibration.md)
长时间任务的步骤：[docs/long-running-harness.md](docs-zh/long-running-harness.md)

主要运用功能：Agent Memory、Worktree isolation、Agent hooks、PreCompact/PostCompact、PermissionDenied tracking、1M Context Window

## 开发规则

### 提交信息

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：`feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`

### 版本管理

通过 `./scripts/sync-version.sh` 保持所有版本面同步（该脚本是目标列表的 SSOT — 目前是 6 个文件中的 7 处字符串，含 `.grok-plugin/plugin.json`）。
日常的功能/文档 PR 必须保持这两个文件不变，并把改动记录在 `CHANGELOG.md` 的 `[Unreleased]` 小节下。
只有在切发布时才使用 `./scripts/sync-version.sh bump`。

### CHANGELOG

详情：[skills/harness-release/references/github-release.md](skills/harness-release/references/github-release.md)（Keep a Changelog 格式；重大变更要含 Before/After 表格）

### 语言

面向用户的回答遵循明确的会话语言或项目语言。若未配置语言，使用英语。
仅当 `i18n.language: ja`、`CLAUDE_CODE_HARNESS_LANG=ja`，或明确的会话指示要求日语输出时才使用日语。

完整详情（如何切换、优先级、哪些不变）：[docs/i18n.md](docs-zh/i18n.md)。

### 代码风格

- 使用清晰、有描述性的名称
- 为复杂逻辑添加注释
- 让 agent/技能保持单一职责

## 仓库结构

`.claude-plugin/` Plugin manifest / `.claude/` Claude 运行时状态、memory、rules、hooks / `.cursor/` Cursor 命令、rules、plans、skills / `agents/` Sub-agent / `skills/` 主技能 / `skills-codex/` Codex 专属技能变体 / `hooks/` Hooks / `scripts/` Shell 脚本 / `src/` TypeScript 实现 / `app/` App 层 / `frontend/` 前端实现 / `docs/` 文档 / `templates/` 模板 / `tests/` 校验 / `go/` Harness v4 Go 原生引擎（[SPEC.md](go/SPEC.md)、[DESIGN.md](go/DESIGN.md)）/ `mcp-server/` MCP server 实现 / `harness-ui/` UI 子项目 / `opencode/` OpenCode 兼容输出

## 使用技能（重要）

**开始工作前**：如果存在相关技能，先用 Skill 工具启动它。

> 对于重任务，技能会通过 Task 工具从 `agents/` 并行 spawn sub-agent。

### 主要技能领域

| 分类 | 用途 | 触发示例 |
|---------|---------|-----------------|
| harness-work | 从 Plans.md 实现任务 | "implement"、"do it all"、"/work" |
| breezing | 用 Agent Teams 做完整并行运行 | "run with team"、"breezing" |
| harness-review | 代码评审、质量检查 | "review"、"security"、"performance" |
| harness-plan | 规划并把任务塑造成 Plans.md 条目 | "plan"、"break this down"、"/plan-with-agent" |
| harness-sync | 检查 Plans.md、git 状态与实现之间的一致性 | "sync"、"is this aligned?"、"check drift" |
| memory | SSOT 管理、memory 搜索、SSOT 晋升 | "SSOT"、"decisions.md"、"memory search"、"harness-mem" |
| cognitive-load（Plan Brief / Progress / Accept） | 面向非工程师 vibecoder 评审的 3 个 HTML 界面（Phase 65） | "plan brief"、"進捗確認"、"受け入れ判断"、"ship/wait/reject" |

技能以扁平目录组织在 `skills/` 下，Codex 专属变体在 `skills-codex/`。完整目录：[docs/CLAUDE-skill-catalog.md](docs-zh/CLAUDE-skill-catalog.md)
Cognitive-load 3 界面详情：[docs/cognitive-load-surfaces.md](docs-zh/cognitive-load-surfaces.md) / 跨项目安全性：[docs/cross-project-safety.md](docs-zh/cross-project-safety.md)

## 开发流程

0. **编辑 skills/hooks 时**：仅技能改动后运行 `/reload-skills`，plugin manifest/hook 改动后运行 `/reload-plugins`，立即刷新运行时缓存
1. **规划**：用 `/plan-with-agent` 把任务加入 Plans.md
2. **实现**：`/work`（Claude 实现）或 `/breezing`（团队完整运行）。两者都支持 `--codex`
3. **评审**：自动执行（手动：`/harness-review`）
4. **校验**：运行 `./tests/validate-plugin.sh` 做结构校验

## 测试

```bash
./tests/validate-plugin.sh          # Validate plugin structure
./scripts/ci/check-consistency.sh   # Consistency check
```

详情：[docs/CLAUDE-commands.md](docs-zh/CLAUDE-commands.md)

## 注意事项

- **注意自指**：在这个插件上运行 `/work` 意味着编辑它自己的代码
- **Hooks 自动运行**：PreToolUse/PostToolUse 守卫处于激活状态
- **VERSION 同步**：日常 PR 不动版本文件；只在发布时更新
- **Worker 契约（v4.3.0+）**：Worker 必须用 `worker-report.v1` 提交 5 条 self_review。改写 Plans.md 的 `cc:*` 标记会被 NG-1 自动 deny。详情：[agents/worker.md](agents/worker.md)
- **Skill frontmatter 设计**：`disable-model-invocation: true` 专用于有危险副作用的技能。给 read-only / 判定类技能加上它，会产生通过 Skill tool 启动被阻断的副作用。反模式：[.claude/rules/skill-editing.md](.claude/rules/skill-editing.md) + [.claude/memory/patterns.md](.claude/memory/patterns.md) P27 不适用条件（2026-05-18 codify）
- **Slash command 输出的摘要契约**：当 `/命令` 的 `<local-command-stdout>` 以长文（10 行以上）传给 host Claude 时，host 必须以 assistant message 的形式用 1-3 行摘要，并明示下一步动作（等待 / 结束 / 请示用户判断）。skill 侧也要在结论时输出 instruction line literal（`↑この結果は Claude が要約します。Enter キーで次へ進むか、新規 prompt で別の指示を出してください。`）。详情：[.claude/memory/patterns.md](.claude/memory/patterns.md) P35（2026-05-19 codify）

## MCP 信任策略

用户级 MCP 全部视为可信来源。
添加外部 MCP 时的规则：
1. 经 `harness_mem_ingest` 写入的内存要加出处标签（`source: "mcp:<server-name>"`）
2. 不特定的外部输入用 sub-agent 检疫（在隔离上下文中验证后再晋升为 memory）
3. 添加项目级 MCP 时，用 deny 限制 `mcp__<新服务器>__*`，只 allow 必需的工具

## 权限边界

以下是 settings.json 的 deny/ask 与守卫引擎（R01-R16）的组合。
**注意各层角色不对称** — 与 deny 等价的阻断由 operator 的 settings
（用户级 `~/.claude/settings.json` 等）的 permissions 层负责，守卫层则按规则
返回 deny / ask / 带警告许可三者之一（2026-08-11 实测确认）。
很多行并不是「两层都 deny 同一操作的双重防御」。

| 规则 | permissions 层 | 守卫层（实测） | 理由 |
|------|--------------|--------------------|------|
| `.claude-plugin/settings*`、`.claude/settings*` | deny | R02/R03: **带警告许可** | 防止自我改写（阻断仅在 permissions 层） |
| `.eslintrc*`、`eslint.config.*`、`biome.json`、`tsconfig*.json` | deny | 不适用 | 保护质量基准 |
| `.github/workflows/*` | deny | R13: **带警告许可** | 保护 CI 流水线（阻断仅在 permissions 层） |
| `git push --force` | deny | R06: deny | 防止不可逆操作（真正的双重防御） |
| `git push origin main/master` | — | R12: ask（可配置为 deny / allow） | 保护受保护分支 |
| `git reset --hard` | deny | R11: deny（**仅当引用受保护分支时**。`HEAD~1` 等会放行） | 防止不可逆操作 |
| `git add <secret file>` | — | R15: deny | 防止秘密文件被暂存 |
| `mcp__codex__*` | deny | 不适用 | 防止直接使用 Codex MCP |

需要变更时请委托用户手动操作。

**新增或修改防御层之前必读**：[.claude/rules/defense-layer-blast-radius.md](.claude/rules/defense-layer-blast-radius.md) — 各层的强制力与影响范围（`permissions` 与 hook 只作用于 agent / `sandbox` 由 OS 对所有进程强制）、强制力越强的层适用范围越窄的原则、新增前的 5 项检查、`excludedCommands` 不会继承到子进程的事实、升格到用户级前先在 1 个项目中验证。2026-08-10 因同型事故发生 2 次而 codify。

- 使用 Cursor 实现后端时的规则：[skills/cursor-do/references/cursor-cli-only.md](skills/cursor-do/references/cursor-cli-only.md)

外部 API 的 sandbox allowlist 设置（Firecrawl / 网页抓取等）：[docs/sandbox-allowlist-recipe.md](docs-zh/sandbox-allowlist-recipe.md) — 将对 `~/.claude/settings.json` 的 patch 步骤 SSOT 化。与 `templates/sandbox-settings.json.template` 保持数值与条目同步。

## 关键命令（开发用）

| 命令 | 用途 |
|---------|---------|
| `/plan-with-agent` | 把改进任务加入 Plans.md |
| `/work` | 实现任务（自动范围识别，支持 --codex） |
| `/breezing` | 用 Agent Teams 做团队完整并行运行（支持 --codex） |
| `/harness-review` | 评审改动 |
| `/validate` | 校验插件 |
| `/remember` | 记录经验 |

详情与交接：[docs/CLAUDE-commands.md](docs-zh/CLAUDE-commands.md)

## SSOT（Single Source of Truth）

- `.claude/memory/decisions.md` - 决策（Why）
- `.claude/memory/patterns.md` - 可复用模式（How）

## 防止篡改测试

> **绝对禁止**：篡改测试来伪造「成功」

详情：[.claude/rules/test-quality.md](.claude/rules/test-quality.md) / [.claude/rules/implementation-quality.md](.claude/rules/implementation-quality.md)

- 迁移策略：[docs/rules/migration-policy.md](docs-zh/rules/migration-policy.md) - deleted-concepts.yaml 的运用规则（Phase 40 引入）
- 主动监听测试策略：[docs/rules/active-watching-test-policy.md](docs-zh/rules/active-watching-test-policy.md) - 外部 daemon / opt-in 文件监听功能的 3 状态测试规约（Phase 50 引入，制度化为 D40 / P29 运用规则）
- 跨仓库交接：[docs/rules/cross-repo-handoff.md](docs-zh/rules/cross-repo-handoff.md) - claude-code-harness ↔ harness-mem 责任边界 + 2 条 handoff 路径（Phase 65 codify，D42 的可共享策略部分）

## 北极星

Harness 追求的 3 层志向（地基 → 顶点）。详情见 [spec.md](spec_zh.md)（Purpose / Execution Backend Contract / Mode 1・Mode 2）。

- **L1 专注判断**：AI 准备 plan / 实现 / 比较 / 验证 evidence，operator（人类）只做最终判断。
- **L2 工具无关（tool-agnostic）**：同一 Harness（R01-R16 + plan/work/review/release）在 Claude / Codex / Cursor 的「任何一方」都有效。1 个 policy engine 通过 native hook 裁决 3 个 host（是路由而非复制）。harness 驱动方向与 host「从外部使用」方向同等支持。
- **L3 协作（collaboration，将来的主战场）**：多个工具协作驱动同一项目，人类不做复制粘贴的信使。Mode 1 = 完全自主编排（v1 固定 Lead=Claude），Mode 2 = 人类在席的 peer co-drive（live notice messaging）。完整的 peer-Lead 协作分阶段引入。

## 防止误解 Codex / Cursor hook

固定围绕 Codex / Cursor 的 hook 反复出现的误解。详情见 [spec.md](spec_zh.md)（Host Adapter / Host Distribution Contract / hosts.toml）。

- **FACT-1（是生成的，不是内联的）**：Codex / Cursor 是一等的 hook host。hook 不内联写在 config.toml 里，而是由 `harness gen` 生成的 `.codex/hooks.json` / `.cursor/hooks.json`（被 gitignore 的 build artifact）。它们都调用 `bin/harness hook pre-tool --host <h>`。
- **FACT-2（无内联 ≠ 无 hook）**：「config.toml 里没有内联 hook」意思是「不写在 config 里」，而不是「没有 hook」。不要混淆这两件事。
- **FACT-3（enforcement 已接线 / delivery 已接线）**：hook 分 2 层。(a) enforcement（PreToolUse → R01-R16 policy engine）已对 3 个 host 对称接线，由 `harness gen` 生成。(b) Mode 2 delivery（inbox-check / monitor 接收）也已接线生成 — `GenerateDeliveryHooksJSON` 在 Phase 105.9 [b82143fe] 接入 `harness gen`，生成的 Codex/Cursor hooks.json 中会带上 inbox-check（turn 边界 delivery）。identity 在 Phase 121.2 改为 runtime env 解析（`inbox check --from-env`，`{{TEAM}}`/`{{AGENT}}` 占位符已移除）。Claude host 的 Stop 接线在 Phase 121.3 加入受版本管理的 `hooks/hooks.json` + `.claude-plugin/hooks.json`（env 展开 + stdin session_id 回退）。live monitor 是 opt-in，默认关闭。
- **FACT-4（materialize 后再确认）**：在断定某个 host 缺少某能力之前，务必真正 materialize `harness gen` 的输出并检查其内容。不要只凭 config 注释就断言「没有」。not_observed != absent。

<!-- harness-integrity: last-audit=2026-05-18 -->

## 技能保留备注

- `agent-browser` 在 Phase 91.7 曾被暂时判定为「含糊」，但在 Phase 104.9 的引用审计中确认它已实际接线到 `skills/harness-work`、`scripts/browser-review-runner.sh`、`scripts/pretooluse-browser-guide.sh`、`scripts/ci/check-consistency.sh`，因此裁定保留（2026-07-05）。
- `cc-update-review` 初次审计时曾被删除，但发现在集成门禁中 `tests/test-claude-upstream-integration.sh` 作为 Upstream Tracking Contract 的一部分固定了它的存在与 A/B/C/P 分类，因此更正为保留（2026-07-05）。教训：引用审计要覆盖包括 tests/ 与 docs/ 在内的全域。
- `gogcli-ops` / `cc-cursor-cc` 在全域审计中仍无任何功能引用，因此确定删除。已登记到 retired-alias registry（`templates/registry/retired-aliases.v1.yaml`）。
