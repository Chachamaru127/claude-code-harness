# Hooks `type: "mcp_tool"` 采用判断 (Phase 62.1.3)

> **判断**: **保留 (Phase 62 不采用)**
> **再评价条件**: harness-mem 的 MCP 路径 GA 后，shell wrapper 产生的延迟在 telemetry 中
> 持续每月超过 5 分钟时。

## 一句话概括

Claude Code `2.1.118` 中 hooks 可以使用 `type: "mcp_tool"` 直接调用 MCP 工具。
但 Harness 侧现行 wrapper（`scripts/hook-handlers/*.sh`）产生的延迟基于实测较小，
fallback 设计和 auth scope 的追加検討成本更大，因此 Phase 62 保留并记录。

## 打比方

类似于「买新电动工具的话题」。手动工具（shell wrapper）也能完成工作，
在切换到电动工具（MCP 直连）之前，需要整理插座（auth）的位置和延长线（fallback）。
目前手动的不便还没有那么突出，所以推迟购买。

## 背景

### Claude Code 2.1.118 的变更

- 除了现有的 `type: "command"`（shell script）和 `type: "agent"`（LLM agent）外，
  `type: "mcp_tool"` 现在可以在 PostToolUse / PreToolUse 等场景使用
- 指定 `mcp_tool` 后，hook 执行时可以直接调用 MCP server 的特定工具
- Harness 中 `harness_mem_record_event`、`harness_mem_resume_pack` 等 MCP 工具已存在

### Harness 的现行 hook 实现

| Hook 路径 | 机制 | 示例 |
|-----------|------|-----|
| `scripts/hook-handlers/memory-bridge.sh` | shell wrapper 通过 `curl` 向 harness-mem daemon POST | UserPromptSubmit, PostToolUse |
| `scripts/hook-handlers/memory-session-start.sh` | shell wrapper 通过 `exec` 执行 `harness-mem` 同名 script | SessionStart |
| `scripts/hook-handlers/elicitation-handler.sh` | shell wrapper 通过 `jq` 格式化 input 并以 JSON 形式 stdout 返回 | Elicitation |

这些已在 Phase 49 (XR-003) 布线，目前几乎无动静。

## 比较表

| 视角 | shell wrapper 経由（现状） | `type: "mcp_tool"` 直接调用 |
|------|--------------------------|----------------------------------|
| latency | 50-200ms (curl + jq + daemon RTT) | 推定 10-50ms (CC 内部 MCP client RTT) |
| auth scope | wrapper 不直接持有 token（在 daemon 侧处理） | hook 执行时需要解决 MCP auth scope |
| error 传播 | shell exit code + stderr 粒度低 | MCP RPC error code 粒度高 |
| fallback | wrapper 内已实现 `silent skip` | hook 本身无法 fallback（依赖 CC 侧） |
| 可观测性 | shell 日志输出到 `.claude/state/hook-runs.jsonl` | 通过 OTel 作为 MCP call 可视化 |
| 实现成本 | 现有资产直接使用 | hooks.json schema 扩展 + auth 设计 + fallback 布线 |
| 配布风险 | 低（shell wrapper 幂等性已确保） | 中（MCP server 不达时 hook 可能失败） |

## 判断材料

### (i) PostToolUse 直接调用 `harness_mem_record_event` 时的预测

- **延迟**: 现状 `memory-post-tool-use.sh` 实测（合计 50-150ms）预计可降至 `mcp_tool` 的 10-50ms。
  但 PostToolUse hook 本身不在关键路径上，对用户体感无影响。
- **auth**: `harness_mem_record_event` 需要 harness-mem daemon 的 bearer token（或 local socket）。
  CC 的 MCP client 在 hook 执行上下文是否能保持此 token 未确认。
- **error 传播**: 现状 daemon 不达时 shell wrapper 执行 silent skip，
  `mcp_tool` 要实现同等行为需依赖 CC 侧的 hook timeout / retry 规格。

### (ii) shell wrapper 経由 vs 直接调用的权衡

shell wrapper 的优点:

- 已在 Phase 49 布线，运营上无问题
- 失败时的 silent skip / 部分成功在 wrapper 内闭环
- harness-mem 的 API schema 变更时无需修改 CC 侧 (hooks.json)

`mcp_tool` 的优点:

- CC 内部闭环，外部进程（curl, jq）的依赖消失
- OTel telemetry 一致
- 将来 `harness-mem` 纯 MCP server 化时的自然路径

### (iii) MCP 不达时的 fallback 方针

候选及本案件的选定:

| 方针 | 说明 | 采纳判断 |
|------|------|----------|
| `silent skip` | MCP 不达 = no-op 继续 | **本案件采用时的首选**。与 Phase 49 的现行行为一致 |
| `queue` | 不达时在本地 queue 积累下次 retry | 过度设计（harness-mem 自身有 queue，会二重化） |
| `drop` | 不达时丢弃事件本身 | 会损害 telemetry 准确性，不推荐 |

如采用则统一为 **silent skip**。

### (iv) Phase 61 本地 ledger との関係

Phase 61 引入的 `.claude/state/elicitation/events.jsonl` 作为
harness-mem 不达时的 **append-only fallback** 发挥作用。
`mcp_tool` 采用后，daemon 不达时仍需保留 CC 侧 hook → 本地 ledger 写入的路径。
这意味着要在 CC hook 侧重新实现与现行 wrapper 结构同等的二段防御。

## 结论

| 项目 | 内容 |
|------|------|
| 采纳判断 | **保留** |
| 理由 | 现行 shell wrapper 运营上无问题，`mcp_tool` 采纳需要额外検討 auth / fallback / 与 Phase 61 ledger 的整合 |
| 再评价触发器 | (a) harness-mem 的 MCP 路径 GA、(b) wrapper 延迟在 telemetry 中每月超过 5 分钟、(c) CC 发布 hook auth 官方指南 |
| Phase 62 要做的事 | 仅创建本文档。实现和 hooks.json 变更待下一 Phase 判断 |

## Acceptance 条件 (Phase 62.1.3 DoD)

- [x] 存在 `docs/hooks-mcp-tool-evaluation.md`
- [x] 存在 shell wrapper 経由 vs `type: "mcp_tool"` 直接调用的比较表（latency / auth / error / fallback 的 4 个项目）
- [x] MCP 不达时的 fallback 方针明确为 `silent skip`
- [x] 用 1 段落说明与 Phase 61 ledger 的重复 / 互补关系
- [x] 采纳 / 保留 / 驳回 中以判断结论记录 → **保留**
- [x] 采纳条件（再评价触发器）以 3 个项目书写

## 参考

- Claude Code CHANGELOG `2.1.118`: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- Phase 53 snapshot doc: `docs/upstream-update-snapshot-2026-04-23.md`（`53.1.2 MCP tool hook decision` 中决定仅允许只读 MCP、禁止写入系）
- Phase 49 (XR-003): `.claude-plugin/hooks.json` shell wrapper 布线
- Phase 61: `.claude/state/elicitation/events.jsonl` 本地 ledger
