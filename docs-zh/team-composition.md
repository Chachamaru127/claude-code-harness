# 团队构成

Harness 的标准团队构成是 5 个角色。
增加实现类 teammate 时，也不改变这 5 个角色的职责边界。

## 构成图

```text
Lead
├── Worker x 1..3
├── Advisor x 0..1
├── Reviewer x 1
└── Scaffolder x 0..1
```

## spawn 权限

- 只有 Lead 可以 spawn teammate
- Worker 不 spawn teammate
- Reviewer 不 spawn teammate
- Scaffolder 不 spawn teammate
- Worker 想商量时，不增加 subagent，而是返回 `advisor-request.v1`

## role contract

| Role | subagent_type | 数量 | 使用的工具 | 返回内容 |
|------|---------------|----|------------|----------|
| Lead | Execute skill 内部 | 1 | Agent, SendMessage, Bash | task 分解、review 判定、main 反映 |
| Worker | `harness:worker` | 1..3 | Read, Write, Edit, Bash, Grep, Glob | 实现结果或 `advisor-request.v1` |
| Advisor | `harness:advisor` | 0..1 | Read, Grep, Glob | `advisor-response.v1` |
| Reviewer | `harness:reviewer` | 1 | Read, Grep, Glob | `review-result.v1` |

## worker 数量的决定方式

| 条件 | worker 数 |
|------|-----------|
| 写入目标文件为 1 组，或文件相互重叠 | 1 |
| 写入目标文件为 2 组，且互不重叠 | 2 |
| 写入目标文件为 3 组以上，且互不重叠 | 3 |

这里所说的「组」是指即使汇总到同一个 commit 也不会冲突的写入集合。
禁止让 2 个 worker 写同一个文件的拆分方式。

### Opus 4.8 中的显式 spawn

Opus 4.8（host = Lead）默认有少 spawn subagent 的倾向。
因此上述 worker 数量条件应作为 **显式 spawn 触发器** 处理。

- 明明有 2 个独立的写入组，却以「直接做更快」为由收拢到 1 个 worker，在这个场景下是错误的。组数为 2 就 spawn 2 个 worker，3 组以上就 spawn 3 个 worker。
- 反之，1 个文件即可完成的工作或串行依赖任务，不增加 subagent，由 Lead 直接推进。

## Worker stall 时的 re-spawn (CC 2.1.113+)

Lead 在满足以下 2 个条件之一时，对同一 task **最多 1 次** 重新 spawn。

- Plans.md 的 `cc:WIP` 状态超过 **10 分钟**（600 秒）未更新
- CC 本体输出 stall log（`subagents stalling mid-stream fail after 10 minutes`）

重新 spawn 后若相同条件再次出现，则进行 escalation。这不影响 worker 并行数的决定方式，stall 检测仅是 Lead 侧的职责。详情参见 [`agents/worker.md`](../agents/worker.md) 的「Stall 检出 — 2 层防御」。

## 执行流程

1. Lead 分解 task，创建 `sprint-contract`
2. Lead spawn worker
3. Worker 进行实现、preflight、验证、commit 准备
4. 仅当 Worker 遇到商量条件时，返回 `advisor-request.v1`
5. Lead 调用 Advisor，将 `advisor-response.v1` 返回给同一个 Worker
6. Worker 返回结果后，Lead 执行 review
7. 仅当 `APPROVE` 时，Lead 反映到 main

## review loop

| 条件 | Lead 的动作 |
|------|-------------|
| `review-result.v1.verdict == APPROVE` | cherry-pick 并 commit 到 main |
| `review-result.v1.verdict == REQUEST_CHANGES` | 向同一个 Worker 返回修正委托 |
| 修正需要规格・Plans・API・权限・计费・迁移的决策 | 用 AskUserQuestion 获取 user decision。不凭推测修改 |

修正循环最多 3 次。
不进入第 4 次，由 Lead 对 task 进行 escalation。

`harness-review` 在需要时使用 TeamAgent Debate。
这并不是增加 Reviewer 的判定权限，而是为了让 Spec Agent / Plans Agent / Regression Agent / Skeptic Agent 的 read-only 视角相互碰撞而收集材料。
最终 verdict 仍由 Reviewer 基于 `review-result.v1` 和明确的合格线给出。

## SendMessage 的固定模式

Lead 向 Worker 返回修正时，使用以下语法。

```text
SendMessage(
  to: "{worker_agent_id}",
  message: "以下の critical/major 指摘を修正してください:\n\n{issues}\n\n修正後 git commit --amend して完了を返してください。"
)
```

## parallel worktree root

在 fan-out 并行 Worker 之前，Lead 用 `scripts/spawn-parallel.sh <task...>`（或
`harness work --team` 的前段）从 **1 个 base SHA** 创建 worktree。root 仅为
`.harness-worktrees/`（`task-<name>` 下，branch 为 `task/<name>`）。`.claude/worktrees/`
是 CC live agent 专用，不要混淆。规约的正本参见 [`spec.md` 的 Worktree Root Discipline](../spec.md)。

