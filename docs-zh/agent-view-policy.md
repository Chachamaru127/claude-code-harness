# Agent View（`claude agents`）策略

CC `2.1.139`+ 引入了 `claude agents`（agent view，Research Preview）作为单一 entrypoint，
`2.1.141` 添加了 `--cwd <path>` flag，`2.1.142` 添加了 `--add-dir` / `--settings` / `--mcp-config` /
`--plugin-dir` / `--permission-mode` / `--model` / `--effort` / `--dangerously-skip-permissions`
flag。

Harness 将此作为 **Lead（operator）一覧监视多个 Worker / Reviewer / Scaffolder 系会话的
独立 entrypoint**，与 Harness 内部的 teammate spawn workflow 分离。

## 适用范围

| 对象 | 使用方法 |
|------|----------|
| Lead（operator，人类） | 使用 `claude agents` 在一个画面中确认多个项目的状态 |
| Harness teammate spawn（Worker / Reviewer / Scaffolder） | 通过 Agent tool / breezing skill 途径，不使用 `claude agents` |
| Codex teammate | 使用 `bash scripts/codex-companion.sh task`（不使用 raw `codex exec` 也不使用 `claude agents`） |

## 动作前提（2.1.139-2.1.142）

- `claude agents --json` 可以 JSON 输出实时会话列表（2.1.145）。仅限于 tmux-resurrect、status bar、session picker 等 **diagnostic / scripting** 用途。不要作为 Harness teammate spawn 的替代。
- agent view 每个会话显示 **running / blocked on you / done**。
- `claude agents --cwd <path>` 可以将会话列表限定在 directory scope（2.1.141）。
- `claude agents` 启动时可以使用 `--add-dir`、`--settings`、`--mcp-config`、`--plugin-dir`、
  `--permission-mode`、`--model`、`--effort`、`--dangerously-skip-permissions` 配置 dispatched
  background session（2.1.142）。
- 通过 Background session 启动的 teammate 保持 permission mode（2.1.141）。不会恢复为 default。

## Harness 安全运用策略

### A. 使用许可

| 使用场景 | 推荐 |
|-----------|------|
| 在当前项目中作业的同时确认其他项目的情况 | `claude agents --cwd <other-project>` |
| 在其他项目中安全地 background dispatch 长运行任务（test / lint） | `claude agents --cwd <path> --permission-mode default --effort low` |
| Read-only 调查 task（想立即确认调查结果） | 使用 `claude agents` 并行启动 |

### B. flag 使用条件

| Flag | 使用条件 | 禁止条件 |
|------|----------|----------|
| `--cwd <path>` | 查看其他项目状态时 | --- |
| `--add-dir` | 扩大搜索 scope 时 | 同目录内包含 secret 的路径（`.env*`、`secrets/**`、`.ssh/**`）在 denyRead 后也禁止 opt-in |
| `--settings <path>` | 开发时试行项目特定设置 | 持续用 `--settings` 覆盖每个 agent 的 `.claude-plugin/settings.json` 禁止（SSOT 崩溃） |
| `--mcp-config <path>` | 试行临时 MCP server | 项目持久 MCP 统一到 `.mcp.json` |
| `--plugin-dir <path>` | 本地测试未发布的 plugin | --- |
| `--permission-mode <mode>` | 明确使用 `default` / `acceptEdits` / `plan` | 在 protected branch（`main`/`master`）上使用 `bypassPermissions` 禁止 |
| `--model <model-id>` | 临时切换 model | 在 release / hotfix 会话中将 model 降级到更小的型号禁止 |
| `--effort <level>` | 根据 task 规模设置强度 | 不能通过 effort 放宽 guard rail（R01-R13） |
| `--dangerously-skip-permissions` | 仅在可信的 ephemeral sandbox 内 | (a) protected branch 上的会话，(b) 读取 credentials 的会话，(c) production deployment 会话中禁止使用 |

### C. teammate spawn 分离

- `claude agents` 是 **operator（人类 Lead）查看多个会话的 UI**。
  Harness 内部的 teammate spawn（Worker / Reviewer / Scaffolder）由 **Agent tool / breezing skill** 启动。
- Worker / Reviewer 不从 `claude agents` spawn 其他会话。仅限 Lead（详细：`.claude/rules/claude-5-prompt-standard.md` 的权限和职责边界）。
- breezing skill 使用 `claude --teammate-mode in-process` / `tmux`。不依赖 `claude agents`。

### D. Background permission mode 保持（2.1.141）

- 通过 `/bg` / `←←` 或 `claude agents` 后台化的 teammate 保持启动时的 permission mode。
- Harness 侧**无需重新注入 permission mode**。breezing teammate 的启动 contract 可以继续使用。
- 确认：如果 teammate 以 `plan` mode 启动，即使后台化后也保持 `plan` mode（CC 本体保证）。

### E. agent view 启动顺序（推荐）

1. operator 打开 `claude` 对话会话。
2. 必要时使用 `claude agents` 确认其他会话的状态。
3. dispatch 不同的 task 时，明确使用 `claude agents --cwd <path> --permission-mode <mode> --effort <level>`。
4. Lead 要启动 breezing 时，不通过 `claude agents` 途径，而是从 `/breezing` skill 启动。

## 违规示例

| 违规 | 影响 | 推荐对策 |
|------|------|----------|
| Worker subagent 调用 `claude agents` spawn 其他会话 | 权限边界崩溃（只有 Lead 可以 spawn） | 从 Worker 步骤中删除 `claude agents` 调用 |
| 在 protected branch（`main`）上使用 `claude agents ... --dangerously-skip-permissions` | guard rail（R12 ask）bypass | 使用 `--permission-mode default` 或 `acceptEdits` |
| 用 `--settings` 覆盖每个 agent 的 `.claude-plugin/settings.json` | settings SSOT 崩溃 | 将更改集中到 project-level `.claude/settings.local.json` |
| 在处理 credentials 的会话（如 `harness-mem`）中使用 `--dangerously-skip-permissions` | secrets 泄露风险 | 移除相应 flag |

## CI / gate

- `tests/validate-plugin.sh` 不验证 `claude agents` flag 的存在（为 CC 本体功能）。
- 代わりに `.claude/rules/claude-5-prompt-standard.md` 的权限边界和 `.claude-plugin/settings.json` 的
  deny 规则作为多层防御发挥作用。
- 如果要审计运用中的 `claude agents` 使用情况，可以通过 env `CLAUDE_CODE_SESSION_ID` 经 webhook
  记录（`scripts/hook-handlers/webhook-notify.sh`）。

## 相关

- `docs/team-composition.md` — teammate spawn 和并行度的 SSOT
- `agents/worker.md` — Worker 契约
- `.claude/rules/claude-5-prompt-standard.md` — 代理契约审计规则（明确 Lead 限定 spawn）
- `docs/upstream-update-snapshot-2026-05-15.md` — Phase 69 snapshot
- `docs/upstream-update-snapshot-2026-05-27.md` — Phase 80 snapshot
- `.claude/rules/hooks-2.1.139-plus.md` — hook 周围的 2.1.133+ 规则
- `.claude/rules/hooks-2.1.152-plus.md` — MessageDisplay / reloadSkills / sessionTitle（2.1.152+）

## 重新审视条件

- CC `claude agents` 升级为 GA（脱离 Research Preview）时 → 重新审视整体策略
- `--dangerously-skip-permissions` flag 被 deprecate / rename 时 → 更新相应的 cell
- Harness teammate spawn 可以集成到 `claude agents` API 时 → 重新审视 C 节（teammate spawn 分离）
