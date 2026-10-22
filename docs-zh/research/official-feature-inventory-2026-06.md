# 官方 3-CLI 功能清单 (2026-06)

Phase 93.2.1 仅研究认证。本清单根据 **Claude Code Harness (CCH)** 重叠度和采用姿态，固定**官方 host capabilities**。

## 证据来源（repo 优先）

| 来源 | 用途 |
|--------|----------|
| `docs/CLAUDE-feature-table.md` | Claude Code 版本、hooks、Agent Teams、Monitor、worktree、`/loop` |
| `docs/agent-view-policy.md` | `claude agents`（agent view）Research Preview + 标志 |
| `docs/research/cursor-adapter-candidate.md` | `cursor-agent` CLI 标志、stream-json、`--mode ask`、权限模型 |
| `.claude/rules/cursor-cli-only.md` | Cursor companion 策略、permissions.json、读/写拓扑 |
| `.claude/rules/codex-cli-only.md` | Codex companion、app-server、subagent 原生 API |
| `docs/upstream-update-snapshot-2026-04-25.md` | Codex `0.124.0` stable hooks + app-server |
| `docs/upstream-update-snapshot-2026-05-03.md` | Codex `0.128.0` plugin-bundled hooks、MultiAgentV2 |
| `docs/upstream-update-snapshot-2026-05-10.md` | Codex `0.130.0` app-server Thread 分页、ThreadStore resume/fork |
| `spec.md` | `hosts.toml` / `hostgen`、三 host `PreToolUse` 收敛、支持层级 |
| `hosts.toml` | 每主机 hook 事件、matcher、deny 机制 |
| `docs/long-running-harness.md` | `/loop` + `ScheduleWakeup` 动态工作流契约 |

**认证规则：** `not_observed != absent`。无 repo 版本或 GA 证据的行标记为 **unverified**；我们不推断官方缺席。

## 清单（5 列）