worktree 的**内容**（共享文件由谁写、禁止 `VERSION` bump、生成物在 trunk 重新生成）遵循
[Shared File Discipline](../.claude/rules/shared-file-discipline.md)。Lead 在 sprint contract 中为
`Plans.md` / `CHANGELOG.md` / `spec.md` 各分配 1 名 owner（或没有 owner → Lead 整合时追记），
worker 不触碰分配外的文件。

## breezing 时的 main 反映

Worker 在 worktree 或 feature branch 中 commit。
Lead 在 `APPROVE` 后用以下 2 个命令合并到 main。

```bash
git cherry-pick --no-commit {worktree_commit_hash}
git commit -m "feat: {task_description}"
```

在 Lead 反映到 main 之前，Worker 不将 Plans.md 更新为 `cc:完了`。

## Advisor 的边界

- Advisor 只返回 `PLAN | CORRECTION | STOP`
- Advisor 不返回 `APPROVE | REQUEST_CHANGES`
- Advisor 不编辑代码
- Reviewer 只看最终成果物，而不是 advisor 的提案文
- Phase 61 的 weak-supervision cue 只是增加 Advisor 的输入信息，不增加回复种类或最终判定权限

## Codex bridge

从 Claude Code 委托给 Codex 时，标准命令只有以下 2 个。

```bash
bash scripts/codex-companion.sh task --write "タスク内容"
bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"
```

不要把 raw `codex exec` 写进团队标准步骤。

## 2.1.111 优先规则

- `xhigh` 是 caller 侧的推理强度指定。worker prompt 不从字符串自动判定
- `/ultrareview` 是 caller 侧的 review entrypoint。review artifact 的契约仍为 `review-result.v1`
- `--auto-mode` 是 opt-in rollout。不作为 shipped default

## permission mode

Plugin subagent frontmatter 中不放置 `permissionMode`。
因为 Claude Code 的 plugin agent 会忽略 agent-local `permissionMode`，
权限从父会话和 plugin settings 继承。

安全边界由以下层保证。

- plugin-level hooks
- Go guardrails
- Worker preflight
- Reviewer 判定

`--auto-mode` 是 rollout 用的 opt-in。
不作为默认值。

### background permission mode 保持 (CC 2.1.141+)

用 `/bg` / `←←` / `claude agents` 将 teammate 后台化时，
CC 2.1.141 以后会保持启动时的 permission mode（不会回到 default）。

- Lead 以 `claude agents --permission-mode <mode>` 明示的 mode
  以后台化后仍维持为前提进行运用。
- 不需要对 breezing teammate 重新注入 permission mode。
  以往用 `--auto-mode` 处理的特殊启动，现在由 CC 本体保证 mode 保持。
- 例外：以 `bypassPermissions` 启动的 teammate 也不会 override `.claude-plugin/settings.json` 的
  `permissions.deny` / `autoMode.hard_deny`（多层防御维持）。

### 经由 `claude agents` 的 dispatched session (CC 2.1.142+)

Lead 用 `claude agents --add-dir / --settings / --mcp-config / --plugin-dir /
--permission-mode / --model / --effort / --dangerously-skip-permissions` 启动
dispatched background session 时，参见 `docs/agent-view-policy.md` 的
flag 使用条件。以与 teammate spawn workflow（breezing skill / Agent tool）分离为前提。

## Cursor adapter mapping (candidate)

Cursor host 将核心角色映射到 adapter surface，而不改变核心
Breezing 契约：

| Core role | Cursor adapter surface | Parallelism |
|---|---|---|
| Lead | Parent agent session | Orchestrates only |
| Worker | Task tool / `.cursor/agents/worker.md` | Parallel when file groups do not overlap |
| Advisor | `.cursor/agents/advisor.md` on `advisor-request.v1` | On demand; max 3 per task |
| Reviewer | `.cursor/agents/reviewer.md` (`readonly: true`) | Serial per worker result |
| Scaffolder | Optional Task/subagent | On demand |

Multitask / background agents 可以 fan out Worker，但 **不得** 并行化
Reviewer verdict 或 main-branch cherry-pick。该边界由核心所有。

Model resolution：

```bash
bash scripts/model-routing.sh --host cursor --role <role> --format json
```

显式的 subagent/Task `model` 会覆盖路由后的默认值。Cursor multitask 是
smoke 目标，不是公开支持或 parity 声明。

Verification: `bash tests/test-cursor-adapter-candidate.sh`

## 团队规模

- 标准为 3 到 5 名 teammate
- Harness 的通常构成为 `Worker 1..3 + Reviewer 1`
- Advisor 和 Scaffolder 仅在需要时追加