| 功能名 | 最低版本 | GA/preview | CCH 重叠 | 采用/替换/丢弃 |
|--------|----------------|------------|----------|-------------------|
| **Claude Code — Agent Teams** | CC `v2.1.71+`（需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`） | preview | `breezing` / `TeammateIdle`・`TaskCompleted` hooks / `docs/team-composition.md` | **采用**（breezing 前提）。GA 时替换抽象化：向 `hosts.toml` + hostgen 的 teammate spawn 描述和 task-dependency 模型靠拢，削减实验标志依赖 |
| **Claude Code — Channels** | unverified（本 repo 无官方版本依据） | unverified | Phase 92.6 `livemsg` / Session Coordination broadcast 设计（`spec.md`） | **丢弃**（本 Phase）。在官方 Channels 规格固定到 repo 之前，不增加 CCH 自身 channel |
| **Claude Code — agent view (`claude agents`)** | CC `v2.1.139+`（`--json` 为 `v2.1.145+`） | preview | `docs/agent-view-policy.md`（operator 专用。与 breezing teammate spawn 分离） | **采用**（仅 operator 监视）。GA 时替换抽象化：以 `orchestration-ledger` + scorecard 为主要 UI，`claude agents` 降级为 diagnostic fallback |
| **Claude Code — dynamic workflows (`/loop`、Cron、ScheduleWakeup)** | CC `v2.1.71+` | GA | `skills/harness-loop` / `docs/long-running-harness.md` | **采用**。GA 时替换抽象化：将 wake 契约（pacing・max-cycles・resume-pack）保持为主机无关的 harness-loop 技能契约，仅替换调度程序 API 名称 |
| **Claude Code — hooks（PreToolUse / PostToolUse / Stop / SessionStart）** | CC `v2.1.50+` 系列（持续扩展。R01-R13 为 `v2.1.77+` deny 尊重） | GA | `hooks/hooks.json` + `bin/harness hook *` + `go/internal/policy` | **采用**（正本）。其他 host 的 PreToolUse 为**替换**目标（hostgen 路由到同一 kernel） |
| **Claude Code — hooks（PreCompact / PostCompact）** | PreCompact `v2.1.105+`、PostCompact `v2.1.76+` | GA | `pre-compact-save` / WIP 警告 agent hook / compaction 事件 ledger | **采用**。作为长时间 Worker 的 compaction 安全阀保持 |
| **Claude Code — Monitor tool** | CC `v2.1.98+`（`monitors` manifest `v2.1.105+`） | GA | CI/部署进度追踪（Feature Table）、Phase 92.6.2 delivery `monitor` 路径 | **采用**（仅 CC）。Codex/Cursor 无 Monitor → `turn` fallback（Plans 92.6.2） |
| **Claude Code — worktree isolation** | CC `v2.1.50+`（`isolation: worktree` / `EnterWorktree`） | GA | `.harness-worktrees/`（并行任务）+ `.claude/worktrees/`（CC 实时隔离。`spec.md` 中分离） | **采用**。CCH 并行 root 以 `.harness-worktrees/` 为正本，CC 原生 worktree 专用 agent 隔离 |
| **Cursor — lifecycle hooks（假设 1.7+ 官方文档）** | unverified（repo 仅 `cursor.com/docs/agent/hooks`。`1.7+` 标注为 Plans 93.2.1 要求） | unverified | `hostgen` → `.cursor/hooks.json` `preToolUse` → `bin/harness hook pre-tool --host cursor` | **采用**（candidate 层级内）。GA 时替换抽象化：仅更新 `hosts.toml` 的 event/matcher/deny 列，R01-R13 本体不变 |
| **Cursor — Stop hook `followup_message`** | unverified（repo 无官方字段依据） | unverified | CC `Stop` / `TeammateIdle` 的 `continue:false` 模式（不同机制） | **丢弃**（不依赖未确认内容）。确认后可在 hostgen 的 stop 响应映射层吸收 |
| **Cursor — `cursor-agent --output-format stream-json`** | CLI `2026.05.28-a70ca7c`（本地 `--help` 确认） | GA | `scripts/cursor-companion.sh` Route A、exit-code-first 契约 | **采用**（headless 委托）。仅使用最终 `.result`，流式传输仅限于进度 UX |
| **Cursor — `--mode ask`（只读硬停止）** | CLI `2026.05.28+`（spike 确认：`--force` 也不能写） | GA | `skills/cursor-ask` / `.claude/rules/cursor-cli-only.md` lean path | **采用**（调查/second-opinion）。写操作分离到 `cursor-do` / `breezing --cursor` |
| **Cursor — `~/.cursor/permissions.json` 允许列表** | unverified（schema 来自 Cursor docs 引用。CLI 版本未固定） | GA | 无（CCH 以 worktree + Lead review + FLOOR 为边界） | **采用**（仅便利性）。**不可替换**：不作为 security boundary 使用（Cursor 官方也为 best-effort） |
| **Cursor — `cursor-agent -p --trust --workspace`** | CLI `2026.05.28+` | GA | `cursor-companion.sh` 必需标志、`*.cursor.sh` 出口允许列表 | **采用**。`--workspace` 仅为 CWD 提示。**替换**：实际 containment 来自专用 `.git` worktree + fingerprint + cherry-pick |
| **Codex — app-server protocol** | Codex `0.124.0` stable+（多环境会话） | GA | `scripts/codex-companion.sh` → 官方 `codex-plugin-cc` app-server | **采用**（通过 companion）。hand-rolled JSON-RPC **丢弃** |
| **Codex — subagents（`spawn_agent` / `wait_agent` 等）** | unverified（`codex-cli-only.md` 作为 skills-codex 例外提及） | unverified | Lead 路径为 `codex-companion.sh task`（禁止 raw spawn） | **采用**（仅在 `skills-codex/` 内）。Lead/breezing 保持 companion **替换** |
| **Codex — PreToolUse hook（Harness 观测：主要是 Bash，官方为 MCP/`apply_patch`/Bash）** | Codex `0.124.0` stable hooks | GA | `hosts.toml` `[codex]` matcher `*` → `bin/harness hook pre-tool --host codex`（R01-R13 重复） | **采用**（hostgen）。按 Plans 93.1.2 的再晋升条件，非 Bash 事件**不采用**（将来通过 hostgen matcher 扩展替换） |
| **Codex — resume thread（`--resume-last` / ThreadStore）** | Codex `0.130.0` stable（ThreadStore resume/fork 改进） | GA | `codex-companion.sh --resume-last`；跨会话为 `harness-mem resume-pack`（不同系统） | **采用**（同一 Codex 线程继续）。跨会话不**替换**为 mem |
| **Codex — plugin-bundled hooks** | Codex `0.128.0` stable+ | GA | Harness no-inline-hooks 策略（upstream snapshot） | **采用**（仅显示/分发判断）。inline hook 推测生成**丢弃** |

## 行数统计

- Claude Code: 8 行
- Cursor: 6 行
- Codex: 5 行
- **数据行总数：19**（不含表头 `^|` 行数为 21）

## 备注

- **CCH 重叠**意味着 Harness 已实现或路由该 capability；采用选择官方表面 vs kernel 抽象。
- **preview 采用**行包含一行 GA 替换抽象化在采用列中。
- 按 `spec.md`，Cursor 保持支持层级 **candidate** / **internal-compatible**；本清单不提升公共 `supported` 声明。

---

> 本清单为手动认证，CI 验证除外。集成时由 Lead 保存到 harness-mem。
